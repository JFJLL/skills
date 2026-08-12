---
name: summarize-product-usage
description: Analyze an entire product project or codebase and generate a polished Chinese internal product usage manual in DOCX format. Use when the user asks Codex to write 产品使用说明, 使用说明书, 内部同事使用说明, 操作手册, onboarding guide, or feature usage guide from a project repository, runnable app, frontend routes, backend APIs, screenshots, or product behavior. Existing Markdown/DOCX manuals may be used only as style references or comparison material when the user explicitly provides them, not as the primary input unless the user asks to summarize documents.
---

# Summarize Product Usage

Use this skill to analyze a product project and write a colleague-facing DOCX usage manual. The source of truth is the project itself: routes, pages, components, API contracts, database/domain models, runnable UI behavior, screenshots, and generated outputs. Reference manuals can inform tone and structure, but they are not the default input.

## Workflow

1. Analyze the project:
   - Inspect README, package scripts, routes, page components, navigation config, API handlers, service modules, and domain models.
   - Identify the real product name, access path, user roles, login state, quotas, task states, upload limits, generated outputs, and error states from code or runtime behavior.
   - If the app is runnable, start it, open the main flows, and capture screenshots with Playwright CLI, an in-app browser, or a headless browser.

2. Map the user-facing product:
   - List the main entry points and workflows a real internal colleague would follow.
   - Separate core flows from secondary pages. Do not give every module equal weight.
   - Prefer evidence from UI labels, forms, buttons, API names, state machines, seed data, and screenshots over guesses.
   - Omit implementation details unless they affect usage.

3. Decide the document structure:
   - Read `references/internal-guide-structure.md` for section options and weighting guidance.
   - Build a practical manual, not a rigid template. Some modules may need detailed steps; others may only need one paragraph, a table row, or a short note.
   - Use explicit numbered text for every step block: `1. ...`, `2. ...`, `3. ...`. Each independent step block must restart at `1.`
   - Do not include a final "问题反馈模板" section.

4. Create a summary JSON matching the renderer schema, then run:

```powershell
rtk C:\Users\liuhao_PC\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe D:\download\pic-vec\skill\summarize-product-usage\scripts\render_usage_summary_docx.py --input summary.json --output 产品使用说明.docx
```

Use the active Python executable if the bundled runtime path differs. The script requires `python-docx`.

5. Verify the DOCX:
   - Confirm the file opens and contains the expected title, summary, key workflows, screenshots, module guidance, rules, and FAQ.
   - Confirm step blocks visibly restart from `1.` in the DOCX.
   - Confirm there is no "问题反馈模板" section.
   - Mention any project areas that could not be verified at runtime.

## Summary JSON

Create JSON with these top-level fields where relevant:

```json
{
  "title": "产品名称 公司内部同事使用说明",
  "subtitle": "适用对象：公司内部同事",
  "version_date": "2026-06-03",
  "audience": "公司内部普通员工",
  "access_url": "http://127.0.0.1:3000/ 或线上地址",
  "overview": "一句到三句话说明产品定位和核心价值。",
  "quick_start": ["打开系统并登录。", "进入核心入口。"],
  "recommended_workflow": ["完成前置配置。", "生成或查看核心结果。"],
  "modules": [
    {
      "name": "核心模块",
      "purpose": "模块用途。",
      "sections": [
        {"heading": "什么时候用", "kind": "bullets", "items": ["适用场景"]},
        {"heading": "怎么操作", "kind": "steps", "items": ["第一步", "第二步"]},
        {"heading": "重点看什么", "kind": "bullets", "items": ["关键结果"]},
        {"heading": "使用提醒", "kind": "paragraph", "body": "限制、依赖或风险。"}
      ],
      "screenshots": [{"path": "images/01-home.png", "caption": "首页"}]
    }
  ],
  "usage_rules": ["内部使用规范或安全提醒"],
  "faq": [{"question": "问题", "answer": "回答"}]
}
```

For lightweight modules, use only `purpose` plus one short `sections` item. For important workflows, include screenshots and detailed `steps`. Do not force every module into the same headings.

Legacy fields `scenarios`, `steps`, `key_outputs`, and `notes` are still supported by the renderer, but prefer `sections` because it allows better weighting.

Do not invent URLs, quota rules, account rules, task states, upload limits, or unsupported capabilities. If a fact is absent from the project and cannot be verified, omit it or mark it as "未在项目中确认".

## Screenshot Guidance

Use screenshots when they help a colleague recognize a page, button, or output. Good screenshot targets:

- Login, home, or project entry.
- Main workspace or dashboard.
- A representative input form.
- A generated result or report page.
- Task history, status, or error area.

When capturing from a runnable web app:

- Start the app in the background, wait for a health check or loaded page, then capture.
- Use desktop width for dense tools unless the user asks for mobile.
- Avoid screenshots that expose credentials, API keys, customer secrets, or unrelated private data.
- If a generated output depends on live AI services, capture the empty/input state and summarize expected results in text.

## Output Standard

The DOCX should be concise enough for internal onboarding, usually 6-15 pages depending on screenshots. Prefer practical sections such as:

- One-page quick summary.
- Quick start.
- Recommended workflow.
- Detailed core workflow sections.
- Short secondary module notes.
- Rules, limits, and security notes.
- FAQ.

Use Chinese headings and practical wording unless the source material is explicitly English.
