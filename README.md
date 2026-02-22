# bb-docx-render — Render DOCX từ template Jinja2

Điền dữ liệu từ **JSON / YAML / TOML** vào file **DOCX template** (cú pháp Jinja2), tạo file DOCX đầu ra với tên file động.

```
fill-docx template.docx data.json -o "out/{{ho_ten}}_{{_today}}.docx"
```

---

## Mục lục

1. [Yêu cầu](#yêu-cầu)
2. [Cài đặt](#cài-đặt)
   - [Homebrew](#1-homebrew-macos--linux)
   - [Scoop](#2-scoop-windows)
   - [Thủ công](#3-cài-thủ-công)
3. [Hướng dẫn sử dụng](#hướng-dẫn-sử-dụng)
4. [Cú pháp template](#cú-pháp-template)
5. [Định dạng dữ liệu](#định-dạng-dữ-liệu)
6. [Tình huống thực tế](#tình-huống-thực-tế)
7. [Khắc phục sự cố](#khắc-phục-sự-cố)

---

## Yêu cầu

| Công cụ | Bắt buộc | Ghi chú |
|---------|----------|---------|
| **Babashka** (`bb`) | Bắt buộc | Chạy script `.bb` |
| **uv** | Khuyến nghị | Quản lý Python env tự động |
| **Python ≥ 3.10** | Fallback | Nếu không dùng `uv`, cần cài thêm deps thủ công |

**Thư viện Python** (uv cài tự động từ `pyproject.toml`):  
`docxtpl`, `jinja2`, `python-docx`, `pyyaml`, `tomli` (Python 3.10)

---

## Cài đặt

### 1. Homebrew (macOS / Linux)

```bash
brew tap drringo/bb-docx-render https://github.com/drringo/bb-docx-render
brew install bb-docx-render
```

Sau khi cài, lệnh `fill-docx` có sẵn. Lần đầu dùng, `uv` sẽ tự tải deps.

---

### 2. Scoop (Windows)

```powershell
scoop install https://raw.githubusercontent.com/DrRingo/bb-docx-render/main/scoop/bb-docx-render.json
```

Sau khi cài, lệnh `fill-docx` có sẵn trong PowerShell.

---

### 3. Cài thủ công

```bash
git clone https://github.com/DrRingo/bb-docx-render
cd bb-docx-render
uv sync          # cài Python deps vào .venv
```

Chạy trực tiếp:

```bash
bb fill_docx.bb template.docx data.json -o output.docx
```

Hoặc thêm task `docx:fill` vào `bb.edn` để gọi ngắn hơn.

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
| `-o <output>` | Đường dẫn đầu ra. Có thể là tên file cố định hoặc **template Jinja2**. Mặc định: `output.docx` |

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
| `_today` | `str` | `"2026-02-22"` |
| `_now` | `datetime` | `datetime.datetime(2026, 2, 22, 9, 0, 0)` |

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

### Tình huống 1 — Hợp đồng đơn giản

Tạo một hợp đồng từ template với dữ liệu JSON:

```bash
fill-docx hop-dong-mau.docx khach-hang.json -o "HopDong_{{ho_ten}}_{{_today}}.docx"
```

Kết quả: `HopDong_Nguyen_Van_A_2026-02-22.docx`

---

### Tình huống 2 — Phiếu xuất viện theo bệnh nhân

Template có nhiều biến y tế, dữ liệu là YAML:

```bash
fill-docx phieu-xuat-vien.docx benh-nhan.yaml \
  -o "xuat-vien/{{msnv}}/TTBA_{{hoten}}_{{ngayrv}}.docx"
```

Kết quả: `xuat-vien/052078/TTBA_Sam_Thi_Luu_Ly_03_08_2025.docx`

---

### Tình huống 3 — Chứng nhận / Chứng chỉ hàng loạt (batch shell script)

Với nhiều học viên, viết vòng lặp shell tạo từng file:

**Linux / macOS / WSL:**

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

### Tình huống 4 — Tên file đầu ra có thư mục con động

Dùng `-o` với thư mục lồng nhau; script tự tạo thư mục:

```bash
fill-docx template.docx data.json -o "out/{{phong_ban}}/{{nam}}/{{ho_ten}}.docx"
```

Tạo ra: `out/Ke_Toan/2026/Nguyen_Van_A.docx`

---

### Tình huống 5 — Dữ liệu TOML từ config dự án

Nếu dự án đã dùng TOML (như `pyproject.toml` mở rộng):

```bash
fill-docx bao-cao-mau.docx project-config.toml -o "BaoCao_{{project_name}}.docx"
```

---

### Tình huống 6 — Chạy qua task Babashka (`bb.edn`)

Nếu dùng trực tiếp từ source với `bb.edn`:

```bash
# Linux / macOS
bb docx:fill template.docx data.json -o "out/{{ho_ten}}.docx"

# Windows PowerShell (nháy đơn để giữ {{ }})
bb docx:fill template.docx data.json -o 'out/{{ho_ten}}.docx'
```

Cài deps Python lần đầu:

```bash
bb docx:install
```

---

## Tên file đầu ra động

Tham số `-o` hỗ trợ cú pháp Jinja2 để tạo tên file động:

```
-o "out/{{msnv}}/{{ho_ten}}_{{_today}}.docx"
```

Script tự động:
- **Render** chuỗi với dữ liệu từ file data
- **Đổi khoảng trắng thành `_`**
- **Xóa ký tự không hợp lệ** trong tên file/path (`< > : " / \ | ? *`)
- **Tạo thư mục** nếu chưa tồn tại

Ví dụ: `"Nguyễn Văn A - 1990-05-20.docx"` → `Nguyễn_Văn_A_-_1990-05-20.docx`

---

## Khắc phục sự cố

### `No module named 'docxtpl'`

`uv` chưa cài deps. Chạy:

```bash
uv add docxtpl jinja2 python-docx pyyaml
```

Hoặc nếu không dùng `uv`:

```bash
pip3 install --user docxtpl jinja2 python-docx pyyaml
```

### `No module named 'yaml'` (khi đọc file YAML)

```bash
uv add pyyaml
# hoặc
pip3 install --user pyyaml
```

### `No module named 'tomllib'` / `'tomli'` (khi đọc file TOML trên Python 3.10)

```bash
uv add tomli
# hoặc
pip3 install --user tomli
```

### `uv run` lỗi `os error 5` trên Windows

File trong `.venv` đang bị Dropbox / OneDrive lock. Giải pháp:
- Tạm dừng đồng bộ cloud drive rồi chạy lại, hoặc
- Chuyển project ra ngoài thư mục sync cloud.

### Ký tự Unicode trong tên file không hiển thị đúng trên CMD Windows

Chạy `chcp 65001` trước khi dùng tool, hoặc dùng PowerShell. File DOCX vẫn được tạo đúng dù terminal hiển thị sai.

### `Không tìm thấy render.py`

`render.py` phải nằm cùng thư mục với `fill_docx.bb`. Khi cài qua brew/scoop điều này được đảm bảo tự động. Nếu clone thủ công, đảm bảo cả hai file cùng thư mục.

---

## Kiến trúc

```
fill_docx.bb          ← Script Babashka: parse args, tìm render.py, gọi Python
render.py             ← Python: đọc data, render DOCX bằng docxtpl + Jinja2
pyproject.toml        ← Khai báo deps Python cho uv
uv.lock               ← Lock file để uv reproduce môi trường nhanh
```

- `fill_docx.bb` đọc `render.py` bằng `slurp` rồi truyền vào Python qua stdin — không cần file tạm.
- `uv run --project <script-dir>` đảm bảo Python luôn tìm đúng môi trường, bất kể user chạy từ thư mục nào.

---

## Giấy phép

Apache License 2.0 — Xem file [`LICENSE`](LICENSE) để biết chi tiết.
