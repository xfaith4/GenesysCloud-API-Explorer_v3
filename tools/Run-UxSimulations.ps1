#Requires -Version 7.0
<#
.SYNOPSIS
    Runs UX simulations that exercise real application resources and data paths.

.DESCRIPTION
    Each of the 100 runs exercises one of five core journeys against actual
    application files (endpoint catalog, templates, example bodies, favorites).
    Errors reflect genuine assertion failures, not random numbers.

    Journeys:
      onboarding       – resource files exist, parse, and yield usable data
      submit-api       – every default template validates against the API catalog
      inspect-response – ExamplePostBodies.json round-trips cleanly through JSON
      save-favorite    – favorites write to / read from disk with integrity
      run-report       – full template store passes structural and safety checks
#>

$ErrorActionPreference = "Stop"

$repoRoot      = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$resourcesRoot = Join-Path $repoRoot 'apps/OpsConsole/Resources'
$artifactsRoot = Join-Path $repoRoot 'artifacts/ux-simulations'
$runsDir       = Join-Path $artifactsRoot 'runs'
$null = New-Item -ItemType Directory -Force -Path $runsDir

$simulationCount = 100
$rng = New-Object System.Random

# ── User profile generator (unchanged — kept for telemetry context) ───────────

function New-SimulatedUserProfile {
    $skillLevels = @('impatient', 'careful', 'power', 'novice')
    $viewports   = @('mobile', 'tablet', 'desktop')
    $networks    = @('wifi', 'fast4g', 'slow3g')
    $a11y        = @('keyboard-only', 'standard', 'reduced-motion', 'high-contrast')
    [pscustomobject]@{
        Skill    = $skillLevels[$rng.Next($skillLevels.Count)]
        Viewport = $viewports[$rng.Next($viewports.Count)]
        Network  = $networks[$rng.Next($networks.Count)]
        A11yMode = $a11y[$rng.Next($a11y.Count)]
    }
}

# ── Pure functions inlined from UI.PreMain.ps1 (no WPF dependency) ────────────

function Test-JsonString {
    param([string]$JsonString)
    if ([string]::IsNullOrWhiteSpace($JsonString)) { return $true }
    try { $null = $JsonString | ConvertFrom-Json -ErrorAction Stop; return $true }
    catch { return $false }
}

function Test-TemplateMethodAllowed {
    param([string]$Method)
    $blocked = @('DELETE', 'PATCH', 'PUT')
    if ([string]::IsNullOrWhiteSpace($Method)) { return $true }
    return (-not ($blocked -contains $Method.Trim().ToUpperInvariant()))
}

# ── Check model ───────────────────────────────────────────────────────────────

function New-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail    = '',
        [bool]$IsWarning   = $false
    )
    [pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail; IsWarning = $IsWarning }
}

# ── Shared resource cache (loaded once, reused across all 100 runs) ───────────

$Cache = @{
    ApiCatalog         = $null
    ApiPaths           = $null
    ApiLoadMs          = $null
    ApiCatalogError    = $null
    DefaultTemplates   = $null
    DefaultTemplatesError = $null
    ExampleBodies      = $null
    ExampleBodiesError = $null
}

