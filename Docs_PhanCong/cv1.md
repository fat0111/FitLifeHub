# BẢNG PHÂN CÔNG NHIỆM VỤ CHI TIẾT – THÀNH VIÊN 1

**Đồ án:** Hệ thống Quản lý Phòng tập FitLife Hub (`2627.ADB.01`) – Giai đoạn 2  
**Phân hệ phụ trách:** Check-in/Check-out, Tối ưu Log lớn (Partitioning) & Báo cáo Tỷ lệ lấp đầy  
**File nộp bài:** `sql/03_TV1_CheckIn_Partition.sql`, mục LaTeX phân hệ Check-in, và các Tab Check-in trên App Demo.

> [!NOTE]
> **Vị trí file phụ trách trong Repository:**
> - **File SQL:** `Database_Scripts/03_VanDe1_CheckIn.sql` (Vấn đề 1: Check-in < 50ms) và `Database_Scripts/05_VanDe3_Log_BaoCao.sql` (Vấn đề 3: Partition CHECK_IN & Báo cáo lấp đầy)
> - **File Báo cáo LaTeX:**
>   + `Report_LaTeX/chuong5_vande1.tex` (Vấn đề 1: Tối ưu Check-in < 50ms)
>   + `Report_LaTeX/chuong5_vande3.tex` (Vấn đề 3: Phân vùng CHECK_IN & Báo cáo lấp đầy)
>   + Phần Giao diện Phân hệ Check-in (Mục 6.2 - Tab 1 & Tab 2) trong `Report_LaTeX/chuong6_ungdung.tex`
> - **Thư mục ảnh minh chứng:** `Report_LaTeX/images/` (bắt buộc đặt tên tiền tố: `tv1_...` như `tv1_checkin_plan.png`)
> - **Module App Demo:** `App_Demo/tv1_checkin_app/` (Tab 1: Check-in/Check-out & Tab 2: Tỷ lệ lấp đầy)



---

## 1. MỤC TIÊU CỐT LÕI & VẤN ĐỀ THỰC TẾ GIẢI QUYẾT

Thành viên 1 chịu trách nhiệm giải quyết trực tiếp 2 bài toán hiệu năng trọng tâm của đề bài:
1. **Vấn đề 1 – Nghẽn Check-in giờ cao điểm (17h00 – 20h00):** Hệ thống có hơn 10.000 lượt quét thẻ/QR đồng thời. Truy vấn kiểm tra hiệu lực gói tập và ghi log vào cổng phải đạt tốc độ **dưới 50ms**.
2. **Vấn đề 3 (nhánh Check-in) – Bùng nổ dữ liệu Log:** Bảng `CHECK_IN` tăng trưởng hơn 300.000 dòng/tháng khiến báo cáo *Tỷ lệ lấp đầy phòng tập theo khung giờ/chi nhánh* chạy chậm.

---

## 2. NHIỆM VỤ 1: CÀI ĐẶT RÀNG BUỘC & CODE SQL (`03_TV1_CheckIn_Partition.sql`)

### 2.1. Phân chia cơ chế cài đặt Ràng buộc toàn vẹn (RBTV)

* **Các ràng buộc tĩnh đã có sẵn trong khung `01_Create_Schema.sql` (không cần viết lại):**
  * `RBTV26`: `CHECK_IN.KetQuaXacThuc IN (N'Hợp lệ', N'Từ chối')`.
  * `RBTV49`: `CHECK_IN.ThoiGianRa IS NULL OR ThoiGianRa >= ThoiGianVao`.

* **Các ràng buộc động cài đặt trong `STORED PROCEDURE` (5 ràng buộc):**
  * **`RBTV12` (Kiểm soát trạng thái ra/vào):** Mỗi hội viên chỉ có tối đa 1 lượt check-in hợp lệ đang mở (`ThoiGianRa IS NULL`) tại một thời điểm.
  * **`RBTV66` (Trạng thái hội viên):** Hội viên thực hiện check-in phải tồn tại và có `HOI_VIEN.TrangThai = N'Hoạt động'`.
  * **`RBTV67` (Hiệu lực gói tập):** Hội viên phải có ít nhất 1 đăng ký gói trong `DANG_KY_GOI` (kết với `GOI_DICH_VU`) thuộc loại `'Gym'` hoặc `'Yoga'`, `TrangThai = N'Đang hiệu lực'`, và `NgayBatDau <= DATE(ThoiGianVao) <= NgayKetThuc`.
  * **`RBTV68` (Dịch vụ tại chi nhánh):** Chi nhánh nơi quét thẻ phải đang `'Hoạt động'` và có cung cấp dịch vụ tương ứng với gói tập của hội viên tại thời điểm quét (đối chiếu `CHI_NHANH_DICH_VU` và `DICH_VU`).
  * **`RBTV69` (Giờ hoạt động & Ngày đăng ký):** `ThoiGianVao >= HOI_VIEN.NgayDangKy` và giờ quét thẻ nằm trong khung `[GioMoCua, GioDongCua]` của `CHI_NHANH`. *(Nếu vi phạm điều kiện gói/giờ/dịch vụ, vẫn ghi nhận 1 dòng log vào `CHECK_IN` với `KetQuaXacThuc = N'Từ chối'` kèm lý do).*

