---
name: testing-system-starter
description: Install and adapt the user's risk-routed verification starter in a
  code project. Use when the user says “接入 testing-system-starter”, invokes
  $testing-system-starter, asks to install the personal testing system, or wants
  project-level verification with deterministic tests, Kimi WebBridge browser
  acceptance, adversarial review, receipts, and optional hooks/CI. The canonical
  source is bundled in this skill; never search npm, GitHub, or the web for it.
disable: false
---

# Testing System Starter

Use this skill's bundled `assets/starter/` directory as the canonical source. Never search npm, GitHub, PATH, or the web for `testing-system-starter`. If an expected bundled file is missing, report that exact local path.

## Defaults

- Target the current Git repository unless the user names another project.
- Install the core verification files, but keep Hook and CI disabled unless explicitly requested.
- Use Kimi WebBridge as the only browser acceptance tool; do not introduce Playwright by default.
- Preserve existing project instructions, scripts, configuration, and unrelated worktree changes.
- Do not commit, push, deploy, or change product behavior unless explicitly requested.

## Install workflow

1. Resolve the target repository root. Read its nearest `AGENTS.md` and any project-specific rules before editing.
2. Inspect the worktree and existing test entry points. For Node projects, inspect `package.json` scripts; for other stacks, inspect their native test/build configuration.
3. Inspect `assets/starter/verification-policy.json`, `assets/starter/scripts/verify-change.ps1`, `assets/starter/templates/kimi-browser-qa.md`, `assets/starter/AGENTS.testing-snippet.md`, and `assets/starter/.gitignore.snippet`.
4. Install or merge the core files:
   - `verification-policy.json`
   - `scripts/verify-change.ps1`
   - `templates/kimi-browser-qa.md`
   - the verification contract from `AGENTS.testing-snippet.md` into the project `AGENTS.md`
   - `.verification/` and `artifacts/verification/` ignore entries into `.gitignore`
5. Adapt `verification-policy.json` to commands that actually exist in the target project. Keep risk routing fail-closed: add a missing test capability when it is in scope, or report the explicit gap; never use `--if-present`, skipped assertions, or fabricated evidence to obtain a pass.
6. Preserve the browser policy:
   - UI and critical user-journey routes require `kimi-browser` locally.
   - Pure background processing does not require a browser.
   - CI excludes local Kimi and agent-review evidence lanes.
7. Validate JSON and PowerShell syntax, then run:

   ```powershell
   pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
   ```

8. Confirm the plan matches representative changed files and the project's available commands. Run relevant deterministic checks when setup changes permit it. Do not claim a full pass when required Kimi or reviewer evidence has not been produced for the current diff.
9. Report installed files, command mappings, validation results, remaining capability gaps, and whether Hook/CI remain disabled.

## Existing installation

If the project already contains the core files, update them conservatively instead of recopying the template. Compare policy version and behavior, preserve project-specific command mappings, and avoid duplicate `AGENTS.md` or `.gitignore` blocks.

## Optional activation

- Enable Hook only after 2–3 days of successful manual use, or when the user explicitly asks. Copy `.codex/hooks.json` and `.codex/hooks/` from the bundled assets and validate the Stop receipt gate.
- Enable CI only when requested. Copy `.github/workflows/ci.yml`, adapt runtime setup to the project, and keep browser/reviewer evidence local.

After installation, the user should not need to mention this starter again. Project instructions and `$verify-change` own the daily verification workflow; the user's normal prompt may remain “修改 XXX，完成后用 Kimi 实际测试”。
