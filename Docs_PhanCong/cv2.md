# BẢNG PHÂN CÔNG NHIỆM VỤ CHI TIẾT – THÀNH VIÊN 2

**Đồ án:** Hệ thống Quản lý Phòng tập FitLife Hub (`2627.ADB.01`) – Giai đoạn 2  
**Phân hệ phụ trách:** Đặt lịch PT (Chống Overbooking), Quản lý sử dụng buổi tập & Điều chuyển Nhân sự / Tính hoa hồng  
**File nộp bài:** `sql/04_TV2_PT_NhanSu.sql`, mục LaTeX phân hệ PT & Nhân sự, và các Tab PT/Nhân sự trên App Demo.

> [!NOTE]
> **Vị trí file phụ trách trong Repository:**
> - **File SQL:** `Database_Scripts/04_VanDe2_OverbookingPT.sql` (Vấn đề 2: Chống Overbooking PT) và `Database_Scripts/07_VanDe5_DieuChuyenNS.sql` (Vấn đề 5: Điều chuyển nhân sự & Hoa hồng PT)
> - **File Báo cáo LaTeX:**
>   + `Report_LaTeX/chuong5_vande2.tex` (Vấn đề 2: Chống Overbooking PT)
>   + `Report_LaTeX/chuong5_vande5.tex` (Vấn đề 5: Điều chuyển nhân sự & Hoa hồng PT)
>   + Phần Giao diện Phân hệ PT & Nhân sự (Mục 6.3 - Tab 3 & Tab 4) trong `Report_LaTeX/chuong6_ungdung.tex`
> - **Thư mục ảnh minh chứng:** `Report_LaTeX/images/` (bắt buộc đặt tên tiền tố: `tv2_...` như `tv2_overbooking_test.png`)
> - **Module App Demo:** `App_Demo/tv2_pt_app/` (Tab 3: Đặt lịch PT & Tab 4: Điều chuyển nhân sự/Hoa hồng)



---

## 1. MỤC TIÊU CỐT LÕI & VẤN ĐỀ THỰC TẾ GIẢI QUYẾT

Thành viên 2 chịu trách nhiệm giải quyết trực tiếp 2 bài toán nghiệp vụ và đồng thời trong đề bài:
1. **Vấn đề 2 – Xung đột đặt lịch HLV cá nhân (Overbooking):** Hai hội viên cùng lúc đặt cùng một PT vào một khung giờ. Phải thiết kế cơ chế giao dịch đồng thời (Transaction + Lock) và ràng buộc CSDL để ngăn chặn tuyệt đối tình trạng trùng lịch dạy.
2. **Vấn đề 5 – Tra cứu Lịch sử điều chuyển Nhân sự & Lương/Hoa hồng bị sai lệch:** Một PT có thể chuyển từ Chi nhánh A sang Chi nhánh B giữa tháng. Phải đảm bảo truy vấn tính hoa hồng PT theo số buổi dạy xác định chính xác chi nhánh nơi PT đang công tác tại từng thời điểm tập.

---

## 2. NHIỆM VỤ 1: CÀI ĐẶT RÀNG BUỘC & CODE SQL (`04_TV2_PT_NhanSu.sql`)

### 2.1. Phân chia cơ chế cài đặt Ràng buộc toàn vẹn (RBTV)

* **Các ràng buộc tĩnh đã có sẵn trong khung `01_Create_Schema.sql` (không cần viết lại):**
  * `RBTV03`: `UNIQUE (MaLich)` trên bảng `LICH_SU_SU_DUNG_PT`.
  * `RBTV27`, `RBTV28`, `RBTV29`, `RBTV30`: Miền giá trị trạng thái lịch hẹn PT, số buổi sử dụng $> 0$, lương cơ bản $> 0$, trạng thái nhân viên.
  * `RBTV50`, `RBTV59`: `ThoiGianKetThuc > ThoiGianBatDau` (Lịch hẹn PT) và `NgayKetThuc >= NgayBatDau` (Lịch sử công tác).

