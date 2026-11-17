# BẢNG PHÂN CÔNG NHIỆM VỤ CHI TIẾT – THÀNH VIÊN 3

**Đồ án:** Hệ thống Quản lý Phòng tập FitLife Hub (`2627.ADB.01`) – Giai đoạn 2

**Phân hệ phụ trách:** Lập Hóa đơn, Thanh toán, Tối ưu Xét hạng/Tích điểm Loyalty ($O(1)$) & Báo cáo Doanh thu

**File nộp bài:** `sql/05_TV3_HoaDon_Loyalty.sql`, mục LaTeX phân hệ Hóa đơn & Loyalty, và các Tab Thu ngân/Doanh thu trên App Demo.

> [!NOTE]
> **Vị trí file phụ trách trong Repository:**
> - **File SQL:** `Database_Scripts/06_VanDe4_HangHoiVien.sql` (Vấn đề 4: Tích điểm Loyalty O(1) & Vấn đề 3: Partition HOA_DON / Báo cáo doanh thu)
> - **File Báo cáo LaTeX:**
>   + `Report_LaTeX/chuong5_vande4.tex` (Vấn đề 4: Loyalty O(1) & Phân vùng HOA_DON)
>   + Phần Giao diện Phân hệ Thu ngân & Loyalty (Mục 6.4 - Tab 5 & Tab 6) trong `Report_LaTeX/chuong6_ungdung.tex`
> - **Thư mục ảnh minh chứng:** `Report_LaTeX/images/` (bắt buộc đặt tên tiền tố: `tv3_...` như `tv3_loyalty_reads.png`)
> - **Module App Demo:** `App_Demo/tv3_member_app/` (Tab 5: Thu ngân/Thanh toán & Tab 6: Báo cáo doanh thu/Top dịch vụ)



## 1. MỤC TIÊU CỐT LÕI & VẤN ĐỀ THỰC TẾ GIẢI QUYẾT

Thành viên 3 chịu trách nhiệm giải quyết trực tiếp 2 bài toán hiệu năng trọng tâm của đề bài:

1. **Vấn đề 4 – Chi phí tính toán lại hạng hội viên bị quá tải:** Mỗi khi hội viên thanh toán hóa đơn mới, hệ thống cũ quét lại toàn bộ hóa đơn trong 12 tháng qua để xét hạng (`Silver`/`Gold`/`Platinum`) và tính điểm thưởng gây chậm thao tác in hóa đơn. Giải pháp là lưu trữ trực tiếp các thuộc tính dẫn xuất `DiemTichLuy`, `TongChiTieuNam` trên `HOI_VIEN` và đồng bộ cộng dồn tức thì với độ phức tạp $O(1)$.

2. **Vấn đề 3 (nhánh Doanh thu) – Báo cáo doanh thu chậm khi dữ liệu bùng nổ:** Phân vùng bảng `HOA_DON` theo thời gian kết hợp Covering Index để tăng tốc các báo cáo doanh thu chi nhánh, toàn hệ thống và top gói dịch vụ 6 tháng gần nhất.

## 2. NHIỆM VỤ 1: CÀI ĐẶT RÀNG BUỘC & CODE SQL (`05_TV3_HoaDon_Loyalty.sql`)

### 2.1. Phân chia cơ chế cài đặt Ràng buộc toàn vẹn (RBTV)

* **Các ràng buộc tĩnh đã có sẵn trong khung `01_Create_Schema.sql` (không cần viết lại):**

  * `RBTV02`, `RBTV04`, `RBTV05`, `RBTV06`: `UNIQUE` cho tên hạng, lịch sử hạng theo năm, mã giao dịch thanh toán ngoài, và quy tắc mỗi hóa đơn chỉ được cộng điểm một lần.

  * `RBTV31`–`RBTV36`, `RBTV40`–`RBTV42`: Miền giá trị tiền không âm, trạng thái hóa đơn/thanh toán, hình thức thanh toán, loại giao dịch điểm, hạng hội viên.

  * `RBTV48`, `RBTV51`–`RBTV55`, `RBTV58`: `ThanhTien = TongTien - GiamGia`, `GiamGia <= TongTien`, chi tiết hóa đơn chỉ chứa gói hoặc sản phẩm, kiểm tra dấu điểm cộng/trừ.

