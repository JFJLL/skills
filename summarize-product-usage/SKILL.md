---
name: summarize-product-usage
description: Analyze a product project and generate a task-oriented Chinese DOCX usage guide for non-technical internal colleagues. Use when the user asks Codex to write 产品使用说明, 使用说明书, 内部同事使用说明, 操作手册, onboarding guide, or feature usage guide from a project repository, runnable app, frontend routes, backend APIs, screenshots, or product behavior. Existing Markdown/DOCX manuals may be used only as style references or comparison material when the user explicitly provides them, not as the primary input unless the user asks to summarize documents.
---

# Summarize Product Usage

Use this skill to analyze a product project and write a DOCX usage guide that a completely non-technical internal colleague can understand quickly, use on their own for the first time, and consult later by task.

## Default Reader

The default reader is an internal colleague who does NOT know code, APIs, databases, architecture, task queues, or AI engineering.

For every sentence you write, ask:

> Does this sentence need development background to be understood naturally?

If yes, convert it to user language. Examples:

| 技术表达（不要这样写） | 用户语言（这样写） |
| --- | --- |
| 任务进入 pending 后由 worker 异步消费。 | 提交成功后页面会显示「等待处理」，系统会在后台继续处理，不需要重复提交。 |
| 请求通过 API endpoint 提交，返回 requestId。 | 点击「提交」后，页面会显示任务编号和状态。 |
| 生成结果写入 database，可通过 schema 查询。 | 生成完成后，结果会自动保存，可以在「历史记录」里找到。 |

## Source of Truth

The source of truth is the real product, in this priority order:

1. Runnable UI and real screenshots.
2. Frontend routes, pages, navigation, forms, buttons, and state text.
3. Backend APIs, task models, upload rules, quota and auth logic.
4. README, product specs, seed data, and tests.
5. Existing manuals only as style references unless the user explicitly asks to summarize documents.

Never guess. If any of the following cannot be confirmed from the project, omit it or mark it as「未在项目中确认」: URLs, quota, account rules, permissions, states, upload formats, file size limits, output locations, supported capabilities.

## Workflow

1. Analyze the project:
   - Inspect README, package scripts, routes, page components, navigation config, API handlers, service modules, and domain models.
   - Identify the real product name, access path, user roles, login state, quotas, task states, upload limits, generated outputs, and error states from code or runtime behavior.
   - If the app is runnable, start it, open the main flows, and capture screenshots with Playwright CLI, an in-app browser, or a headless browser.
2. Map the user-facing product:
   - List the tasks a real internal colleague would say out loud: 「我要看看最近有什么热点」「我要找优秀内容参考」「我要生成内容」「我要找到之前生成的结果」.
   - For each task, record the real entry point (menu/page/button names exactly as shown), what happens after each action, and where the result lands.
3. Weigh every feature:
   - `core`: directly produces the user's main result. Write full guidance (purpose, entry, prerequisites, steps, expected results, result location, common problems, screenshots).
   - `supporting`: helper capabilities. Write briefly as needed.
   - `reference`: settings, profile pages, low-frequency entries. Provide just enough to look things up.
   - Do not give every route or module the same amount of content.
4. Choose the document structure:
   - Default to task-oriented: organize by user tasks, not by code modules, routes, or architecture. Keep real entry names visible, e.g. 「我要看看最近有什么热点 — 入口：左侧菜单「趋势洞察」」.
   - Read `references/internal-guide-structure.md` for structure and plain-language rules.
   - Use explicit numbered text for every step block: `1. ...`, `2. ...`, `3. ...`. Each independent step block must restart at `1.`.
   - Do not include a final「问题反馈模板」section.
5. Create a summary JSON matching the renderer schema (V2 fields below; legacy fields remain supported), then run:

```powershell
python summarize-product-usage/scripts/render_usage_summary_docx.py --input summary.json --output 产品使用指南.docx
```