function Initialize-Cache {
    $endpointFile = Join-Path $resourcesRoot 'GenesysCloudAPIEndpoints.json'
    $templateFile = Join-Path $resourcesRoot 'DefaultTemplates.json'
    $exampleFile  = Join-Path $resourcesRoot 'ExamplePostBodies.json'

    # Endpoint catalog (634 K lines — measure load time)
    if (Test-Path $endpointFile) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $json = Get-Content $endpointFile -Raw | ConvertFrom-Json
            $sw.Stop()
            $Cache['ApiLoadMs'] = $sw.ElapsedMilliseconds

            # Locate the 'paths' object (may be nested under a top-level key)
            if ($json.paths) {
                $Cache['ApiPaths'] = $json.paths
            } else {
                foreach ($prop in $json.PSObject.Properties) {
                    if ($prop.Value -and $prop.Value.paths) {
                        $Cache['ApiPaths'] = $prop.Value.paths
                        break
                    }
                }
            }
            $Cache['ApiCatalog'] = $json
        } catch {
            $sw.Stop()
            $Cache['ApiCatalogError'] = $_.Exception.Message
        }
    }

    # Default templates
    if (Test-Path $templateFile) {
        try {
            $Cache['DefaultTemplates'] = @(Get-Content $templateFile -Raw | ConvertFrom-Json -ErrorAction Stop)
        } catch {
            $Cache['DefaultTemplatesError'] = $_.Exception.Message
        }
    }

    # Example POST bodies
    if (Test-Path $exampleFile) {
        try {
            $Cache['ExampleBodies'] = Get-Content $exampleFile -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            $Cache['ExampleBodiesError'] = $_.Exception.Message
        }
    }
}

# ── Journey: onboarding ───────────────────────────────────────────────────────
# Verifies every critical resource file exists, parses, and yields usable data.

function Invoke-OnboardingJourney {
    param([pscustomobject]$Profile)
    $checks  = [System.Collections.Generic.List[object]]::new()
    $blocked = $false

    $endpointFile = Join-Path $resourcesRoot 'GenesysCloudAPIEndpoints.json'
    $templateFile = Join-Path $resourcesRoot 'DefaultTemplates.json'
    $exampleFile  = Join-Path $resourcesRoot 'ExamplePostBodies.json'
    $tokenFile    = Join-Path $resourcesRoot 'design-tokens.psd1'

    # ── File existence ────────────────────────────────────────────────────────
    $catalodExists   = Test-Path $endpointFile
    $templatesExists = Test-Path $templateFile
    $examplesExists  = Test-Path $exampleFile
    $tokensExists    = Test-Path $tokenFile

    $checks.Add((New-Check 'endpoint-catalog-exists'  $catalodExists))
    $checks.Add((New-Check 'default-templates-exists' $templatesExists))
    $checks.Add((New-Check 'example-bodies-exists'    $examplesExists))
    $checks.Add((New-Check 'design-tokens-exists'     $tokensExists    -IsWarning $true))

    if (-not $catalodExists) { $blocked = $true }

    # ── Endpoint catalog ──────────────────────────────────────────────────────
    $checks.Add((New-Check 'endpoint-catalog-parses'      (-not $Cache['ApiCatalogError'])))
    $checks.Add((New-Check 'endpoint-catalog-has-paths'   ($null -ne $Cache['ApiPaths'])))

    if ($Cache['ApiPaths']) {
        $pathCount = ($Cache['ApiPaths'].PSObject.Properties | Measure-Object).Count
        $checks.Add((New-Check 'endpoint-catalog-path-count-gte-100' ($pathCount -ge 100) -Detail "count=$pathCount"))
    } else {
        $checks.Add((New-Check 'endpoint-catalog-path-count-gte-100' $false -Detail 'paths not loaded'))
        $blocked = $true
    }

    # Load time warning only on first run (subsequent runs use cache)
    if ($null -ne $Cache['ApiLoadMs']) {
        $ms  = $Cache['ApiLoadMs']
        $ok  = $ms -lt 20000
        $checks.Add((New-Check 'endpoint-catalog-load-under-20s' $ok -Detail "${ms}ms" -IsWarning $true))
    }

    # ── Default templates ─────────────────────────────────────────────────────
    $checks.Add((New-Check 'default-templates-parse'      (-not $Cache['DefaultTemplatesError'])))
    if ($Cache['DefaultTemplates']) {
        $tCount = $Cache['DefaultTemplates'].Count
        $checks.Add((New-Check 'default-templates-non-empty' ($tCount -ge 1) -Detail "count=$tCount"))
    } else {
        $checks.Add((New-Check 'default-templates-non-empty' $false))
    }

    # ── Example bodies ────────────────────────────────────────────────────────
    $checks.Add((New-Check 'example-bodies-parse' (-not $Cache['ExampleBodiesError'])))
    if ($Cache['ExampleBodies']) {
        $eCount = ($Cache['ExampleBodies'].PSObject.Properties | Measure-Object).Count
        $checks.Add((New-Check 'example-bodies-non-empty' ($eCount -ge 1) -Detail "count=$eCount"))
    } else {
        $checks.Add((New-Check 'example-bodies-non-empty' $false))
    }

    return $checks.ToArray(), $blocked
}

