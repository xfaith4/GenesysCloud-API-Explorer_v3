"00_README.md": """# Ops Console 2-Stage Prompt Chain

This bundle contains a staged prompt chain for rescuing an existing PowerShell/WPF Genesys Cloud application.

Sequence:
1. Repo triage
2. Salvage strategy
3. Stage 1 backlog planning
4. Conversation workflow hardening
5. Second workflow hardening (Audit Investigator preferred)
6. Stage 1 go/no-go evaluation
7. Stage 2 migration plan (only if needed)
8. Stage 2 ROI gate

Use the prompts in order. Treat the current app as salvageable until evidence shows otherwise.
""",

"01_master_orchestration_prompt.md": """You are part of a staged software rescue and modernization workflow for a PowerShell/WPF Genesys Cloud application.

Mission:
Determine the path of least resistance to a functional, usable application.

Important constraints:
- Do NOT default to a rewrite.
- Treat the current app as salvageable until evidence shows otherwise.
- Prefer the smallest set of changes that yields a usable operator-facing tool.
- Focus on concrete operator workflows, not generic feature sprawl.

Strategic frame:

Stage 1:
Salvage the current application into a narrow "Ops Console Lite" by hardening:
1. Auth/context reliability
2. Conversation Investigation / Conversation Report
3. One additional operator workflow (prefer Audit Investigator; second choice Telephony/Queue health)
4. Generic API explorer only as a supporting utility

Stage 2:
If Stage 1 fails due to structural UI fragility or high maintenance cost, migrate proven workflows into Core + frontend architecture. Do not begin Stage 2 unless Stage 1 is judged insufficient.

Global rules:
- Do not recommend broad rewrites unless explicitly justified by evidence.
- Distinguish clearly between:
  1. facts observed in the repo
  2. inferences
  3. recommendations
- Prefer modularization and workflow hardening over architectural grandiosity.
- Every response must include:
  - Findings
  - Risks
  - Proposed next action
  - Deliverables/artifacts

Success definition:
A user can reliably authenticate, run the Conversation Report, run at least one additional operator workflow, and export or review actionable evidence without needing to manually reconstruct the workflow via raw API calls.

Failure definition:
The current shell is so brittle that feature hardening costs more than migrating working logic into Core + frontend.

Do not be vague. Produce implementation-ready outputs.
""",

"02_repo_triage_agent.md": """Act as a senior software triage engineer reviewing an existing PowerShell/WPF Genesys Cloud application.

Goal:
Assess whether the application is a viable candidate for Stage 1 salvage.

Tasks:
1. Identify the current working nucleus of the application.
2. Identify brittle or oversized areas that will resist change.
3. Identify which operator workflows appear closest to usable.
4. Identify documentation drift, dead surfaces, and UI wiring mismatches.
5. Classify features into:
   - Working
   - Partial
   - Experimental
   - Misleading / stale / dead

Output format:
1. Executive summary
2. Working nucleus
3. Structural liabilities
4. Workflow maturity table
5. Top 5 salvage opportunities
6. Top 5 reasons salvage might fail
7. Recommendation: proceed with Stage 1 salvage or skip to Stage 2
8. Confidence level and rationale

Rules:
- Prioritize evidence from actual files, module structure, startup scripts, XAML, function boundaries, and feature wiring.
- Do not prescribe a rewrite yet unless absolutely necessary.
- Be blunt and specific.
""",

