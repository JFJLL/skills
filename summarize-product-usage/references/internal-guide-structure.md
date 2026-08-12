# Internal Product Usage Guide Structure

Use this reference when analyzing a project and writing a Chinese internal product usage manual in DOCX format.

## Source-of-Truth Priority

1. Runnable UI and screenshots.
2. Frontend routes, pages, navigation, components, form labels, buttons, and state text.
3. Backend APIs, task models, upload handlers, quota checks, auth logic, and generated output paths.
4. README, product specs, seed data, and tests.
5. Existing usage manuals only as style references unless the user explicitly asks to summarize documents.

## Section Options

Choose sections based on the product, not by filling a fixed template.

- Title and metadata: product name, audience, access URL, version date, scope.
- Short summary: what the product does and the first workflow a colleague should try.
- Quick start: 5-9 explicit steps from entry to first useful result.
- Recommended workflow: use when several modules must be used in order.
- Core workflow: detailed steps, screenshots, prerequisites, expected results, and limits.
- Secondary module notes: short paragraphs or small lists for lower-priority modules.
- Role-based usage: only when the project clearly supports different internal roles.
- Rules and safety: quotas, duplicate task cautions, data confidentiality, API key/password warnings, AI output review.
- FAQ: login failure, no selectable data, generation failed, slow response, bad output quality, missing quota.

Do not add a final "问题反馈模板" section.

## Weighting Guidance

- Give detailed steps to flows that create, generate, submit, upload, export, or affect quota.
- Summarize passive dashboards more lightly unless they are the product's primary value.
- Merge similar generation features into one section or table when their operation is nearly identical.
- Use screenshots for recognition and handoff, not decoration.
- Mention a dependency before the step that needs it, for example "使用内容洞察前，必须先有已完成的关键词任务。"

## Step Formatting

- Render step blocks as visible text: `1. ...`, `2. ...`, `3. ...`
- Restart every independent step block at `1.`
- Do not rely on Word automatic numbering, because numbering can continue across sections after editing.

## Writing Rules

- Write for internal colleagues, not external customers.
- Prefer "怎么用" and "建议怎么做" over feature marketing.
- Keep button and menu names exactly as the product shows them.
- Do not exaggerate AI output quality.
- Do not hide prerequisites, limits, or failure states.
- Do not include code-level implementation details unless they affect usage.
- If screenshots are included, caption them as "图 1：..." in source order.

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