* **Các ràng buộc động cài đặt trong `STORED PROCEDURE` (14 ràng buộc — không dùng Trigger để tránh khóa dây chuyền):**
  * **`RBTV07` & `RBTV08` (Chống trùng lịch HLV và Hội viên):** Một HLV không được có hai lịch hẹn còn hiệu lực (`TrangThai <> N'Hủy'`) chồng lấn thời gian; đồng thời một hội viên cũng không có hai lịch PT chồng lấn thời gian (xử lý bằng Transaction + `UPDLOCK, HOLDLOCK` trong `sp_DatLichPT`).
  * **`RBTV70`, `RBTV71`, `RBTV72` (Điều kiện hợp lệ khi đặt lịch PT):** Gói đăng ký `MaDK` phải thuộc loại `'PT'`, đang hiệu lực, còn hạn và `SoBuoiConLai > 0`; `MaHV` của lịch hẹn phải trùng với `MaHV` sở hữu gói `MaDK`; nhân viên phụ trách phải có `ChucVu = N'HLV'` và đang làm việc.
  * **`RBTV73`, `RBTV74`, `RBTV75` (Địa điểm & Giờ hoạt động):** Tại thời điểm hẹn, HLV phải đang công tác tại chi nhánh `MaCN` đó (đối chiếu `LICH_SU_CONG_TAC`); chi nhánh phải đang hoạt động và có cung cấp dịch vụ `'PT'`; khung giờ tập phải nằm trong `[GioMoCua, GioDongCua]`.
  * **`RBTV76` & `RBTV77` (Xác nhận hoàn thành buổi PT):** Chỉ được thêm bản ghi vào `LICH_SU_SU_DUNG_PT` khi lịch hẹn có trạng thái `'Đã hoàn thành'`, trùng `MaDK` và `ThoiDiemXacNhan >= ThoiGianBatDau`.
  * **`RBTV09`, `RBTV10`, `RBTV11`, `RBTV79` (Quản lý điều chuyển công tác):** Các giai đoạn công tác của một nhân viên không chồng lấn; mỗi nhân viên chỉ có tối đa 1 bản ghi công tác hiệu lực (`NgayKetThuc IS NULL`); ngày bắt đầu đợt mới nối tiếp hợp lệ và không sớm hơn `NHAN_VIEN.NgayVaoLam`.

* **Các ràng buộc đồng bộ dữ liệu dẫn xuất cài đặt bằng `TRIGGER` (Chỉ dùng đúng 2 Trigger):**
  * **Trigger 1 (`trg_SauKhiSuDungPT` trên `LICH_SU_SU_DUNG_PT` — giải quyết `RBTV65`):** Khi xác nhận hoàn thành buổi tập PT, tự động trừ `DANG_KY_GOI.SoBuoiConLai = SoBuoiConLai - SoBuoiSuDung` (và rollback nếu `SoBuoiConLai < 0`).
  * **Trigger 2 (`trg_DongBoCongTac` trên `LICH_SU_CONG_TAC` — giải quyết `RBTV78`):** Khi thêm/cập nhật bản ghi công tác mới nhất (`NgayKetThuc IS NULL`), tự động đồng bộ `MaCNHienTai`, `ChucVu`, `LuongCoBan` sang bảng `NHAN_VIEN` để phục vụ tra cứu nhanh (Vấn đề 5).

### 2.2. Cài đặt User-Defined Function (`FUNCTION`)

* **Hàm `fn_LayChiNhanhHLV(@MaNV VARCHAR(15), @ThoiDiem DATETIME2)`:**
  * *Mục đích:* Nhận mã nhân viên và một mốc thời gian bất kỳ, truy xuất bảng `LICH_SU_CONG_TAC` để trả về `MaCN` (mã chi nhánh) nơi nhân viên đó đang công tác tại đúng thời điểm `@ThoiDiem`.
  * *Ứng dụng:* Gọi trực tiếp bên trong `sp_DatLichPT` (kiểm tra `RBTV73`) và dùng để đối chiếu khi kiểm thử tính hoa hồng HLV.

### 2.3. Thiết kế lưu trữ vật lý (Concurrency Control & Indexing)

1. **Cơ chế chống tranh chấp đồng thời (Concurrency Control):**
   * Sử dụng `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` kết hợp gợi ý khóa `WITH (UPDLOCK, HOLDLOCK)` khi kiểm tra khoảng thời gian trùng trên `LICH_HEN_PT` trong `sp_DatLichPT` để chặn hiện tượng *Phantom Read* khi 2 giao dịch đặt cùng 1 PT tại cùng một mili-giây.
2. **Đánh chỉ mục tối ưu (Indexing):**
   * **Index 1 (Tối ưu kiểm tra trùng lịch HLV):** Filtered Composite Index trên `LICH_HEN_PT(MaNV, ThoiGianBatDau, ThoiGianKetThuc) INCLUDE (MaHV, TrangThai) WHERE TrangThai <> N'Hủy'`.
   * **Index 2 (Tối ưu tra cứu lịch sử công tác khi tính hoa hồng):** Composite Index trên `LICH_SU_CONG_TAC(MaNV, NgayBatDau, NgayKetThuc) INCLUDE (MaCN, ChucVu, LuongCoBan)`.
   * **Index 3 (Tối ưu đếm số buổi đã đặt/sử dụng của gói):** Index trên `LICH_SU_SU_DUNG_PT(MaDK, ThoiDiemXacNhan) INCLUDE (MaLich, SoBuoiSuDung)`.