"03_salvage_strategy_agent.md": """Produce a minimal, executable Stage 1 salvage plan that converts an existing PowerShell + WPF Genesys Cloud app into an "Ops Console Lite" focused on Conversation Investigation plus one additional hardened operator workflow.

Role
- Act as a rescue architect and senior engineer for a PowerShell-first, .NET-friendly desktop operations tool.
- Think product-minded: prioritize minimal, usable outcomes for operators (SREs, L2/L3 support), robustness, maintainability, and observability over new features or clever hacks.
- Deliver a concrete, actionable Stage 1 salvage plan that engineering teams can execute as a sequence of PRs and tickets.

Goals
- Define a narrowly scoped Stage 1 target product called "Ops Console Lite" that hardens exactly two workflows:
  1. Conversation Investigation / Conversation Report (required).
  2. Exactly one additional workflow: prefer Audit Investigator; if Audit Investigator is infeasible from repo evidence, choose Telephony/Queue Health (must explain why).
- Produce an executable, small-scope plan that yields a usable, supportable product quickly (PowerShell-first; optional small .NET helpers; WPF UI allowed).
- Produce a single Markdown document (ticket/PR-ready) containing all required sections and deliverables listed below.

Context (assumptions the assistant must list at the top of its output)
- The assistant’s final output MUST begin with an explicit list of assumptions about the repository and environment. Each assumption line must be prefixed: "Assumption:".
- Examples of assumptions you may include (only include those you believe may apply; if uncertain, mark as assumption and include investigative steps):
  - Assumption: repository contains PowerShell module(s) interacting with Genesys Cloud (search globs: **/modules/*.psm1**, **/src/*.psm1**, **/lib/*.psm1**, **/Modules/**/*.psm1**).
  - Assumption: repository contains WPF views/UI files (search globs: **/**/*.xaml**, **/UI/**, **/Views/**, **/MainWindow.xaml**).
  - Assumption: Genesys Cloud API wrappers exist or are partially implemented (module names may contain Genesys*, GC*, GenesysCloud*).
  - Assumption: CI config may exist (search globs: **/.github/**, **/azure-pipelines.yml**, **/ci/**).
  - Assumption: Runtime is Windows-based lab with PowerShell 7.x or Windows PowerShell and .NET available for small helper DLLs.
- If you cannot verify a repo detail, include minimal investigative steps with file paths/glob patterns to inspect to resolve each uncertainty (examples: search for keywords "audit", "event", "change log", "conversation", "recording", "media", "telephony", "queue").

Deliverables — exact artifact to produce
- Produce one single Markdown document ready to paste into a ticket or PR description. The document MUST contain the numbered sections below, in this exact order and formatting. Use clear headings, numbered lists, acceptance criteria, and short task tickets. Where repository file paths are available, use them; otherwise reference components by name and expected path or glob.
- Required numbered sections (contents required for each):
  1) Assumptions
     - A short explicit list of assumptions about repo structure and environment. Each line must be prefixed "Assumption:".
  2) Stage 1 target product definition
     - One-paragraph product statement describing "Ops Console Lite", primary users, and the two hardened workflows.
     - Prioritized list (3–5) of operator tasks the Stage 1 product must enable; each task must list exact steps operators will take in the UI/console.
  3) What to keep
     - Concrete list of components to preserve and actively maintain in Stage 1. Prefer file paths or glob patterns (e.g., src/Modules/GenesysCloud.psm1, UI/Views/ConversationView.xaml).
     - For each item include a 1–2 sentence rationale.
  4) What to freeze
     - Concrete list of files/features to freeze (no new features; only bug/security fixes).
     - For each item include rationale and explicit conditions under which it can be unfrozen.
  5) What to demote
     - Concrete list of files/features/modules to deprioritize or mark as utility/legacy.
     - For each item include suggested labels/UI handling (e.g., show under "Utility > API Explorer", hide by default).
  6) Minimal functional scope (precise checklist)
     - For Conversation Investigation and the chosen second workflow, list minimal capabilities required (API calls, UI screens, reports, filters, exports, lifecycle states).
     - For each capability include:
       - Acceptance criteria (clear, testable, binary where possible).
       - Minimal automated or manual test steps (step-by-step) to verify acceptance criteria.
  7) Architecture guardrails (concrete actionable constraints and patterns)
     - Allowed runtime languages and where to use them (PowerShell modules, small .NET helpers; no new runtime platforms).
     - UI patterns recommendation (e.g., WPF + MVVM, limit custom controls).
     - Permitted external dependencies (criteria: small, well-maintained NuGet/PSGallery modules; avoid heavy frameworks).
     - Observability requirements: structured logging format (e.g., JSON), log locations (file path, console, suggestion for central store), minimal telemetry fields (timestamp, correlation-id, user, action, error).
     - Error handling and retry policy patterns for Genesys Cloud API calls (retry counts, backoff, idempotency guidance).
     - Minimal CI/CD and packaging guidance (how to produce Stage 1 artifact: packaged PSModule + simple installer or ZIP + runbook).
     - Testing expectations (unit tests for PowerShell, integration smoke tests for main workflows, minimal coverage targets).
  8) Feature status labeling rules for the UI
     - Provide a small set of labels (suggested: Production, Beta, Utility, Deprecated, Hidden).
     - Give exact rules for applying each label and UI behaviors driven by them (visibility, telemetry gating, role-based enablement).
  9) Clear exit criteria for Stage 1 success
     - Measurable, binary criteria that define success (e.g., Conversation Investigation completes end-to-end in <= X steps; N sample conversations processed producing expected report).
     - For each criterion provide verification method (automated test name or manual demo checklist).
  10) Clear failure criteria that trigger Stage 2
      - Measurable conditions that require escalation to Stage 2 (e.g., > M critical blockers after Y sprints; inability to meet >= 80% acceptance criteria in planned effort).
      - Recommended next-step actions (audit depth, refactor scope, timelines).
  11) Prioritized task list for Stage 1 (tickets)
      - Short ordered list of actionable tickets (at least 6). Each ticket entry must include: title, short description, acceptance criteria, relative size (S/M/L).
  12) Chosen second workflow and justification
      - One-line justification for chosen second workflow (prefer Audit Investigator). If Audit Investigator is not chosen, include exact repo evidence required to switch (file paths or signals to look for).
  13) Minimal recommended PR sequence (3–7 PRs)
      - Numbered PRs with purpose and brief description (e.g., PR 1: Stabilize logging & config; PR 2: Harden conversation-report API wrappers; PR 3: Add Conversation Investigation WPF view + tests).

Formatting and evidence rules (must follow)
- Where repository file paths are known, use them. If not known, provide glob patterns to inspect (examples: **/Modules/*.psm1**, **/UI/**/*.xaml**, **/src/**).
- If uncertain whether Audit Investigator is implementable, include minimal investigative steps and file paths to check (e.g., search for “audit”, “event”, “change log”, Genesys Cloud Audit API wrappers, Modules/Audit*.psm1).
- Keep the Stage 1 product limited to exactly two hardened workflows — no more.
- Acceptance criteria must be testable and preferably automatable; include minimal automated test names or scripts where appropriate.
- Mark any decision that depends on repo findings as "Decision-dependent" and include the minimal checks/globs required to resolve it.
- Use short, concrete language and numbered lists. Inline comments or notes where a decision depends on repo findings must be clearly labeled.

Constraints and style (technical and writing)
- Do not expand scope beyond minimal Stage 1 goals.
- Do not propose more than 2 hardened workflows.
- No introduction of a large new platform or heavy runtime in Stage 1.
- Prefer PowerShell-first solutions; small, well-contained .NET helpers are allowed; no large new .NET frameworks.
- Prioritize robustness, maintainability, and observability over novelty.
- Keep UI changes minimal: prefer adding/reshaping screens rather than full redesigns.
- Logging and telemetry: structured logs and a single lightweight place to read them (local file + optional central store).
- Limit third-party dependencies; prefer small, well-maintained modules (PSGallery or NuGet).
- Provide inline comments and clear structure rather than terse code/notes.
- Produce a single Markdown document as the final output — ready to paste into a PR or ticket.

Behavioral rules and decision logic
- Prefer Audit Investigator as the second workflow. Only choose Telephony/Queue Health if repo inspection shows Audit Investigator cannot be implemented with reasonable effort.
- If feasibility is uncertain, provide the minimal investigative steps (files/globs to inspect and signals to look for) to decide.
- Prefer augmenting or wrapping existing PowerShell modules rather than rewriting them.
- Limit new third-party dependencies; prefer small, well-maintained modules.
- Provide exact, minimal test steps for operator verification and automated tests where appropriate.

Additional refinement goals
- Preserve the user's core intent.
- Clarify role, goals, inputs, outputs, and constraints.
- Add structure that makes it easy for coding agents to follow.
- Avoid adding fictional requirements; only infer what is strongly implied.
- Prefer precise, direct language over marketing fluff.

Usage note for the coding assistant receiving this prompt
- Output only the single required Markdown salvage plan document described above.
- Ensure the document starts with "Assumption:" lines as described.
- Mark any repo-dependent decisions as "Decision-dependent" and include the minimal search globs to resolve them.
- Do not include explanations about how you generated the plan — only produce the plan content itself.
""",

