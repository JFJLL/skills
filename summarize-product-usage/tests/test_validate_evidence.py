"""Tests for the evidence-ledger validator."""

from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "validate_evidence.py"
EXAMPLE = Path(__file__).resolve().parents[1] / "references" / "evidence-ledger.example.json"


def load_validator():
    spec = importlib.util.spec_from_file_location("validate_evidence", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_claim(**updates):
    claim = {
        "claim_id": "claim-1",
        "claim": "管理员可查看教师列表。",
        "type": "permission",
        "source": "运行中的管理后台",
        "source_locator": "/admin/teachers",
        "runtime_verified": True,
        "confidence": "high",
        "status": "confirmed",
        "conflict": None,
    }
    claim.update(updates)
    return claim


def cli_env():
    env = os.environ.copy()
    env["PYTHONIOENCODING"] = "utf-8"
    return env


class ValidateEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.validator = load_validator()

    def test_example_is_valid(self) -> None:
        data = json.loads(EXAMPLE.read_text(encoding="utf-8"))
        self.assertEqual([], self.validator.validate_ledger(data))

    def test_all_supported_types_are_accepted(self) -> None:
        claims = [
            valid_claim(claim_id=f"claim-{index}", type=claim_type)
            for index, claim_type in enumerate(sorted(self.validator.ALLOWED_TYPES))
        ]
        self.assertEqual([], self.validator.validate_ledger({"claims": claims}))

    def test_missing_sources_and_invalid_runtime_flag_are_reported(self) -> None:
        issues = self.validator.validate_ledger(
            {
                "claims": [
                    valid_claim(source=" ", source_locator=None, runtime_verified="yes")
                ]
            }
        )
        codes = {issue.code for issue in issues}
        self.assertEqual(
            {"missing_source", "missing_source_locator", "invalid_runtime_verified"},
            codes,
        )

    def test_critical_claim_must_be_confirmed(self) -> None:
        issues = self.validator.validate_ledger(
            {"claims": [valid_claim(status="pending")]}
        )
        self.assertIn("critical_not_confirmed", {issue.code for issue in issues})

    def test_critical_claim_must_have_high_confidence(self) -> None:
        issues = self.validator.validate_ledger(
            {"claims": [valid_claim(confidence="low")]}
        )
        self.assertIn("critical_not_high_confidence", {issue.code for issue in issues})

    def test_noncritical_claim_may_be_pending(self) -> None:
        issues = self.validator.validate_ledger(
            {"claims": [valid_claim(status="pending", critical=False)]}
        )
        self.assertEqual([], issues)

    def test_unresolved_conflict_is_rejected(self) -> None:
        for conflict in (
            "页面与代码不一致",
            {"status": "unresolved", "detail": "页面与代码不一致"},
            {"status": "resolved", "resolution": ""},
        ):
            with self.subTest(conflict=conflict):
                issues = self.validator.validate_ledger(
                    {"claims": [valid_claim(conflict=conflict)]}
                )
                self.assertIn("unresolved_conflict", {issue.code for issue in issues})

    def test_resolved_conflict_is_accepted(self) -> None:
        conflict = {"status": "resolved", "resolution": "以运行结果为准。"}
        self.assertEqual(
            [], self.validator.validate_ledger({"claims": [valid_claim(conflict=conflict)]})
        )

    def test_duplicate_ids_are_rejected(self) -> None:
        issues = self.validator.validate_ledger(
            {"claims": [valid_claim(), valid_claim()]}
        )
        self.assertIn("duplicate_claim_id", {issue.code for issue in issues})

    def test_cli_returns_zero_for_valid_file(self) -> None:
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(EXAMPLE), "--strict"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            env=cli_env(),
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("校验通过", result.stdout)

    def test_cli_returns_nonzero_with_clear_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "invalid.json"
            ledger.write_text(
                json.dumps({"claims": [valid_claim(status="pending")]}, ensure_ascii=False),
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(ledger)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                env=cli_env(),
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("证据账本校验失败", result.stderr)
        self.assertIn("关键事实", result.stderr)

    def test_invalid_json_reports_line_and_column(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "broken.json"
            ledger.write_text('{"claims": [}', encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(ledger)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                env=cli_env(),
            )
        self.assertEqual(1, result.returncode)
        self.assertIn("JSON 格式错误", result.stderr)
        self.assertIn("第 1 行", result.stderr)


if __name__ == "__main__":
    unittest.main()
