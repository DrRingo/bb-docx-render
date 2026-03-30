# -*- coding: utf-8 -*-
"""
fill_docx_main.py — Standalone entry point cho fill-docx.

Cách dùng:
    fill-docx <template.docx> <data.json|yaml|toml> [-o <output>]

Đây là file entry point cho PyInstaller — gộp toàn bộ logic của
fill_docx.bb (arg parse) và render.py (render DOCX) vào một file Python duy nhất.
"""

import sys
import json
import datetime
import re
import os
import argparse

# Cố định encoding stdout/stderr sang UTF-8 (quan trọng trên Windows)
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

os.environ.setdefault("PYTHONIOENCODING", "utf-8")
os.environ.setdefault("PYTHONUTF8", "1")


# ── Data loading ─────────────────────────────────────────────────────────────

def load_data(data_path: str) -> dict:
    """Đọc file JSON, YAML, hoặc TOML, trả về dict."""
    ext = os.path.splitext(data_path)[1].lower()

    if ext in (".yaml", ".yml"):
        try:
            import yaml
        except ImportError:
            print(
                "Lỗi: cần cài PyYAML để đọc file YAML. Chạy: pip install pyyaml",
                file=sys.stderr,
            )
            sys.exit(1)
        with open(data_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)

    elif ext == ".toml":
        try:
            import tomllib  # Python 3.11+
        except ImportError:
            try:
                import tomli as tomllib  # type: ignore[no-redef]
            except ImportError:
                print(
                    "Lỗi: cần cài tomli để đọc file TOML trên Python < 3.11.",
                    file=sys.stderr,
                )
                sys.exit(1)
        with open(data_path, "rb") as f:
            return tomllib.load(f)

    else:
        # Mặc định: JSON
        with open(data_path, "r", encoding="utf-8") as f:
            return json.load(f)


# ── Path sanitization ─────────────────────────────────────────────────────────

def sanitize_filename(name: str) -> str:
    """Thay khoảng trắng thành '_', xóa ký tự không hợp lệ trong tên file."""
    name = name.replace(" ", "_")
    return re.sub(r'[<>:"/\\|?*]+', "", name)


def sanitize_path(path: str) -> str:
    """Chuẩn hóa toàn bộ đường dẫn (từng phần) bằng sanitize_filename."""
    drive, rest = os.path.splitdrive(path)
    is_abs = bool(drive) or path.startswith("/") or path.startswith("\\")

    parts = re.split(r"[/\\]+", rest.lstrip("/\\"))
    sanitized_parts = [sanitize_filename(p) for p in parts if p]
    result = os.path.join(*sanitized_parts) if sanitized_parts else ""

    if drive:
        return os.path.join(drive + os.sep, result)
    if is_abs:
        return os.path.join("/", result)
    return result


# ── Render ────────────────────────────────────────────────────────────────────

def resolve_output_path(out_path_tmpl: str, ctx: dict) -> str:
    """Render template Jinja trong chuỗi đường dẫn đầu ra (nếu có {{ }})."""
    from jinja2 import Environment as JEnv
    if "{{" in out_path_tmpl:
        raw = JEnv().from_string(out_path_tmpl).render(ctx)
    else:
        raw = out_path_tmpl
    return sanitize_path(raw)


def enrich_context_with_template_vars(tpl, ctx: dict) -> None:
    """Trích xuất biến/hàm định nghĩa trong template DOCX và inject vào ctx."""
    try:
        xml_ctx = tpl.patch_xml(tpl.get_xml())
        module = tpl.get_jinja_env().from_string(xml_ctx).make_module(ctx)
        for k in dir(module):
            if not k.startswith("_"):
                ctx.setdefault(k, getattr(module, k))
    except Exception:
        pass


def render(template_path: str, data_path: str, out_path_tmpl: str) -> str:
    """Render template DOCX với dữ liệu, trả về đường dẫn file đầu ra."""
    from docxtpl import DocxTemplate

    ctx = load_data(data_path)

    now = datetime.datetime.now()
    ctx.setdefault("_now", now)
    ctx.setdefault("_today", now.date().isoformat())

    tpl = DocxTemplate(template_path)
    tpl.init_docx()

    enrich_context_with_template_vars(tpl, ctx)

    out_path = resolve_output_path(out_path_tmpl, ctx)

    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    tpl.render(ctx)
    tpl.save(out_path)

    return out_path


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="fill-docx",
        description="Điền dữ liệu JSON/YAML/TOML vào DOCX template (Jinja2).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Ví dụ:
  fill-docx template.docx data.json -o output.docx
  fill-docx template.docx data.yaml -o "out/{{ho_ten}}_{{_today}}.docx"
  fill-docx template.docx data.toml -o "out/{{msnv}}/{{ho_ten}}.docx"
""",
    )
    parser.add_argument("template", help="File DOCX template (Jinja2)")
    parser.add_argument(
        "datafile", help="File dữ liệu: .json / .yaml / .yml / .toml"
    )
    parser.add_argument(
        "-o",
        "--output",
        default="output.docx",
        metavar="OUTPUT",
        help='Đường dẫn / tên file đầu ra. Hỗ trợ Jinja2: "out/{{ho_ten}}.docx" (mặc định: output.docx)',
    )
    parser.add_argument(
        "--version", action="version", version="fill-docx 1.0.0"
    )

    args = parser.parse_args()

    # Validate inputs
    if not os.path.exists(args.template):
        print(f"Lỗi: Không tìm thấy template: {args.template}", file=sys.stderr)
        sys.exit(2)
    if not os.path.exists(args.datafile):
        print(f"Lỗi: Không tìm thấy data file: {args.datafile}", file=sys.stderr)
        sys.exit(3)

    try:
        out_path = render(args.template, args.datafile, args.output)
        try:
            print(f"Đã tạo: {out_path}")
        except UnicodeEncodeError:
            sys.stdout.buffer.write(f"Đã tạo: {out_path}\n".encode("utf-8"))
    except Exception as e:
        print(f"Lỗi khi render: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
