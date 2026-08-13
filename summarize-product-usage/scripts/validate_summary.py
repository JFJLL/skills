#!/usr/bin/env python3
"""正式交付前校验产品使用说明 JSON。

退出码：0 表示通过；1 表示内容校验失败；2 表示输入文件无法读取或解析。
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, List, Optional, Sequence

from PIL import Image, UnidentifiedImageError


VALID_PRIORITIES = {"core", "supporting", "reference"}
REQUIRED_SCREENSHOT_COVERAGE = {"entry", "action", "success", "result"}

# 这些动作会改变产品状态、产生交付物或完成不可忽略的业务节点，因此读者
# 需要知道动作是否真正成功。纯导航、填写和筛选动作不在这里，以免制造空话。
KEY_ACTION_TERMS = (
    "提交",
    "生成",
    "保存",
    "发布",
    "删除",
    "下载",
    "上传",
    "导出",
    "创建",
    "添加",
    "修改",
    "更新",
    "确认",
    "发送",
    "支付",
    "注册",
    "登录",
    "重置",
    "同步",
    "启用",
    "停用",
    "绑定",
    "解绑",
    "approve",
    "submit",
    "generate",
    "save",
    "publish",
    "delete",
    "download",
    "upload",
    "create",
    "update",
    "send",
)


@dataclass(frozen=True)
class ValidationIssue:
    location: str
    message: str

    def format(self) -> str:
        return f"{self.location}：{self.message}"


def _has_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _as_entries(value: Any) -> Iterable[Any]:
    if isinstance(value, list):
        return value
    if value is None:
        return []
    return [value]


def _resolve_path(raw_path: str, base_dir: Path) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else base_dir / path


def _validate_image(path_value: Any, location: str, base_dir: Path, issues: List[ValidationIssue]) -> None:
    if not _has_text(path_value):
        issues.append(ValidationIssue(location, "截图缺少非空 path。"))
        return
    image_path = _resolve_path(path_value.strip(), base_dir)
    if not image_path.is_file():
        issues.append(ValidationIssue(location, f"截图不存在：{image_path}"))
        return
    try:
        with Image.open(image_path) as image:
            image.verify()
    except (OSError, ValueError, UnidentifiedImageError) as exc:
        issues.append(ValidationIssue(location, f"截图无法读取或文件已损坏：{image_path}（{exc}）"))


def _validate_screenshot(value: Any, location: str, base_dir: Path, issues: List[ValidationIssue]) -> None:
    for index, shot in enumerate(_as_entries(value), start=1):
        shot_location = f"{location}[{index}]"
        if isinstance(shot, str):
            _validate_image(shot, shot_location, base_dir, issues)
        elif isinstance(shot, dict):
            _validate_image(shot.get("path"), f"{shot_location}.path", base_dir, issues)
        else:
            issues.append(ValidationIssue(shot_location, "截图必须是路径字符串或包含 path 的对象。"))


def _screenshot_coverage(value: Any) -> set[str]:
    coverage: set[str] = set()
    for shot in _as_entries(value):
        if not isinstance(shot, dict) or not _has_text(shot.get("path")):
            continue
        raw = shot.get("coverage")
        if isinstance(raw, list):
            coverage.update(item.strip().lower() for item in raw if _has_text(item))
    return coverage


def _validate_faq(value: Any, location: str, issues: List[ValidationIssue]) -> None:
    if value is None:
        return
    if not isinstance(value, list):
        issues.append(ValidationIssue(location, "FAQ 必须是问答对象数组。"))
        return
    for index, item in enumerate(value, start=1):
        item_location = f"{location}[{index}]"
        if not isinstance(item, dict):
            issues.append(ValidationIssue(item_location, "FAQ 条目必须是包含 question 和 answer 的对象。"))
            continue
        if not _has_text(item.get("question")):
            issues.append(ValidationIssue(f"{item_location}.question", "问题不能为空。"))
        if not _has_text(item.get("answer")):
            issues.append(ValidationIssue(f"{item_location}.answer", "答案不能为空。"))


def _is_key_action(action: str) -> bool:
    normalized = action.casefold()
    return any(term in normalized for term in KEY_ACTION_TERMS)


def _validate_steps(
    value: Any,
    location: str,
    issues: List[ValidationIssue],
    base_dir: Path,
    require_nonempty: bool,
    require_key_results: bool,
) -> None:
    if not isinstance(value, list):
        issues.append(ValidationIssue(location, "steps 必须是数组。"))
        return
    if require_nonempty and not value:
        issues.append(ValidationIssue(location, "核心任务至少需要一个操作步骤。"))
        return
    for index, step in enumerate(value, start=1):
        step_location = f"{location}[{index}]"
        if isinstance(step, str):
            if not step.strip():
                issues.append(ValidationIssue(step_location, "步骤说明不能为空。"))
            elif require_key_results and _is_key_action(step):
                issues.append(
                    ValidationIssue(
                        step_location,
                        "这是会提交、生成、保存或改变状态的关键步骤；请改为对象步骤并填写 expected_result。",
                    )
                )
            continue
        if not isinstance(step, dict):
            issues.append(ValidationIssue(step_location, "步骤必须是非空字符串或对象。"))
            continue
        action = step.get("action")
        if not _has_text(action):
            issues.append(ValidationIssue(f"{step_location}.action", "对象步骤必须包含非空 action。"))
        elif require_key_results and _is_key_action(action) and not _has_text(step.get("expected_result")):
            issues.append(
                ValidationIssue(
                    f"{step_location}.expected_result",
                    "关键步骤必须说明成功后页面出现什么或结果保存在哪里。",
                )
            )
        if "screenshot" in step:
            _validate_screenshot(step.get("screenshot"), f"{step_location}.screenshot", base_dir, issues)


def _validate_task(task: Any, index: int, base_dir: Path, issues: List[ValidationIssue]) -> None:
    location = f"tasks[{index}]"
    if not isinstance(task, dict):
        issues.append(ValidationIssue(location, "任务必须是对象。"))
        return

    priority = task.get("priority", "core")
    if not _has_text(priority) or priority.strip().lower() not in VALID_PRIORITIES:
        issues.append(
            ValidationIssue(
                f"{location}.priority",
                "priority 只能是 core、supporting 或 reference。",
            )
        )
        # 继续按核心任务检查，防止一次只暴露一个问题。
        is_core = True
    else:
        is_core = priority.strip().lower() == "core"

    if not _has_text(task.get("title")):
        issues.append(ValidationIssue(f"{location}.title", "任务标题不能为空。"))
    if is_core and not _has_text(task.get("entry")):
        issues.append(ValidationIssue(f"{location}.entry", "核心任务必须写明真实入口。"))
    if is_core:
        claim_ids = task.get("claim_ids")
        if not isinstance(claim_ids, list) or not claim_ids or not all(_has_text(item) for item in claim_ids):
            issues.append(
                ValidationIssue(
                    f"{location}.claim_ids",
                    "核心任务必须引用 evidence.json 中一条或多条已确认 claim_id。",
                )
            )
        prerequisites = task.get("prerequisites")
        if not isinstance(prerequisites, list) or not any(_has_text(item) for item in prerequisites):
            issues.append(
                ValidationIssue(
                    f"{location}.prerequisites",
                    "核心任务必须写明至少一个真实前置条件；没有特殊条件时明确写“已登录系统”等基础条件。",
                )
            )
    if "steps" in task or is_core:
        _validate_steps(task.get("steps"), f"{location}.steps", issues, base_dir, is_core, is_core)
    if is_core:
        result = task.get("result")
        has_result = _has_text(result) or (
            isinstance(result, list) and any(_has_text(item) for item in result)
        )
        if not has_result:
            issues.append(
                ValidationIssue(
                    f"{location}.result",
                    "核心任务必须说明完成后的成功信号或结果位置。",
                )
            )
    if "screenshots" in task:
        _validate_screenshot(task.get("screenshots"), f"{location}.screenshots", base_dir, issues)
    if is_core:
        coverage = _screenshot_coverage(task.get("screenshots"))
        if isinstance(task.get("steps"), list):
            for step in task.get("steps", []):
                if isinstance(step, dict):
                    coverage.update(_screenshot_coverage(step.get("screenshot")))
        missing_coverage = sorted(REQUIRED_SCREENSHOT_COVERAGE - coverage)
        if missing_coverage:
            issues.append(
                ValidationIssue(
                    f"{location}.screenshots",
                    "核心任务截图缺少 coverage 标记或覆盖不完整；必须覆盖 entry、action、success、result。"
                    f" 当前缺少：{', '.join(missing_coverage)}。",
                )
            )
    _validate_faq(task.get("common_problems"), f"{location}.common_problems", issues)


def _validate_modules(modules: Any, base_dir: Path, issues: List[ValidationIssue]) -> None:
    if modules is None:
        return
    if not isinstance(modules, list):
        issues.append(ValidationIssue("modules", "modules 必须是数组。"))
        return
    if modules:
        issues.append(
            ValidationIssue(
                "modules",
                "正式交付必须使用 V2 tasks；modules 仅供旧 JSON 直接渲染兼容，不能通过严格预检。",
            )
        )
    for index, module in enumerate(modules, start=1):
        location = f"modules[{index}]"
        if not isinstance(module, dict):
            issues.append(ValidationIssue(location, "模块必须是对象。"))
            continue
        if "screenshots" in module:
            _validate_screenshot(module.get("screenshots"), f"{location}.screenshots", base_dir, issues)
        if "steps" in module:
            _validate_steps(module.get("steps"), f"{location}.steps", issues, base_dir, False, False)


def validate_summary(
    data: Any,
    base_dir: Path,
    confirmed_claim_ids: Optional[set[str]] = None,
) -> List[ValidationIssue]:
    """Return all formal-delivery validation issues in stable document order."""
    issues: List[ValidationIssue] = []
    if not isinstance(data, dict):
        return [ValidationIssue("$", "JSON 顶层必须是对象。")]
    if not data:
        return [ValidationIssue("$", "文档为空，无法正式交付。")]
    if not _has_text(data.get("title")):
        issues.append(ValidationIssue("title", "文档标题不能为空。"))

    tasks = data.get("tasks")
    modules = data.get("modules")
    if tasks is None and modules is None:
        issues.append(ValidationIssue("$", "文档至少需要 tasks 或 modules 之一。"))
    elif isinstance(tasks, list):
        if not tasks and not (isinstance(modules, list) and modules):
            issues.append(ValidationIssue("tasks", "文档没有任何任务或模块，无法正式交付。"))
        for index, task in enumerate(tasks, start=1):
            _validate_task(task, index, base_dir, issues)
    elif tasks is not None:
        issues.append(ValidationIssue("tasks", "tasks 必须是数组。"))

    _validate_modules(modules, base_dir, issues)
    _validate_faq(data.get("faq"), "faq", issues)
    if "screenshots" in data:
        _validate_screenshot(data.get("screenshots"), "screenshots", base_dir, issues)
    if confirmed_claim_ids is not None and isinstance(tasks, list):
        for index, task in enumerate(tasks, start=1):
            if not isinstance(task, dict):
                continue
            for claim_id in task.get("claim_ids", []) if isinstance(task.get("claim_ids"), list) else []:
                if _has_text(claim_id) and claim_id not in confirmed_claim_ids:
                    issues.append(
                        ValidationIssue(
                            f"tasks[{index}].claim_ids",
                            f"claim_id {claim_id!r} 不存在或未确认。",
                        )
                    )
    return issues


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="正式交付前校验产品使用说明 JSON")
    parser.add_argument("--input", required=True, type=Path, help="待校验的 JSON 文件")
    parser.add_argument(
        "--base-dir",
        type=Path,
        help="相对截图路径的基准目录；默认使用 JSON 文件所在目录",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="启用正式交付严格校验（当前版本默认即为严格校验，保留该参数以明确调用意图）",
    )
    parser.add_argument("--evidence", type=Path, help="已通过校验的 evidence.json；--strict 时必填")
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    input_path = args.input.resolve()
    try:
        with input_path.open("r", encoding="utf-8-sig") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        print(f"校验失败：找不到输入文件：{input_path}", file=sys.stderr)
        return 2
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        print(f"校验失败：无法读取 JSON：{input_path}（{exc}）", file=sys.stderr)
        return 2

    base_dir = (args.base_dir or input_path.parent).resolve()
    confirmed_claim_ids: Optional[set[str]] = None
    if args.strict:
        if args.evidence is None:
            print("校验失败：--strict 必须同时提供 --evidence。", file=sys.stderr)
            return 2
        try:
            evidence = json.loads(args.evidence.read_text(encoding="utf-8-sig"))
            confirmed_claim_ids = {
                item.get("claim_id")
                for item in evidence.get("claims", [])
                if isinstance(item, dict) and item.get("status") == "confirmed" and _has_text(item.get("claim_id"))
            }
        except (OSError, UnicodeError, json.JSONDecodeError, AttributeError) as exc:
            print(f"校验失败：无法读取 evidence.json（{exc}）", file=sys.stderr)
            return 2
    issues = validate_summary(data, base_dir, confirmed_claim_ids)
    if issues:
        print(f"预检未通过：发现 {len(issues)} 个问题：", file=sys.stderr)
        for issue in issues:
            print(f"- {issue.format()}", file=sys.stderr)
        print("请修复以上问题后再生成正式文档。", file=sys.stderr)
        return 1

    print(f"预检通过：{input_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
