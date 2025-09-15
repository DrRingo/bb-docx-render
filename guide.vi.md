# Hướng dẫn cài đặt và sử dụng fill_docx

Script `fill_docx.bb` giúp bạn điền dữ liệu JSON/YAML/TOML vào một file DOCX mẫu bằng thư viện **docxtpl** và cú pháp **Jinja**.
Tài liệu này trình bày chi tiết cách cài đặt, cách sử dụng cơ bản và một vài tình huống ứng dụng hàng ngày.

## 1. Cài đặt

### 1.1 Cài nhanh bằng Homebrew (macOS/Linux)
```bash
brew tap drringo/bb-docx-render https://github.com/drringo/bb-docx-render
brew install bb-docx-render
```
Sau khi cài, lệnh `fill-docx` có sẵn để sử dụng.

### 1.2 Cài bằng Scoop (Windows)
```powershell
scoop install https://raw.githubusercontent.com/DrRingo/bb-docx-render/main/scoop/bb-docx-render.json
```
Lệnh `fill-docx` sẽ sẵn sàng sau khi cài đặt.

### 1.3 Cài đặt thủ công khi làm việc với mã nguồn
```bash
git clone https://github.com/DrRingo/bb-docx-render.git
cd bb-docx-render
uv init
uv add docxtpl jinja2 python-docx pyyaml tomli
```

## 2. Sử dụng cơ bản

Cấu trúc tối thiểu của thư mục làm việc:
```
template.docx
fill_docx.bb
data.json|data.yaml|data.toml
```

Chạy script:
```bash
bb fill_docx.bb template.docx data.json -o '{{ho_ten}} - {{ngay_sinh}}.docx'
```
Các định dạng dữ liệu khác nhau:
- JSON: `bb fill_docx.bb template.docx data.json`
- YAML: `bb fill_docx.bb template.docx data.yaml`
- TOML: `bb fill_docx.bb template.docx data.toml`

Khi tham số `-o` chứa cú pháp Jinja, tên file đầu ra sẽ được render dựa trên nội dung dữ liệu. Script cũng thay khoảng trắng bằng `_` và loại bỏ ký tự không hợp lệ.

## 3. Tình huống sử dụng hàng ngày

### 3.1 Tạo thư mời họp từ dữ liệu JSON
1. Chuẩn bị `template.docx` với các biến `{{ten}}`, `{{ngay}}`, `{{dia_diem}}`.
2. Tạo `data.json`:
   ```json
   {"ten": "Nguyễn Văn A", "ngay": "2024-09-01", "dia_diem": "Hội trường A"}
   ```
3. Chạy:
   ```bash
   bb fill_docx.bb template.docx data.json -o '{{ten}}-thu-moi.docx'
   ```

### 3.2 Xuất báo cáo công việc từ dữ liệu YAML
1. `template.docx` có vòng lặp cho danh sách nhiệm vụ: `{% for n in nhiem_vu %} - {{n}} {% endfor %}`.
2. `data.yaml`:
   ```yaml
   nhan_vien: Trần Thị B
   nhiem_vu:
     - Viết tài liệu
     - Họp nhóm
   ```
3. Chạy:
   ```bash
   bb fill_docx.bb template.docx data.yaml -o '{{nhan_vien}}-bao-cao.docx'
   ```

### 3.3 Tạo phiếu thu chi từ dữ liệu TOML
1. `template.docx` có biến `{{so_tien}}` và `{{mo_ta}}`.
2. `data.toml`:
   ```toml
   so_tien = 500000
   mo_ta = "Chi phí văn phòng"
   ```
3. Chạy:
   ```bash
   bb fill_docx.bb template.docx data.toml -o 'phieu-{{so_tien}}.docx'
   ```

Các ví dụ trên cho thấy bạn có thể linh hoạt chọn định dạng dữ liệu phù hợp với công việc hằng ngày để tạo ra các văn bản Word được điền sẵn thông tin.

