# 从这里开始

## 先明确边界

本体系覆盖 Windows + PowerShell + Node/npm 项目。浏览器验收层只用 Kimi WebBridge；单元、集成、AI eval、数据和 smoke 测试由项目命令执行。代价是 CI 不自动点击页面，UI 的最终证据来自本地 Kimi 验收。

## 第一次接入

选一个真实项目，直接发：

```text
使用 $testing-system-starter 接入当前项目，先不开 Hook，不提交代码。
```

接入时 Codex 应完成：

1. 按项目真实命令调整 verification-policy.json，并适配 `changeScope.baseRef`。
2. 将 `.verification/` 和 `artifacts/verification/` 加入 .gitignore。
3. 运行 `-PlanOnly`，确认 UI 改动命中 kimi-browser、auth 命中 R3、docs/auth.md 是 R0、ThemeProvider 不命中 ai-eval。
4. 生成 verification-system.json，暂不复制 hooks 和 CI。

## 每天怎么用

在开发要求末尾追加：

```text
完成修改后执行 $verify-change。
按 PlanOnly 返回的 required lanes 做验证：
需要 kimi-browser 时使用 Kimi WebBridge；
需要 agent-review 时执行 fresh-context independent review（只读、双轴、最多 3 轮，超限升级给我）。
修复发现的问题并重跑，直到当前 change set 的 receipt 为 pass。
```

机械流程：

```powershell
pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
pwsh -NoProfile -File scripts/verify-change.ps1 -InitEvidence
pwsh -NoProfile -File scripts/verify-change.ps1
pwsh -NoProfile -File scripts/verify-change.ps1 -CheckReceipt
```

当 `requiredLanes` 包含 `kimi-browser` 时：

1. 启动或确认本地应用可访问。
2. 检查 Kimi WebBridge 健康（`scripts/kimi-browser.ps1 -Action status`）。
3. 对用户当前页面使用 find_tab，或导航到测试 URL；整次验收保持同一个 session。
4. 操作前 `network start`，用 snapshot 定位控件。
5. 覆盖计划要求的 case：KIMI-001 必跑，其余按 route 条件增补。
6. 按模板生成验收文件（changeSetHash 必填，不得残留 pending/fail）。

## 缺陷怎么沉淀

- 业务规则、接口、状态或数据错误：先补失败的 unit/API/domain/data 回归，再修复。
- 只存在于交互或视觉层：在 Kimi 模板中新增一条有稳定名称的 case，后续相关 UI 改动重复执行。
- 偶发问题：保留截图、请求、环境和复现频率，不把"这次没出现"写成 pass。

## 什么时候开 Hook

手动运行 2–3 天，确认风险路由和项目命令没有误判后，再让 Codex 复制 `.codex/hooks.json` 与 `.codex/hooks/`。Stop Hook 每次都直接校验 receipt 是否新鲜，不再依赖编辑工具名。

本地流程稳定后再复制 `.github/workflows/ci.yml`。CI 只重跑确定性 lane；kimi-browser 和 agent-review 是本地证据 lane，不在 CI 中伪造执行。
