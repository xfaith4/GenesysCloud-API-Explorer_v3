function Get-TestRepoRoot {
    param(
        [string]$StartPath = $PSScriptRoot
    )

    $current = if ($StartPath) { $StartPath } else { (Get-Location).Path }
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        $current = Split-Path -Parent $current
    }

    for ($i = 0; $i -lt 8; $i++) {
        if (Test-Path -LiteralPath (Join-Path -Path $current -ChildPath 'GenesysCloudAPIExplorer.ps1')) {
            return $current
        }

        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }

    throw "Unable to locate repository root from start path: $StartPath"
}

function Join-TestRepoPath {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [string]$StartPath = $PSScriptRoot
    )

    $repoRoot = Get-TestRepoRoot -StartPath $StartPath
    return Join-Path -Path $repoRoot -ChildPath $RelativePath
}

function Import-TestModuleManifest {
    param(
        [Parameter(Mandatory)]
        [string]$ManifestRelativePath,

        [string]$StartPath = $PSScriptRoot
    )

    $manifestPath = Join-TestRepoPath -RelativePath $ManifestRelativePath -StartPath $StartPath
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Module manifest not found: $manifestPath"
    }

    Import-Module -Name $manifestPath -Force -Global -ErrorAction Stop
}

function Import-TestPrimaryModules {
    param(
        [string]$StartPath = $PSScriptRoot
    )

    Import-TestModuleManifest -ManifestRelativePath 'src/GenesysCloud.OpsInsights.Core/GenesysCloud.OpsInsights.Core.psd1' -StartPath $StartPath
    Import-TestModuleManifest -ManifestRelativePath 'src/GenesysCloud.OpsInsights/GenesysCloud.OpsInsights.psd1' -StartPath $StartPath
    Import-TestModuleManifest -ManifestRelativePath 'apps/OpsConsole/OpsConsole.psd1' -StartPath $StartPath
}

function Get-AstParseInfo {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)

    return [pscustomobject]@{
        Path   = $Path
        Ast    = $ast
        Tokens = @($tokens)
        Errors = @($errors)
    }
}

function Get-SourceScriptPaths {
    param(
        [string]$StartPath = $PSScriptRoot
    )

    $repoRoot = Get-TestRepoRoot -StartPath $StartPath
    $paths = New-Object System.Collections.Generic.List[string]

    $includePatterns = @('*.ps1', '*.psm1')
    $roots = @(
        (Join-Path -Path $repoRoot -ChildPath 'src'),
        (Join-Path -Path $repoRoot -ChildPath 'apps/OpsConsole'),
        (Join-Path -Path $repoRoot -ChildPath 'Scripts/GenesysCloud.NotificationsToolkit'),
        (Join-Path -Path $repoRoot -ChildPath 'GenesysCloudAPIExplorer.ps1')
    )

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }

        if (Test-Path -LiteralPath $root -PathType Leaf) {
            $paths.Add((Resolve-Path -LiteralPath $root).Path) | Out-Null
            continue
        }

        foreach ($pattern in $includePatterns) {
            $files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $paths.Add($f.FullName) | Out-Null
            }
        }
    }

    return @($paths.ToArray() | Sort-Object -Unique)
}

function Get-FunctionDefinitionsFromFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IncludeNested
    )

    $parseInfo = Get-AstParseInfo -Path $Path
    if ($parseInfo.Errors.Count -gt 0) {
        $messages = $parseInfo.Errors | ForEach-Object { $_.Message }
        throw "Cannot build function inventory for $Path because parsing failed: $($messages -join ' | ')"
    }

    $repoRoot = Get-TestRepoRoot -StartPath $Path
    $searchNested = $IncludeNested.IsPresent
    $functionAsts = @(
        $parseInfo.Ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $searchNested
        )
    )

    $items = foreach ($func in $functionAsts) {
        [pscustomobject]@{
            Name         = $func.Name
            SourcePath   = $Path
            RelativePath = $Path.Replace(($repoRoot + '\'), '')
            StartLine    = $func.Extent.StartLineNumber
            EndLine      = $func.Extent.EndLineNumber
            Definition   = [string]$func.Extent.Text
            IsFilter     = [bool]$func.IsFilter
        }
    }

    return @($items)
}

function Get-SourceFunctionInventory {
    param(
        [string]$StartPath = $PSScriptRoot,
        [switch]$IncludeNested
    )

    $items = New-Object System.Collections.Generic.List[object]
    $paths = Get-SourceScriptPaths -StartPath $StartPath
    foreach ($path in $paths) {
        $defs = Get-FunctionDefinitionsFromFile -Path $path -IncludeNested:$IncludeNested.IsPresent
        foreach ($def in $defs) {
            $items.Add($def) | Out-Null
        }
    }

    return $items.ToArray()
}

function Get-UiRunFindNameTargets {
    param(
        [Parameter(Mandatory)]
        [string]$UiRunScriptPath
    )

    $raw = Get-Content -LiteralPath $UiRunScriptPath -Raw
    $matches = [System.Text.RegularExpressions.Regex]::Matches($raw, 'FindName\("(?<name>[^"]+)"\)')
    $names = foreach ($m in $matches) {
        $m.Groups['name'].Value
    }

    return @($names | Sort-Object -Unique)
}

function Get-XamlNamedTargets {
    param(
        [Parameter(Mandatory)]
        [string]$XamlPath
    )

    $raw = Get-Content -LiteralPath $XamlPath -Raw
    $matches = [System.Text.RegularExpressions.Regex]::Matches($raw, '(?:x:Name|Name)="(?<name>[^"]+)"')
    $names = foreach ($m in $matches) {
        $m.Groups['name'].Value
    }

    return @($names | Sort-Object -Unique)
}