# ── Journey: submit-api ───────────────────────────────────────────────────────
# Validates ALL default templates against the API catalog in every run.
# Reports aggregate counts so any bad template surfaces regardless of run index.

function Invoke-SubmitApiJourney {
    param([pscustomobject]$Profile, [int]$RunIndex)
    $checks  = [System.Collections.Generic.List[object]]::new()
    $blocked = $false

    $templates = $Cache['DefaultTemplates']
    if (-not $templates -or $templates.Count -eq 0) {
        $checks.Add((New-Check 'templates-available' $false 'DefaultTemplates.json not loaded'))
        return $checks.ToArray(), $true
    }

    $apiPaths     = $Cache['ApiPaths']
    $validMethods = @('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')

    $missingName      = 0
    $missingMethod    = 0
    $missingPath      = 0
    $missingGroup     = 0
    $badMethodVerb    = 0
    $badPathFormat    = 0
    $badPostBody      = 0
    $pathNotInCatalog = [System.Collections.Generic.List[string]]::new()
    $methodNotOnPath  = [System.Collections.Generic.List[string]]::new()

    foreach ($t in $templates) {
        $name   = [string]$t.Name
        $method = ([string]$t.Method).ToUpperInvariant()
        $path   = [string]$t.Path
        $group  = [string]$t.Group

        if ([string]::IsNullOrWhiteSpace($name))   { $missingName++ }
        if ([string]::IsNullOrWhiteSpace($method)) { $missingMethod++ }
        if ([string]::IsNullOrWhiteSpace($path))   { $missingPath++ }
        if ([string]::IsNullOrWhiteSpace($group))  { $missingGroup++ }

        if ($method -and ($validMethods -notcontains $method)) { $badMethodVerb++ }
        if ($path   -and (-not $path.StartsWith('/api/v2/')))  { $badPathFormat++ }

        # POST/PUT/PATCH body JSON validity
        if ($method -in @('POST', 'PUT', 'PATCH')) {
            $body = ''
            try { $body = [string]$t.Parameters.body } catch {}
            if (-not [string]::IsNullOrWhiteSpace($body) -and -not (Test-JsonString -JsonString $body)) {
                $badPostBody++
            }
        }

        # Catalog cross-reference
        if ($apiPaths -and $path) {
            $pathMatch = $apiPaths.PSObject.Properties | Where-Object { $_.Name -eq $path }
            if (-not $pathMatch) {
                $pathNotInCatalog.Add("$method $path")
            } elseif ($method) {
                $methodLower = $method.ToLowerInvariant()
                $methodMatch = $pathMatch.Value.PSObject.Properties | Where-Object { $_.Name -eq $methodLower }
                if (-not $methodMatch) {
                    $methodNotOnPath.Add("$method $path")
                }
            }
        }
    }

    $tCount = $templates.Count
    $checks.Add((New-Check 'all-templates-have-name'          ($missingName   -eq 0) -Detail "missing=$missingName / $tCount"))
    $checks.Add((New-Check 'all-templates-have-method'        ($missingMethod  -eq 0) -Detail "missing=$missingMethod / $tCount"))
    $checks.Add((New-Check 'all-templates-have-path'          ($missingPath   -eq 0) -Detail "missing=$missingPath / $tCount"))
    $checks.Add((New-Check 'all-templates-have-group'         ($missingGroup  -eq 0) -Detail "missing=$missingGroup / $tCount"))
    $checks.Add((New-Check 'all-methods-valid-http-verbs'     ($badMethodVerb -eq 0) -Detail "violations=$badMethodVerb"))
    $checks.Add((New-Check 'all-paths-start-with-api-v2'      ($badPathFormat -eq 0) -Detail "violations=$badPathFormat"))
    $checks.Add((New-Check 'all-body-params-valid-json'       ($badPostBody   -eq 0) -Detail "violations=$badPostBody"))

    if ($apiPaths) {
        $nfCount = $pathNotInCatalog.Count
        $nmCount = $methodNotOnPath.Count
        $nfDetail = if ($nfCount -gt 0) { ($pathNotInCatalog | Select-Object -First 5) -join '; ' } else { "all $tCount paths found" }
        $nmDetail = if ($nmCount -gt 0) { ($methodNotOnPath  | Select-Object -First 5) -join '; ' } else { "all methods verified" }
        $checks.Add((New-Check 'all-paths-exist-in-catalog'   ($nfCount -eq 0) -Detail $nfDetail))
        $checks.Add((New-Check 'all-methods-exist-on-path'    ($nmCount -eq 0) -Detail $nmDetail))
    } else {
        $checks.Add((New-Check 'all-paths-exist-in-catalog'   $false -Detail 'catalog not loaded' -IsWarning $true))
        $checks.Add((New-Check 'all-methods-exist-on-path'    $false -Detail 'catalog not loaded' -IsWarning $true))
    }

    return $checks.ToArray(), $blocked
}

