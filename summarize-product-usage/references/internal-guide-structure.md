# Internal Product Usage Guide Structure

Use this reference when analyzing a project and writing a Chinese internal product usage manual in DOCX format.

## Default Reader

The reader is an internal colleague with no technical background: no code, APIs, databases, architecture, task queues, or AI engineering. Every sentence must be understandable without development background.

## Source-of-Truth Priority

1. Runnable UI and screenshots.
2. Frontend routes, pages, navigation, components, form labels, buttons, and state text.
3. Backend APIs, task models, upload handlers, quota checks, auth logic, and generated output paths.
4. README, product specs, seed data, and tests.
5. Existing usage manuals only as style references unless the user explicitly asks to summarize documents.

Never guess. Unverifiable facts (URLs, quotas, account rules, permissions, states, upload formats, file size limits, output locations) must be omitted or marked「未在项目中确认」.

## User-Task-Oriented Principle

Section headings should use the goal a user would actually express, not the technical module name.

Correct:

> 我要查看以前生成的结果

Not:

> Generation History Module

Default document shape:

```text
我想要……
├─ 我要看看最近有什么热点
├─ 我要找优秀内容参考
├─ 我要生成内容
└─ 我要找到之前生成的结果
```

Keep the real entry name next to each task:

```text
我要看看最近有什么热点
入口：左侧菜单「趋势洞察」
```

Only fall back to a module-oriented structure (按模块/页面) when the product genuinely has no task-shaped workflows.

## Weighting: core / supporting / reference

Assign a weight to every feature instead of writing equal-length sections for everything.

### core

Directly produces the user's main result. Include as much as possible:

- What it is used for.
- Where to enter.
- What you need before starting.
- Operation steps.
- What you should see after each step succeeds.
- Where the final result is.
- High-frequency problems.
- Necessary screenshots.

### supporting

Helper capabilities. Summarize briefly as needed: purpose, entry, steps, screenshots if useful. Skip result and problem sections unless they are genuinely needed.

### reference

Settings, profile pages, low-frequency entries. Provide only enough to look things up: purpose, entry, and at most a short step list.

## First-Page 3-Minute Summary

Page 1 answers, in under 3 minutes of reading:

- What this product helps you do (one very short sentence).
- The most common 3-5 things it is used for.
- How to get the first useful result (Quick Start).
- The 2-4 things to know before starting.
- The system entry, when it can be confirmed from the project.

Version date, audience, and other metadata may exist but with lower visual weight. Detailed content starts after page 1.

## Quick Start and Recommended Workflow

Quick Start answers only:

> First time using this product, what is the shortest path to the first useful result?

Keep it short. Recommended Workflow answers only:

> During normal work, how should several capabilities be combined?

Only include Recommended Workflow when a real ordering between capabilities exists in the project. If one clearly duplicates the other (equal, or one is a prefix), render the longer list once as Quick Start and skip Recommended Workflow.

## Section Options

Choose sections based on the product, not by filling a fixed template.

- Title and metadata: product name, audience, access URL, version date, scope.
- First-page 3-minute summary.
- Task-oriented core workflow sections (entry, purpose, prerequisites, steps, expected results, result location, common problems, screenshots).
- Secondary feature notes: short paragraphs or small lists for supporting features.
- Reference entries: settings, profile pages, low-frequency pages.
- Role-based usage: only when the project clearly supports different internal roles.
- Rules and safety: quotas, duplicate task cautions, data confidentiality, API key/password warnings, AI output review.
- FAQ: login failure, no selectable data, generation failed, slow response, bad output quality, missing quota.

Do not add a final「问题反馈模板」section.

## Plain Language Rules

### Keep exactly as the product shows them

- Menu names.
- Button names.
- Page names.
- State text users actually see.

### Convert to plain language by default

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

Examples:

```text
异步执行 → 系统会在后台继续处理
pending → 等待处理
```

If the original UI itself displays an English state, keep that real state text and add one short plain-Chinese explanation.

## Step Formatting

- Render step blocks as visible text: `1. ...`, `2. ...`, `3. ...`
- Restart every independent step block at `1.`
- Do not rely on Word automatic numbering, because numbering can continue across sections after editing.
- Do not merge a step's expected result, warning, and tip into one flat paragraph. Render them as visually distinct callouts（完成后 / 注意 / 建议）under the step.

V2 object step:

```json
{
  "action": "点击「开始分析」",
  "expected_result": "页面出现「处理中」，说明任务已经成功提交。",
  "warning": "已经进入处理中时不要再次点击。",
  "tip": "可以稍后到任务历史中查看结果。"
}
```

Renders approximately as:

```text
3. 点击「开始分析」

完成后：
页面出现「处理中」，说明已经成功提交。

注意：
已经进入处理中时不要再次点击。
```

`action` is required. Use `expected_result` for core flows, `warning` only for real risks, `tip` only when it genuinely helps. Screenshots attach to the step they illustrate (step-level `screenshot`), with module/task-level `screenshots` as fallback.

## FAQ Rules

FAQ titles must be questions a normal user would actually ask:

```text
为什么一直显示「处理中」？
为什么这里没有可以选择的内容？
为什么生成失败了？
```

Avoid implementation-flavored titles:

```text
异步任务异常
数据源为空
AI 接口调用异常
```

## Writing Rules

- Write for internal colleagues, not external customers.
- Prefer「怎么用」and「建议怎么做」over feature marketing.
- Keep button and menu names exactly as the product shows them.
- Do not exaggerate AI output quality.
- Do not hide prerequisites, limits, or failure states.
- Do not include code-level implementation details unless they affect usage.
- If screenshots are included, caption them as「图 1：...」in source order and place each near the step it supports.

## Project Analysis Checklist

- App entry and routing.
- Login/account states and permission differences.
- Main navigation labels.
- Required inputs for each important flow.
- Submit/generate/export buttons.
- Task states and result locations.
- Upload formats and file size limits.
- Quota or credit consumption.
- Empty, failed, loading, and completed states.
- Download, share, report, or history behavior.

After generating the DOCX, run `references/reader-test.md` and report the result honestly.
