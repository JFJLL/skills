# Risk routing and evidence

## Contents

- Risk levels
- Lane meanings
- Change scope
- Evidence file
- Adversarial review protocol
- Kimi browser acceptance

## Risk levels

| Risk | Typical change | Required intent |
|---|---|---|
| R0 | Documentation or copy with no runtime behavior | Diff hygiene only |
| R1 | Local behavior with small blast radius | Static checks and targeted unit regression |
| R2 | User-visible UI, API contract, or AI behavior | R1 plus integration and route-specific Kimi/eval |
| R3 | Auth, tenant isolation, credits, data migration, queue/retry, deployment | Full routed verification, independent review, and smoke evidence |

Use the highest matching route. Union all required lanes when one file matches multiple routes. Risk can only escalate with `-RiskFloor`; it can never be lowered.

## Lane meanings

- `static`: diff hygiene, project check, typecheck, and lint when available.
- `unit`: deterministic behavior near the change.
- `build`: production compilation or packaging.
- `integration`: API, database, external adapter, or process-boundary checks.
- `smoke`: health and a minimal happy path against a running build.
- `ai-eval`: deterministic golden cases and behavioral invariants for AI/data output.
- `data`: migrations, rollback, constraints, idempotency, and concurrent writes.
- `kimi-browser`: real-session Kimi WebBridge acceptance with named cases, screenshots, and network evidence.
- `agent-review`: independent fresh-context review with a machine-checkable report.

## Change scope

The change set is `merge-base(baseRef, HEAD)` → working tree, including committed diffs, deletions, renames (old and new path both route), and untracked files. Runtime files (`.db*`, `dist/`, binaries) are excluded from routing and fingerprinting. An empty change set refuses a receipt.

## Evidence file

Use `-InitEvidence` to create `.verification/evidence.json`; never hand-copy the fingerprint. Example:

```json
{
  "schemaVersion": 2,
  "changeSetHash": "PLAN_OUTPUT_HASH",
  "lanes": {
    "kimi-browser": {
      "status": "pass",
      "artifact": "artifacts/verification/kimi-browser-qa.md"
    },
    "agent-review": {
      "status": "pass",
      "artifact": "artifacts/verification/agent-review.json"
    }
  }
}
```

The artifact must exist, carry the current changeSetHash, and its SHA256 is bound into the receipt. Re-running evidence lanes is required whenever the change set changes.

## Adversarial review protocol

1. Two axes, reported separately, never merged or reranked into one verdict:
   - standards: does the change follow repo rules, security, and reliability invariants?
   - spec: does the change actually implement the original task?
2. Reviewer contract: fresh-context (`freshContext: true`), read-only (`implementedFix: false`, identical `git status` before and after), findings carry references and severity.
3. Convergence: no high/critical open findings + two consecutive rounds without required fixes → pass. Hard limit of 3 rounds; beyond that, escalate to the user with a decision ledger.
4. Decision ledger: every finding has an outcome — fixed, recorded, or deferred with reason. The review is closed when the ledger has no pending items.
5. If the original spec is missing, say so explicitly; never reconstruct requirements from the code.

## Kimi browser acceptance

- Use `scripts/kimi-browser.ps1` for one-line calls (navigate, snapshot, click, fill, network, screenshot, close_session).
- Check WebBridge health first (`kimi-browser.ps1 -Action status`). If the daemon or extension is unavailable, the lane is blocked and verification stays failed.
- One task = one session name; prefer semantic snapshots over CSS selectors; start `network start` before the tested action.
- Required cases: `KIMI-001` (changed happy path) always; conditional cases per route: KIMI-002 failure/recovery, KIMI-003 refresh/persisted state, KIMI-004 permission/account boundary, KIMI-005 duplicate/idempotency, KIMI-006 large/slow/cancellation.
- Evidence naming: `artifacts/verification/kimi-browser-qa.md` (template name; keep it stable so `-InitEvidence` and the verifier agree).
