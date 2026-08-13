#!/usr/bin/env python3
"""Validate the evidence ledger used by summarize-product-usage.

The validator deliberately has no third-party dependencies so it can run early in
the document-generation workflow.  A claim is considered critical by default;
supplementary notes must opt out explicitly with ``"critical": false``.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import sys
from typing import Any, Sequence


ALLOWED_TYPES = frozenset(
    {
        "ui_text",
        "ui_behavior",
        "permission",
        "quota",
        "upload_limit",
        "state",
        "result_location",
        "account_rule",
    }
)
ALLOWED_STATUSES = frozenset({"confirmed", "pending", "rejected"})
ALLOWED_CONFIDENCE = frozenset({"high", "medium", "low"})


@dataclass(frozen=True)
class ValidationIssue:
    """One actionable ledger validation error."""

    location: str
    code: str
    message: str

    def format(self) -> str:
        return f"{self.location}：{self.message}（{self.code}）"


def _is_non_empty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _conflict_is_unresolved(value: Any) -> bool:
    """Return whether a conflict value represents an unresolved disagreement.

    Supported no-conflict values are null, false, an empty string/list/object, or
    an object whose status is ``none``.  A resolved conflict must declare both
    ``status: resolved`` and a non-empty ``resolution`` so the decision remains
    auditable.
    """

    if value is None or value is False or value == "" or value == [] or value == {}:
        return False
    if isinstance(value, dict):
        status = value.get("status")
        if status == "none":
            return False
        if status == "resolved" and _is_non_empty_text(value.get("resolution")):
            return False
        return True
    return True


def validate_ledger(data: Any) -> list[ValidationIssue]:
    """Return all validation issues without stopping at the first failure."""

    issues: list[ValidationIssue] = []
    if not isinstance(data, dict):
        return [ValidationIssue("根节点", "invalid_root", "账本必须是 JSON 对象")]

    claims = data.get("claims")
    if not isinstance(claims, list) or not claims:
        return [
            ValidationIssue(
                "claims", "missing_claims", "必须提供至少一条事实记录"
            )
        ]

    seen_ids: set[str] = set()
    for index, claim in enumerate(claims):
        location = f"claims[{index}]"
        if not isinstance(claim, dict):
            issues.append(ValidationIssue(location, "invalid_claim", "事实记录必须是对象"))
            continue

        claim_id = claim.get("claim_id")
        if not _is_non_empty_text(claim_id):
            issues.append(ValidationIssue(location, "missing_claim_id", "claim_id 不能为空"))
        elif claim_id in seen_ids:
            issues.append(
                ValidationIssue(location, "duplicate_claim_id", f"claim_id {claim_id!r} 重复")
            )
        else:
            seen_ids.add(claim_id)

        if not _is_non_empty_text(claim.get("claim")):
            issues.append(ValidationIssue(location, "missing_claim", "claim 不能为空"))

        claim_type = claim.get("type")
        if claim_type not in ALLOWED_TYPES:
            allowed = "、".join(sorted(ALLOWED_TYPES))
            issues.append(
                ValidationIssue(
                    location,
                    "invalid_type",
                    f"type 必须是以下值之一：{allowed}",
                )
            )

        for field, label in (("source", "source"), ("source_locator", "source_locator")):
            if not _is_non_empty_text(claim.get(field)):
                issues.append(
                    ValidationIssue(location, f"missing_{field}", f"{label} 不能为空")
                )

        if not isinstance(claim.get("runtime_verified"), bool):
            issues.append(
                ValidationIssue(
                    location,
                    "invalid_runtime_verified",
                    "runtime_verified 必须明确填写 true 或 false",
                )
            )

        confidence = claim.get("confidence")
        if confidence not in ALLOWED_CONFIDENCE:
            issues.append(
                ValidationIssue(
                    location,
                    "invalid_confidence",
                    "confidence 必须是 high、medium 或 low",
                )
            )

        status = claim.get("status")
        if status not in ALLOWED_STATUSES:
            issues.append(
                ValidationIssue(
                    location,
                    "invalid_status",
                    "status 必须是 confirmed、pending 或 rejected",
                )
            )

        critical = claim.get("critical", True)
        if not isinstance(critical, bool):
            issues.append(
                ValidationIssue(location, "invalid_critical", "critical 必须是 true 或 false")
            )
        elif critical and status != "confirmed":
            issues.append(
                ValidationIssue(
                    location,
                    "critical_not_confirmed",
                    "正式交付的关键事实必须为 status=confirmed",
                )
            )
        elif critical and confidence != "high":
            issues.append(
                ValidationIssue(
                    location,
                    "critical_not_high_confidence",
                    "正式交付的关键事实必须为 confidence=high",
                )
            )

        if claim_type in {"ui_behavior", "state", "result_location"} and claim.get("runtime_verified") is not True:
            issues.append(
                ValidationIssue(
                    location,
                    "runtime_verification_required",
                    f"{claim_type} 必须通过真实运行确认并填写 runtime_verified=true",
                )
            )

        if "conflict" not in claim:
            issues.append(
                ValidationIssue(
                    location,
                    "missing_conflict",
                    "必须填写 conflict；无冲突时使用 null",
                )
            )
        elif _conflict_is_unresolved(claim.get("conflict")):
            issues.append(
                ValidationIssue(
                    location,
                    "unresolved_conflict",
                    "存在未解决的证据冲突；解决后填写 status=resolved 和 resolution",
                )
            )

    return issues


def load_and_validate(path: Path) -> list[ValidationIssue]:
    try:
        raw = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        return [ValidationIssue(str(path), "read_error", f"无法读取文件：{exc}")]

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        return [
            ValidationIssue(
                str(path),
                "invalid_json",
                f"JSON 格式错误（第 {exc.lineno} 行，第 {exc.colno} 列）：{exc.msg}",
            )
        ]
    return validate_ledger(data)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="校验正式交付文档的事实证据账本")
    parser.add_argument("ledger", nargs="?", type=Path, help="evidence.json 的路径")
    parser.add_argument("--input", dest="input_path", type=Path, help="evidence.json 的路径")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="启用正式交付严格校验（当前版本默认即为严格校验，保留该参数以明确调用意图）",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    ledger = args.input_path or args.ledger
    if ledger is None:
        print("证据账本校验失败：请通过 --input 指定 evidence.json。", file=sys.stderr)
        return 2
    issues = load_and_validate(ledger)
    if issues:
        print(f"证据账本校验失败：共 {len(issues)} 个问题。", file=sys.stderr)
        for issue in issues:
            print(f"- {issue.format()}", file=sys.stderr)
        print("请修复以上问题后再生成正式文档。", file=sys.stderr)
        return 1

    print(f"证据账本校验通过：{ledger}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