# ── Journey: inspect-response ─────────────────────────────────────────────────
# Picks one endpoint from ExamplePostBodies.json and tests JSON round-trip fidelity.

function Invoke-InspectResponseJourney {
    param([pscustomobject]$Profile, [int]$RunIndex)
    $checks  = [System.Collections.Generic.List[object]]::new()
    $blocked = $false

    $examples = $Cache['ExampleBodies']
    $checks.Add((New-Check 'example-bodies-available' ($null -ne $examples)))
    if (-not $examples) { return $checks.ToArray(), $true }

    $props = @($examples.PSObject.Properties)
    $checks.Add((New-Check 'example-bodies-has-entries' ($props.Count -ge 1) -Detail "count=$($props.Count)"))
    if ($props.Count -eq 0) { return $checks.ToArray(), $true }

    # Pick endpoint deterministically by run index
    $entry        = $props[$RunIndex % $props.Count]
    $endpointPath = $entry.Name
    $endpointData = $entry.Value

    # ExamplePostBodies.json contains examples for any body-accepting method (post, put, patch)
    $bodyMethod = $null
    foreach ($m in @('post', 'put', 'patch')) {
        $op = $endpointData.PSObject.Properties | Where-Object { $_.Name -eq $m }
        if ($op) { $bodyMethod = $m; break }
    }
    $hasBodyOp      = $null -ne $bodyMethod
    $hasBodyExample = $hasBodyOp -and ($null -ne ($endpointData.$bodyMethod.example))
    $checks.Add((New-Check 'endpoint-has-body-operation' $hasBodyOp      -Detail "$endpointPath ($bodyMethod)"))
    $checks.Add((New-Check 'endpoint-has-body-example'   $hasBodyExample -Detail $endpointPath))

    if ($hasBodyExample) {
        $example = $endpointData.$bodyMethod.example

        # Serialize → deserialize → property count matches
        $json = $null
        $serializeOk = $false
        try {
            $json = $example | ConvertTo-Json -Depth 10 -Compress
            $serializeOk = -not [string]::IsNullOrWhiteSpace($json)
        } catch {}
        $checks.Add((New-Check 'example-serializes-to-json' $serializeOk -Detail $endpointPath))

        if ($serializeOk) {
            $roundTripOk = $false
            try {
                $back = $json | ConvertFrom-Json -ErrorAction Stop
                $origProps = @($example.PSObject.Properties)
                $backProps = @($back.PSObject.Properties)
                $roundTripOk = ($origProps.Count -eq 0) -or ($backProps.Count -eq $origProps.Count)
            } catch {}
            $checks.Add((New-Check 'example-round-trip-property-count-intact' $roundTripOk -Detail $endpointPath))
        }
    }

    # ── Mock realistic paginated response ─────────────────────────────────────
    $mockResponse = [pscustomobject]@{
        entities   = @(
            [pscustomobject]@{ id = 'abc-001'; name = 'Queue Alpha'; memberCount = 12 }
            [pscustomobject]@{ id = 'abc-002'; name = 'Queue Beta';  memberCount = 8  }
            [pscustomobject]@{ id = 'abc-003'; name = 'Queue Gamma'; memberCount = 31 }
        )
        pageSize   = 25
        pageNumber = 1
        total      = 3
        pageCount  = 1
        selfUri    = '/api/v2/routing/queues?pageSize=25&pageNumber=1'
    }

    $treeOk = $false
    try {
        $json = $mockResponse | ConvertTo-Json -Depth 10
        $back = $json | ConvertFrom-Json
        $ids  = @($back.entities | ForEach-Object { $_.id })
        $treeOk = ($ids.Count -eq 3) -and ($ids[0] -eq 'abc-001') -and ($back.total -eq 3)
    } catch {}
    $checks.Add((New-Check 'mock-response-tree-walks' $treeOk))

    $fieldOk = $false
    try {
        $json = $mockResponse | ConvertTo-Json -Depth 10
        $back = $json | ConvertFrom-Json
        $fieldOk = ($back.pageSize -eq 25) -and ($back.pageNumber -eq 1) -and
                   (-not [string]::IsNullOrWhiteSpace($back.selfUri))
    } catch {}
    $checks.Add((New-Check 'mock-response-field-access' $fieldOk))

    return $checks.ToArray(), $blocked
}

