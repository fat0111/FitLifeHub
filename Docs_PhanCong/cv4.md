# BẢNG PHÂN CÔNG NHIỆM VỤ CHI TIẾT – THÀNH VIÊN 4

**Đồ án:** Hệ thống Quản lý Phòng tập FitLife Hub (`2627.ADB.01`) – Giai đoạn 2

**Phân hệ phụ trách:** Phát sinh Dữ liệu lớn ($\ge 70.000$ dòng), Quản lý Tồn kho, Thống kê Hội viên & Dựng khung App Demo

**File nộp bài:** `data/generate_data.py` (hoặc `02_Insert_BigData.sql`), `sql/06_TV4_TonKho_ThongKe.sql`, Ma trận tham chiếu & mục LaTeX phân hệ Kho/Thống kê, và Khung App Demo chính.

> [!NOTE]
> **Vị trí file phụ trách trong Repository:**
> - **File SQL:** `Database_Scripts/02_Seed_Data.sql` (Sinh >= 70k dòng/bảng) và `Database_Scripts/08_Kho_Va_ThongKe.sql` (Nghiệp vụ kho & Thống kê hội viên)
> - **File Báo cáo LaTeX:**
>   + `Report_LaTeX/chuong5_tongquan_dulieu.tex` (Ma trận 10 KB x 20 bảng & Dữ liệu lớn >= 70k dòng)
>   + `Report_LaTeX/chuong5_kho_thongke.tex` (Nghiệp vụ Tồn kho & Thống kê doanh thu, CSKH)
>   + Phần Khung kiến trúc tổng thể (Mục 6.1) & Giao diện Phân hệ Kho/Dashboard (Mục 6.5 - Tab 7 & Tab 8) trong `Report_LaTeX/chuong6_ungdung.tex`
>   + Toàn bộ `Report_LaTeX/chuong7_quanly_danhgia.tex` (Quản lý Kanban & Bảng đánh giá đóng góp nhóm)
> - **Thư mục ảnh minh chứng:** `Report_LaTeX/images/` (bắt buộc đặt tên tiền tố: `tv4_...` như `tv4_kanban_board.png`)
> - **Khung & Module App Demo:** `App_Demo/` (Dựng Khung App 8 Tab) và `App_Demo/tv4_inventory_app/` (Tab 7: Tồn kho & Tab 8: Dashboard CSKH)



## 1. MỤC TIÊU CỐT LÕI & VẤN ĐỀ THỰC TẾ GIẢI QUYẾT

Thành viên 4 đóng vai trò **kiến trúc hạ tầng dữ liệu & tích hợp toàn hệ thống**, đảm bảo 3 mục tiêu then chốt của đề bài:

1. **Dữ liệu kiểm chứng quy mô lớn (**$\ge 70.000$ **dòng/bảng):** Tự phát sinh dữ liệu chuẩn khóa ngoại cho toàn bộ 20 bảng (trong đó các bảng nghiệp vụ cốt lõi như `CHECK_IN`, `HOA_DON`, `CHI_TIET_HOA_DON`, `LICH_HEN_PT` đạt từ `70.000` đến `150.000` dòng) để cả 4 thành viên có đủ dữ liệu benchmark Index và Partition.

2. **Quản lý Tồn kho & Chăm sóc Hội viên (Mục 4 đề bài):** Giải quyết bài toán xuất/nhập kho không âm, cảnh báo sản phẩm dưới mức tồn tối thiểu, thống kê hội viên sắp hết hạn gói tập và tỷ lệ phân bổ hạng hội viên (`Silver` / `Gold` / `Platinum`).

3. **Tích hợp Ma trận & Ứng dụng Demo:** Tổng hợp **Ma trận tham chiếu truy vấn (10 kịch bản** $\times$ **20 bảng)** trong báo cáo và dựng sẵn khung giao diện App Demo kết nối SQL Server để TV1, TV2, TV3 gắn các tab chức năng vào.

## 2. NHIỆM VỤ 1: PHÁT SINH DỮ LIỆU LỚN (`generate_data.py` / `02_Insert_BigData.sql`)