### 2.4. Cài đặt 3 Kịch bản truy vấn (Có cả Đọc và Ghi)

* **Kịch bản 4 – KB04 (`sp_DatLichPT` – Tần suất cao | Đọc + Ghi có tranh chấp đồng thời):**
  * *Luồng xử lý:* Nhận `@MaHV`, `@MaNV`, `@MaCN`, `@MaDK`, `@ThoiGianBatDau`, `@ThoiGianKetThuc`. Mở Transaction mức cô lập cao, gọi `fn_LayChiNhanhHLV` và kiểm tra toàn bộ điều kiện `RBTV07`, `RBTV08`, `RBTV70`–`RBTV75`. Nếu hợp lệ $\rightarrow$ `INSERT` vào `LICH_HEN_PT` với trạng thái `'Đã đặt'`; nếu trùng lịch hoặc hết buổi $\rightarrow$ `ROLLBACK` và báo lỗi cụ thể.
* **Kịch bản 5 – KB05 (`sp_HoanThanhBuoiPT` + Trigger 1 – Tần suất trung bình | Ghi):**
  * *Luồng xử lý:* Nhận `@MaLich`, `@SoBuoiSuDung`, `@GhiChu`. Cập nhật `LICH_HEN_PT.TrangThai = N'Đã hoàn thành'` và `INSERT` vào `LICH_SU_SU_DUNG_PT` (thỏa `RBTV76, RBTV77`). Trigger `trg_SauKhiSuDungPT` tự động trừ `SoBuoiConLai` trên `DANG_KY_GOI` (`RBTV65`).
* **Kịch bản 6 – KB06 (`sp_DieuChuyenNhanSu` + Trigger 2 và `sp_TinhLuongHoaHongPT` – Tần suất thấp | Ghi + Đọc tổng hợp):**
  * *Luồng xử lý 1 (`sp_DieuChuyenNhanSu`):* Nhận `@MaNV`, `@MaCNMoi`, `@ChucVuMoi`, `@LuongMoi`, `@NgayChuyen`. Đóng bản ghi công tác cũ (`NgayKetThuc = DATEADD(day, -1, @NgayChuyen)`), tạo bản ghi mới trong `LICH_SU_CONG_TAC` (Trigger `trg_DongBoCongTac` tự cập nhật sang `NHAN_VIEN`).
  * *Luồng xử lý 2 (`sp_TinhLuongHoaHongPT`):* Nhận `@Thang`, `@Nam`, `@MaCN` (tùy chọn). Kết nối `LICH_SU_SU_DUNG_PT` $\bowtie$ `LICH_HEN_PT` $\bowtie$ `LICH_SU_CONG_TAC` (theo điều kiện ngày tập nằm trong `[NgayBatDau, NgayKetThuc]`) để thống kê chính xác số buổi dạy và tiền hoa hồng của từng HLV tại mỗi chi nhánh trong tháng.

---

## 3. NHIỆM VỤ 2: VIẾT BÁO CÁO LATEX (PHẦN THIẾT KẾ VẬT LÝ & GIAO DIỆN)

Thành viên 2 viết hoàn chỉnh nội dung vào các file LaTeX được phân công sau:
1. **File `Report_LaTeX/chuong5_vande2.tex` (Vấn đề 2: Chống Overbooking PT):**
   - Mô tả kịch bản KB04 và phân tích nguy cơ race condition khi hai hội viên cùng đặt một PT.
   - Đề xuất giải pháp kiểm soát đồng thời: `SERIALIZABLE` kết hợp gợi ý khóa `WITH (UPDLOCK, HOLDLOCK)`.
   - Cài đặt hàm `fn_LayChiNhanhHLV` và thủ tục `sp_DatLichPT` (xử lý RBTV07, 08, 70-75).
   - Chụp ảnh minh chứng: Chạy 2 session đồng thời cùng 1 HLV, cùng khung giờ (có `WAITFOR DELAY`), chứng minh giao dịch 2 bị khóa chờ và báo lỗi trùng lịch.
2. **File `Report_LaTeX/chuong5_vande5.tex` (Vấn đề 5: Điều chuyển nhân sự & Hoa hồng PT):**
   - Mô tả kịch bản KB05, KB06 và bài toán điều chuyển chi nhánh giữa tháng.
   - Cài đặt Trigger `trg_SauKhiSuDungPT` (RBTV65), `trg_DongBoCongTac` (RBTV78).
   - Cài đặt thủ tục `sp_HoanThanhBuoiPT`, `sp_DieuChuyenNhanSu` và `sp_TinhLuongHoaHongPT`.
   - Chụp ảnh Execution Plan và `STATISTICS IO, TIME` trước/sau khi đánh Index `LICH_SU_CONG_TAC`.