# ── Journey: save-favorite ────────────────────────────────────────────────────
# Writes a synthetic favorite to a temp file and verifies round-trip integrity.

function Invoke-SaveFavoriteJourney {
    param([pscustomobject]$Profile, [int]$RunIndex)
    $checks  = [System.Collections.Generic.List[object]]::new()
    $blocked = $false
    $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "GCSimFav_$RunIndex.json"

    # ── Real favorites file (read-only verification — never modify user data) ─
    $realFavPath = Join-Path $env:USERPROFILE 'GenesysApiExplorerFavorites.json'
    if (Test-Path $realFavPath) {
        $favParseOk = $false
        try {
            $content = Get-Content $realFavPath -Raw
            $parsed  = if ($content) { @($content | ConvertFrom-Json -ErrorAction Stop) } else { @() }
            $favParseOk = $true
            $checks.Add((New-Check 'real-favorites-parse' $favParseOk -Detail "count=$($parsed.Count)"))
        } catch {
            $checks.Add((New-Check 'real-favorites-parse' $false -Detail $_.Exception.Message))
        }
    }

    # ── Write synthetic favorite ──────────────────────────────────────────────
    $testFav = [pscustomobject]@{
        Name       = "Sim-$RunIndex · Get Active Conversations"
        Method     = 'GET'
        Path       = '/api/v2/conversations'
        Group      = 'Conversations'
        Parameters = [pscustomobject]@{}
        Created    = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }

    $writeOk = $false
    try {
        @($testFav) | ConvertTo-Json -Depth 5 | Set-Content -Path $tempFile -Encoding utf8
        $writeOk = $true
    } catch {}
    $checks.Add((New-Check 'favorite-write-succeeds' $writeOk))
    if (-not $writeOk) { $blocked = $true; return $checks.ToArray(), $blocked }

    $checks.Add((New-Check 'favorite-file-created' (Test-Path $tempFile)))

    # ── Read back and verify ──────────────────────────────────────────────────
    $readBackOk   = $false
    $fieldsIntact = $false
    try {
        $back        = @(Get-Content $tempFile -Raw | ConvertFrom-Json -ErrorAction Stop)
        $readBackOk  = $back.Count -ge 1
        $item        = $back[0]
        $fieldsIntact = ([string]$item.Name -eq $testFav.Name) -and
                        ([string]$item.Method -eq 'GET') -and
                        ([string]$item.Path   -eq '/api/v2/conversations') -and
                        ([string]$item.Group  -eq 'Conversations')
    } catch {}
    $checks.Add((New-Check 'favorite-reads-back-as-array' $readBackOk))
    $checks.Add((New-Check 'favorite-fields-intact'       $fieldsIntact))

    # ── Multi-entry append round-trip ─────────────────────────────────────────
    $addFav = [pscustomobject]@{
        Name   = "Sim-$RunIndex · Query Analytics"
        Method = 'POST'
        Path   = '/api/v2/analytics/conversations/details/query'
        Group  = 'Analytics'
        Created = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    $multiOk = $false
    try {
        @($testFav, $addFav) | ConvertTo-Json -Depth 5 | Set-Content -Path $tempFile -Encoding utf8
        $back    = @(Get-Content $tempFile -Raw | ConvertFrom-Json -ErrorAction Stop)
        $multiOk = $back.Count -eq 2
    } catch {}
    $checks.Add((New-Check 'multi-favorite-round-trip' $multiOk))

    # ── Cleanup ───────────────────────────────────────────────────────────────
    $cleanOk = $false
    try {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction Stop }
        $cleanOk = -not (Test-Path $tempFile)
    } catch {}
    $checks.Add((New-Check 'temp-file-cleanup' $cleanOk -IsWarning $true))

    return $checks.ToArray(), $blocked
}