* **Yêu cầu kỹ thuật (Thực hiện ngay Ngày 1–2 để bàn giao cho cả nhóm):**

  * Sinh dữ liệu tuân thủ tuyệt đối toàn bộ khóa ngoại (`FK`) và 52 ràng buộc tĩnh trong `01_Create_Schema.sql` (không bị lỗi `CHECK` hoặc `UNIQUE` khi import).

  * **Quy mô dữ liệu tối thiểu:**

    * Bảng danh mục: `HANG_HOI_VIEN` (3 dòng: Silver, Gold, Platinum), `CHI_NHANH` (12 chi nhánh), `DICH_VU` (5 dịch vụ), `CHI_NHANH_DICH_VU` (\~50 dòng), `GOI_DICH_VU` (\~15 gói), `SAN_PHAM` (\~30 sản phẩm), `TON_KHO` (360 dòng), `NHAN_VIEN` (\~150 nhân viên), `LICH_SU_CONG_TAC` (\~250 dòng).

    * Bảng dữ liệu lớn ($\ge 70.000$ dòng để test Index/Partition): `HOI_VIEN` (`30.000` dòng), `DANG_KY_GOI` (`75.000` dòng), `HOA_DON` (`80.000` dòng), `CHI_TIET_HOA_DON` (`120.000` dòng), `THANH_TOAN` (`80.000` dòng), `LICH_HEN_PT` (`75.000` dòng), `LICH_SU_SU_DUNG_PT` (`70.000` dòng), `CHECK_IN` (`150.000` dòng trải đều nhiều tháng).

  * Dùng kỹ thuật nạp nhanh (`pyodbc` với `fast_executemany = True` hoặc `BULK INSERT` từ file `.csv`) và xuất file backup `.bak` (hoặc bộ `.csv` + script `BULK INSERT`) gửi lên nhóm.

## 3. NHIỆM VỤ 2: CÀI ĐẶT RÀNG BUỘC & CODE SQL (`06_TV4_TonKho_ThongKe.sql`)

### 3.1. Phân chia cơ chế cài đặt Ràng buộc toàn vẹn (RBTV)

* **Các ràng buộc tĩnh đã có sẵn trong khung `01_Create_Schema.sql` (không cần viết lại):**

  * `RBTV37`, `RBTV38`, `RBTV39`: Miền giá trị giá bán $\ge 0$, `SoLuongTon >= 0`, `MucTonToiThieu >= 0`, loại giao dịch kho (`'Nhập'`, `'Xuất'`, `'Điều chỉnh'`).

  * `RBTV56`, `RBTV57`: Dấu của `SoLuongThayDoi` khớp với `LoaiGiaoDich` (`Nhập > 0`, `Xuất < 0`), và giao dịch nhập/điều chỉnh thì `MaHD IS NULL`.

* **Các ràng buộc động cài đặt trong `STORED PROCEDURE` (2 ràng buộc):**

  * **`RBTV88` (Đối chiếu xuất kho bán hàng):** Khi thực hiện giao dịch kho với `LoaiGiaoDich = N'Xuất'` và có đính kèm `MaHD`, sản phẩm `MaSP` và số lượng xuất phải khớp chính xác với dòng chi tiết tương ứng trong `CHI_TIET_HOA_DON` của hóa đơn đó.

  * **`RBTV89` (Thẩm quyền nhân viên kho):** Nhân viên thực hiện giao dịch kho (`MaNV`) phải đang làm việc tại chính chi nhánh `MaCN` phát sinh giao dịch.

* **Các ràng buộc đồng bộ dữ liệu dẫn xuất cài đặt bằng `TRIGGER` (Chỉ dùng đúng 1 Trigger):**

  * **Trigger 1 (`trg_CapNhatTonKho` trên `LICH_SU_KHO` — gom `RBTV86` & `RBTV87`):**

    1. Kiểm tra nếu `TON_KHO.SoLuongTon + inserted.SoLuongThayDoi < 0` thì báo lỗi *"Không đủ số lượng tồn kho tại chi nhánh"* và `ROLLBACK` (`RBTV86`).

    2. Nếu hợp lệ, tự động cập nhật `TON_KHO.SoLuongTon = SoLuongTon + SoLuongThayDoi` và `NgayCapNhat = GETDATE()` (`RBTV87`).

### 3.2. Thiết kế lưu trữ vật lý (Indexing)