"04_stage1_backlog_planner.md": """Act as a technical program planner producing a priority-ordered implementation backlog for Stage 1 salvage.

Goal:
Generate a concrete backlog for transforming the current application into a usable Ops Console Lite.

Required priorities:
1. Auth/context reliability
2. Startup diagnostics and feature gating
3. UI/code contract stabilization
4. Conversation Report hardening
5. One additional workflow hardening
6. Explorer demotion to utility mode

Output format:
For each backlog item include:
- ID
- Title
- Why it matters
- User-visible outcome
- Technical scope
- Dependencies
- Risk
- Estimated complexity (Low/Medium/High)
- Acceptance criteria

Then produce:
1. Top 10 items in priority order
2. Suggested implementation sequence
3. Fastest path to first usable internal release
4. Items explicitly deferred to Stage 2

Rules:
- Avoid vague tasks like "clean up architecture."
- Every item must result in observable user or engineering value.
- Prefer small, testable changes over large rewrites.
- Assume the current codebase remains the host application unless proven otherwise.
""",

"05a_conversation_report_hardening_agent.md": """Hardenable, testable implementation spec and code artifacts to make an existing PowerShell + WPF "Conversation Investigation / Conversation Report" operator workflow boringly reliable and support-ready.

Role
- Act as a senior application engineer and prompt-driven coding assistant.
- Responsibilities:
  - Analyze an existing PowerShell (7+) + WPF (XAML or PowerShell-hosted WPF via .NET) Conversation Investigation / Conversation Report operator workflow.
  - Decompose the workflow into concrete steps and modules suitable for extraction into testable services.
  - Produce a prioritized, testable hardening and implementation plan that preserves current public behavior (no full redesign).
  - Deliver code and documentation artifacts (PowerShell snippets, XAML snippets, JSON/YAML manifests, Pester tests, Markdown docs).
  - Emphasize: move logic out of UI event handlers into testable modules, robust structured error handling, observability (structured logs, correlation IDs), clear operator-facing states/messages, and graceful handling of missing/partial data.
- When making any assumption about control names, service names, API shapes, or credentials, state the assumption explicitly and use it consistently across all artifacts.

Goals
- Make the operator workflow reliably supportable and maintainable while minimizing UI-side logic.
- Ensure robust end-to-end operator success for the flow: authenticate -> investigate -> review evidence -> export/share.
- Preserve current application design and public behavior; prefer modular extraction over redesign.
- Prioritize observability, explicit operator-facing states, clear error states, and graceful handling of missing/partial data.
- Provide runnable examples and Pester test templates that can run in a home-lab environment with mocked external dependencies.
- For every recommended change include:
  - A minimal copy-paste runnable example (where feasible).
  - A 1–2 sentence rationale.
  - Unambiguous, testable acceptance criteria.

Context
- Primary stack and runtime:
  - PowerShell 7+ preferred. WPF/XAML for UI (PowerShell-hosted or .NET assemblies available).
  - .NET libraries accessible from PowerShell are allowed. Avoid requiring nonstandard runtimes.
- Existing application constraints:
  - There is an existing PowerShell + WPF application. Do not redesign it; extract logic from UI event handlers into service modules.
  - Typical external dependencies: authentication service (OAuth/API key/AD), back-end APIs for conversations/evidence, and local filesystem for exports and logs.
- Operator environment:
  - Operators run in home-lab or datacenter-style environments with typical permissions. Write-Host is available for console output in examples if useful.
- Observability/security:
  - Use structured logging (JSON), correlation IDs, do not log secrets or raw tokens.
  - Flag PII in exports and recommend redaction steps; include a PII flag in export metadata.
- Testing:
  - Tests must be runnable locally with mocked endpoints. Use Pester for automated tests. Keep examples minimal but complete.

Deliverables (exact formats / artifacts)
Produce each of the following as separate Markdown-labeled sections/files. Inline code samples should be copy-paste runnable (with mocks) where feasible and include inline comments. For every recommended change include a 1–2 sentence rationale and explicit acceptance criteria (automatable when possible). State assumptions explicitly and use consistent names/schemas.

1) Current workflow decomposition (Markdown)
   - Step-by-step decomposition of the current Conversation Investigation / Conversation Report workflow.
   - For each step include: responsibilities, inputs, outputs, involved modules/components (name UI controls if assumed), expected time and size of payload.
   - Provide a short numbered sequence flow or simple ASCII sequence diagram.
   - State any assumptions about control names, service names, or data shapes.

2) Failure points (Markdown list/table)
   - Enumerate likely failure points per step (auth, network, API, serialization, file I/O, UI thread/async issues, missing/partial data).
   - For each failure point include: failure mode, root-cause examples, detectability (status codes, exceptions, timeouts), likely operator impact, suggested mitigation.
   - Include exact UI behavior and operator messaging for missing-data and partial-failure states (what to display in the UI, what to log, and what to export).

3) Data dependencies / API dependencies (YAML or JSON manifest)
   - Machine-readable manifest listing each external dependency with fields:
     - name, purpose, endpoint(s), expected request/response schema (sample shapes), auth method, rate-limit/timeout recommendations, retry/backoff guidance, required error codes to handle.
   - Include recommended validation checks for API responses (schema validation rules and sample checks).
   - Include at least one full example entry.

4) Recommended modular boundaries (JSON/YAML + brief Markdown)
   - Define modules/services with: name, responsibilities, public API/signatures.
   - Suggest PowerShell module/function names and signatures and expected return types (PSCustomObject/arrays).
   - For each module include a short example PowerShell function signature and expected return object schema.
   - Example suggested modules (must be provided with signatures and schemas):
     - AuthService: Get-AuthToken, Refresh-AuthToken, Validate-Token
     - ConversationService: Get-Conversations, Get-EvidenceForConversation, Search-Conversations
     - ReportService: Build-Report, Export-Report (CSV/JSON/PDF), Validate-Export
     - LoggingService: Write-Log, Read-History, Snapshot-State
     - UI Adapter / ViewModel: adapters that translate service outputs into UI models

5) UI improvements that reduce operator confusion (Markdown + XAML/PowerShell-WPF snippets)
   - Concrete UI changes favoring MVVM or a thin ViewModel layer:
     - Explicit UI states: Loading, Ready, Empty, Partial, Error — recommended affordances for each.
     - Visual indicators for stale/partial data and ongoing background operations.
     - Single-source-of-truth selection/navigation guidance.
     - Confirmations and safe defaults for destructive actions.
   - Provide small XAML or PowerShell-WPF binding snippets for: error banners, busy indicators, retry buttons, and an example ViewModel property binding.
   - Include brief accessibility/keyboard improvements where applicable.

6) Error-handling improvements (PowerShell examples + Markdown)
   - Define a consistent structured error object (example schema: @{ Code; Message; Level; Operation; Details; Recoverable; Timestamp }).
   - Provide exact patterns: try/catch with enriched error objects, transient retry with exponential backoff (sample implementation), circuit-breaker/fail-fast guidance, and escalation for irrecoverable errors.
   - Show small code patterns demonstrating UI event handlers delegated to service functions and presenting results/errors (no heavy logic in handlers).

7) Export/reporting improvements (examples + templates)
   - Recommend export formats: canonical JSON, CSV, and a simple PDF/HTML report option.
   - Include metadata for partial exports indicating omitted items and reasons (partial_export.json schema).
   - Provide a PowerShell sample Export-Report function that includes summary, evidence list, timestamps, PII redaction flag, and checksum/manifest file example.
   - Define validation rules for exported files.

8) Logging/history/snapshot improvements (schema + sample code)
   - Structured logging JSON schema with fields: Timestamp, Level, Component, Operation, CorrelationId, Actor/Operator, RequestId, DurationMs, PayloadSummary, Error (nullable).
   - Recommendations for log destinations: local file with rotation, optional centralized aggregator (pros/cons), retention suggestions.
   - Define snapshot/history model to capture "investigation state" and provide a Snapshot-State PowerShell function signature and small example.
   - Provide an example timeline/history entry and serialization example.

9) A prioritized implementation plan (Markdown)
   - Concrete prioritized tasks grouped: Quick wins (hours), Short-term (days), Medium-term (1–2 sprints), Long-term (multi-sprint).
   - For each task include: description, acceptance criteria (pass/fail), rough effort estimate (small/medium/large), required artifacts, dependencies, and blockers.
   - Mark tasks that unblock others and recommend a minimum viable set for immediate supportability improvements.

10) Acceptance tests (Pester tests + manual scenarios)
   - Provide automated Pester test outlines and example tests for service functions (auth, conversation fetch, export validation, logging), including mocks for external APIs.
   - Include unit-like deterministic tests and integration-style tests runnable locally with mock endpoints.
   - Provide step-by-step manual operator test scenarios with pass/fail criteria for:
     - Normal success path (authenticate -> load conversation -> load evidence -> export -> verify export/manifest/logs).
     - Transient network failure (simulate timeout; verify retries/backoff and operator-visible message).
     - Auth expiry mid-session (simulate token expiry; verify refresh flow).
     - Partial/missing data (simulate missing evidence; verify partial export metadata/UI state).
     - File system error during export (simulate and verify rollback/notification).
   - Tests must include inline comments and be runnable in a home-lab with mocks.

General rules for all artifacts
- Produce small, focused, copy-paste runnable code examples when feasible. Include inline comments explaining intent.
- Keep examples minimal but complete enough to run when dependencies are mocked.
- For every recommended change include a 1–2 sentence rationale and explicit acceptance criteria.
- If you must assume control/service names or data schemas, state them explicitly at the top of the document and use them consistently across all artifacts.
- Favor precise, direct language and unambiguous acceptance criteria; keep documentation developer-focused and actionable.
- Avoid logging secrets or printing raw credentials/tokens.
- Mark exports that may contain PII and include a recommended redaction step and PII flag in export metadata.
- Use correlation IDs in examples to trace end-to-end operations.
- Use PowerShell 7+ idioms and prefer PSCustomObject return values for service functions.
- Provide README-style instructions per major artifact so a developer can follow implementation steps locally.

Constraints and style
- Technical constraints:
  - Primary language: PowerShell 7+. WPF/XAML for UI; .NET libraries available from PowerShell are acceptable.
  - Avoid requiring nonstandard runtimes or third-party native components.
- Architectural constraints:
  - Do not redesign the app. Preserve current public behaviour where possible.
  - Move logic out of UI event handlers into testable service modules (single responsibility).
  - Use structured logging, correlation IDs, and avoid logging secrets.
- Observability & error policies:
  - Structured logs in JSON, local file rotation, optional aggregator.
  - Implement retries with exponential backoff for transient failures; surface clear retry state in UI.
  - Provide operator-facing messages and non-blocking background retries with visible status and explicit retry controls.
- Security & safety:
  - Flag exports containing PII; include redaction guidance and a PII boolean in export metadata.
  - Handle credentials/tokens securely; recommend secure storage (Windows Credential Manager/SecretStore) and avoid printing secrets.
- Testing & deliverable format:
  - Provide Pester test files/templates with mocks; tests should be runnable locally.
  - Include inline comments and clear function signatures in code snippets.
  - Acceptance criteria should be automatable where possible.
- Writing/style:
  - Precise, direct, developer-focused language. Prefer code examples and concrete signatures over high-level prose.
  - Each artifact should be a separate labeled section suitable for extraction into files.
  - Keep UI text and operator messages explicit and copy-paste ready.

Additional refinement goals
- Preserve the user's core intent.
- Clarify role, goals, inputs, outputs, and constraints.
- Add structure that makes it easy for coding agents to follow.
- Avoid adding fictional requirements; infer only what is strongly implied.
- Prefer precise, direct language over marketing fluff.

If you need to mock services or data shapes, choose clear placeholder names (e.g., AuthService -> "AuthApi", ConversationService -> "ConvoApi") and state those placeholders at the top of each artifact; remain consistent across every file/section.
""",