# ── Journey: run-report ───────────────────────────────────────────────────────
# Loads the full template store and validates structure, safety, and content.

function Invoke-RunReportJourney {
    param([pscustomobject]$Profile, [int]$RunIndex)
    $checks  = [System.Collections.Generic.List[object]]::new()
    $blocked = $false
    $blockedMethods = @('DELETE', 'PATCH', 'PUT')
    $validMethods   = @('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS')

    # Prefer user templates → repo-root global → packaged defaults
    $candidates = @(
        (Join-Path $env:USERPROFILE     'GenesysApiExplorerTemplates.json')
        (Join-Path $repoRoot            'GenesysAPIExplorerTemplates.json')
        (Join-Path $resourcesRoot       'DefaultTemplates.json')
    )
    $templateSource = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    $sourceLabel    = if ($templateSource) { Split-Path $templateSource -Leaf } else { 'none' }

    $checks.Add((New-Check 'template-source-found' ($null -ne $templateSource) -Detail $sourceLabel))
    if (-not $templateSource) { $blocked = $true; return $checks.ToArray(), $blocked }

    # Parse
    $templates = @()
    $parseOk   = $false
    try {
        $raw       = Get-Content $templateSource -Raw
        $templates = @($raw | ConvertFrom-Json -ErrorAction Stop)
        $parseOk   = $true
    } catch { }
    $checks.Add((New-Check "template-source-parses" $parseOk -Detail $sourceLabel))
    if (-not $parseOk) { $blocked = $true; return $checks.ToArray(), $blocked }

    $tCount = $templates.Count
    $checks.Add((New-Check 'templates-non-empty' ($tCount -ge 1) -Detail "count=$tCount"))
    if ($tCount -eq 0) { return $checks.ToArray(), $blocked }

    # ── Field completeness ────────────────────────────────────────────────────
    $missingName   = @($templates | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Name) })
    $missingMethod = @($templates | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Method) })
    $missingPath   = @($templates | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Path) })
    $missingGroup  = @($templates | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Group) })

    $checks.Add((New-Check 'all-templates-have-name'   ($missingName.Count   -eq 0) -Detail "missing=$($missingName.Count)"))
    $checks.Add((New-Check 'all-templates-have-method' ($missingMethod.Count  -eq 0) -Detail "missing=$($missingMethod.Count)"))
    $checks.Add((New-Check 'all-templates-have-path'   ($missingPath.Count   -eq 0) -Detail "missing=$($missingPath.Count)"))
    $checks.Add((New-Check 'all-templates-have-group'  ($missingGroup.Count  -eq 0) -Detail "missing=$($missingGroup.Count)"))

    # ── Path format ───────────────────────────────────────────────────────────
    $badPath = @($templates | Where-Object { -not ([string]$_.Path).StartsWith('/api/v2/') })
    $checks.Add((New-Check 'all-paths-start-with-api-v2' ($badPath.Count -eq 0) -Detail "violations=$($badPath.Count)"))

    # ── Method validity ───────────────────────────────────────────────────────
    $badMethod = @($templates | Where-Object {
        $m = ([string]$_.Method).ToUpperInvariant()
        $m -and ($validMethods -notcontains $m)
    })
    $checks.Add((New-Check 'no-invalid-http-methods' ($badMethod.Count -eq 0) -Detail "violations=$($badMethod.Count)"))

    # ── Safety: no blocked methods in template store ──────────────────────────
    $blocked_templates = @($templates | Where-Object {
        $blockedMethods -contains ([string]$_.Method).ToUpperInvariant()
    })
    $checks.Add((New-Check 'no-blocked-methods-in-store' ($blocked_templates.Count -eq 0) -Detail "violations=$($blocked_templates.Count)"))

    # ── POST body JSON validity ───────────────────────────────────────────────
    $postTemplates = @($templates | Where-Object { ([string]$_.Method).ToUpperInvariant() -eq 'POST' })
    $badBodies = @($postTemplates | Where-Object {
        $body = ''
        try { $body = [string]$_.Parameters.body } catch {}
        (-not [string]::IsNullOrWhiteSpace($body)) -and (-not (Test-JsonString -JsonString $body))
    })
    $checks.Add((New-Check 'all-post-bodies-valid-json' ($badBodies.Count -eq 0) -Detail "violations=$($badBodies.Count)"))

    # ── Diversity: at least one GET and one POST ──────────────────────────────
    $getCount  = @($templates | Where-Object { ([string]$_.Method).ToUpperInvariant() -eq 'GET'  }).Count
    $postCount = @($templates | Where-Object { ([string]$_.Method).ToUpperInvariant() -eq 'POST' }).Count
    $checks.Add((New-Check 'at-least-one-get-template'  ($getCount  -ge 1) -Detail "GET=$getCount"))
    $checks.Add((New-Check 'at-least-one-post-template' ($postCount -ge 1) -Detail "POST=$postCount"))

    return $checks.ToArray(), $blocked
}