* **Các ràng buộc động cài đặt trong `STORED PROCEDURE` (12 ràng buộc — tránh dùng Trigger dây chuyền trên `CHI_TIET_HOA_DON`):**

  * **`RBTV80` & `RBTV82` (Tính tiền & Đơn giá hóa đơn):** Khi lập/thêm chi tiết hóa đơn trong `sp_TaoHoaDon`, tự động lấy đúng `DonGia` hiện hành từ `GOI_DICH_VU.GiaTien` hoặc `SAN_PHAM.GiaBan`, đồng thời cập nhật `HOA_DON.TongTien` và `HOA_DON.ThanhTien` ngay trong luồng xử lý (không tạo Trigger trên `CHI_TIET_HOA_DON` để tránh kích hoạt dây chuyền).

  * **`RBTV83` (Trạng thái kinh doanh):** Sản phẩm hoặc gói dịch vụ đưa vào chi tiết hóa đơn phải đang ở trạng thái `'Đang kinh doanh'`.

  * **`RBTV84` (Khóa sửa đổi hóa đơn đã chốt):** Không cho phép thêm/sửa/xóa chi tiết khi `HOA_DON.TrangThai` đã là `'Đã thanh toán'` hoặc `'Đã hủy'`.

  * **`RBTV85` (Nhân viên lập hóa đơn):** Nhân viên lập (`MaNV`) phải đang làm việc tại chính chi nhánh `MaCN` lập hóa đơn.

  * **`RBTV60`–`RBTV64` (Khởi tạo & Kích hoạt gói đăng ký):** Khi hóa đơn có mua gói dịch vụ, tự động sinh bản ghi `DANG_KY_GOI` đúng `MaHV`, tính `NgayKetThuc = DATEADD(MONTH, ThoiHanThang, NgayBatDau)`, gán `SoBuoiConLai = SoBuoiPT` (nếu là gói PT) và chỉ chuyển trạng thái `'Đang hiệu lực'` sau khi hóa đơn thanh toán thành công.

  * **`RBTV13` & `RBTV91` (Kiểm tra số dư khi tiêu điểm):** Trong `sp_DoiDiemThuong`, số điểm trừ (`LoaiGiaoDich = N'Trừ'`) không được vượt quá `HOI_VIEN.DiemTichLuy` hiện có.

* **Các ràng buộc đồng bộ dữ liệu dẫn xuất cài đặt bằng `TRIGGER` (Chỉ dùng đúng 1 Trigger tổng hợp):**

  * **Trigger 1 (`trg_CapNhatThanhToan_Va_Loyalty` trên `THANH_TOAN` — gom 6 ràng buộc `RBTV81`, `RBTV90`, `RBTV92`–`RBTV95` vào 1 luồng duy nhất):**
    Khi một giao dịch thanh toán được thêm mới hoặc cập nhật sang `TrangThaiTT = N'Thành công'` (và tổng tiền đã thanh toán đủ `>= HOA_DON.ThanhTien`):

    1. Cập nhật `HOA_DON.TrangThai = N'Đã thanh toán'` (`RBTV81`) và kích hoạt các gói đăng ký thuộc hóa đơn đó (`RBTV64`).

    2. Nếu hóa đơn có `MaHV`, gọi hàm `dbo.fn_TinhDiemLoyalty(ThanhTien)` và chèn 1 dòng vào `LICH_SU_DIEM` (`RBTV90`).

    3. Cộng dồn trực tiếp `DiemTichLuy` (`RBTV92`) và `TongChiTieuNam` (`RBTV93`) ngay trên dòng `HOI_VIEN` tương ứng với chi phí $O(1)$ (giải quyết **Vấn đề 4**).

    4. Đối chiếu `TongChiTieuNam` mới với bảng `HANG_HOI_VIEN` để nâng `HOI_VIEN.MaHang` nếu đạt ngưỡng cao hơn (`RBTV94`) và ghi nhận/cập nhật vào `LICH_SU_HANG` cho năm hiện tại (`RBTV95`).

### 2.2. Cài đặt User-Defined Function (`FUNCTION`)

* **Hàm `fn_TinhDiemLoyalty(@ThanhTien DECIMAL(15, 2))`:**

  * *Mục đích:* Nhận giá trị thanh toán thực tế của hóa đơn, quy đổi điểm thưởng theo quy tắc $1\text{ điểm} = 100.000\text{ VNĐ}$ (`RETURN FLOOR(@ThanhTien / 100000)`).

  * *Ứng dụng:* Gọi trực tiếp bên trong Trigger `trg_CapNhatThanhToan_Va_Loyalty` và dùng để hiển thị điểm dự kiến trên màn hình thu ngân trước khi chốt hóa đơn.

### 2.3. Thiết kế lưu trữ vật lý (Partitioning & Indexing)

