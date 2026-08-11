---
name: verify-change
description: Verify a code change through repository-defined risk routing, deterministic tests, Kimi WebBridge browser acceptance, AI/data evaluation, fresh-context independent review, and a fresh verification receipt. Use after implementing or fixing behavior, before reporting completion, before a commit/PR, or whenever verification-policy.json requires evidence for the current diff.
---

# Verify Change

Treat `verification-policy.json` and `scripts/verify-change.ps1` as the execution authority. Do not invent replacement commands when the repository defines them. This skill covers Windows + PowerShell + Node/npm projects.

## Workflow

1. Read the nearest `AGENTS.md`, `verification-policy.json`, and the current change set.
2. Run:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
   ```

3. Read the explainable plan: which file hit which route, why each lane is required, and which Kimi cases apply. Read [risk-routing.md](references/risk-routing.md) when a route or evidence lane is unfamiliar.
4. If `requiredLanes` contains no evidence lane and the risk is R0/R1, skip steps 5-6 and run the verifier directly.
5. Prepare evidence lanes (only when the plan requires them):

   - `kimi-browser`: use Kimi WebBridge against the affected real user journey. Prefer `scripts/kimi-browser.ps1` for one-line calls. Keep one task/session name, start network capture before the tested action, cover the required cases from the plan (`KIMI-001` plus conditional cases), and record steps, expected/actual results, screenshots, and relevant request failures in `artifacts/verification/kimi-browser-qa.md` using the repository template. The artifact must carry the current `changeSetHash` and must not contain `pending`/`fail`/`blocked` verdicts. If WebBridge is unhealthy, record the lane as blocked and keep verification failed — never bypass.
   - `agent-review`: dispatch fresh-context read-only reviewer(s) on the change set. Use the two axes: standards (repo rules, security, reliability) and spec (original task). Each finding must carry a reference (file:line, hunk, or spec line) and severity; high/critical findings must be resolved before pass. Keep a decision ledger so every finding has an outcome (fixed / recorded / deferred with reason). Stop when two consecutive rounds have no required fixes, and never exceed three review rounds — beyond that, escalate to the user.
   - When exploratory QA finds a reproducible bug, add a failing deterministic regression test before fixing it whenever the behavior is testable below the UI.

6. Run `-InitEvidence` when the plan requires evidence lanes (it creates `.verification/evidence.json` with pending state and the current changeSetHash), then fill the artifacts.
7. Run the deterministic verifier:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1
   ```

8. Fix root causes and rerun until `.verification/receipt.json` reports `pass`. Do not hand-edit the receipt.
9. Report the risk, lanes, failures fixed, evidence paths, capability gaps, and receipt path.

## Evidence Rules

- Treat Kimi WebBridge as the repository's browser acceptance gate. Do not require a separate scripted browser suite unless the project policy is changed later.
- Convert a reproducible browser defect into a unit, API, domain, or data regression whenever the root behavior is testable below the UI. If it is genuinely UI-only, keep it as a named reusable Kimi case.
- Test quality: expected values must come from an independent source of truth (never recompute with the same algorithm as the implementation); observe behavior through public interfaces, not internal state; mock only system boundaries; always run the test to confirm it is red before fixing and green after.
- For AI/data changes, run deterministic schema, provenance, missing-data, forbidden-claim, and golden-case checks before any model-based rubric.
- If the app, credentials, fixture, or target environment required by a lane is unavailable, record the lane as blocked and keep verification failed.
- Preserve baseline failures separately from regressions: when a lane fails, run the same command against the baseline ref in a throwaway worktree if a baseline failure is suspected, and record both outputs in `artifacts/verification/baseline-diff.md`. Only baseline-pass → current-fail items count as regressions.

## Completion Contract

Completion requires a fresh receipt whose schemaVersion is 2 and whose changeSetHash, policy hash, runner hash, risk, required lanes, and evidence artifact hashes match the current workspace. A receipt for an empty change set is not completion evidence. A prose statement such as "tests passed" is not evidence. A receipt obtained with a lowered risk override is not completion evidence; only `-RiskFloor` (raising) is allowed.
