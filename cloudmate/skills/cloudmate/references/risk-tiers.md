# Risk Tiers

Tag every task in the DAG with one of these tiers. The tier determines verification depth and maps to the user's merge behavior.

## Routine
**What:** Low blast radius, easily reversible. Config changes, docs, tests, small refactors, adding new files that don't affect existing code.
**Verification:** Run acceptance command. If it passes, done.
**Merge signal:** User can `Ctrl+Shift+M` (Merge & Close) confidently.

## Careful
**What:** User-visible changes, moderate impact. New features, API endpoint changes, auth modifications, UI changes, dependency updates.
**Verification:** Run acceptance command + review the diff summary. For UI tasks, suggest manual browser check.
**Merge signal:** User should `Ctrl+Shift+K` (Merge & Keep) and test before closing, in case a quick fix is needed.

## Critical
**What:** Irreversible or high-consequence. DB schema migrations, payment logic, auth system overhauls, data deletion, security-sensitive code, deployment configs.
**Verification:** Run acceptance command + have the lead (or a dedicated review subagent) audit the changes before marking complete. List what could go wrong.
**Merge signal:** User should review carefully. Suggest: "Ask me to review the diff before merging."

## Assignment Heuristics
- Touches only tests or docs → `routine`
- New code in existing patterns → `routine`
- Modifies existing API contracts → `careful`
- Touches auth, payments, or user data → `careful` minimum, `critical` if changing core logic
- DB migrations or schema changes → `critical`
- Deletes code or data → `critical`
- If uncertain between two tiers → pick the higher one