1. **Phân vùng bảng `HOA_DON` (Table Partitioning — giải quyết Vấn đề 3):**

   * Tạo `PARTITION FUNCTION pf_HoaDon_TheoQuy (DATETIME2)` và `PARTITION SCHEME ps_HoaDon_TheoQuy` phân vùng bảng `HOA_DON` theo mốc thời gian `NgayLap` (từng quý/năm) để cô lập dữ liệu báo cáo tài chính.

2. **Đánh chỉ mục tối ưu (Indexing):**

   * **Index 1 (Tối ưu báo cáo doanh thu theo chi nhánh & thời gian):** Filtered Covering Index trên `HOA_DON(MaCN, NgayLap) INCLUDE (ThanhTien, GiamGia) WHERE TrangThai = N'Đã thanh toán'`.

   * **Index 2 (Tối ưu thống kê top gói dịch vụ/sản phẩm bán chạy):** Composite Covering Index trên `CHI_TIET_HOA_DON(MaGoi, MaSP) INCLUDE (MaHD, SoLuong, ThanhTien)`.

   * **Index 3 (Tối ưu kiểm tra tổng tiền đã thanh toán của hóa đơn):** Filtered Index trên `THANH_TOAN(MaHD, TrangThaiTT) INCLUDE (SoTien) WHERE TrangThaiTT = N'Thành công'`.

### 2.4. Cài đặt 2 Kịch bản truy vấn chính (Có cả Đọc và Ghi)

* **Kịch bản 7 – KB07 (`sp_TaoHoaDon`, `sp_ThanhToanHoaDon` + Trigger 1 và `sp_DoiDiemThuong` – Tần suất cao | Ghi + Đồng bộ Loyalty):**

  * *Luồng xử lý:* Tạo hóa đơn gồm nhiều gói dịch vụ/sản phẩm (`sp_TaoHoaDon`), xác nhận thanh toán qua Tiền mặt/VNPay/Thẻ (`sp_ThanhToanHoaDon`). Trigger `trg_CapNhatThanhToan_Va_Loyalty` tự động chốt hóa đơn, kích hoạt gói tập, cộng điểm và nâng hạng hội viên tức thì.

* **Kịch bản 8 – KB08 (`sp_BaoCaoDoanhThu` và `sp_TopGoiDichVuBanChay` – Tần suất trung bình/thấp | Đọc tổng hợp):**

  * *Luồng xử lý 1 (`sp_BaoCaoDoanhThu`):* Thống kê doanh thu theo Ngày/Tháng/Quý/Năm của từng chi nhánh và so sánh doanh thu giữa 12 chi nhánh trên toàn hệ thống.

  * *Luồng xử lý 2 (`sp_TopGoiDichVuBanChay`):* Thống kê các gói tập/sản phẩm mang lại doanh thu cao nhất trong 6 tháng gần nhất tại từng chi nhánh hoặc toàn hệ thống.

## 3. NHIỆM VỤ 2: VIẾT BÁO CÁO LATEX (PHẦN THIẾT KẾ VẬT LÝ & GIAO DIỆN)

Thành viên 3 viết hoàn chỉnh nội dung vào các file LaTeX được phân công sau:
1. **File `Report_LaTeX/chuong5_vande4.tex` (Vấn đề 4: Loyalty O(1) & Phân vùng HOA_DON):**
   - Mô tả kịch bản KB07, KB08 và bài toán quá tải tính toán hạng hội viên khi quét 12 tháng.
   - Đề xuất giải pháp phi chuẩn hóa có kiểm soát: lưu trực tiếp `DiemTichLuy`, `TongChiTieuNam` và 1 Trigger duy nhất `trg_CapNhatThanhToan_Va_Loyalty` trên `THANH_TOAN` (gom RBTV81, 90, 92-95).
   - Thiết kế phân vùng bảng `HOA_DON` theo quý (`pf_HoaDon_TheoQuy`) và Covering Index doanh thu.
   - Cài đặt các SP: `sp_TaoHoaDon`, `sp_ThanhToanHoaDon`, `sp_DoiDiemThuong`, `sp_BaoCaoDoanhThu`, `sp_TopGoiDichVuBanChay`.
   - Chụp ảnh minh chứng: So sánh `STATISTICS IO, TIME` quét 12 tháng ($O(N)$) vs cập nhật tức thì ($O(1)$ qua Trigger); Execution Plan báo cáo doanh thu trước/sau Partition & Index trên $\ge 70.000$ dòng.
