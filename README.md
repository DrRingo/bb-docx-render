# fill-docx — Render DOCX từ template Jinja2

Điền dữ liệu từ **JSON / YAML / TOML** vào file **DOCX template** (cú pháp Jinja2), tạo file DOCX đầu ra với tên file động.

```
fill-docx template.docx data.json -o "out/{{ho_ten}}_{{_today}}.docx"
```

**Không cần cài Python, runtime hay bất kỳ dependency nào.** Binary standalone, chạy thẳng.

---

## Mục lục

1. [Cài đặt](#cài-đặt)
   - [Homebrew](#1-homebrew-macos--linux)
   - [Scoop](#2-scoop-windows)
   - [Thủ công](#3-tải-thủ-công)
2. [Hướng dẫn sử dụng](#hướng-dẫn-sử-dụng)
3. [Cú pháp template](#cú-pháp-template)
4. [Định dạng dữ liệu](#định-dạng-dữ-liệu)
5. [Tình huống thực tế](#tình-huống-thực-tế)
6. [Khắc phục sự cố](#khắc-phục-sự-cố)
7. [Build từ source](#build-từ-source)

---

## Cài đặt

### 1. Homebrew (macOS / Linux)

```bash
brew tap drringo/bb-docx-render https://github.com/drringo/bb-docx-render
brew install bb-docx-render
```

Sau khi cài, lệnh `fill-docx` có sẵn ngay trong terminal.

---

### 2. Scoop (Windows)

```powershell
scoop install https://raw.githubusercontent.com/DrRingo/bb-docx-render/main/scoop/bb-docx-render.json
```

Sau khi cài, lệnh `fill-docx` có sẵn trong PowerShell.

---

### 3. Tải thủ công

Tải binary phù hợp từ [**GitHub Releases**](https://github.com/DrRingo/bb-docx-render/releases/latest):

| Hệ điều hành | File |
|---|---|
| macOS (Apple Silicon / Intel) | `fill-docx-macos` |
| Linux | `fill-docx-linux` |
| Windows | `fill-docx-windows.exe` |

**macOS / Linux:**

```bash
chmod +x fill-docx-macos
mv fill-docx-macos /usr/local/bin/fill-docx
```

**Windows:** Đổi tên thành `fill-docx.exe` và đặt vào thư mục trong `PATH`.

---

## Hướng dẫn sử dụng

### Cú pháp lệnh

```
fill-docx <template.docx> <data.json|yaml|toml> [-o <output>]
```

| Tham số | Mô tả |
|---------|-------|
| `template.docx` | File DOCX mẫu chứa cú pháp Jinja2 |
| `data.json\|yaml\|toml` | File dữ liệu (JSON, YAML hoặc TOML) |
| `-o <output>` | Đường dẫn đầu ra. Hỗ trợ template Jinja2. Mặc định: `output.docx` |

### Ví dụ nhanh

```bash
# Tên file cố định
fill-docx template.docx data.json -o output.docx

# Tên file động từ dữ liệu
fill-docx template.docx data.json -o "out/{{ho_ten}}_{{_today}}.docx"

# Dùng YAML
fill-docx template.docx data.yaml -o "{{ho_ten}}.docx"

# Dùng TOML
fill-docx template.docx config.toml -o "report.docx"

# Tạo thư mục con tự động
fill-docx template.docx data.json -o "out/{{msnv}}/{{ho_ten}}.docx"
```

---

## Cú pháp template

Soạn thảo `template.docx` trong Word với cú pháp Jinja2 nguyên bản:

### Biến đơn giản

```
Họ tên: {{ ho_ten }}
Ngày sinh: {{ ngay_sinh }}
Hôm nay: {{ _today }}
```

### Điều kiện

```
{% if so_tien > 1000000 %}
Số tiền lớn hơn 1 triệu đồng.
{% else %}
Số tiền nhỏ hơn 1 triệu đồng.
{% endif %}
```

### Vòng lặp

```
{% for item in ds_muc %}
- {{ item.ten }}: {{ item.so_luong }} x {{ item.gia }} VNĐ
{% endfor %}
```

### Filter built-in của Jinja2

```
{{ ho_ten | upper }}          {# IN HOA #}
{{ ho_ten | lower }}          {# in thường #}
{{ so_tien | int }}           {# ép kiểu số nguyên #}
{{ ghi_chu | default("Không có") }}  {# giá trị mặc định #}
```

### Biến tiện ích tự động

Script tự thêm các biến sau vào context:

| Biến | Kiểu | Ví dụ |
|------|------|-------|
| `_today` | `str` | `"2026-03-30"` |
| `_now` | `datetime` | `datetime.datetime(2026, 3, 30, 9, 0, 0)` |

---

## Định dạng dữ liệu

Script nhận diện định dạng tự động qua phần mở rộng file.

### JSON (`.json`)

```json
{
  "ho_ten": "Nguyễn Văn A",
  "ngay_sinh": "1990-05-20",
  "so_tien": 15000000,
  "ds_muc": [
    { "ten": "Mục 1", "so_luong": 2, "gia": 50000 },
    { "ten": "Mục 2", "so_luong": 1, "gia": 120000 }
  ]
}
```

### YAML (`.yaml` / `.yml`)

```yaml
ho_ten: Nguyễn Văn A
ngay_sinh: "1990-05-20"
so_tien: 15000000
ds_muc:
  - ten: Mục 1
    so_luong: 2
    gia: 50000
  - ten: Mục 2
    so_luong: 1
    gia: 120000
```

### TOML (`.toml`)

```toml
ho_ten = "Nguyễn Văn A"
ngay_sinh = "1990-05-20"
so_tien = 15000000

[[ds_muc]]
ten = "Mục 1"
so_luong = 2
gia = 50000

[[ds_muc]]
ten = "Mục 2"
so_luong = 1
gia = 120000
```

---

## Tình huống thực tế

### Hợp đồng đơn giản

```bash
fill-docx hop-dong-mau.docx khach-hang.json -o "HopDong_{{ho_ten}}_{{_today}}.docx"
```

Kết quả: `HopDong_Nguyen_Van_A_2026-03-30.docx`

---

### Phiếu xuất viện theo bệnh nhân

```bash
fill-docx phieu-xuat-vien.docx benh-nhan.yaml \
  -o "xuat-vien/{{msnv}}/TTBA_{{hoten}}_{{ngayrv}}.docx"
```

---

### Chứng nhận / Chứng chỉ hàng loạt (batch)

**Linux / macOS:**

```bash
for f in data/hocvien_*.json; do
  fill-docx chung-chi-mau.docx "$f" -o "out/ChungChi_{{ho_ten}}.docx"
done
```

**Windows PowerShell:**

```powershell
Get-ChildItem data\hocvien_*.json | ForEach-Object {
    fill-docx chung-chi-mau.docx $_.FullName -o "out\ChungChi_{{ho_ten}}.docx"
}
```

---

### Tên file đầu ra có thư mục con động

```bash
fill-docx template.docx data.json -o "out/{{phong_ban}}/{{nam}}/{{ho_ten}}.docx"
```

Tạo ra: `out/Ke_Toan/2026/Nguyen_Van_A.docx`

---

## Tên file đầu ra động

Tham số `-o` hỗ trợ cú pháp Jinja2:

```
-o "out/{{msnv}}/{{ho_ten}}_{{_today}}.docx"
```

Script tự động:
- **Render** chuỗi với dữ liệu từ file data
- **Đổi khoảng trắng thành `_`**
- **Xóa ký tự không hợp lệ** trong tên file (`< > : " / \ | ? *`)
- **Tạo thư mục** nếu chưa tồn tại

---

## Khắc phục sự cố

### macOS: "cannot be opened because the developer cannot be verified"

```bash
xattr -d com.apple.quarantine /usr/local/bin/fill-docx
```

### Windows: SmartScreen cảnh báo

Nhấn **"More info" → "Run anyway"**. Binary không được ký bởi certificate thương mại, nhưng mã nguồn mở hoàn toàn.

### Ký tự Unicode trong tên file không hiển thị đúng trên CMD Windows

Chạy `chcp 65001` trước khi dùng tool, hoặc dùng PowerShell. File DOCX vẫn được tạo đúng dù terminal hiển thị sai.

---

## Build từ source

Yêu cầu: Python ≥ 3.10, [uv](https://docs.astral.sh/uv/)

```bash
git clone https://github.com/DrRingo/bb-docx-render
cd bb-docx-render
uv sync
uv run python fill_docx_main.py template.docx data.json -o output.docx
```

Build binary local (PyInstaller):

```bash
uv run python build_exe.py
# → dist/fill-docx  (macOS/Linux)
# → dist/fill-docx.exe  (Windows)
```

---

## Tạo GitHub Release thủ công (local build)

Thay vì dùng GitHub Actions, bạn có thể build và publish release trực tiếp từ máy:

### Yêu cầu thêm

- **[gh CLI](https://cli.github.com/)** (khuyên dùng): `winget install GitHub.cli` → `gh auth login`  
  _Hoặc_ đặt biến môi trường `GITHUB_TOKEN` với Personal Access Token có quyền `repo`.

### Windows — build `fill-docx-windows.exe`

```powershell
.\release.ps1 -Tag v0.2.0
```

Tùy chọn:
- `-Draft` — tạo release ở chế độ Draft (chưa public)
- `-SkipBuild` — bỏ qua bước build, chỉ upload file đã có trong `dist/`

### Linux / WSL — build `fill-docx-linux`

```bash
chmod +x release.sh
./release.sh v0.2.0
# Hoặc:
./release.sh v0.2.0 --draft
./release.sh v0.2.0 --skip-build
```

### macOS — build `fill-docx-macos`

```bash
chmod +x release.sh
./release.sh v0.2.0
```

> **Lưu ý:** Script `release.sh` xác định tên binary theo OS đang chạy. Chạy trên Linux
> → tạo `fill-docx-linux`; trên macOS → tạo `fill-docx-macos`.
> Để có đủ cả 3 platform, chạy `release.ps1` trên Windows và `release.sh` trên
> Linux/macOS — mỗi lần upload thêm binary vào cùng một release tag.

### Quy trình release đầy đủ (ví dụ: v0.2.0)

```
1. Chạy release.ps1 -Tag v0.2.0          (Windows)
2. Chạy ./release.sh v0.2.0 --skip-build  (Linux/WSL — bỏ qua vì tag đã push)
3. Chạy ./release.sh v0.2.0 --skip-build  (macOS)
```

---

## Kiến trúc

```
fill_docx_main.py   ← Entry point Python: parse args + render DOCX
render.py           ← Module render (docxtpl + Jinja2) — tham chiếu nội bộ
pyproject.toml      ← Khai báo deps Python
build_exe.py        ← Build script PyInstaller (tạo standalone binary)
.github/workflows/  ← CI build binary cho macOS, Linux, Windows
```

---

## Giấy phép

Apache License 2.0 — Xem file [`LICENSE`](LICENSE) để biết chi tiết.