* **Sử dụng `TRIGGER` (0 Trigger):**
  * **Không cài Trigger trên bảng `CHECK_IN`** nhằm tối đa hóa thông lượng ghi (`INSERT`) giờ cao điểm, tránh giữ khóa (`Lock`) lâu làm vượt ngưỡng `< 50ms`.

### 2.2. Thiết kế lưu trữ vật lý (Partitioning & Indexing)

1. **Phân vùng bảng `CHECK_IN` (Table Partitioning):**
   * Tạo `PARTITION FUNCTION pf_CheckIn_TheoThang (DATETIME2)` chia các mốc theo từng tháng/quý.
   * Tạo `PARTITION SCHEME ps_CheckIn_TheoThang` ánh xạ phân vùng vào Filegroup.
   * Chuyển đổi bảng `CHECK_IN` sang lưu trữ phân vùng (cập nhật khóa chính thành `PRIMARY KEY (MaCheckIn, ThoiGianVao)` để SQL Server kích hoạt được *Partition Elimination*).
2. **Đánh chỉ mục tối ưu (Indexing):**
   * **Index 1 (Tối ưu xác thực vào cổng < 50ms):** Filtered Covering Index trên `DANG_KY_GOI(MaHV, TrangThai, NgayBatDau, NgayKetThuc) INCLUDE (MaGoi) WHERE TrangThai = N'Đang hiệu lực'`.
   * **Index 2 (Tối ưu kiểm tra dịch vụ chi nhánh):** Composite Index trên `CHI_NHANH_DICH_VU(MaCN, MaDV, NgayBatDau, NgayKetThuc)`.
   * **Index 3 (Tối ưu báo cáo tỷ lệ lấp đầy):** Composite Covering Index trên `CHECK_IN(MaCN, ThoiGianVao, KetQuaXacThuc) INCLUDE (MaHV, ThoiGianRa)`.

### 2.3. Cài đặt 3 Kịch bản truy vấn (Đọc & Ghi)

* **Kịch bản 1 – KB01 (`sp_XuLyCheckIn` và `sp_XuLyCheckOut` – Tần suất cực cao | Đọc + Ghi):**
  * `sp_XuLyCheckIn`: Nhận `@MaHV`, `@MaCN`, `@MaThietBi`, `@ThoiGianQuet`. Kiểm tra tuần tự `RBTV12`, `RBTV66`–`RBTV69` bằng Index; ghi nhận vào `CHECK_IN` (`'Hợp lệ'` hoặc `'Từ chối'`) và trả về kết quả ngay lập tức.
  * `sp_XuLyCheckOut`: Nhận `@MaHV`, `@ThoiGianRa`. Tìm lượt check-in hợp lệ gần nhất chưa có `ThoiGianRa` của hội viên để cập nhật giờ ra.
* **Kịch bản 2 – KB02 (`sp_TraCuuCheckInTrongNgay` – Tần suất cao | Đọc):**
  * Nhận `@MaCN`, `@Ngay`, `@KhungGioTu`, `@KhungGioDen`. Truy xuất danh sách hội viên đã check-in thành công kèm họ tên, hạng thành viên và trạng thái đang tập hay đã ra về.
* **Kịch bản 3 – KB03 (`sp_ThongKeTyLeLapDay` – Tần suất thấp | Đọc / Báo cáo nặng):**
  * Nhận `@MaCN` (hoặc `NULL` cho toàn hệ thống), `@TuNgay`, `@DenNgay`. Thống kê số lượt tập hợp lệ phân bổ theo các khung giờ (Sáng 05h–11h, Trưa 11h–17h, Cao điểm 17h–20h, Tối 20h–22h) và tính tỷ lệ phần trăm lấp đầy.

---

## 3. NHIỆM VỤ 2: VIẾT BÁO CÁO LATEX (PHẦN THIẾT KẾ VẬT LÝ & GIAO DIỆN)

Thành viên 1 viết hoàn chỉnh nội dung vào các file LaTeX được phân công sau:
1. **File `Report_LaTeX/chuong5_vande1.tex` (Vấn đề 1: Tối ưu Check-in < 50ms):**
   - Mô tả kịch bản KB01 (mục đích, tần suất, đọc/ghi, câu lệnh SQL).
   - Mẫu phân tích truy vấn và nhận xét điểm nghẽn trước tối ưu.
   - Đề xuất giải pháp chỉ mục bao phủ (`DANG_KY_GOI`, `CHI_NHANH_DICH_VU`).
   - Cài đặt `sp_XuLyCheckIn` và `sp_XuLyCheckOut` (xử lý RBTV12, RBTV66-69).
   - Phân tích kết quả đo đạc `STATISTICS IO, TIME` và Actual Execution Plan, chứng minh thời gian phản hồi đạt $< 50$ms.
