## Verification contract

- `verification-policy.json` is the risk-routing authority; `scripts/verify-change.ps1` is the deterministic execution authority.
- Change scope is merge-base against `changeScope.baseRef` (uncommitted + committed + deleted + renamed + untracked files all count).
- After any runtime behavior change, run `$verify-change` or `pwsh -NoProfile -File scripts/verify-change.ps1`.
- Completion requires `.verification/receipt.json` with `schemaVersion: 2`, `status: pass`, and a `changeSetHash` matching the current change set (policy hash, runner hash, and evidence artifact hashes are bound to the receipt).
- Do not skip failing tests, weaken assertions, hand-edit the receipt, or fabricate evidence.
- Risk can only escalate: `-RiskFloor` may raise the computed risk, never lower it.
- `agent-review` runs only when the plan requires it. Reviewers must be fresh-context and read-only; high/critical findings must be resolved before pass.
- Browser acceptance uses Kimi WebBridge. When WebBridge is unavailable, record the lane as blocked and keep verification failed.
- Deleted files and committed feature-branch diffs are routed by the same policy.