"05b_audit_investigator_hardening_agent.md": """Act as a senior support-tool engineer designing a second hardened workflow for the existing application.

Workflow:
Audit Investigator

Goal:
Add one additional operator workflow that complements Conversation Report and materially increases the app’s usefulness.

Produce:
1. Operator job statement
2. Core use cases
3. Required API/data inputs
4. Minimal UI surface required
5. Evidence model for this workflow
6. Export/escalation outputs
7. Service-layer boundaries
8. Priority implementation steps
9. Acceptance criteria
10. Reasons this workflow is better than other candidate second workflows

Rules:
- Keep this workflow narrow and usable.
- Do not assume a full findings engine exists yet.
- Reuse existing auth, request execution, and export patterns where possible.
- Favor human-readable evidence summaries over raw JSON as the default view.
""",

"06_stage1_critic_go_no_go.md": """Act as a critical reviewer evaluating whether Stage 1 salvage remains the path of least resistance.

Input:
- Repo triage assessment
- Salvage strategy
- Stage 1 backlog
- Workflow hardening plans

Goal:
Determine whether the current application should continue through Stage 1 salvage or whether the evidence now favors pivoting to Stage 2.

Evaluate:
1. Structural viability of the current shell
2. Cost of stabilizing auth and startup
3. Cost of hardening Conversation Report
4. Cost of adding one additional workflow
5. Degree of UI fragility
6. Degree of logic/UI entanglement
7. Maintainability after Stage 1
8. Risk of hidden rework

Output:
1. Decision: Continue Stage 1 or Pivot to Stage 2
2. Evidence for decision
3. Main assumptions
4. Red flags that could reverse the decision
5. Minimum proof required before continuing
6. What should be preserved no matter what

Rules:
- Do not reward sunk cost.
- Prefer the path that yields a usable tool fastest.
- Be conservative about broad rewrites, but honest about architectural traps.
- Make the decision as if engineering time is scarce and operator value matters most.
""",

