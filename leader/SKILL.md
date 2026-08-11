---
name: leader
description: 把当前对话、已有研究或一句模糊需求整理成适合低成本执行模型的任务包。用户要“给 agent 写目标/任务书/brief/goal 提示词”“把分析交给新会话”“拆成可并行任务”或要求 fresh-context 审查时使用。先复用当前上下文，不重复调研；一个 fresh context 能完成就直接给 Goal，不能就生成轻量 Spec、纵向 Tickets 和一个启动 Goal；只有已有重要研究时才附 Handoff。
---

# Leader

让高智力模型负责理解、取舍和审查，让低成本模型拿到边界清楚、可以独立验收的工作。

## 1. 先综合，不重来

完整利用当前对话、代码探索、截图、文档和已有研究。不要重新采访用户已经回答过的问题，也不要让执行模型重做已经验证的调研。

只在某个未决选择会改变用户流程、数据口径、风险权限或验收结果时提问；一次最多 3 个，并给推荐默认值。

## 2. 只做一个复杂度判断

问：**一个 fresh context 能否在不重新决定产品方向的情况下，完成实现并验证用户结果？**

- **能**：直接生成一个紧凑 Goal。
- **不能**：生成 Spec，再拆成纵向 Tickets，最后给一个短启动 Goal。
- **已有大量外部研究或实测契约**：额外生成 Handoff；没有就不创建。

不要使用字数、文件数或技术层数作为主要复杂度标准。

## 3. 先定结果，再定实现

复杂任务按 [references/spec-template.md](references/spec-template.md) 写 Spec：从用户问题、完成后的使用流程和可观察行为出发，记录已经拍板的产品/技术决定、最高可用测试接缝、范围外事项和真正未决问题。

Spec 是耐久的产品契约：避免易过期的文件路径和大段代码。只有状态机、Schema 或类型形状比文字更准确地表达决定时，才保留最小片段。

若已有接口、Payload、抓包、迁移边界等研究，按 [references/handoff.md](references/handoff.md) 保存证据，不把这些临时事实塞进 Spec，也不让执行者重新发现。

## 4. 按纵向结果拆 Tickets

按 [references/ticket-template.md](references/ticket-template.md) 拆分：

- 每张 Ticket 贯穿完成该用户结果所需的 UI、API、数据和测试，而不是“前端一张、后端一张、测试一张”。
- 每张完成后都可单独演示或机器验证，并能放进一个 fresh context。
- 明确 `Blocked by`；阻塞项完成的 Ticket 才进入当前 frontier。
- 只有结构使任何纵向切片都无法保持可运行时，才增加小型前置重构；大范围迁移使用 expand → migrate → contract。

长期 Spec 不写文件路径；短期 Ticket 可以写当前文件所有权、基线和命令，防止多个执行代理争抢同一文件。

只有 Ticket 粒度会明显改变成本、上线顺序或产品范围时，才让用户确认；其余直接采用最小可交付拆分。

## 5. 交付一个执行入口

### 直接路径

给一段可直接粘贴的 `/goal`：用户结果、硬边界、必要上下文、验收和未授权操作。

### Spec 路径

管理者自动保存任务包，用户不手工建文件：

```text
outputs/<task>/spec.md
outputs/<task>/handoff.md          # 仅有研究时
outputs/<task>/tickets/01-*.md
outputs/<task>/goal.md
```

Goal 要求执行者完整读取 Spec、Handoff（如有）和当前 frontier Tickets；可并行时仅分派互不阻塞、文件所有权不重叠的 Tickets。主执行者负责共享接线、集成和最终验证。

不要把项目 `AGENTS.md` 已有规则、通用防作弊清单或调研过程重复抄进每张 Ticket；只写本任务新增约束和可观察验收。

## 6. 执行后独立审查

用户要求执行、验收或独立审查时，完成实现与项目验证后再读取 [references/fresh-review.md](references/fresh-review.md)。独立 reviewer 必须 fresh context、只看冻结 diff 与 Spec/Ticket 验收要求、禁止修改文件；修复任何审查问题后必须换一个全新 reviewer。

规划任务只生成审查要求，不在本轮启动实现或 reviewer。

## 交付检查

- 是否复用了当前讨论，而不是重新分析？
- 是否从用户结果出发，避免技术层横切？
- 每张 Ticket 是否独立可演示、可验证、适合一个 fresh context？
- 阻塞关系是否真实，当前 frontier 是否明确？
- 只有确有研究时才生成 Handoff，只有执行完成时才加载 Fresh Review？

最终只给用户需要的文件链接和一段可执行 Goal；不要输出内部调研流水账。
