---
name: summarize-product-usage
description: Generate a formally deliverable Chinese DOCX product usage guide from a product repository or runnable application for non-technical internal end users. Use for 产品使用说明、使用说明书、内部操作手册、产品功能使用指南, including role-specific guides, when the source of truth is the product code and runtime behavior. Do not use for developer/API documentation, architecture or release notes, employee onboarding, a non-DOCX answer, or summarizing existing documents unless the user explicitly asks for that.
---

# Summarize Product Usage

Produce a formally deliverable guide every time. Do not create Fast/Deep variants, reduce necessary screenshots to save time, or report completion before every delivery gate passes.

## Success Standard

The finished guide must let a cold, non-technical colleague:

- understand what the product does and where to start;
- complete every core task without help;
- recognize the successful state and find the final result;
- recover from common problems and avoid real risks.

All usage-affecting facts must be traceable. Every core task must have sufficient screenshots. The final DOCX must pass strict preflight, an independent Reader Test, visual page inspection, and repository hygiene checks.

## Working Directory

Keep evidence, manifests, screenshots, browser profiles, rendered PDF/PNG previews, and QA reports outside the product repository by default:

```powershell
$work = Join-Path $env:LOCALAPPDATA "Codex\summarize-product-usage\<project>-<revision>\<run-id>"
```

Write only the requested final DOCX to the user's chosen destination. Never commit screenshots, temporary scripts, QA files, JSON intermediates, browser profiles, or preview files unless the user explicitly asks.

## Required Workflow

### 1. Analyze the product and build evidence

Inspect repository instructions first. If `.codegraph/` exists at the repository root, use CodeGraph before text search. Analyze independent roles or product areas in parallel when possible.

Create `evidence.json` in the external work directory. Use `references/evidence-ledger.example.json` as the shape and validate it with:

```powershell
rtk <python> <skill>/scripts/validate_evidence.py --input <work>/evidence.json --strict
```

Choose evidence by fact type:

- Use the runnable UI for visible names, entry points, button labels, and user-visible states.
- Use server-side validation or domain rules for permissions, quotas, account rules, upload formats, and size limits; runtime-test them when feasible.
- Use end-to-end behavior for submission success, state transitions, and final result locations.
- Use README, specs, seed data, and tests only as supporting evidence when stronger evidence exists.

Do not silently resolve conflicts. Investigate them; otherwise mark the claim unresolved and keep it out of the final guide or disclose it explicitly as unconfirmed.

### 2. Build the task map

Organize by goals a real user would say, not by routes, components, APIs, or architecture. Classify each capability:

- `core`: directly produces the user's main result; document the full workflow.
- `supporting`: helps a core task; explain only what users need.
- `reference`: low-frequency lookup or settings; keep concise.

For every core task record: exact entry, prerequisites, numbered actions, success signal after the important action, final result location, common problems, real risks, and required screenshots.

Read `references/internal-guide-structure.md` only when deciding structure, wording, task priority, or FAQ phrasing. Read `references/summary-schema-v2.md` before writing `summary.json`.

### 3. Plan and capture complete screenshots

Create `screenshot-manifest.json` from `references/capture-manifest.example.json`. Capture enough images for a cold reader to complete each core task. There is no screenshot count limit.

For each core task, cover every applicable moment:

- recognizable entry page;
- important input or configuration;
- confirmation, destructive, privacy, quota, or other risk state;
- visible success signal;
- final result location.

Prefer viewport screenshots so a full-width image remains readable and fits naturally on a DOCX page. For a long scrolling page, capture several focused states or sections as separate manifest entries; do not create one extremely tall image that Word or Feishu must shrink to unreadable size.

Reuse a public/login screenshot or an unchanged page only when its project revision, role, and manifest cache key match. Keep screenshots next to the steps they explain. Never expose passwords, tokens, API keys, customer data, or unrelated private information.

Run the manifest-driven capture tool. It reuses each role session, waits for explicit readiness, retries transient failures once, verifies output images, and writes `capture-report.json`:

```powershell
rtk pwsh -NoProfile -File <skill>/scripts/capture_product_pages.ps1 `
  -Manifest <work>/screenshot-manifest.json `
  -OutputDir <work>/images `
  -NodeExecutable <bundled-node-or-node-22-path>
```

Any required capture failure blocks delivery. Fix the cause and rerun the failed capture; do not replace necessary screenshots with prose merely to finish faster.

### 4. Write and strictly validate the summary

Write `summary.json` using only confirmed facts from the ledger. Keep UI names exactly as displayed and translate implementation terms into user language.

Run strict preflight before rendering:

```powershell
rtk <python> <skill>/scripts/validate_summary.py `
  --input <work>/summary.json `
  --evidence <work>/evidence.json `
  --strict
```

Strict errors include an empty guide, invalid priorities, incomplete core tasks, missing actions or success signals, incomplete FAQ items, and missing or unreadable screenshots. Fix every error. Do not allow diagnostic placeholders such as「截图缺失」or「此步骤缺少操作说明」into a deliverable.

### 5. Render without damaging an existing deliverable

Render only after both evidence and summary validation pass:

```powershell
rtk <python> <skill>/scripts/render_usage_summary_docx.py `
  --input <work>/summary.json `
  --output <destination>/产品使用指南.docx
```

The renderer saves to a temporary file and replaces the destination only after a successful save, preserving the previous deliverable if rendering fails.
Screenshots are embedded at the full available text width with their original aspect ratio. This prepares the DOCX for Feishu import without requiring this skill to upload or test the document in Feishu.

### 6. Run the formal delivery gates

Run all three gates and fix failures before reporting completion:

1. **Reader Test:** read `references/reader-test.md`; give only the final document to a genuinely fresh-context reader. All 8 questions must be answered with document evidence. Any missing or vague answer fails the gate and requires regeneration and retest.
2. **Visual inspection:** render the DOCX to PDF and page PNGs with the available document tooling. Inspect every page for blank pages, clipping, blurred or stretched screenshots, detached captions, orphan headings, broken step flow, and numbering that does not restart at `1.`.
3. **Artifact hygiene:** run `rtk git -C <product-repo> status --short`. Compare with the starting status. Unexpected screenshots, DOCX/PDF files, JSON, QA artifacts, browser profiles, or helper scripts block delivery. Preserve all pre-existing user changes.

## Delivery Report

Report only what the user needs to accept the result:

- final DOCX path and page/screenshot counts;
- evidence validation status and unresolved facts, if any;
- capture successes versus required captures;
- strict summary validation result;
- Reader Test score (`8/8` required) and whether it used fresh context;
- visual inspection result and repository hygiene status.

Never claim a gate passed unless it was actually executed.
