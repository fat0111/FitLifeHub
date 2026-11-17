# FitLife Hub - Đồ án Cơ sở dữ liệu nâng cao (CSC12002)

## Giới thiệu dự án

**FitLife Hub** là hệ thống quản lý chuỗi phòng tập gym hiện đại, bao gồm **12 chi nhánh** trải khắp các thành phố lớn tại Việt Nam. Hệ thống xử lý toàn bộ nghiệp vụ: quản lý hội viên theo hạng (Silver/Gold/Platinum), đặt lịch huấn luyện viên cá nhân (PT), tích điểm & xét hạng tự động, quản lý kho hàng và thống kê doanh thu theo chi nhánh.

| Thông tin | Chi tiết |
|---|---|
| Môn học | CSC12002 - Cơ sở dữ liệu nâng cao |
| Hệ QTCSDL | Microsoft SQL Server |
| Database | FitLifeHub |
| Số bảng | 20 bảng |
| Nhóm | Nhóm 10 |

### Thành viên nhóm

| Mã SV | Họ tên | Vai trò |
|---|---|---|
| 24120321 | Bùi Ngọc Minh Huy | ... |
| 24120324 | Lê Đình Huy | ... |
| 24120326 | Phạm Bá Quốc Huy | ... |
| 24120405 | Đinh Tiến Phát | ... |

---

## Cấu trúc thư mục

```
FitLifeHub/
├── .gitignore                # Bỏ qua file rác, file build, file phụ LaTeX
├── Database_Scripts/
│   ├── 01_Create_Schema.sql     # 20 bảng + 63 RBTV tĩnh
│   ├── 02_Seed_Data.sql         # TV4: Dữ liệu mẫu >= 70.000 dòng/bảng
│   ├── 03_VanDe1_CheckIn.sql    # TV1: Tối ưu Check-in < 50ms
│   ├── 04_VanDe2_OverbookingPT.sql  # TV2: Chống Overbooking PT
│   ├── 05_VanDe3_Log_BaoCao.sql # TV1: Partition CHECK_IN + Báo cáo lấp đầy
│   ├── 06_VanDe4_HangHoiVien.sql    # TV3: Tích điểm O(1) + Xét hạng
│   ├── 07_VanDe5_DieuChuyenNS.sql   # TV2: Điều chuyển nhân sự + Hoa hồng
│   └── 08_Kho_Va_ThongKe.sql    # TV4: Tồn kho + Thống kê doanh thu
├── Report_LaTeX/
│   ├── main.tex                 # File chính (include Chương 1-7)
│   ├── chuong5_tongquan_dulieu.tex  # TV4: Ma trận 10 KB x 20 bảng & Dữ liệu >= 70k dòng
│   ├── chuong5_vande1.tex       # TV1: Vấn đề 1 - Tối ưu Check-in < 50ms
│   ├── chuong5_vande2.tex       # TV2: Vấn đề 2 - Chống Overbooking PT
│   ├── chuong5_vande3.tex       # TV1: Vấn đề 3 - Partition CHECK_IN & Tỷ lệ lấp đầy
│   ├── chuong5_vande4.tex       # TV3: Vấn đề 4 - Loyalty O(1) & Partition HOA_DON
│   ├── chuong5_vande5.tex       # TV2: Vấn đề 5 - Điều chuyển nhân sự & Hoa hồng PT
│   ├── chuong5_kho_thongke.tex  # TV4: Nghiệp vụ Tồn kho & Thống kê doanh thu
│   ├── chuong6_ungdung.tex      # Chương 6: Cài đặt App Demo (Kiến trúc & 8 Tab của 4 TV)
│   ├── chuong7_quanly_danhgia.tex # Chương 7: Quản lý Kanban & Đánh giá đóng góp (TV4)
│   ├── ER.jpg, hcmus-logo.png   # Sơ đồ ER và Logo trường
│   └── images/                  # Thư mục ảnh chung (quy ước tiền tố: tv1_..., tv2_..., tv3_..., tv4_...)
├── App_Demo/
│   ├── README.md
│   ├── tv1_checkin_app/
│   ├── tv2_pt_app/
│   ├── tv3_member_app/
│   └── tv4_inventory_app/
└── Docs_PhanCong/
    ├── README.md                # File này
    ├── cv1.md                   # Nhiệm vụ TV1
    ├── cv2.md                   # Nhiệm vụ TV2
    ├── cv3.md                   # Nhiệm vụ TV3
    └── cv4.md                   # Nhiệm vụ TV4
```