Use any active Python executable that has `python-docx` installed (the Codex bundled runtime works if present; otherwise use the environment's Python after `pip install python-docx`). Run from the repository root or adjust the script path to your local checkout.
If your machine follows the `rtk` shell convention from AGENTS.md, run the same command through `rtk` with your Python executable, e.g. `rtk <python> summarize-product-usage/scripts/render_usage_summary_docx.py --input summary.json --output 产品使用指南.docx`.

6. Verify the DOCX:
   - Confirm it opens and contains the first-page 3-minute summary, task entries, steps with expected results, callouts, screenshots, and FAQ.
   - Confirm step blocks visibly restart from `1.` in the DOCX.
   - Confirm there is no「问题反馈模板」section.
   - Mention any project areas that could not be verified at runtime.
7. Run the Reader Test: read `references/reader-test.md` and apply it to the final DOCX. Follow its fresh-context rules and report honestly whether an independent reader test was executed.

## Quick Start and Recommended Workflow

### Quick Start

Answers only:

> First time using this product, what is the shortest path to the first useful result?

Keep it as short as possible.

### Recommended Workflow

Answers only:

> During normal work, how should several capabilities be combined?

Only include it when the project has a real, confirmed ordering between capabilities.

Decision rule: if one clearly duplicates the other (equal, or one is a prefix of the other), render the longer list once as Quick Start and do NOT generate a duplicate Recommended Workflow.

## Summary JSON (V2)

Create JSON with these top-level fields where relevant:

```json
{
  "title": "产品名称 公司内部同事使用说明",
  "subtitle": "面向公司内部同事",
  "audience": "公司内部普通员工（非技术）",
  "version_date": "2026-08-12",
  "access_url": "示例占位：请替换为真实可确认的入口地址",
  "at_a_glance": {
    "what_it_does": "一句话说明这个产品解决什么问题。",
    "top_tasks": [
      "看看最近有什么热点",
      "找优秀内容参考",
      "生成自己的内容",
      "找到之前生成的结果"
    ],
    "before_you_start": [
      "部分生成操作会消耗额度。",
      "任务进入「处理中」后不要重复提交。"
    ]
  },
  "quick_start": ["登录系统。", "打开「趋势洞察」看热点。"],
  "recommended_workflow": ["先看趋势确认方向。", "再生成并保存内容。"],
  "tasks": [
    {
      "title": "我要看看最近有什么热点",
      "entry": "左侧菜单「趋势洞察」",
      "purpose": "查看当前值得关注的话题和内容方向。",
      "prerequisites": ["已经登录系统"],
      "priority": "core",
      "steps": [
        "打开系统并登录。",
        {
          "action": "点击「开始分析」",
          "expected_result": "页面出现「处理中」，说明任务已经成功提交。",
          "warning": "已经进入处理中时不要再次点击。",
          "tip": "可以稍后到任务历史中查看结果。",
          "screenshot": {
            "path": "images/trend-submit.png",
            "caption": "提交趋势分析任务"
          }
        }
      ],
      "result": "完成后可以看到趋势列表和对应分析。",
      "common_problems": [
        {"question": "为什么这里没有可以选择的内容？", "answer": "……"}
      ],
      "screenshots": [{"path": "images/trend-page.png", "caption": "趋势洞察页面"}]
    }
  ],
  "modules": [],
  "usage_rules": ["内部使用规范或安全提醒"],
  "faq": [
    {"question": "为什么一直显示「处理中」？", "answer": "系统会在后台继续处理，请稍等；不要重复提交。"}
  ]
}
```

### `at_a_glance`（第一页）

Drives the first page「3 分钟了解这个产品」:

- `what_it_does`: one sentence explaining what the product solves.
- `top_tasks`: 3-5 things the product is most often used for.
- `before_you_start`: only the 2-4 things that genuinely matter before starting.

If these fields are absent, the renderer falls back to `overview`, `quick_start`, module names, and `usage_rules` automatically.
When `usage_rules` is used as the「开始前要知道」fallback, the same items are not repeated in the later「使用规范」section (only the remainder is rendered there).

### `tasks`（主要阅读结构）

When `tasks` exists, the renderer uses the task-oriented structure first. `tasks` items:

- `title`: a real user goal, e.g.「我要查看以前生成的结果」.
- `entry`: the real menu/page/button name, e.g. 左侧菜单「历史记录」.
- `purpose`: one short paragraph.
- `prerequisites`: what must be true before starting.
- `priority`: `core` / `supporting` / `reference`. The renderer gives core tasks the full treatment (prerequisites, steps, expected results, common problems, screenshots); supporting tasks render purpose, entry, prerequisites, steps, and screenshots (result and common problems are not rendered); reference tasks render purpose, entry, and steps only (screenshots and problem sections are not rendered).
- `steps`: string steps or object steps (see below).
- `result`: what the user should see or where the result lands.
- `common_problems`: FAQ entries phrased as real user questions.
- `screenshots`: task-level fallback screenshots.

When `tasks` are present, a module whose name appears in a task entry renders as a query-level index entry (name + purpose) so task content is not duplicated; modules not covered by any task render in full so their details are not lost. Without `tasks`, `modules` render in full as before.
When a module is covered by a task, make sure the task steps carry that module's key details so nothing important is left only in the index entry.

### Steps

Plain string steps keep working:

```json
["打开系统。", "点击开始分析。"]
```

V2 object steps add expected results, warnings, tips, and step-level screenshots:

```json
{
  "action": "点击「开始分析」",
  "expected_result": "页面出现「处理中」，说明任务已经成功提交。",
  "warning": "已经进入处理中时不要再次点击。",
  "tip": "可以稍后到任务历史中查看结果。",
  "screenshot": {"path": "images/trend-submit.png", "caption": "提交趋势分析任务"}
}
```

Rules:

- `action` is required.
- `expected_result` is recommended for core flows.
- `warning` only when there is a real risk (duplicate submission, quota consumption, privacy).
- `tip` only when it genuinely helps.
- The renderer must NOT merge the four fields into one flat paragraph; it renders them as a numbered step plus visually distinct callouts（完成后 / 注意 / 建议）.

### Legacy fields

`overview`, `quick_start`, `recommended_workflow`, `modules`, `sections`, `scenarios`, `steps`, `key_outputs`, `notes`, `screenshots`, `usage_rules`, and `faq` remain fully supported. Old JSON continues to generate DOCX without migration. The renderer uses `tasks` only when present, and falls back to `modules` otherwise.

## Plain Language Rules

Keep these exactly as the real product shows them:

- Menu names.
- Button names.
- Page names.
- State text users actually see.

Convert these to plain language by default:

```text
API
schema
worker
payload
requestId
async
queue
endpoint
database
model
cron
job
```

Example conversions:

```text
异步执行 → 系统会在后台继续处理
pending → 等待处理
```

If the UI itself shows an English state, keep the real state text and add a short plain-Chinese explanation.

## Screenshot Guidance

Use screenshots when they help a colleague recognize a page, button, or output. Place each screenshot as close as possible to the step it illustrates (step-level `screenshot`), instead of stacking all screenshots at the end of a module. Module/task-level `screenshots` remain the fallback.

The same screenshot path is inserted only once per document; repeated references (for example the same image at step level and task level) do not produce duplicate images.

Good targets:

- Login, home, or project entry.
- Main workspace or dashboard.
- A representative input form.
- A generated result or report page.
- Task history, status, or error area.

When capturing from a runnable web app:

- Start the app in the background, wait for a health check or loaded page, then capture.
- Use desktop width for dense tools unless the user asks for mobile.
- Never include passwords, API keys, tokens, customer secrets, or unrelated private data.
- If a generated output depends on live AI services, capture the empty/input state and summarize expected results in text.

## Output Standard

The DOCX should be concise enough for internal onboarding, usually 6-15 pages depending on screenshots. Practical structure:

- Page 1: 3-minute summary（产品是做什么的 / 最常用的几件事 / 第一次建议这样用 / 开始前要知道 / 系统入口）.
- Task-oriented sections for core work.
- Short notes for supporting features.
- Lookup-level info for reference features.
- Rules, limits, and security notes.
- FAQ phrased as real user questions.

Use Chinese headings and practical wording unless the source material is explicitly English. Keep the document simple, businesslike, and easy to scan: no dark full-page backgrounds, no large brand-color blocks, no decorative graphics, no PPT-style pages.

After generating, always run the Reader Test (`references/reader-test.md`) and report its result honestly.