2. **Mục 6.4 trong `Report_LaTeX/chuong6_ungdung.tex` (Giao diện Thu ngân & Loyalty):**
   - Tab 5: Quầy thu ngân (Lập hóa đơn, Giỏ hàng, Thanh toán, Tự động nhảy hạng Silver/Gold/Platinum tức thì).
   - Tab 6: Báo cáo Doanh thu theo kỳ và Biểu đồ Top gói dịch vụ bán chạy nhất.
3. **Lưu ý ảnh minh họa:** Lưu toàn bộ ảnh vào `Report_LaTeX/images/` với tiền tố `tv3_...` (ví dụ `tv3_loyalty_reads.png`).

1. **Mô tả kịch bản sử dụng (KB07, KB08):** Trình bày rõ mục đích, tần suất thực hiện, các bảng tham chiếu (Đọc/Ghi), hàm `fn_TinhDiemLoyalty` và câu lệnh SQL.

2. **Mẫu phân tích truy vấn + nhận xét:** Lập bảng phân tích thuộc tính `WHERE`, `JOIN`, `GROUP BY`, ước lượng chi phí và chỉ ra điểm nghẽn trước tối ưu.

3. **Đề xuất giải pháp Phi chuẩn hóa có kiểm soát (Vấn đề 4) & Partition/Index (Vấn đề 3):**

   * Giải thích chi tiết kiến trúc lưu sẵn `DiemTichLuy`, `TongChiTieuNam` kết hợp 1 Trigger duy nhất trên `THANH_TOAN` (tránh Trigger dây chuyền, giảm độ phức tạp từ $O(N)$ quét hóa đơn 12 tháng xuống $O(1)$).

   * Trình bày thiết kế Partition theo quý và Covering Index trên `HOA_DON`.

4. **Phân tích kết quả thực nghiệm (Có hình chụp minh chứng):**

   * **Minh chứng Vấn đề 4:** Chụp `STATISTICS IO, TIME` so sánh thời gian & số trang đọc (`Logical Reads`) giữa cách truy vấn quét lại hóa đơn 12 tháng mỗi lần thanh toán vs cơ chế cập nhật $O(1)$ qua Trigger.

   * **Minh chứng Vấn đề 3 (Doanh thu):** Chụp ảnh **Actual Execution Plan** của `sp_BaoCaoDoanhThu` và `sp_TopGoiDichVuBanChay` trên tập dữ liệu $\ge 70.000$ dòng `HOA_DON` trước và sau khi áp dụng Partition + Covering Index.

## 4. NHIỆM VỤ 3: LẬP TRÌNH GIAO DIỆN APP DEMO

Gắn vào khung App chung của nhóm (do Thành viên 4 khởi tạo) 2 màn hình/tab sau:

1. **Tab 5 – Quầy Thu Ngân (Lập Hóa đơn & Thanh toán):**

   * Chọn Hội viên (hiển thị sẵn Hạng hiện tại & Điểm tích lũy), Nhân viên lập, Chi nhánh; chọn Gói dịch vụ / Sản phẩm vào giỏ hàng $\rightarrow$ bấm **"Lập & Thanh toán Hóa đơn"** (`KB07`).

   * Hiển thị trực tiếp thông báo cộng điểm và tự động cập nhật Hạng mới (`Silver` $\rightarrow$ `Gold` $\rightarrow$ `Platinum`) ngay sau khi thanh toán thành công.

2. **Tab 6 – Báo cáo Doanh thu & Top Dịch vụ:**

   * Bộ lọc Chi nhánh / Khoảng thời gian $\rightarrow$ hiển thị bảng/biểu đồ doanh thu theo tháng/quý và Top gói dịch vụ mang lại doanh thu cao nhất 6 tháng gần nhất (`KB08`).

## 5. LỘ TRÌNH THỰC HIỆN SONG SONG

* \[ \] **Ngày 1–2:** Chạy `01_Create_Schema.sql`, viết xong file `05_TV3_HoaDon_Loyalty.sql` (Function `fn_TinhDiemLoyalty`, SP lập hóa đơn, 1 Trigger tổng hợp Loyalty, Partition + Index, KB07–KB08) và viết phần lý thuyết kịch bản + mẫu phân tích truy vấn vào LaTeX.

* \[ \] **Ngày 3–4:** Restore file dữ liệu mẫu $\ge 70.000$ dòng của TV4, chạy benchmark đo hiệu năng thanh toán $O(1)$ và báo cáo doanh thu trước/sau tối ưu, chụp hình đưa vào LaTeX.

* \[ \] **Ngày 5:** Tích hợp 2 tab Thu ngân & Doanh thu vào App Demo chung và kiểm thử toàn bộ luồng.