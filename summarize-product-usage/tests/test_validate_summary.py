"""Tests for strict formal-delivery summary validation."""

from __future__ import annotations

import base64
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "validate_summary.py"
MINIMAL_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQ"
    "AAAABJRU5ErkJggg=="
)


def load_validator():
    spec = importlib.util.spec_from_file_location("validate_summary", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class ValidateSummaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.validator = load_validator()

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.tmpdir = Path(self.tmp.name)
        (self.tmpdir / "screen.png").write_bytes(MINIMAL_PNG)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def valid_data(self) -> dict:
        return {
            "title": "产品使用说明",
            "tasks": [
                {
                    "title": "我要生成内容",
                    "entry": "顶部导航「内容生成」",
                    "priority": "core",
                    "claim_ids": ["claim-generate"],
                    "prerequisites": ["已登录系统"],
                    "steps": [
                        "选择内容方向。",
                        {
                            "action": "点击「开始生成」。",
                            "expected_result": "状态显示为处理中，完成后结果进入历史记录。",
                            "screenshot": {
                                "path": "screen.png",
                                "caption": "提交任务",
                                "coverage": ["entry", "action", "success", "result"],
                            },
                        },
                    ],
                    "result": "结果保存在历史记录。",
                    "common_problems": [{"question": "为什么没完成？", "answer": "稍后刷新历史记录。"}],
                }
            ],
            "faq": [{"question": "在哪里登录？", "answer": "打开系统首页。"}],
        }

    def messages(self, data) -> list[str]:
        return [issue.format() for issue in self.validator.validate_summary(data, self.tmpdir)]

    def test_valid_formal_summary_passes(self) -> None:
        self.assertEqual(self.messages(self.valid_data()), [])

    def test_top_level_must_be_object_and_nonempty(self) -> None:
        self.assertIn("JSON 顶层必须是对象", self.messages([])[0])
        self.assertIn("文档为空", self.messages({})[0])

    def test_title_and_content_are_required(self) -> None:
        messages = "\n".join(self.messages({"title": " ", "tasks": []}))
        self.assertIn("title", messages)
        self.assertIn("没有任何任务或模块", messages)

    def test_core_task_requires_title_entry_steps_and_result(self) -> None:
        data = {"title": "说明", "tasks": [{"priority": "core", "steps": []}]}
        messages = "\n".join(self.messages(data))
        for field in ("title", "entry", "prerequisites", "steps", "result", "screenshots"):
            self.assertIn(f"tasks[1].{field}", messages)

    def test_core_task_requires_at_least_one_screenshot(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"][1].pop("screenshot")
        self.assertIn("tasks[1].screenshots", "\n".join(self.messages(data)))

    def test_empty_screenshot_array_cannot_satisfy_core_coverage(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"][1]["screenshot"] = []
        self.assertIn("覆盖不完整", "\n".join(self.messages(data)))

    def test_modules_only_cannot_pass_formal_preflight(self) -> None:
        messages = "\n".join(
            self.messages({"title": "空壳", "modules": [{"name": "设置"}]})
        )
        self.assertIn("必须使用 V2 tasks", messages)

    def test_unknown_claim_id_fails_when_evidence_is_supplied(self) -> None:
        issues = self.validator.validate_summary(
            self.valid_data(), self.tmpdir, {"another-claim"}
        )
        self.assertIn("不存在或未确认", "\n".join(issue.format() for issue in issues))

    def test_object_step_requires_action(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"] = [{"expected_result": "成功"}]
        self.assertIn("tasks[1].steps[1].action", "\n".join(self.messages(data)))

    def test_key_core_action_requires_expected_result(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"] = [{"action": "点击「提交」按钮。"}]
        self.assertIn("tasks[1].steps[1].expected_result", "\n".join(self.messages(data)))

    def test_key_core_string_action_must_be_object(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"] = ["点击「保存」按钮。"]
        self.assertIn("请改为对象步骤", "\n".join(self.messages(data)))

    def test_non_key_core_action_does_not_require_expected_result(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["steps"] = [
            {
                "action": "打开左侧菜单。",
                "screenshot": {
                    "path": "screen.png",
                    "caption": "菜单入口",
                    "coverage": ["entry", "action", "success", "result"],
                },
            }
        ]
        self.assertEqual(self.messages(data), [])

    def test_priority_must_be_known(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["priority"] = "high"
        self.assertIn("priority 只能是", "\n".join(self.messages(data)))

    def test_missing_and_corrupt_screenshots_fail(self) -> None:
        data = self.valid_data()
        data["tasks"][0]["screenshots"] = [
            {"path": "missing.png"},
            {"path": "broken.png"},
        ]
        (self.tmpdir / "broken.png").write_text("not an image", encoding="utf-8")
        messages = "\n".join(self.messages(data))
        self.assertIn("截图不存在", messages)
        self.assertIn("截图无法读取", messages)

    def test_faq_question_and_answer_are_both_required(self) -> None:
        data = self.valid_data()
        data["faq"] = [{"question": ""}, {"answer": "答案"}, "问题"]
        messages = "\n".join(self.messages(data))
        self.assertIn("faq[1].question", messages)
        self.assertIn("faq[1].answer", messages)
        self.assertIn("faq[2].question", messages)
        self.assertIn("faq[3]", messages)

    def test_legacy_module_screenshot_is_checked(self) -> None:
        data = {
            "title": "旧版说明",
            "modules": [{"name": "趋势", "screenshots": [{"path": "missing.png"}]}],
        }
        self.assertIn("modules[1].screenshots[1].path", "\n".join(self.messages(data)))

    def test_cli_returns_zero_for_valid_input(self) -> None:
        input_path = self.tmpdir / "valid.json"
        evidence_path = self.tmpdir / "evidence.json"
        input_path.write_text(json.dumps(self.valid_data(), ensure_ascii=False), encoding="utf-8")
        evidence_path.write_text(
            json.dumps(
                {"claims": [{"claim_id": "claim-generate", "status": "confirmed"}]},
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--input",
                str(input_path),
                "--strict",
                "--evidence",
                str(evidence_path),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("预检通过", result.stdout)

    def test_cli_returns_nonzero_with_clear_chinese_diagnostics(self) -> None:
        input_path = self.tmpdir / "invalid.json"
        input_path.write_text(json.dumps({"title": "说明", "tasks": []}), encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(input_path)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("预检未通过", result.stderr)
        self.assertIn("请修复以上问题后再生成正式文档", result.stderr)

    def test_cli_returns_two_for_invalid_json(self) -> None:
        input_path = self.tmpdir / "invalid.json"
        input_path.write_text("{", encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(input_path)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("无法读取 JSON", result.stderr)


if __name__ == "__main__":
    unittest.main()