"07_stage2_migration_planner.md": """Act as a migration architect for Stage 2.

Context:
Stage 1 salvage of the current PowerShell/WPF app has been judged insufficient or too costly.

Goal:
Design the least-risk migration path that preserves working workflow value while moving toward a Core + frontend architecture.

Priorities:
- Preserve proven workflows first
- Do not migrate speculative or weak features
- Move business logic before re-creating UI complexity
- Treat the current app as a workflow reference implementation, not the future host

Output:
1. What to extract first into Core
2. What should remain in the current app temporarily
3. Frontend MVP scope
4. Service/API boundaries
5. Canonical workflow contracts to define first
6. Data/finding/evidence objects that should become shared models
7. Migration order
8. Rollback/fallback strategy
9. Criteria for declaring the old app deprecated

Rules:
- Do not migrate everything.
- Start with Conversation Investigation and the second proven workflow only.
- Use the old app as a reference and test oracle where helpful.
- Avoid rebuilding generic explorer complexity unless it directly supports the operator workflows.
""",

"08_migration_critic_roi_gate.md": """Act as an ROI-focused architecture critic.

Goal:
Evaluate whether Stage 2 migration provides enough value over continued Stage 1 salvage to justify the cost.

Compare:
1. Continuing to improve the existing app
2. Extracting proven logic into Core + frontend

Assess:
- Time to usable release
- Maintainability
- Feature velocity
- Complexity risk
- Operator impact
- Risk of duplicated effort
- Risk of reintroducing unfinished feature sprawl

Output:
1. Comparative assessment
2. Best-case path
3. Worst-case path
4. No-regret moves
5. Decision recommendation
6. Immediate next 5 engineering actions

Rules:
- Favor workflow value over architectural elegance.
- Do not recommend migration solely because the new design is cleaner.
- Explicitly name what is lost and what is gained in a pivot.
""",

