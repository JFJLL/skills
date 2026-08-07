---
name: verify-change
description: Verify a code change through repository-defined risk routing, deterministic tests, Kimi WebBridge browser acceptance, AI/data evaluation, independent review, and a fresh verification receipt. Use after implementing or fixing behavior, before reporting completion, before a commit/PR, or whenever verification-policy.json requires evidence for the current diff.
---

# Verify Change

Treat `verification-policy.json` and `scripts/verify-change.ps1` as the execution authority. Do not invent replacement commands when the repository defines them.

## Workflow

1. Read the nearest `AGENTS.md`, `verification-policy.json`, and the current diff.
2. Run:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
   ```

3. Use the returned risk and required lanes. Read [risk-routing.md](references/risk-routing.md) when a route or evidence lane is unfamiliar.
4. Prepare evidence lanes before the final verifier run:

   - `kimi-browser`: use Kimi WebBridge against the affected real user journey. Check WebBridge health first, keep one task/session name, prefer semantic snapshots, start network capture before the tested action, and record steps, expected/actual results, screenshots, and relevant request failures in `artifacts/verification/kimi-browser-qa.md`. Start from `templates/kimi-browser-qa.md` when the repository provides it.
   - `agent-review`: dispatch fresh-context reviewers only for the risk dimensions selected by the policy. Reviewers provide evidence, reproduction, severity, and a proposed regression test. A reviewer must not approve its own fix.
   - When exploratory QA finds a reproducible bug, add a failing deterministic regression test before fixing it whenever the behavior can be automated.

5. Write `.verification/evidence.json` using the plan fingerprint. Never claim `pass` without an existing artifact.
6. Run the deterministic verifier:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1
   ```

7. Fix root causes and rerun until `.verification/receipt.json` reports `pass`. Do not hand-edit the receipt.
8. Report the risk, lanes, failures fixed, evidence paths, and receipt path.

## Evidence Rules

- Treat Kimi WebBridge as the repository's browser acceptance gate. Do not require a separate scripted browser suite unless the project policy is changed later.
- Convert a reproducible browser defect into a unit, API, domain, or data regression whenever the root behavior is testable below the UI. If it is genuinely UI-only, keep it as a named reusable case in the Kimi browser artifact/template.
- For AI/data changes, run deterministic schema, provenance, missing-data, forbidden-claim, and golden-case checks before any model-based rubric.
- If the app, credentials, fixture, or target environment required by a lane is unavailable, record the lane as blocked and keep verification failed.
- Preserve baseline failures separately from regressions introduced by the current diff.

## Completion Contract

Completion requires a fresh receipt whose fingerprint, risk, required lanes, and policy version match the current workspace. A prose statement such as “tests passed” is not evidence.
