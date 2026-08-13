# Reader Test

Run this check after the final DOCX is generated, before reporting completion. It targets a cold reader who did NOT participate in the project analysis or document generation.

## Required Questions

A cold reader must be able to answer all of these from the document alone:

1. 这个产品是做什么的？
2. 第一次应该从哪里开始？
3. 最常用的几件事是什么？
4. 核心任务应该怎么完成？
5. 提交以后怎么知道成功？
6. 最终结果在哪里？
7. 常见问题应该怎么办？
8. 哪些操作有额度、隐私或重复提交风险？

## Also Check

- 无法回答的问题 (questions the document leaves unanswered).
- 含糊的地方 (vague wording).
- 需要技术背景才能理解的表达 (sentences that require development background).
- 重复内容 (duplicated content, including Quick Start vs Recommended Workflow).
- 隐藏前置条件 (hidden prerequisites).
- 截图与步骤脱节 (screenshots detached from the steps they illustrate).

## Procedure

1. Prepare the final DOCX (and the summary JSON only if needed to verify facts).
2. If a fresh-context agent is available:
   - The fresh context must not have seen the project analysis or implementation discussion.
   - Give it ONLY the final document, not code or analysis context.
   - Ask it to answer the eight questions and the additional checks above, citing document evidence for each answer.
   - Fix any gaps found, then re-test.
3. If no fresh-context agent is available:
   - Do NOT fake a fresh reader result.
   - Perform a structured self-check against the same questions and checks.
   - Explicitly mark in the final report:「未完成独立 Reader Test」.

## Pass/Fail Rule

The guide passes only when all eight questions are answered from the DOCX alone and each answer cites a page, heading, step, screenshot, or other document evidence. `answered` without evidence is not sufficient. Any `not answered`, vague core step, unexplained technical term, hidden prerequisite, detached screenshot, or unresolved contradiction fails the test.

Fix every failure, regenerate the DOCX, and rerun the independent test. Do not weaken the questions or accept a partial score. The required delivery score is `8/8`.

## Result Reporting

Report per question: answered with evidence / not answered. List every gap found and whether it was fixed. State clearly whether the test was run by a genuinely fresh context or by self-check. A self-check may diagnose a draft but cannot satisfy the formal delivery gate when a fresh-context agent is available.
