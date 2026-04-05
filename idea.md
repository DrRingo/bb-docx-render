# Ý tưởng phát triển cho bb-docx-render

Dưới đây là danh sách các ý tưởng nâng cấp công cụ để tham khảo và thực hiện dần trong tương lai.

## 1. Các tùy chọn (options) mới cho lệnh `fill-docx`

*   **`--pdf` hoặc `-p` (Tự động xuất PDF)**
    *   **Ý tưởng:** Rất nhiều người dùng tạo file DOCX xong là để in hoặc gửi PDF.
    *   **Thực hiện:** Có thể dùng thư viện `docx2pdf` (nếu dùng Windows/macOS có cài sẵn MS Word) hoặc gọi `soffice --headless` (nếu dùng LibreOffice).

*   **`--var` hoặc `-V` (Ghi đè biến từ command line)**
    *   **Ý tưởng:** Khi chỉ cần thêm một vài biến nhỏ (ví dụ cờ trạng thái, tên người duyệt) thay vì phải tự sửa file JSON/YAML.
    *   **Ví dụ:** `fill-docx template.docx data.json -V nguoi_duyet="Giám đốc" -V trang_thai="DaDuyet"`

*   **`--strict` (Báo lỗi nếu thiếu biến)**
    *   **Ý tưởng:** Mặc định Jinja2 có thể bỏ qua biến không tồn tại (để trống). Nếu bật `--strict`, Jinja2 sẽ ném ra lỗi (dùng `jinja2.StrictUndefined`) để người dùng biết file dữ liệu của họ đang khai báo thiếu biến so với Template.

*   **`--batch` hoặc `-b` (Tạo hàng loạt từ 1 file)**
    *   **Ý tưởng:** Nếu file `data.json` của user là một Mảng (Array) gồm nhiều object thay vì 1 object, `fill-docx` sẽ tự động lặp để in ra nhiều file DOCX tương ứng.
    *   **Ví dụ:** `fill-docx template.docx list_nhan_vien.json -o "out/{{ho_ten}}.docx" --batch`

*   **`--dry-run` (Chạy nháp)**
    *   **Ý tưởng:** Chỉ validate xem template có lỗi cú pháp Jinja2 nào không, biến truyền vào đã đủ chưa, tên file output sinh ra là gì, mà không thực sự ghi file ra ổ cứng.

*   **`--watch` (Tự động reload khi chỉnh sửa)**
    *   **Ý tưởng:** Giám sát (watch) thư mục, nếu file `.docx` mẫu hoặc `.json` thay đổi thì tự chạy lại lệnh render và phản ánh kết quả lên file output. Tiện cho người dùng khi đang vừa căn chỉnh file template trong MS Word vừa xem kết quả ngay lập tức.

---

## 2. Các lệnh mới có thể phát triển bên cạnh `fill-docx`

*   **`inspect-docx template.docx` (Trích xuất danh sách biến)**
    *   **Tác dụng:** Quét file DOCX mẫu và in ra màn hình tất cả các biến (variables/tags) mà template đang yêu cầu (Ví dụ: `ho_ten`, `ngay_sinh`, `list_san_pham`).
    *   **Lợi ích:** Giúp người mới nhận template biết họ cần phải chuẩn bị cấu trúc file JSON/YAML thế nào cho đúng và đủ mà không cần phải mở MS Word ra đọc dò từng dòng. (Sử dụng `docxtpl.DocxTemplate.get_undeclared_template_variables`).

*   **`merge-docx file1.docx file2.docx -o combined.docx` (Gộp file DOCX)**
    *   **Tác dụng:** Nối nhiều file DOCX (đã render) lại thành 1 file DOCX duy nhất, xử lý được tính trạng ngắt trang (page breaks).
    *   **Lợi ích:** Ví dụ sau khi tạo 50 trang chứng chỉ từ `--batch`, người dùng muốn gộp chúng thành 1 file duy nhất để mang đi in cho tiện. Thư viện Python `docxcompose` làm việc này rất tốt.

*   **`init-docx <tên_dự_án>` (Tạo project mẫu)**
    *   **Tác dụng:** Tự động tạo một thư mục cấu trúc sẵn gồm 1 file `template.docx` có sẵn bảng biểu cơ bản, 1 file `data.yaml` mẫu và báo kết quả thành công.

*   **`serve-docx` (Khởi chạy Microservice / Web API)**
    *   **Tác dụng:** Biến script CLI thành một HTTP Server nhỏ ở local (dùng `Flask` hoặc `FastAPI` qua Python).
    *   **Lợi ích:** Một project khác của người dùng (ví dụ Web Node.js, PHP, app nội bộ) có thể gửi POST request mang cục JSON tới server, và Server này sẽ trả thẳng về file DOCX dạng binary download. Như vậy bb-docx-render biến từ CLI tool thành Rendering Engine nội bộ.