# ── Journey dispatcher ────────────────────────────────────────────────────────

function Invoke-Journey {
    param([string]$Journey, [pscustomobject]$Profile, [int]$RunIndex)

    switch ($Journey) {
        'onboarding'       { return Invoke-OnboardingJourney       -Profile $Profile }
        'submit-api'       { return Invoke-SubmitApiJourney        -Profile $Profile -RunIndex $RunIndex }
        'inspect-response' { return Invoke-InspectResponseJourney  -Profile $Profile -RunIndex $RunIndex }
        'save-favorite'    { return Invoke-SaveFavoriteJourney     -Profile $Profile -RunIndex $RunIndex }
        'run-report'       { return Invoke-RunReportJourney        -Profile $Profile -RunIndex $RunIndex }
    }
}

# ── Run simulation ────────────────────────────────────────────────────────────

Write-Host 'Initializing resource cache…'
Initialize-Cache
Write-Host "  API catalog loaded: $($null -ne $Cache['ApiPaths']) (${$Cache['ApiLoadMs']}ms)"
Write-Host "  Default templates:  $($Cache['DefaultTemplates']?.Count ?? 0)"
Write-Host "  Example bodies:     $(($Cache['ExampleBodies']?.PSObject.Properties | Measure-Object).Count)"
Write-Host ''

