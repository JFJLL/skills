# Fresh-context Review

用于证明最终 diff 由未参与实现、未继承实现讨论的 reviewer 独立审查。

## Freeze

1. 完成实现、测试、build、smoke 和必要的真实界面验证。
2. 冻结基线和完整 diff（含未跟踪文件），记录 diff SHA256。
3. 记录审查前 `git status --porcelain=v1`；reviewer 运行期间禁止继续实现。

## Spawn

- 使用未参与实现的新 reviewer；当前工具必须 `fork_turns="none"`，旧工具等价为 `fork_context:false`。
- 不设置模型或 reasoning override，除非用户明确要求且当前模型目录允许。
- 只给冻结 diff（或带 SHA256 的只读 patch）、Spec/Ticket 验收要求；不给实现总结、辩解或预期答案。
- 禁止 reviewer 修改或创建文件、修复问题、启动其他代理；只在回复中返回证据。

## Review Axes

分别报告，不互相掩盖：

- **Spec fidelity**：缺失/部分实现、范围外行为、看似实现但语义错误。
- **Regression & safety**：回归、安全、数据口径、错误静默、边界和测试漏判。

每个问题给严重度、diff 文件/行、触发条件和证据；无问题也列检查过什么及残余风险。

## Proof

主代理保存 reviewer agent id、fresh 参数原始输出、基线、diff SHA256、审查前后状态和 reviewer 原始回复。前后状态必须一致；原始回复不可改写，执行方处置另存。

若 reviewer 发现问题：主代理修复、重跑验证、冻结新 diff，并启动另一个全新 reviewer。旧 verdict 自动失效；只给 receipt 或“review pass”摘要不算独立审查证明。
