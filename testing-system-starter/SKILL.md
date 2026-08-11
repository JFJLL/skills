---
name: testing-system-starter
description: Install and adapt the user's risk-routed verification starter in a code project. Use when the user says "接入 testing-system-starter", invokes $testing-system-starter, asks to install the personal testing system, or wants project-level verification with deterministic tests, Kimi WebBridge browser acceptance, adversarial review, receipts, and optional hooks/CI.
---

# Testing System Starter

Use this skill's bundled `assets/starter/` directory as the canonical source. Never search npm, GitHub, PATH, or the web for `testing-system-starter`. If an expected bundled file is missing, report that exact local path.

## Scope

Windows + PowerShell + Node/npm projects. Do not promise other stacks; report them as out of scope.

## Defaults

- Target the current Git repository unless the user names another project.
- Install the core verification files, but keep Hook and CI disabled unless explicitly requested.
- Use Kimi WebBridge as the only browser acceptance tool; do not introduce Playwright by default.
- Preserve existing project instructions, scripts, configuration, and unrelated worktree changes.
- Do not commit, push, deploy, or change product behavior unless explicitly requested.

## Install workflow

1. Resolve the target repository root. Read its nearest `AGENTS.md` and any project-specific rules before editing.
2. Inspect the worktree, existing test entry points, the default base branch (`origin/main` or `origin/master`), and package.json scripts.
3. Inspect the bundled `verification-policy.json`, `scripts/verify-change.ps1`, `scripts/kimi-browser.ps1`, `templates/`, `AGENTS.testing-snippet.md`, and `.gitignore.snippet`.
4. Install or merge the core files:
   - `verification-policy.json` (adapt `changeScope.baseRef` and command mappings to the real project; bump `version` when you change it)
   - `scripts/verify-change.ps1` and `scripts/kimi-browser.ps1`
   - `templates/kimi-browser-qa.md` and `templates/agent-review.json`
   - the verification contract from `AGENTS.testing-snippet.md` into the project `AGENTS.md`
   - `.verification/` and `artifacts/verification/` ignore entries into `.gitignore`
   - `verification-system.json` manifest (record installed files and versions)
5. Adapt `verification-policy.json` to commands that actually exist. Detectable scripts must be mapped; missing capabilities must be reported as explicit gaps. Never use `--if-present`, skipped assertions, or fabricated evidence to obtain a pass.
6. Ensure `$verify-change` resolves: if the global `verify-change` skill is installed (this is the default), the project contract works without a nested copy; otherwise install the nested `skills/verify-change/` copy explicitly and say so.
7. Validate JSON and PowerShell syntax, then run:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
   ```

8. Confirm the plan routes representative files correctly (UI → kimi-browser, auth → R3 + agent-review, docs/auth.md → R0, ThemeProvider.tsx → not ai-eval). Run relevant deterministic checks when setup changes permit it. Do not claim a full pass when required Kimi or reviewer evidence has not been produced for the current change set.
9. Report installed files, command mappings, baseRef, validation results, remaining capability gaps, and whether Hook/CI remain disabled.

## Existing installation

Read `verification-system.json` first. If the project already contains the core files, update conservatively instead of recopying the template: preserve project command mappings and route overrides, bump `policyVersion`, and avoid duplicate `AGENTS.md` or `.gitignore` blocks.

## Optional activation

- Enable Hook only after 2–3 days of successful manual use, or when the user explicitly asks. Copy `.codex/hooks.json` and `.codex/hooks/` from the bundled assets. The Stop hook always runs `-CheckReceipt` (no dirty marker dependency).
- Enable CI only when requested. Copy `.github/workflows/ci.yml` (windows-latest), keep Kimi and agent-review evidence local, and make sure `fetch-depth: 0` is set so merge-base works.

After installation, the user should not need to mention this starter again. Project instructions and `$verify-change` own the daily verification workflow; the user's normal prompt may remain "修改 XXX，完成后用 Kimi 实际测试"。