* **Index 1 (Tối ưu cảnh báo hàng dưới mức tồn tối thiểu):** Filtered Index trên `TON_KHO(MaCN, SoLuongTon, MucTonToiThieu) INCLUDE (MaSP, NgayCapNhat)`.

* **Index 2 (Tối ưu truy xuất lịch sử xuất/nhập kho theo chi nhánh và thời gian):** Composite Covering Index trên `LICH_SU_KHO(MaCN, MaSP, ThoiGian) INCLUDE (LoaiGiaoDich, SoLuongThayDoi, MaNV)`.

* **Index 3 (Tối ưu lọc hội viên sắp hết hạn gói tập):** Filtered Covering Index trên `DANG_KY_GOI(TrangThai, NgayKetThuc) INCLUDE (MaHV, MaGoi, SoBuoiConLai) WHERE TrangThai = N'Đang hiệu lực'`.

### 3.3. Cài đặt 2 Kịch bản truy vấn chính (Có cả Đọc và Ghi)

* **Kịch bản 9 – KB09 (`sp_GiaoDichKho` + Trigger 1 và `sp_BaoCaoTonKho` – Tần suất trung bình | Ghi + Đọc):**

  * `sp_GiaoDichKho`: Nhận `@MaCN`, `@MaSP`, `@MaNV`, `@LoaiGiaoDich`, `@SoLuongThayDoi`, `@MaHD`, `@GhiChu`. Kiểm tra `RBTV88, RBTV89` và chèn vào `LICH_SU_KHO` để Trigger `trg_CapNhatTonKho` tự động cập nhật `TON_KHO` (`RBTV86, RBTV87`).

  * `sp_BaoCaoTonKho`: Liệt kê tồn kho hiện tại theo chi nhánh, đánh dấu cảnh báo các sản phẩm có `SoLuongTon <= MucTonToiThieu`.

* **Kịch bản 10 – KB10 (`sp_ThongKeHoiVienSapHetHan` và `sp_ThongKePhanBoHangHoiVien` – Tần suất thấp | Đọc / Báo cáo quản trị):**

  * `sp_ThongKeHoiVienSapHetHan`: Tìm danh sách hội viên có gói tập hết hạn trong `N` ngày tới (ví dụ 7 hoặc 15 ngày) hoặc không có lượt `CHECK_IN` nào trong 30 ngày gần nhất để bộ phận CSKH liên hệ gia hạn.

  * `sp_ThongKePhanBoHangHoiVien`: Thống kê số lượng và tỷ lệ phần trăm hội viên ở từng hạng (`Silver`, `Gold`, `Platinum`) trên toàn hệ thống (đọc trực tiếp trên `HOI_VIEN.MaHang` tốc độ cực nhanh).

## 4. NHIỆM VỤ 3: VIẾT BÁO CÁO LATEX (PHẦN THIẾT KẾ VẬT LÝ, ỨNG DỤNG & TỔNG HỢP)

Thành viên 4 viết hoàn chỉnh nội dung vào các file LaTeX được phân công sau:
1. **File `Report_LaTeX/chuong5_tongquan_dulieu.tex` (Tổng quan Dữ liệu lớn):**
   - Ma trận tham chiếu truy vấn (10 kịch bản KB01-KB10 $	imes$ 20 bảng), đánh dấu rõ thao tác Read/Write và tần suất.
   - Nhận xét các bảng điểm nóng cần ưu tiên Index/Partition.
   - Quy trình và công cụ sinh dữ liệu lớn $\ge 70.000$ dòng/bảng; Bảng thống kê số dòng thực tế của 20 bảng.
2. **File `Report_LaTeX/chuong5_kho_thongke.tex` (Nghiệp vụ Kho & Thống kê):**
   - Mô tả kịch bản KB09, KB10 và quy tắc nghiệp vụ kho không âm.
   - Cài đặt Trigger `trg_CapNhatTonKho` (RBTV86, 87) và các SP: `sp_GiaoDichKho`, `sp_BaoCaoTonKho`, `sp_ThongKeHoiVienSapHetHan`, `sp_ThongKePhanBoHangHoiVien`.
   - Đo lường và chụp ảnh Execution Plan trước/sau Index.
