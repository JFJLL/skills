# 从这里开始

## 先明确边界

浏览器验收层当前只用 Kimi WebBridge；单元、集成、AI eval、数据和 smoke 测试继续由项目命令执行。这样不需要同时维护两套浏览器流程，代价是 CI 暂时不自动点击页面，UI 的最终证据来自本地 Kimi 验收。

## 第一次接入

先选一个真实项目试跑，推荐从已有 `test/check/build` 的项目开始。直接把下面这段话发给 Codex，并替换项目路径：

```text
把这个测试 Starter 接入 TARGET_PROJECT：
C:\Users\liuhao_PC\Documents\Codex\2026-07-16\vibecoding-codex-kimiwebbrige-skill-hook-anysearch-2\outputs\testing-system-starter

先不开 Hook，也不提交代码。读取项目现有命令和 AGENTS.md，复制并按项目实际情况调整 verification-policy.json、scripts/verify-change.ps1、templates/kimi-browser-qa.md 和 AGENTS.testing-snippet.md。运行 PlanOnly，修正 lane 映射，做一次完整验证并告诉我 receipt 路径。
```

Codex 接入时应完成：

1. 将项目真实的 `check/test/build/integration/smoke/eval` 命令映射到 `verification-policy.json`。
2. 将 `.verification/` 和 `artifacts/verification/` 加入项目 `.gitignore`。
3. 运行 `-PlanOnly`，确认普通 UI 改动会得到 `kimi-browser`，纯后台队列/重试改动不会误触发浏览器。
4. 暂不复制 `.codex/hooks.json`；先手动运行 2–3 天。

## 每天怎么用

最省事的调用方式是在开发要求末尾追加：

```text
完成修改后执行 $verify-change。需要 kimi-browser 时，使用 Kimi WebBridge 在真实登录态下验收受影响旅程，覆盖成功路径、相邻失败/恢复路径和刷新后的状态；把证据写入 artifacts/verification/kimi-browser-qa.md。修复发现的问题并重跑，直到当前 diff 的 receipt 为 pass。最后再做一次与修复者上下文分离的对抗审查。
```

对应的机械流程是：

```powershell
pwsh -NoProfile -File scripts/verify-change.ps1 -PlanOnly
pwsh -NoProfile -File scripts/verify-change.ps1
pwsh -NoProfile -File scripts/verify-change.ps1 -CheckReceipt
```

当 `requiredLanes` 包含 `kimi-browser` 时，Codex 应：

1. 启动或确认本地应用可访问。
2. 检查 Kimi WebBridge 守护进程和扩展连接。
3. 对用户当前打开的页面使用 `find_tab`，或导航到测试 URL；整次验收保持同一个 session。
4. 操作前开启 network 捕获，用 snapshot 定位控件，再执行 click/fill。
5. 至少覆盖受影响的成功路径、一个相邻失败/恢复路径，以及刷新或返回后的状态。
6. 记录截图和相关失败请求，按 `templates/kimi-browser-qa.md` 生成验收文件。
7. 从 `-PlanOnly` 输出复制 fingerprint，生成 `.verification/evidence.json`，然后运行完整 verifier。

## Kimi 缺陷怎么沉淀

- 业务规则、接口、状态或数据错误：先补失败的 unit/API/domain/data 回归，再修复。
- 只存在于交互或视觉层：在模板中新增一条有稳定名称的 Kimi case，以后相关 UI 改动重复执行。
- 偶发问题：保留截图、请求、环境和复现频率，不把“这次没出现”写成 pass。

## 什么时候开 Hook

手动运行 2–3 天，确认风险路由和项目命令没有误判后，再让 Codex 复制 `.codex/hooks.json` 与 `.codex/hooks/`。Hook 只负责阻止“没有新鲜 receipt 就结束任务”，不在 Stop 阶段重新跑整套测试。

等本地流程稳定后再复制 `.github/workflows/ci.yml`。CI 只重跑确定性 lane；`kimi-browser` 和 `agent-review` 是本地证据 lane，不在 CI 中伪造执行。

