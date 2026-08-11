# Ticket 模板

每张 Ticket 是一个可独立完成、演示和验证的纵向切片。

```markdown
# <NN> — <用户结果标题>

**What it delivers:** 用户完成什么动作后，可以看到什么完整结果。

**Blocked by:** <Ticket 编号/标题；无则写 None — ready now>

**Acceptance criteria:**
- [ ] 可观察结果 1
- [ ] 重要边界或失败恢复
- [ ] 与风险匹配的自动化/浏览器证据

**Execution context:**
- 本 Ticket 需要的 Spec/Handoff 章节
- 当前基线和临时文件所有权
- 不得修改的共享接线点
- 已验证命令或项目验证入口

**Evidence to return:** 修改结果、实际验证输出、剩余风险。
```

## 拆分规则

1. 纵向切片：完整穿过实现该用户结果所需的层，不按技术层拆票。
2. 单上下文：一个 fresh execution context 能完成并验证；太大就按可演示状态继续切。
3. 明确阻塞：只写真正必须先完成的 Ticket；没有阻塞即可并行进入 frontier。
4. 保持可运行：每张完成后主线应保持可测试；无法做到的宽迁移采用 expand → 分批 migrate → contract。
5. 轻量确认：只有粒度影响成本、发布顺序或产品范围时才让用户审批。

默认一个 Ticket 一个文件。Goal 只调度当前 frontier，完成后再解锁下一批。
