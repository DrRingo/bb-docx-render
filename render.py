# -*- coding: utf-8 -*-
"""
render.py — Render DOCX template bằng docxtpl + Jinja2.

Cách gọi:
    python render.py <template.docx> <data.json|data.yaml|data.toml> <output_path_template>

Định dạng dữ liệu được hỗ trợ:
    .json             — JSON (built-in)
    .yaml / .yml      — YAML (cần pyyaml: uv add pyyaml)
    .toml             — TOML (built-in Python 3.11+, hoặc cần tomli cho 3.10)

Đầu ra:
    In đường dẫn file đã tạo ra stdout.
"""

import sys
import json
import datetime
import re
import os

# Cố định encoding stdout/stderr sang UTF-8 (quan trọng trên Windows)
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

os.environ.setdefault("PYTHONIOENCODING", "utf-8")
os.environ.setdefault("PYTHONUTF8", "1")

from docxtpl import DocxTemplate
from jinja2 import Environment as JEnv


def load_data(data_path: str) -> dict:
    """Đọc file JSON, YAML, hoặc TOML, trả về dict."""
    ext = os.path.splitext(data_path)[1].lower()

    if ext in (".yaml", ".yml"):
        try:
            import yaml
        except ImportError:
            print(
                "Lỗi: cần cài PyYAML để đọc file YAML. Chạy: uv add pyyaml",
                file=sys.stderr,
            )
            sys.exit(1)
        with open(data_path, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)

    elif ext == ".toml":
        # tomllib có sẵn từ Python 3.11+; dùng tomli làm fallback cho 3.10
        try:
            import tomllib  # Python 3.11+
        except ImportError:
            try:
                import tomli as tomllib  # type: ignore[no-redef]
            except ImportError:
                print(
                    "Lỗi: cần cài tomli để đọc file TOML trên Python < 3.11. Chạy: uv add tomli",
                    file=sys.stderr,
                )
                sys.exit(1)
        # tomllib yêu cầu mở file ở binary mode
        with open(data_path, "rb") as f:
            return tomllib.load(f)

    else:
        # Mặc định: JSON
        with open(data_path, "r", encoding="utf-8") as f:
            return json.load(f)


def sanitize_filename(name: str) -> str:
    """Thay khoảng trắng thành '_', xóa ký tự không hợp lệ trong tên file."""
    name = name.replace(" ", "_")
    return re.sub(r'[<>:"/\\|?*]+', "", name)


def sanitize_path(path: str) -> str:
    """
    Chuẩn hóa toàn bộ đường dẫn (từng phần) bằng sanitize_filename.
    Giữ nguyên đường dẫn tuyệt đối (Unix '/', Windows 'C:\\...').
    """
    # Phát hiện đường dẫn tuyệt đối: Unix (/...) hoặc Windows (C:\... hoặc \\...)
    drive, rest = os.path.splitdrive(path)
    is_abs = bool(drive) or path.startswith("/") or path.startswith("\\")

    parts = re.split(r"[/\\]+", rest.lstrip("/\\"))
    sanitized_parts = [sanitize_filename(p) for p in parts if p]
    result = os.path.join(*sanitized_parts) if sanitized_parts else ""

    if drive:
        # Windows: C:\foo\bar
        return os.path.join(drive + os.sep, result)
    if is_abs:
        return os.path.join("/", result)
    return result


def resolve_output_path(out_path_tmpl: str, ctx: dict) -> str:
    """Render template Jinja trong chuỗi đường dẫn đầu ra (nếu có {{ }})."""
    if "{{" in out_path_tmpl:
        raw = JEnv().from_string(out_path_tmpl).render(ctx)
    else:
        raw = out_path_tmpl
    return sanitize_path(raw)


def enrich_context_with_template_vars(tpl: DocxTemplate, ctx: dict) -> None:
    """
    Trích xuất các biến/hàm được định nghĩa trong template DOCX
    (dùng {% set %} hoặc macro) và inject vào ctx (nếu chưa có).
    Dùng đúng môi trường Jinja của docxtpl để tránh lỗi với tag đặc thù.
    """
    try:
        xml_ctx = tpl.patch_xml(tpl.get_xml())
        # Dùng env của docxtpl thay vì JEnv() thuần để tránh parse sai tag {%tr%} v.v.
        module = tpl.get_jinja_env().from_string(xml_ctx).make_module(ctx)
        for k in dir(module):
            if not k.startswith("_"):
                ctx.setdefault(k, getattr(module, k))
    except Exception:
        # Không làm cứng — nếu bước này lỗi thì vẫn render tiếp
        pass


def main():
    if len(sys.argv) < 4:
        print(
            "Usage: python render.py <template.docx> <data.json|data.yaml> <output_path_template>",
            file=sys.stderr,
        )
        sys.exit(1)

    tpl_path, data_path, out_path_tmpl = sys.argv[1], sys.argv[2], sys.argv[3]

    # Đọc dữ liệu (JSON, YAML, hoặc TOML)
    ctx = load_data(data_path)

    # Thêm biến tiện ích vào context
    now = datetime.datetime.now()
    ctx.setdefault("_now", now)
    ctx.setdefault("_today", now.date().isoformat())

    # Khởi tạo template
    tpl = DocxTemplate(tpl_path)
    tpl.init_docx()

    # Trích xuất biến từ template và bổ sung vào ctx
    enrich_context_with_template_vars(tpl, ctx)

    # Xác định đường dẫn đầu ra
    out_path = resolve_output_path(out_path_tmpl, ctx)

    # Tạo thư mục đầu ra nếu chưa có
    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    # Render và lưu
    tpl.render(ctx)
    tpl.save(out_path)

    # In đường dẫn file đầu ra
    try:
        print(out_path)
    except UnicodeEncodeError:
        sys.stdout.buffer.write((out_path + "\n").encode("utf-8"))


if __name__ == "__main__":
    main()
