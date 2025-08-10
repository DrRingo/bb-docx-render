# fill_docx — Điền dữ liệu JSON vào template DOCX (tên file cũng động)

`fill_docx.bb` là script **Babashka** dùng **Python + docxtpl** (chạy trong **Poetry env**) để:
- Render nội dung từ `template.docx` theo cú pháp **Jinja** (`{{ var }}`, `{% for %}`, `{% if %}`).
- **Đặt tên file đầu ra động** theo template (cũng dùng Jinja), ví dụ: `-o '{{ho_ten}} - {{ngay_sinh}}.docx'`.
- Tự **chuẩn hóa tên file**: thay khoảng trắng thành `_` và loại bỏ ký tự không hợp lệ (`<>:"/\|?*`).

---

## Yêu cầu & Dependencies

### Bắt buộc
- **Babashka** (chạy script `.bb`)  
- **Poetry** (quản lý môi trường Python)
- **Python** (được Poetry cài theo env của dự án)

### Thư viện Python (cài bằng Poetry)
- `docxtpl`
- `jinja2`
- `python-docx`

> Script gọi Python qua: `poetry run python -` để chắc chắn dùng đúng môi trường Poetry.

---

## Cài đặt

### 1) Clone / copy project
Đặt các file trong một thư mục, ví dụ `bb-docx-runner/`:
```
bb-docx-runner/
├─ fill_docx.bb
├─ bb.edn                (tùy chọn, nếu dùng task)
├─ template.docx         (mẫu)
└─ data.json             (dữ liệu)
```

### 2) Khởi tạo Poetry & cài dependencies
```bash
cd bb-docx-runner
poetry init --no-interaction
poetry add docxtpl jinja2 python-docx
```

*(Nếu dùng **task** của Babashka, thêm `bb.edn` như bên dưới.)*

---

## Hướng dẫn sử dụng

### A) Chạy trực tiếp script Babashka (Poetry env)

#### Linux / WSL / macOS
```bash
# render + đặt tên file bằng template Jinja (lưu ý dùng NHÁY ĐƠN để giữ {{ }})
bb fill_docx.bb template.docx data.json -o '{{ho_ten}} - {{ngay_sinh}}.docx'
```

#### Windows PowerShell
```powershell
# Dùng NHÁY ĐƠN để giữ nguyên {{ }}
bb fill_docx.bb template.docx data.json -o '{{ho_ten}} - {{ngay_sinh}}.docx'
```

> Script sẽ:
> - Mở `data.json` (UTF-8)
> - Render nội dung `template.docx` bằng Jinja
> - Render **tên file** từ `-o` (nếu có `{{ }}`), sau đó đổi khoảng trắng thành `_` và loại bỏ ký tự cấm
> - Lưu file DOCX đầu ra và in đường dẫn đã tạo

### B) Chạy qua `bb.edn` (ngắn gọn hơn)

Tạo file `bb.edn`:

```clojure
{:paths ["."]
 :deps  {cheshire/cheshire {:mvn/version "5.13.0"}}
 :tasks
 {docx:fill
  {:doc "Điền JSON vào template DOCX (Poetry env). Usage: bb docx:fill <template.docx> <data.json> [-o output.docx|template]"
   :requires ([babashka.process :refer [shell]])
   :task (let [args *command-line-args*]
           (apply shell (concat ["poetry" "run" "bb" "fill_docx.bb"] args)))}}}
```

Chạy:

**Linux / WSL / macOS**
```bash
bb docx:fill template.docx data.json -o '{{ho_ten}} - {{ngay_sinh}}.docx'
```

**Windows PowerShell**
```powershell
bb docx:fill template.docx data.json -o '{{ho_ten}} - {{ngay_sinh}}.docx'
```

---

## Cú pháp trong `template.docx`

- Biến đơn:
  ```
  {{ ho_ten }}, {{ ngay_sinh }}, {{ _today }}
  ```
- Vòng lặp:
  ```
  {% for item in ds_muc %}
  - {{ item.ten }} (SL: {{ item.so_luong }}, Giá: {{ item.gia }})
  {% endfor %}
  ```
- Điều kiện:
  ```
  {% if so_tien > 1000000 %}
  Số tiền lớn.
  {% endif %}
  ```

> Script tự thêm biến tiện ích:  
> - `_now` (datetime hiện tại)  
> - `_today` (YYYY-MM-DD)

---

## Ví dụ `data.json`
```json
{
  "ho_ten": "Nguyễn Văn A",
  "ngay_sinh": "1990-05-20",
  "so_tien": 15000000,
  "ds_muc": [
    {"ten": "Mục 1", "so_luong": 2, "gia": 50000},
    {"ten": "Mục 2", "so_luong": 1, "gia": 120000}
  ]
}
```

---

## Tên file đầu ra động

Dùng tham số `-o` với template Jinja (nhớ **nháy đơn**):

```bash
-o '{{ho_ten}} - {{ngay_sinh}}.docx'
```

- Render ra chuỗi, **đổi khoảng trắng → `_`**, và loại ký tự không hợp lệ.  
  Ví dụ: `Nguyễn Văn A - 1990-05-20.docx` → `Nguyễn_Văn_A_-_1990-05-20.docx`

> Nếu cần **bỏ dấu tiếng Việt** trong tên file, có thể bổ sung bước normalize (chưa bật mặc định).

---

## Lưu ý quan trọng

- **Encoding**:  
  - `data.json` nên là UTF-8.  
  - Script đã ép IO Python UTF-8 để in tiếng Việt ổn trên nhiều môi trường.
- **Shell quoting**:
  - Linux/WSL/macOS: dùng **nháy đơn** `'{{...}}'`.  
  - PowerShell: cũng nên dùng **nháy đơn**.  
  - CMD: có thể dùng nháy kép `"` nhưng nên thử trước.
- **Poetry**:  
  - Script luôn gọi `poetry run python`, nên bạn **không cần** `poetry shell`.
  - Nếu thấy lỗi “No module named docxtpl”: chạy `poetry add docxtpl jinja2 python-docx`.

---

## Khắc phục sự cố

- **Không có Python/Poetry**: Cài Poetry theo hướng dẫn của Poetry, rồi `poetry add ...`.
- **WSL báo PEP 668 / externally-managed**: Không ảnh hưởng vì ta dùng Poetry (venv riêng). Đừng cài system-wide bằng `pip`.
- **UnicodeEncodeError khi in tên file**: Script đã reconfigure stdout UTF-8. Nếu console vẫn lỗi hiển thị, file vẫn được tạo đúng; bạn có thể đặt UTF-8 cho terminal (VD: `chcp 65001` trên CMD, hoặc cấu hình profile PowerShell).

---

## Kiến trúc & bảo trì

- `fill_docx.bb` bơm Python code qua stdin (`python -`) để không cần file tạm.  
- Mọi dependency Python nằm trong Poetry env → không “bẩn” hệ thống.  
- Dễ mở rộng: thêm format tiền tệ, chèn ảnh (`InlineImage`), hoặc tiền xử lý tên file (bỏ dấu, lower-case, v.v.).

---

## Giấy phép

Apache License 2.0 - Xem file `LICENSE` để biết chi tiết.
