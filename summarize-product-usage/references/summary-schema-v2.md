# Summary JSON V2

Read this reference before writing the renderer input. Prefer V2 `tasks`; legacy fields remain renderer-compatible but should not be used for new formal deliverables.

## Minimum Shape

```json
{
  "title": "<产品名称>内部使用指南",
  "subtitle": "面向公司内部同事",
  "audience": "<真实使用角色>",
  "version_date": "YYYY-MM-DD",
  "access_url": "<已确认入口；未确认则省略>",
  "at_a_glance": {
    "what_it_does": "<一句话说明>",
    "top_tasks": ["<真实任务>"],
    "before_you_start": ["<真实风险或前置条件>"]
  },
  "quick_start": ["<最短首个成功路径>"],
  "tasks": [
    {
      "title": "<我要完成什么>",
      "entry": "<页面或菜单的真实名称>",
      "purpose": "<为什么使用>",
      "prerequisites": ["<开始前必须满足的条件>"],
      "priority": "core",
      "claim_ids": ["<evidence.json 中已确认的 claim_id>"],
      "steps": [
        {
          "action": "<用户动作>",
          "expected_result": "<用户看得见的成功信号>",
          "warning": "<仅填写真实风险>",
          "tip": "<仅填写真正有帮助的建议>",
          "screenshot": {
            "path": "<截图路径>",
            "caption": "<截图说明>",
            "coverage": ["entry", "action", "success", "result"]
          }
        }
      ],
      "result": "<最终结果位置或内容>",
      "common_problems": [
        {"question": "<真实用户问题？>", "answer": "<已确认处理方法>"}
      ],
      "screenshots": []
    }
  ],
  "usage_rules": ["<真实规则、限制或安全提醒>"],
  "faq": [
    {"question": "<真实用户问题？>", "answer": "<已确认答案>"}
  ]
}
```

The strings above are placeholders, not product facts. Never copy them into a finished guide.

## Field Rules

### `at_a_glance`

- `what_it_does`: one short sentence.
- `top_tasks`: the most important 3–5 user goals, ordered by real frequency or importance.
- `before_you_start`: the most important 2–4 confirmed risks or prerequisites. Put security, privacy, paid/quota, and irreversible risks before ordinary advice. Put remaining confirmed rules in `usage_rules`.

### `tasks`

- `title`: a user goal, not a module name.
- `entry`: exact visible entry point.
- `priority`: exactly `core`, `supporting`, or `reference`.
- `claim_ids`: evidence-ledger claims supporting the task; every value must exist with `status=confirmed`.
- `prerequisites`: conditions that must already be true.
- `steps`: strings or step objects. Use objects for core actions so success signals and screenshots stay attached.
- `result`: what the user receives and where it appears.
- `common_problems`: complete question/answer pairs only.
- `screenshots`: task-level fallback images; prefer step-level images when they illustrate one action.

For formal delivery, every core task needs a title, entry, prerequisites, non-empty steps, at least one visible `expected_result`, a final `result`, common-problem coverage when the product exposes failure states, and sufficient referenced screenshots.

### Step objects

`action` is required. `expected_result` is required on every submission, save, generation, upload, login, export, or other state-changing action, and wherever the reader otherwise cannot tell whether the step succeeded. Use `warning` only for a confirmed risk and `tip` only for genuinely useful help.

### `covers_modules`

When both `tasks` and `modules` exist, add `covers_modules` to tasks using exact `modules[].name` values. Declare coverage only after all usage-affecting limits, steps, results, and warnings from that module are present in the task. Prefer omitting `modules` entirely for new task-oriented guides when it would only duplicate content.

## Screenshot Values

Screenshot paths may be absolute or relative to `summary.json`. Use an object with `path`, `caption`, and `coverage`. Across each core task, coverage must include `entry`, `action`, `success`, and `result`; one image may prove multiple moments only when it visibly contains them. Every referenced image must exist, be readable, and be intentionally placed. A missing or corrupt image is a delivery-blocking validation error.

The renderer inserts every screenshot at the full available text width while preserving its aspect ratio. Keep the captured PNG at the original high resolution; do not pre-shrink it. The skill prepares the DOCX for Feishu import but does not upload or test it in Feishu.

## Legacy Compatibility

The renderer still accepts `overview`, `modules`, `sections`, `scenarios`, `key_outputs`, `notes`, and legacy string steps. This exists for old inputs only. Do not use legacy compatibility as a reason to omit the stricter V2 fields in a new formal deliverable.
