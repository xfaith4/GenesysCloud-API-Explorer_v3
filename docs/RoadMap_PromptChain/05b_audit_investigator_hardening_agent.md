Design a hardened, implementation-ready "Audit Investigator" operator workflow specification for a PowerShell-first engineering team.

# Role
Act as a senior support-tool engineer / prompt-guided coding assistant delivering a concise, implementation-ready specification for a single operator workflow named "Audit Investigator". The output must be a single Markdown document (see Deliverables) intended for immediate implementation by a PowerShell-first engineering team that owns small .NET services and a basic web UI.

# Goals
- Propose exactly one narrow, high-value operator workflow: "Audit Investigator" that complements an existing "Conversation Report".
- Produce a single Markdown document containing 10 numbered sections (see Deliverables) that is immediately implementable.
- Prioritize robustness, maintainability, observability (rich logs/metrics), clear inline comments, and reuse of existing auth/request/export patterns.
- Provide an end-to-end Minimal Viable Product (MVP) path early: accept input, produce a human-readable evidence summary, and offer exports (JSON/CSV/PDF-friendly) and ticket escalation.
- Keep scope narrow: do not require a findings engine; any new component must be small and explicitly justified (e.g., an Evidence Aggregator).
- Provide PowerShell-first artifacts (scripts/function stubs) and concise .NET class/interface sketches where appropriate.

# Context
- Primary stack: PowerShell-first automation (scripts/modules), small .NET services for backend work, and a basic web UI.
- Execution environment: scripts run in lab/home-lab with typical permissions; Write-Host is available for console output.
- Reuse expectations: conversation API (source of transcripts/metadata), existing auth and request execution patterns (HTTP client + bearer token), and export utilities are available. Do not assume a findings engine or large new infra.
- Team priorities: inline comments and clear structure; pragmatic performance (single-operator latency in seconds to low tens of seconds); enterprise security and privacy (PII minimization); observability (logs, metrics).
- Acceptable new component: a small Evidence Aggregator module (explicitly justified, minimal state).

# Deliverables (exact required output from coding assistant)
Produce one Markdown document that contains exactly these 10 numbered sections in order. Each section must be concise, unambiguous, and implementation-ready. Include required code blocks, schemas, and examples in the indicated sections.

1) Operator job statement
- 1–2 sentence mission statement describing the operator’s role and outcomes.

2) Core use cases
- 4–8 concrete, prioritized use cases (bulleted). For each use case include: actor, trigger, expected outcome, and a short example (conversation id, timeframe, or suspicious pattern).

3) Required API / data inputs
- Clear list of required inputs with: Name, Type (string/datetime/integer/object/array), Required/Optional, Example value, Source (Conversation API, logs, or user input).
- Provide a minimal JSON Schema for the primary request payload the workflow accepts (JSON Schema code block).

4) Minimal UI surface required
- One-page list of UI components/screens. For each view include: Screen name and primary actions, Required fields/controls/default behaviors, and low-fidelity behavior notes (e.g., default human-readable summary, raw JSON toggle).

5) Evidence model for this workflow
- Define human-readable evidence model and machine-serializable schema: field list, types, cardinality, primary evidence types (transcripts excerpts, metadata, timeline entries, derived tags).
- Provide a short template for the human-readable summary generator (pseudocode or text template).
- Include a JSON Schema (code block) for the evidence object.
- Provide 2 example evidence objects (JSON): one benign, one suspicious.
- State that default view is human-readable summary; raw JSON available on demand.

6) Export / escalation outputs
- Supported export formats and their schemas: CSV, JSON, minimal PDF-friendly summary, and ticket payload.
- Example payloads for: file export (CSV/JSON), escalation to a ticketing endpoint (fields and auth header reuse), and notification payloads (Slack/email) — minimal templates.
- Explain where and how to reuse existing auth/request execution patterns (e.g., existing HTTP client bearer-token header).

7) Service-layer boundaries
- Concrete list of components/services and interfaces between them. For each include: Responsibility, Input and output contracts (schemas or summaries), and suggested placement (PowerShell module, .NET service, front-end).
- Keep boundaries minimal and explicit so implementers can map to current codebase.

8) Priority implementation steps
- 8–12 discrete, ordered implementation steps (small milestones). For each: Title, short description, estimated complexity (Low/Med/High), and optional example commands or PowerShell function stub signatures.
- Emphasize delivering a working end-to-end MVP early (human-readable summary + export) then enhancements.

9) Acceptance criteria
- 6–10 specific, measurable, testable criteria covering happy paths, edge cases, observability (logs/metrics), auth, and export correctness.
- Use examples like: "Given conversation id X, operator can run Investigator and receive a human-readable summary ≤ 200 words and an exported JSON file conforming to schema Y".

10) Reasons this workflow is better than other candidate second workflows
- Short comparative analysis (6–8 bullets). Compare at least two plausible alternatives (e.g., Incident Triage, Findings Aggregator, Search & Correlate) and explain why Audit Investigator is preferred given constraints (narrow scope, no findings engine, reuse of patterns, quick operator value).

Required formatting and artifacts embedded in the Markdown
- Include JSON Schema blocks for the primary request payload and evidence schema.
- Include short PowerShell function stubs with parameter validation and inline comments where helpful (use param validation attributes).
- Include concise .NET class/interface sketches (C#) where they clarify service contracts.
- Provide example payloads and example evidence objects (realistic, minimal).
- Provide suggested log messages and metric names and indicate where to emit them (e.g., Investigator.Run.start, Investigator.EvidenceFetched.count, Investigator.Export.failed).
- Include PII-handling notes (mask/remove PII in exports by default) and minimal retention guidance.
- State explicit reuse points for existing auth and request patterns (e.g., use existing singleton HTTP client and bearer token retrieval function).
- Keep the MVP path first (input → human summary → export).

# Constraints and style
- Language/stack focus: PowerShell-first artifacts for scripting, concise .NET class/interface sketches for service contracts, minimal front-end UI descriptions.
- Observability: recommend specific logs and metric names and minimal telemetry to validate usage and failures.
- Security/privacy: PII minimization required; do not store raw PII in exports by default; include masking rules and retention guidance.
- Performance: pragmatic single-operator response times (seconds to low tens of seconds for evidence aggregation).
- Implementation assumptions: do not assume a findings engine; any new component must be small and justified (Evidence Aggregator allowed).
- Reuse: explicitly indicate where existing auth, request execution, and export utilities are reused (do not invent new auth flows).
- Output requirements: single Markdown document only; do not output additional files.
- Tone and style: concise, direct, implementation-focused. Prefer explicit lists, code blocks, and inline comments. Avoid marketing language and fictional system details.
- Observability metric examples: include Investigator.Run.start, Investigator.Run.success, Investigator.Run.failed, Investigator.EvidenceFetched.count, Investigator.Export.success, Investigator.Export.failed.
- PII guidance: include default masking patterns, minimal retention guidance (e.g., 30 days configurable), and statement that sensitive raw transcripts must not be retained unless explicitly approved.

# Additional refinement goals
- Preserve the user's core intent: a hardened "Audit Investigator" operator workflow.
- Clarify role, goals, inputs, outputs, and constraints for implementers.
- Add structure that makes it easy for coding agents to implement the workflow.
- Avoid adding fictional requirements; only infer what is strongly implied.
- Prefer precise, direct language over marketing fluff.

Use this prompt to produce the single Markdown deliverable described above. Do not produce other files or commentary.