---

## Quy ước đặt tên file ảnh minh họa (`Report_LaTeX/images/`)

> [!TIP]
> Toàn bộ ảnh chụp Execution Plan, Statistics IO/Time, biểu đồ và giao diện ứng dụng được lưu chung trong thư mục `Report_LaTeX/images/`. Để tránh xung đột khi merge Git, bắt buộc đặt tên file ảnh có tiền tố của thành viên:
> - **TV1:** `tv1_<ten_anh>.<png/jpg>` (Ví dụ: `tv1_checkin_plan_before.png`, `tv1_checkin_plan_after.png`, `tv1_tab1_checkin.png`)
> - **TV2:** `tv2_<ten_anh>.<png/jpg>` (Ví dụ: `tv2_overbooking_concurrent.png`, `tv2_commission_plan.png`, `tv2_tab3_pt.png`)
> - **TV3:** `tv3_<ten_anh>.<png/jpg>` (Ví dụ: `tv3_loyalty_reads.png`, `tv3_revenue_partition_plan.png`, `tv3_tab5_pos.png`)
> - **TV4:** `tv4_<ten_anh>.<png/jpg>` (Ví dụ: `tv4_bigdata_scale.png`, `tv4_inventory_plan.png`, `tv4_kanban_board.png`)

---

## Quy ước đặt tên đối tượng SQL

| Loại đối tượng | Quy ước | Ví dụ |
|---|---|---|
| Index | `IX_<TenBang>_<TenCot>` | `IX_CHECK_IN_MaHV_ThoiGianVao` |
| Stored Procedure | `sp_<PhanHe>_<TenChucNang>` | `sp_CheckIn_GhiNhanVao` |
| Trigger | `trg_<TenBang>_<HanhDong>` | `trg_THANH_TOAN_CongDiem` |
| Function | `fn_<TenHam>` | `fn_KiemTraQuyenVaoCong` |
| Partition Function | `PF_<TenBang>_<TenCot>` | `PF_CHECK_IN_ThoiGianVao` |
| Partition Scheme | `PS_<TenBang>_<TenCot>` | `PS_CHECK_IN_ThoiGianVao` |

---

## Quy tắc Git - Mỗi người chỉ sửa file của mình

> [!IMPORTANT]
> Không được chỉnh sửa file của thành viên khác. Nếu cần sửa file dùng chung, phải trao đổi với nhóm trưởng trước.

| Thành viên | File được phép sửa |
|---|---|
| **TV1** | `03_VanDe1_CheckIn.sql`, `05_VanDe3_Log_BaoCao.sql`, `chuong5_vande1.tex`, `chuong5_vande3.tex`, phần Giao diện TV1 trong `chuong6_ungdung.tex`, `images/tv1_*` |
| **TV2** | `04_VanDe2_OverbookingPT.sql`, `07_VanDe5_DieuChuyenNS.sql`, `chuong5_vande2.tex`, `chuong5_vande5.tex`, phần Giao diện TV2 trong `chuong6_ungdung.tex`, `images/tv2_*` |
| **TV3** | `06_VanDe4_HangHoiVien.sql`, `chuong5_vande4.tex`, phần Giao diện TV3 trong `chuong6_ungdung.tex`, `images/tv3_*` |
| **TV4** | `02_Seed_Data.sql`, `08_Kho_Va_ThongKe.sql`, `chuong5_tongquan_dulieu.tex`, `chuong5_kho_thongke.tex`, phần Kiến trúc & Giao diện TV4 trong `chuong6_ungdung.tex`, `chuong7_quanly_danhgia.tex`, `images/tv4_*` |
| **Nhóm trưởng** | `main.tex`, `README.md`, `App_Demo/README.md` |

### Quy trình commit

```bash
git checkout -b tv<X>/<ten-nhanh>
# ... code ...
git add <file-cua-ban>
git commit -m "[TV<X>] Mô tả thay đổi ngắn gọn"
git push origin tv<X>/<ten-nhanh>
# Tạo Pull Request, nhờ 1 người khác review
```

---

## Deadline nội bộ

> [!WARNING]
> Các mốc dưới đây là deadline nội bộ của nhóm. Mỗi thành viên tự cập nhật ngày cụ thể vào ô `[TBD]`.

| Mốc | Nội dung | Người phụ trách | Deadline |
|---|---|---|---|
| **Mốc 1** | TV4 hoàn thành `02_Seed_Data.sql` (đủ 70k dòng, test FK pass) | TV4 | `[TBD]` |
| **Mốc 2** | Hoàn thiện toàn bộ code SQL, App Demo demo được và các file LaTeX cá nhân được phân công | Tất cả | `[TBD]` |
| **Nộp cuối** | Theo lịch môn học | Nhóm trưởng | Theo GV |

