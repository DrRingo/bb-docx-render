#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_exe.py — Build fill-docx standalone executable (local / macOS).

Yêu cầu:
    pip install pyinstaller

Chạy:
    python build_exe.py
"""

import subprocess
import sys
import platform
import shutil
import os

ENTRY_POINT = "fill_docx_main.py"
EXE_NAME = "fill-docx"

HIDDEN_IMPORTS = [
    "docxtpl",
    "docx",
    "jinja2",
    "yaml",
    "tomli",
    "PIL",           # pillow
    "lxml",
    "lxml.etree",
    "lxml._elementpath",
    "zipfile",
    "copy",
    "re",
    "os",
    "sys",
    "json",
    "datetime",
    "argparse",
]


def check_pyinstaller():
    if shutil.which("pyinstaller") is None:
        print("PyInstaller chưa được cài. Đang cài...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pyinstaller"])


def build():
    check_pyinstaller()

    os_name = platform.system().lower()
    arch = platform.machine().lower()
    print(f"Building for: {os_name} / {arch}")

    hidden = []
    for h in HIDDEN_IMPORTS:
        hidden += ["--hidden-import", h]

    cmd = [
        "pyinstaller",
        "--onefile",
        "--name", EXE_NAME,
        "--clean",
        *hidden,
        ENTRY_POINT,
    ]

    print("Running:", " ".join(cmd))
    result = subprocess.run(cmd, cwd=os.path.dirname(os.path.abspath(__file__)))

    if result.returncode == 0:
        dist_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dist")
        exe = EXE_NAME + (".exe" if os_name == "windows" else "")
        out = os.path.join(dist_dir, exe)
        print(f"\n✅ Build thành công: {out}")
        print(f"   Kích thước: {os.path.getsize(out) / 1024 / 1024:.1f} MB")
    else:
        print("\n❌ Build thất bại!")
        sys.exit(result.returncode)


if __name__ == "__main__":
    build()
