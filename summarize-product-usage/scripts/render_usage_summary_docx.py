#!/usr/bin/env python3
"""Render a structured project-derived product usage guide JSON file to DOCX."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt


def text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    return str(value).strip()


def as_list(value: Any) -> list[Any]:
    if value is None or value == "":
        return []
    if isinstance(value, list):
        return value
    return [value]


def set_run_font(run: Any, east_asia: str = "微软雅黑") -> None:
    run.font.name = east_asia
    run._element.rPr.rFonts.set(qn("w:eastAsia"), east_asia)


def set_cell_shading(cell: Any, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def configure_document(doc: Document) -> None:
    section = doc.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)

    styles = doc.styles
    for style_name in ["Normal", "Title", "Subtitle", "Heading 1", "Heading 2", "Heading 3"]:
        style = styles[style_name]
        style.font.name = "微软雅黑"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "微软雅黑")

    styles["Normal"].font.size = Pt(10.5)
    styles["Heading 1"].font.size = Pt(16)
    styles["Heading 2"].font.size = Pt(13)
    styles["Heading 3"].font.size = Pt(11.5)


def add_paragraph(doc: Document, value: Any, style: str | None = None) -> None:
    content = text(value)
    if not content:
        return
    para = doc.add_paragraph(style=style)
    run = para.add_run(content)
    set_run_font(run)


def add_bullets(doc: Document, items: Any) -> None:
    for item in as_list(items):
        content = text(item)
        if not content:
            continue
        para = doc.add_paragraph(style="List Bullet")
        run = para.add_run(content)
        set_run_font(run)


def add_numbers(doc: Document, items: Any) -> None:
    for index, item in enumerate(as_list(items), start=1):
        content = text(item)
        if not content:
            continue
        para = doc.add_paragraph()
        run = para.add_run(f"{index}. {content}")
        set_run_font(run)


def add_key_value_table(doc: Document, rows: list[tuple[str, str]]) -> None:
    rows = [(k, v) for k, v in rows if text(v)]
    if not rows:
        return
    table = doc.add_table(rows=1, cols=2)
    table.style = "Table Grid"
    header = table.rows[0].cells
    header[0].text = "项目"
    header[1].text = "说明"
    for cell in header:
        set_cell_shading(cell, "D9EAF7")
    for key, value in rows:
        cells = table.add_row().cells
        cells[0].text = key
        cells[1].text = value


def resolve_path(raw_path: str, base_dir: Path) -> Path:
    path = Path(raw_path)
    if path.is_absolute():
        return path
    return base_dir / path


def add_screenshots(doc: Document, screenshots: Any, base_dir: Path, image_width: float = 5.8) -> None:
    for index, shot in enumerate(as_list(screenshots), start=1):
        if isinstance(shot, str):
            path_value = shot
            caption = f"图 {index}"
        else:
            path_value = text(shot.get("path"))
            caption = text(shot.get("caption")) or f"图 {index}"
        if not path_value:
            continue
        image_path = resolve_path(path_value, base_dir)
        if not image_path.exists():
            add_paragraph(doc, f"截图缺失：{image_path}")
            continue
        try:
            doc.add_picture(str(image_path), width=Inches(image_width))
            last = doc.paragraphs[-1]
            last.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cap = doc.add_paragraph()
            cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            run = cap.add_run(caption)
            run.italic = True
            run.font.size = Pt(9)
            set_run_font(run)
        except Exception as exc:
            add_paragraph(doc, f"截图无法插入：{image_path}（{exc}）")


def add_section(doc: Document, section: dict[str, Any]) -> None:
    heading = text(section.get("heading"))
    kind = text(section.get("kind")).lower() or "paragraph"
    if heading:
        doc.add_heading(heading, level=3)

    if kind in {"steps", "numbered", "numbers"}:
        add_numbers(doc, section.get("items") or section.get("body"))
    elif kind in {"bullets", "bullet", "list"}:
        add_bullets(doc, section.get("items") or section.get("body"))
    elif kind == "table":
        rows = []
        for row in as_list(section.get("rows")):
            if isinstance(row, dict):
                rows.append((text(row.get("key") or row.get("name") or row.get("项目")), text(row.get("value") or row.get("description") or row.get("说明"))))
            elif isinstance(row, (list, tuple)) and len(row) >= 2:
                rows.append((text(row[0]), text(row[1])))
        add_key_value_table(doc, rows)
    else:
        body = section.get("body")
        if body is None:
            body = section.get("items")
        for paragraph in as_list(body):
            add_paragraph(doc, paragraph)


def add_legacy_module_sections(doc: Document, module: dict[str, Any]) -> None:
    if as_list(module.get("scenarios")):
        doc.add_heading("适用场景", level=3)
        add_bullets(doc, module.get("scenarios"))

    if as_list(module.get("steps")):
        doc.add_heading("操作步骤", level=3)
        add_numbers(doc, module.get("steps"))

    if as_list(module.get("key_outputs")):
        doc.add_heading("重点结果", level=3)
        add_bullets(doc, module.get("key_outputs"))

    if as_list(module.get("notes")):
        doc.add_heading("注意事项", level=3)
        add_bullets(doc, module.get("notes"))


def add_modules(doc: Document, modules: Any, base_dir: Path) -> None:
    for module in as_list(modules):
        if not isinstance(module, dict):
            continue
        name = text(module.get("name"))
        if not name:
            continue
        doc.add_heading(name, level=2)
        add_paragraph(doc, module.get("purpose"))

        sections = [section for section in as_list(module.get("sections")) if isinstance(section, dict)]
        if sections:
            for section in sections:
                add_section(doc, section)
        else:
            add_legacy_module_sections(doc, module)

        add_screenshots(doc, module.get("screenshots"), base_dir)


def add_faq(doc: Document, faq: Any) -> None:
    items = as_list(faq)
    if not items:
        return
    doc.add_heading("常见问题", level=1)
    for item in items:
        if isinstance(item, dict):
            question = text(item.get("question"))
            answer = text(item.get("answer"))
        else:
            question = text(item)
            answer = ""
        if question:
            doc.add_heading(question, level=3)
        if answer:
            add_paragraph(doc, answer)


def render(data: dict[str, Any], output_path: Path, base_dir: Path) -> None:
    doc = Document()
    configure_document(doc)

    title = text(data.get("title")) or "产品使用说明总结"
    title_para = doc.add_paragraph(style="Title")
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title_para.add_run(title)
    set_run_font(run)

    subtitle_parts = [
        text(data.get("subtitle")),
        f"适用对象：{text(data.get('audience'))}" if text(data.get("audience")) else "",
        f"版本日期：{text(data.get('version_date'))}" if text(data.get("version_date")) else "",
    ]
    subtitle = "    ".join(part for part in subtitle_parts if part)
    if subtitle:
        para = doc.add_paragraph(style="Subtitle")
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = para.add_run(subtitle)
        set_run_font(run)

    add_key_value_table(
        doc,
        [
            ("系统入口", text(data.get("access_url"))),
            ("使用对象", text(data.get("audience"))),
            ("文档范围", text(data.get("scope"))),
            ("额度/账号规则", text(data.get("quota_rules") or data.get("account_rules"))),
            ("输出位置", text(data.get("output_location"))),
        ],
    )

    if text(data.get("overview")):
        doc.add_heading("简短说明", level=1)
        add_paragraph(doc, data.get("overview"))

    if as_list(data.get("quick_start")):
        doc.add_heading("快速开始", level=1)
        add_numbers(doc, data.get("quick_start"))

    if as_list(data.get("recommended_workflow")):
        doc.add_heading("推荐使用流程", level=1)
        add_numbers(doc, data.get("recommended_workflow"))

    if as_list(data.get("modules")):
        doc.add_heading("模块使用说明", level=1)
        add_modules(doc, data.get("modules"), base_dir)

    if as_list(data.get("usage_rules")):
        doc.add_heading("使用规范", level=1)
        add_bullets(doc, data.get("usage_rules"))

    add_faq(doc, data.get("faq"))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    doc.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render product usage summary JSON to DOCX.")
    parser.add_argument("--input", required=True, help="Path to summary JSON.")
    parser.add_argument("--output", required=True, help="Path to output DOCX.")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    data = json.loads(input_path.read_text(encoding="utf-8"))
    render(data, output_path, input_path.parent)


if __name__ == "__main__":
    main()