3. **Mục 6.3 trong `Report_LaTeX/chuong6_ungdung.tex` (Giao diện Phân hệ PT & Nhân sự):**
   - Tab 3: Đặt lịch PT và Xác nhận hoàn thành buổi tập (demo trừ buổi còn lại).
   - Tab 4: Điều chuyển chi nhánh nhân sự và Thống kê tính hoa hồng HLV theo lịch sử.
4. **Lưu ý ảnh minh họa:** Lưu toàn bộ ảnh vào `Report_LaTeX/images/` với tiền tố `tv2_...` (ví dụ `tv2_overbooking_test.png`).
1. **Mô tả kịch bản sử dụng (KB04, KB05, KB06):** Trình bày rõ mục đích, tần suất thực hiện, các bảng tham chiếu (Đọc/Ghi) và câu lệnh SQL (kèm mô tả hàm `fn_LayChiNhanhHLV`).
2. **Mẫu phân tích truy vấn + nhận xét:** Lập bảng phân tích cho KB04, KB05, KB06 (thuộc tính `WHERE`, `JOIN`, `GROUP BY`, ước lượng chi phí và điểm nghẽn).
3. **Đề xuất giải pháp Concurrency Control & Indexing:** Giải thích cơ chế `SERIALIZABLE` / `UPDLOCK, HOLDLOCK` chống Overbooking (Vấn đề 2), lý do tách biệt điều kiện kiểm tra vào SP và chỉ dùng 2 Trigger đồng bộ dữ liệu dẫn xuất, cùng thiết kế Index tra cứu lịch sử công tác (Vấn đề 5).
4. **Phân tích kết quả thực nghiệm (Bắt buộc có hình chụp minh chứng):**
   * **Minh chứng Vấn đề 2 (Chống trùng lịch):** Chụp màn hình mở 2 cửa sổ SSMS chạy đồng thời `sp_DatLichPT` cùng 1 HLV, cùng khung giờ (dùng `WAITFOR DELAY '00:00:05'`) — chứng minh giao dịch 1 thành công, giao dịch 2 bị khóa chờ và báo lỗi trùng lịch.
   * **Minh chứng Vấn đề 5 (Tối ưu tính hoa hồng):** Chụp ảnh **Actual Execution Plan** và `STATISTICS IO, TIME` của `sp_TinhLuongHoaHongPT` trên tập dữ liệu $\ge 70.000$ dòng `LICH_HEN_PT` trước và sau khi đánh Index.

---

## 4. NHIỆM VỤ 3: LẬP TRÌNH GIAO DIỆN APP DEMO

Gắn vào khung App chung của nhóm (do Thành viên 4 khởi tạo) 2 màn hình/tab sau:
1. **Tab 3 – Đặt lịch PT & Xác nhận buổi tập:**
   * Form chọn Hội viên, Gói PT đang có (hiển thị số buổi còn lại), HLV, Chi nhánh, Ngày & Giờ bắt đầu/kết thúc $\rightarrow$ nút **"Đặt lịch PT"** (`KB04`).
   * Danh sách lịch hẹn `'Đã đặt'` kèm nút **"Xác nhận hoàn thành"** (`KB05`) để demo số buổi còn lại tự động giảm.
2. **Tab 4 – Điều chuyển Nhân sự & Tính hoa hồng HLV:**
   * Form điều chuyển chi nhánh cho nhân viên (`sp_DieuChuyenNhanSu`).
   * Bộ lọc Tháng/Năm/Chi nhánh $\rightarrow$ bảng kết quả tính lương & hoa hồng HLV tách bạch theo từng chi nhánh công tác (`sp_TinhLuongHoaHongPT`).

---

## 5. LỘ TRÌNH THỰC HIỆN SONG SONG

* [ ] **Ngày 1–2:** Chạy `01_Create_Schema.sql`, viết xong file `04_TV2_PT_NhanSu.sql` (Function, Transaction chống trùng lịch, 2 Trigger, Index, KB04–KB06) và viết xong phần lý thuyết kịch bản + mẫu phân tích truy vấn vào LaTeX.
* [ ] **Ngày 3–4:** Restore file dữ liệu mẫu $\ge 70.000$ dòng của TV4, chạy test 2 session đồng thời để chụp ảnh chống Overbooking và đo benchmark tính hoa hồng đưa vào LaTeX.
* [ ] **Ngày 5:** Tích hợp 2 tab giao diện PT & Nhân sự vào App Demo chung và kiểm thử toàn bộ luồng.