3. **Mục 6.1 & Mục 6.5 trong `Report_LaTeX/chuong6_ungdung.tex` (Kiến trúc App & Phân hệ Kho):**
   - Mục 6.1: Mô hình kiến trúc đa tầng N-tier và cơ chế kết nối SQL Server.
   - Mục 6.5: Chi tiết giao diện Tab 7 (Quản lý Tồn kho) và Tab 8 (Dashboard Giám đốc & CSKH).
4. **Toàn bộ `Report_LaTeX/chuong7_quanly_danhgia.tex` (Quản lý tiến độ & Đánh giá nhóm):**
   - Quy trình quản lý tiến độ Kanban và bảng theo dõi tiến độ chi tiết qua các giai đoạn.
   - Bảng phân công trách nhiệm và mức độ hoàn thành của 4 thành viên theo lưu ý ở trang 4 đề bài.
   - Tự đánh giá, đánh giá chéo và bài học kinh nghiệm rút ra.
5. **Lưu ý ảnh minh họa:** Lưu toàn bộ ảnh vào `Report_LaTeX/images/` với tiền tố `tv4_...` (ví dụ `tv4_kanban_board.png`).

1. **Ma trận tham chiếu truy vấn (Query Reference Matrix) + Nhận xét:**

   * Lập bảng tổng hợp **10 kịch bản (KB01 – KB10)** $\times$ **20 bảng**, đánh dấu rõ thao tác `R` (Read) / `W` (Write) kèm tần suất giao dịch của từng kịch bản.

   * Viết nhận xét chỉ ra các bảng "điểm nóng" (như `CHECK_IN`, `HOA_DON`, `DANG_KY_GOI`, `LICH_HEN_PT`) cần ưu tiên Index/Partition.

2. **Mô tả kịch bản (KB09, KB10), Mẫu phân tích truy vấn & Phân tích kết quả Index:**

   * Chụp `STATISTICS IO, TIME` và **Actual Execution Plan** của `KB09` và `KB10` trước và sau khi đánh Index trên tập dữ liệu $\ge 70.000$ dòng.

3. **Mô tả quy trình phát sinh dữ liệu lớn (**$\ge 70.000$ **dòng/bảng) & Bảng phân công/đánh giá nhóm:**

   * Trình bày công cụ/script phát sinh dữ liệu, bảng thống kê số dòng thực tế của 20 bảng, và bảng phân công + mức độ hoàn thành của 4 thành viên theo đúng lưu ý ở trang 4 đề bài.

## 5. NHIỆM VỤ 4: DỰNG KHUNG APP DEMO & TÍCH HỢP

1. **Dựng khung ứng dụng chính (Ngày 1–2):**

   * Khởi tạo project (Python Streamlit / PyQt hoặc C# WinForms) đã cấu hình sẵn chuỗi kết nối SQL Server và thanh điều hướng gồm **8 Tab** cho 4 thành viên (TV1: Tab 1–2, TV2: Tab 3–4, TV3: Tab 5–6, TV4: Tab 7–8) đẩy lên GitHub/Google Drive nhóm.

2. **Lập trình Tab 7 & Tab 8 của riêng TV4:**

   * **Tab 7 – Quản lý Tồn kho:** Nhập/xuất kho (`sp_GiaoDichKho`) và bảng cảnh báo sản phẩm sắp hết hàng (`sp_BaoCaoTonKho`).

   * **Tab 8 – Dashboard Giám đốc & CSKH:** Biểu đồ tỷ lệ phân bổ hạng hội viên (`Silver`/`Gold`/`Platinum`) và danh sách hội viên sắp hết hạn gói tập (`KB10`).

## 6. LỘ TRÌNH THỰC HIỆN SONG SONG

* \[ \] **Ngày 1–2:** Chạy `01_Create_Schema.sql`, chạy script phát sinh $\ge 70.000$ dòng dữ liệu và gửi bộ data cho TV1, TV2, TV3; đồng thời dựng khung App 8 Tab.

* \[ \] **Ngày 3–4:** Code xong `06_TV4_TonKho_ThongKe.sql`, chạy benchmark KB09–KB10, lập Ma trận tham chiếu 10 KB $\times$ 20 bảng và hoàn thiện phần LaTeX.

* \[ \] **Ngày 5:** Ghép code giao diện của TV1, TV2, TV3 vào khung App chính, chụp ảnh màn hình demo và kiểm thử toàn bộ hệ thống trước khi xuất PDF nộp bài.