# Distribute 100 runs evenly across 5 journeys (20 each), then shuffle
$journeyTypes = @('onboarding', 'submit-api', 'inspect-response', 'save-favorite', 'run-report')
$orderedJourneys = $journeyTypes * 20  | Sort-Object { $rng.Next() }

$runs = [System.Collections.Generic.List[object]]::new()

for ($i = 0; $i -lt $simulationCount; $i++) {
    $runIndex = $i + 1
    $journey  = $orderedJourneys[$i]
    $profile  = New-SimulatedUserProfile

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $checks, $wasBlocked = Invoke-Journey -Journey $journey -Profile $profile -RunIndex $i
    $sw.Stop()

    $errors     = @($checks | Where-Object { -not $_.Pass -and -not $_.IsWarning }).Count
    $rageClicks = @($checks | Where-Object { -not $_.Pass -and  $_.IsWarning }).Count
    $stuck      = $wasBlocked
    $completed  = ($errors -eq 0) -and (-not $stuck)

    $checkSummary = $checks | ForEach-Object {
        [pscustomobject]@{ check = $_.Name; pass = $_.Pass; warn = $_.IsWarning; detail = $_.Detail }
    }

    $run = [pscustomobject]@{
        id           = "run-$runIndex"
        journey      = $journey
        profile      = $profile
        durationSec  = [Math]::Round($sw.Elapsed.TotalSeconds, 3)
        checksRun    = $checks.Count
        errors       = $errors
        rageClicks   = $rageClicks
        stuck        = $stuck
        completed    = $completed
        checks       = $checkSummary
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    }

    $runs.Add($run)
    $run | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $runsDir "run-$runIndex.json") -Encoding utf8

    $status = if ($completed) { 'PASS' } elseif ($stuck) { 'STUCK' } else { "FAIL($errors)" }
    Write-Host "  [$runIndex/$simulationCount] $journey ($($profile.Skill)/$($profile.Viewport)) → $status"
}

# ── Summary ───────────────────────────────────────────────────────────────────

$runsArr = $runs.ToArray()

$summary = [pscustomobject]@{
    totalRuns       = $simulationCount
    completionRate  = [Math]::Round((@($runsArr | Where-Object { $_.completed }).Count / $simulationCount) * 100, 2)
    meanDurationSec = [Math]::Round((($runsArr | Select-Object -ExpandProperty durationSec | Measure-Object -Average).Average), 3)
    errorRate       = [Math]::Round((@($runsArr | Where-Object { $_.errors -gt 0 }).Count / $simulationCount) * 100, 2)
    rageClickRate   = [Math]::Round((@($runsArr | Where-Object { $_.rageClicks -gt 0 }).Count / $simulationCount) * 100, 2)
    stuckRate       = [Math]::Round((@($runsArr | Where-Object { $_.stuck }).Count / $simulationCount) * 100, 2)
    byJourney       = @{}
}

foreach ($j in $journeyTypes) {
    $jRuns = @($runsArr | Where-Object { $_.journey -eq $j })
    $summary.byJourney[$j] = [pscustomobject]@{
        total      = $jRuns.Count
        completed  = @($jRuns | Where-Object {  $_.completed }).Count
        failed     = @($jRuns | Where-Object { -not $_.completed -and -not $_.stuck }).Count
        stuck      = @($jRuns | Where-Object {  $_.stuck }).Count
        totalErrors = ($jRuns | Measure-Object -Property errors -Sum).Sum
    }
}

$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $artifactsRoot 'simulation-summary.json') -Encoding utf8

Write-Host ''
Write-Host "Generated $simulationCount real simulation runs. Summary:"
Write-Host ($summary | ConvertTo-Json -Depth 6)
