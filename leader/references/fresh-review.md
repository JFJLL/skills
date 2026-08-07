# Fresh-context 独立审查协议

目标：证明审查者没有参与实现、没有继承实现讨论、没有修改代码，并针对冻结 diff 独立产出证据。

## 前置条件

1. 实现、测试、build、smoke 和必要的浏览器验证已经结束。
2. 冻结审查输入：记录基线 ref、完整 diff（含未跟踪文件）和 diff SHA256。
3. 记录审查前 `git status --porcelain=v1`；不得在 reviewer 运行期间继续实现。
4. 准备独立审查要求，只写要检查的风险、完成标准和报告格式，不提供实现总结、设计辩解或预期结论。

大 diff 可保存为只读 `review-input.patch`。给 reviewer 的上下文仍只能是该 patch 与审查要求，不能让其读取当前对话。patch 路径和 SHA256 必须记录。

## 启动 reviewer

- 使用从未参与实现的全新子代理。
- 当前工具：`fork_turns="none"`。
- 旧工具等价：`fork_context:false`。
- 不设置模型或 reasoning override，除非用户明确要求且模型目录当前有效。
- reviewer 禁止修改任何文件，也不得创建证据文件；所有证据只在回复中返回。
- reviewer 不得启动其他代理。

建议提示词：

```text
你是独立 reviewer。只读审查，禁止修改或创建任何文件，禁止修复问题，禁止启动其他代理。

你只获得：
1. 基线与完整 diff：<内联 diff 或 review-input.patch + SHA256>
2. 审查要求：<风险清单与报告格式>

检查功能回归、安全、数据口径、边界、错误静默、测试漏判和范围越界。每个问题给严重度、diff 文件/行、触发条件和证据；无问题也列出逐项检查证据与残余风险。不要采信实现者结论。
```

## 必须保存的独立性证明

主代理在 reviewer 返回后保存：

- reviewer agent id / task name；
- 启动参数原始输出，明确 `fork_turns="none"` 或 `fork_context:false`；
- 基线 ref、diff/patch SHA256；
- 审查前和审查后 `git status --porcelain=v1`，两者必须一致；
- reviewer 原始回复，不能只保存主代理摘要；
- reviewer 是否发现问题、问题如何处理、是否需要新 reviewer。

reviewer 原始回复一经保存即视为不可变证据。主代理不得向其中追加“执行方修复记录”、改写 verdict 或删除问题；问题处置与反证必须写入单独的 disposition 文件。只要主代理根据意见改变了 diff，原 verdict 就自动失效。

可生成 `artifacts/verification/fresh-review-proof.md`，但只能由主代理在 reviewer 结束后写入。该证明至少包含：

```text
reviewer_agent_id:
fresh_context_parameter:
base_ref:
diff_sha256:
status_before_sha256 / raw:
status_after_sha256 / raw:
raw_reviewer_output:
verdict:
```

## 判定规则

- 没有 agent id：未证明。
- 没有 fresh-context 参数：未证明。
- reviewer 继承了实现对话：不独立，作废重启。
- reviewer 修改了任何文件：本轮作废，恢复状态并重启新 reviewer。
- 只给 receipt 或“agent-review pass”摘要：未证明。
- 主代理修复 reviewer 问题后：旧结论失效，必须冻结新 diff 并启动另一个全新 reviewer。
- 不得把主代理的修复说明追加到 reviewer 原始证据后继续沿用旧 PASS；这不算 post-fix 独立审查。
- reviewer 发现中高风险问题但被主代理口头判为误报：必须提供可复现反证；否则保留为未解决问题。

最终报告必须同时说明“实现验证是否通过”和“独立审查是否被证明”，两者不得合并成一句“全部通过”。