---

## Hướng dẫn chạy scripts theo thứ tự

> [!CAUTION]
> **Phải chạy đúng thứ tự** vì các file sau phụ thuộc vào schema và dữ liệu từ file trước.

```
Bước 1: Chạy 01_Create_Schema.sql
         → Tạo database FitLifeHub, 20 bảng, 63 RBTV tĩnh (CHECK, UNIQUE, FK, DEFAULT...)

Bước 2: Chạy 02_Seed_Data.sql
         → Cần chạy TRƯỚC TẤT CẢ file còn lại
         → Sinh >= 70.000 dòng cho các bảng chính

Bước 3: Chạy 03_VanDe1_CheckIn.sql  (TV1)
Bước 4: Chạy 04_VanDe2_OverbookingPT.sql  (TV2)
Bước 5: Chạy 05_VanDe3_Log_BaoCao.sql  (TV1)
Bước 6: Chạy 06_VanDe4_HangHoiVien.sql  (TV3)
Bước 7: Chạy 07_VanDe5_DieuChuyenNS.sql  (TV2)
Bước 8: Chạy 08_Kho_Va_ThongKe.sql  (TV4)
         → Các file 03-08 độc lập với nhau, có thể chạy song song sau Bước 2
```

---

## Tóm tắt 20 bảng trong FitLifeHub

| STT | Tên bảng | Mô tả |
|---|---|---|
| 1 | `CHI_NHANH` | Thông tin 12 chi nhánh |
| 2 | `DICH_VU` | Các dịch vụ (Gym, Yoga, GroupX, PT, Spa) |
| 3 | `CHI_NHANH_DICH_VU` | Dịch vụ khả dụng tại từng CN |
| 4 | `HANG_HOI_VIEN` | Hạng hội viên (Silver, Gold, Platinum) |
| 5 | `HOI_VIEN` | Thông tin hội viên (70k+) |
| 6 | `GOI_DICH_VU` | Các gói dịch vụ |
| 7 | `NHAN_VIEN` | Nhân viên (HLV, lễ tân, quản lý...) |
| 8 | `LICH_SU_CONG_TAC` | Lịch sử phân công NV theo CN |
| 9 | `SAN_PHAM` | Sản phẩm bán tại quầy |
| 10 | `TON_KHO` | Tồn kho sản phẩm theo CN |
| 11 | `HOA_DON` | Hóa đơn (70k+) |
| 12 | `CHI_TIET_HOA_DON` | Chi tiết từng dòng hóa đơn |
| 13 | `THANH_TOAN` | Thanh toán hóa đơn |
| 14 | `DANG_KY_GOI` | Đăng ký gói dịch vụ của hội viên |
| 15 | `LICH_SU_KHO` | Lịch sử nhập/xuất kho |
| 16 | `CHECK_IN` | Lịch sử check-in tại cổng (70k+) |
| 17 | `LICH_HEN_PT` | Lịch hẹn với huấn luyện viên PT (70k+) |
| 18 | `LICH_SU_SU_DUNG_PT` | Lịch sử buổi PT đã thực hiện |
| 19 | `LICH_SU_DIEM` | Lịch sử cộng/trừ điểm tích lũy |
| 20 | `LICH_SU_HANG` | Lịch sử thay đổi hạng hội viên |

---

## RBTV động (cài bằng Trigger/Stored Procedure)

| Mã | Mô tả | Cài trong | Phụ trách |
|---|---|---|---|
| RBTV07 | HLV không có 2 lịch PT chồng lấn | `sp_PT_DatLich` | TV2 |
| RBTV08 | Hội viên không có 2 lịch PT chồng lấn | `sp_PT_DatLich` | TV2 |
| RBTV09 | Các giai đoạn công tác của cùng NV không chồng lấn | `sp_NhanSu_DieuChuyen` | TV2 |
| RBTV11 | Mỗi CN có đúng 1 quản lý tại một thời điểm | `sp_NhanSu_DieuChuyen` | TV2 |
| RBTV12 | Ngưỡng chi tiêu tăng dần theo hạng (Silver < Gold < Platinum) | `fn_XacDinhHang` + trigger | TV3 |
| RBTV13 | Tổng điểm hội viên không âm | `trg_THANH_TOAN_CongDiem` | TV3 |