2. **File `Report_LaTeX/chuong5_vande3.tex` (Vấn đề 3: Phân vùng CHECK_IN & Báo cáo lấp đầy):**
   - Mô tả kịch bản KB02, KB03 và bài toán bùng nổ dữ liệu log.
   - Đề xuất giải pháp phân vùng `CHECK_IN` theo tháng (`pf_CheckIn_TheoThang`, `ps_CheckIn_TheoThang`) và chỉ mục bao phủ báo cáo.
   - Cài đặt `sp_TraCuuCheckInTrongNgay` và `sp_ThongKeTyLeLapDay`.
   - Minh chứng Partition Elimination (loại bỏ phân vùng thừa) trên tập dữ liệu $\ge 100.000$ dòng.
3. **Mục 6.2 trong `Report_LaTeX/chuong6_ungdung.tex` (Giao diện Phân hệ Check-in):**
   - Tab 1: Mô phỏng Cửa kiểm soát Check-in/Check-out kèm thời gian thực thi (ms).
   - Tab 2: Theo dõi lưu lượng và Biểu đồ tỷ lệ lấp đầy theo khung giờ.
4. **Lưu ý ảnh minh họa:** Lưu toàn bộ ảnh vào `Report_LaTeX/images/` với tiền tố `tv1_...` (ví dụ `tv1_checkin_plan_after.png`).
1. **Mô tả kịch bản sử dụng (KB01, KB02, KB03):** Nêu mục đích, tần suất thực hiện, các bảng tham chiếu (Đọc/Ghi) và câu lệnh SQL.
2. **Mẫu phân tích truy vấn + nhận xét:** Lập bảng phân tích thuộc tính chọn lọc (`WHERE`), kết nối (`JOIN`), gom nhóm (`GROUP BY`), ước lượng chi phí và chỉ ra điểm nghẽn trước tối ưu.
3. **Đề xuất giải pháp Partition & Index:** Giải thích lý do chọn phân vùng theo tháng trên `ThoiGianVao`, lý do không dùng Trigger trên `CHECK_IN` và cơ chế hoạt động của từng Index.
4. **Phân tích kết quả thực nghiệm (Có hình chụp minh chứng):**
   * Chạy đo trên tập dữ liệu lớn ($\ge 100.000$ dòng `CHECK_IN`) với `SET STATISTICS IO, TIME ON` và **Actual Execution Plan**.
   * Chụp hình so sánh **Trước khi tối ưu** vs **Sau khi tối ưu**: lập bảng đối chiếu `Logical Reads`, `CPU Time`, `Elapsed Time` (chứng minh KB01 đạt **< 50ms** và KB03 loại bỏ được các phân vùng thừa).

---

## 4. NHIỆM VỤ 3: LẬP TRÌNH GIAO DIỆN APP DEMO

Gắn vào khung App chung của nhóm (do Thành viên 4 khởi tạo) 2 màn hình/tab sau:
1. **Tab 1 – Mô phỏng Cửa kiểm soát Check-in / Check-out:**
   * Nhập `Mã Hội Viên`, chọn `Chi nhánh`, mã cửa kiểm soát $\rightarrow$ bấm **"Quét thẻ Check-in"** (`sp_XuLyCheckIn`) hoặc **"Quét thẻ Check-out"** (`sp_XuLyCheckOut`).
   * Hiển thị trạng thái mở cửa (Xanh = Hợp lệ / Đỏ = Từ chối + Lý do) kèm **thời gian thực thi (ms)** ngay trên màn hình để demo trực tiếp.
2. **Tab 2 – Theo dõi Lưu lượng & Tỷ lệ lấp đầy:**
   * Hiển thị danh sách khách check-in trong ngày (`KB02`) và bảng/biểu đồ tỷ lệ lấp đầy theo khung giờ (`KB03`).

---

## 5. LỘ TRÌNH THỰC HIỆN SONG SONG

* [ ] **Ngày 1–2:** Chạy `01_Create_Schema.sql` (do nhóm thống nhất), code xong `03_TV1_CheckIn_Partition.sql` và viết xong phần lý thuyết kịch bản + mẫu phân tích truy vấn vào LaTeX.
* [ ] **Ngày 3–4:** Nạp dữ liệu mẫu $\ge 70.000$ dòng từ TV4, chạy benchmark trước/sau tối ưu, chụp ảnh Execution Plan & Statistics đưa vào LaTeX.
* [ ] **Ngày 5:** Tích hợp 2 tab giao diện Check-in vào App Demo chung và kiểm thử toàn bộ luồng.