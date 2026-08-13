# Writing and Structure Rules

Read this reference when deciding document structure, task priority, wording, or FAQ coverage.

## Reader and Tone

Write for an internal colleague who does not know code, APIs, databases, queues, models, or system architecture. Explain what they should do, what they will see, and what to do next.

Keep real menu names, page names, button labels, and visible status text exactly as shown. Translate implementation language:

| Avoid | Write instead |
| --- | --- |
| 任务进入 pending 后由 worker 异步消费。 | 提交后页面会显示「等待处理」，系统会在后台继续处理，不需要重复提交。 |
| 请求通过 API endpoint 提交。 | 点击「提交」后，页面会显示任务状态。 |
| 结果写入 database。 | 完成后结果会自动保存，可以在「历史记录」中找到。 |

Do not exaggerate AI quality or hide prerequisites, limits, failure states, privacy risks, or quota consumption.

## Task-Oriented Structure

Use a goal the user would actually say as each core heading:

```text
我要找到以前生成的结果
入口：左侧菜单「历史记录」
```

Do not use implementation headings such as「Generation History Module」. Fall back to page/module organization only when the product genuinely has no task-shaped workflow.

Give features unequal weight:

- `core`: purpose, exact entry, prerequisites, full numbered steps, success signals, result location, common problems, risks, and screenshots.
- `supporting`: purpose, entry, and only the steps/results needed to support a core task.
- `reference`: purpose, entry, and a short lookup procedure.

## First Page

Make the first page answer within three minutes:

1. What does the product help me do?
2. What are the 3–5 most common tasks?
3. What is the shortest path to the first useful result?
4. What 2–4 important things must I know before starting?
5. Where is the confirmed system entry?

Use `quick_start` for the shortest first-success path. Include `recommended_workflow` only when the product has a confirmed normal ordering across multiple capabilities. If it duplicates or extends Quick Start, render the longer sequence once as Quick Start.

## Steps and Screenshots

Write explicit text numbering: `1.`, `2.`, `3.`. Restart every independent step block from `1.`; do not rely on Word automatic numbering.

For important actions, separate:

- action;
- `expected_result` shown as「完成后」;
- real risk shown as「注意」;
- genuinely useful shortcut shown as「建议」.

Place each screenshot beside the step it proves. A screenshot is useful when it helps the reader recognize an entry, input, risk state, success state, or final result. Do not stack screenshots at the end merely to increase coverage.

## FAQ

Phrase FAQ entries as real questions:

- 为什么一直显示「处理中」？
- 为什么这里没有可以选择的内容？
- 完成后的结果在哪里？

Avoid technical titles such as「异步任务异常」or「数据源为空」. Include only problems supported by product behavior, tests, or runtime evidence.

## Final Shape

A typical guide contains:

- first-page three-minute summary;
- task-oriented core workflows;
- short supporting notes;
- reference lookups;
- confirmed rules, limits, and security notes;
- user-worded FAQ.

Do not add a final「问题反馈模板」section. Keep the result businesslike and scannable: no dark full-page backgrounds, decorative graphics, or slide-style layouts.
