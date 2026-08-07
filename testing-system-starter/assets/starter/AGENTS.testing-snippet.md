## Verification contract

- `verification-policy.json` defines change risk and required verification lanes.
- After any runtime behavior change, run `$verify-change` or `pwsh -NoProfile -File scripts/verify-change.ps1`.
- Completion requires `.verification/receipt.json` with `status: pass` and a fingerprint matching the current diff.
- Do not skip failing tests, weaken assertions, or edit the receipt by hand.
- Kimi WebBridge is the browser acceptance gate. Reproducible defects become unit/API/domain/data regressions when practical; UI-only defects become named reusable Kimi cases.
- Independent reviewers provide evidence and reproduction; the same reviewer does not approve its own fix.
- R3 work includes production-like smoke and rollback/recovery checks before release.

### Canonical commands

```powershell
pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
pwsh -NoProfile -File scripts/verify-change.ps1
pwsh -NoProfile -File scripts/verify-change.ps1 -CheckReceipt
```