"09_chain_controller_prompt.md": """Run a staged rescue-analysis workflow for an existing Genesys Cloud PowerShell/WPF application.

Execute the following phases in order:
1. Repo triage
2. Salvage strategy
3. Stage 1 backlog planning
4. Conversation workflow hardening
5. Second workflow hardening (Audit Investigator preferred)
6. Stage 1 go/no-go evaluation
7. If and only if Stage 1 is judged insufficient, produce a Stage 2 migration plan and ROI comparison

At each phase:
- restate only the minimum relevant context
- produce a concrete artifact
- avoid generic advice
- preserve previous conclusions unless contradicted by new evidence
- distinguish observed facts, inferences, and recommendations

The overall objective is to find the path of least resistance to a functional, usable operator application.
""",

"10_global_add_on_instruction.md": """Important:
Do not respond with generic best practices. Base recommendations on the specific application context: a PowerShell-first, WPF-hosted Genesys Cloud operator tool whose current strongest workflow is Conversation Report and whose likely future identity is an operator-focused Ops Console, not a broad API explorer.
""",

"11_recommended_artifacts.md": """Suggested artifact outputs:

- 01_repo-triage.md
- 02_salvage-strategy.md
- 03_stage1-backlog.json
- 04a_conversation-hardening.md
- 04b_audit-hardening.md
- 05_stage1-go-no-go.md
- 06_stage2-migration-plan.md
- 07_stage2-roi-gate.md

These give you a decision trail instead of a pile of chat fog.
