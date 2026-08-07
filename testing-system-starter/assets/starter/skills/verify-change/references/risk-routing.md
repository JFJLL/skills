# Risk routing and evidence

## Contents

- Risk levels
- Lane meanings
- Evidence file
- Adversarial review dimensions

## Risk levels

| Risk | Typical change | Required intent |
|---|---|---|
| R0 | Documentation or copy with no runtime behavior | Diff hygiene only |
| R1 | Local behavior with small blast radius | Static checks and targeted unit regression |
| R2 | User-visible UI, API contract, or AI behavior | R1 plus build and route-specific integration/Kimi acceptance/eval |
| R3 | Auth, tenant isolation, credits, data migration, queue/retry, deployment | Full routed verification, independent review, and smoke evidence |

Use the highest matching route. Union all required lanes when one file matches multiple routes.

## Lane meanings

- `static`: diff hygiene, project check, typecheck, and lint when available.
- `unit`: deterministic behavior near the change.
- `build`: production compilation or packaging.
- `integration`: API, database, external adapter, or process-boundary checks.
- `smoke`: health and a minimal happy path against a running build.
- `ai-eval`: deterministic golden cases and behavioral invariants for AI/data output.
- `data`: migrations, rollback, constraints, idempotency, and concurrent writes.
- `kimi-browser`: real-session Kimi WebBridge acceptance with named cases, screenshots, and network evidence.
- `agent-review`: independent risk review with reproduction and regression-test proposals.

## Evidence file

Write `.verification/evidence.json` after `-PlanOnly` returns the current fingerprint:

```json
{
  "fingerprint": "PLAN_FINGERPRINT",
  "lanes": {
    "kimi-browser": {
      "status": "pass",
      "artifact": "artifacts/verification/kimi-browser-qa.md"
    },
    "agent-review": {
      "status": "pass",
      "artifact": "artifacts/verification/adversarial-review.json"
    }
  }
}
```

The artifact must exist. Re-run evidence lanes when the workspace fingerprint changes.

## Adversarial review dimensions

Select only dimensions relevant to the route:

1. Data truth and provenance: missing fields, source traceability, fabricated conclusions.
2. Reliability: timeout, retry, idempotency, duplicate work, cancellation, partial failure.
3. Security and isolation: auth, tenant boundaries, permissions, secrets, unsafe inputs.
4. UX and recovery: loading, empty/error states, interrupted flows, actionable feedback.
5. Resource pressure: large files, long HTML, queues, memory, backpressure, rate limits.

Require evidence and a reproduction. Convert accepted findings into deterministic regression tests before closing them.
