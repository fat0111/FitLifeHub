# FitLife Hub - Hệ thống Quản lý Chuỗi Phòng tập Thể hình (MS SQL Server)

## 📌 Đồ án Thực hành môn Cơ sở dữ liệu nâng cao (CSC12002)
* **Trường Đại học Khoa học Tự nhiên - ĐHQG TP.HCM**
* **Khoa Công nghệ Thông tin - Bộ môn Hệ thống Thông tin**
* **Mã số đồ án:** 2627.ADB.01
* **Môi trường:** Microsoft SQL Server 2019+
* **Giảng viên hướng dẫn:** ThS. Hồ Thị Hoàng Vy, ThS. Tiết Gia Hồng

---

## 👥 Danh sách Thành viên Nhóm 10

| Thành viên | Họ và tên | MSSV | Nhiệm vụ chính phụ trách |
|---|---|---|---|
| **TV1** | Bùi Ngọc Minh Huy | 24120321 | Vấn đề 1 (Check-in < 50ms), Vấn đề 3 (Báo cáo lấp đầy), Module Check-in Demo |
| **TV2** | Lê Đình Huy | 24120324 | Vấn đề 2 (Chống Overbooking PT), Vấn đề 5 (Điều chuyển NS & Hoa hồng), Module PT Demo |
| **TV3** | Phạm Bá Quốc Huy | 24120326 | Vấn đề 4 (Tích điểm O(1) & Xét hạng), Nghiệp vụ Hóa đơn/Thanh toán, Module Hội viên Demo |
| **TV4** | Đinh Tiến Phát | 24120405 | Thiết kế vật lý tổng thể, Seed Data $\ge$ 70k dòng, Nghiệp vụ Kho & Doanh thu, Kanban, Đánh giá |

---

## 📂 Cấu trúc Repository Chuẩn

```
FitLifeHub/
├── README.md                           # Giới thiệu tổng quan toàn bộ dự án
├── .gitignore                          # Cấu hình bỏ qua file phụ LaTeX, build và DB dump
│
├── Database_Scripts/                   # Bộ 8 script SQL chạy tuần tự không lỗi
│   ├── 01_Create_Schema.sql            # Tạo DB FitLifeHub, 20 bảng & 63 RBTV tĩnh
│   ├── 02_Seed_Data.sql                # (TV4) Khung sinh >= 70.000 dòng/bảng đúng thứ tự FK
│   ├── 03_VanDe1_CheckIn.sql           # (TV1) Partition CHECK_IN & Check-in < 50ms
│   ├── 04_VanDe2_OverbookingPT.sql     # (TV2) Chống Overbooking PT bằng SERIALIZABLE + UPDLOCK
│   ├── 05_VanDe3_Log_BaoCao.sql        # (TV1) Bảng tổng hợp CHECKIN_TONGHOP & Báo cáo lấp đầy
│   ├── 06_VanDe4_HangHoiVien.sql       # (TV3) Trigger tích điểm O(1) & Xét hạng hội viên
│   ├── 07_VanDe5_DieuChuyenNS.sql      # (TV2) Điều chuyển nhân sự an toàn & Tính hoa hồng PT
│   └── 08_Kho_Va_ThongKe.sql           # (TV4) Nghiệp vụ tồn kho & Partition HOA_DON, Doanh thu
│
├── Report_LaTeX/                       # Toàn bộ mã nguồn LaTeX Báo cáo Tổng kết
│   ├── main.tex                        # File gốc gộp Giai đoạn 1 (Chương 1-4) & Giai đoạn 2 (Chương 5-7)
│   ├── chuong5_tongquan_dulieu.tex     # (TV4) Ma trận tham chiếu truy vấn 10 KB x 20 bảng & Dữ liệu >= 70k dòng
│   ├── chuong5_vande1.tex              # (TV1) Vấn đề 1: Tối ưu Check-in < 50ms trong giờ cao điểm
│   ├── chuong5_vande2.tex              # (TV2) Vấn đề 2: Chống Overbooking PT bằng Transaction Isolation & Locking
│   ├── chuong5_vande3.tex              # (TV1) Vấn đề 3: Phân vùng bảng CHECK_IN & Báo cáo tỷ lệ lấp đầy
│   ├── chuong5_vande4.tex              # (TV3) Vấn đề 4: Tích điểm Loyalty O(1), Xét hạng & Phân vùng HOA_DON
│   ├── chuong5_vande5.tex              # (TV2) Vấn đề 5: Điều chuyển nhân sự an toàn & Tính hoa hồng PT theo lịch sử
│   ├── chuong5_kho_thongke.tex         # (TV4) Nghiệp vụ Tồn kho sản phẩm & Thống kê doanh thu, sản phẩm bán chạy
│   ├── chuong6_ungdung.tex             # (Chương 6) Cài đặt ứng dụng minh họa (Kiến trúc tổng thể & 8 Tab của 4 TV)
│   ├── chuong7_quanly_danhgia.tex      # (Chương 7) Quản lý tiến độ Kanban & Bảng đánh giá đóng góp cá nhân/nhóm
│   ├── hcmus-logo.png                  # Logo Trường ĐH Khoa học Tự nhiên
│   ├── ER.jpg                          # Sơ đồ thực thể kết hợp (ERD) hệ thống FitLife Hub
│   └── images/                         # Thư mục ảnh chung (quy ước đặt tên: tv1_..., tv2_..., tv3_..., tv4_...)
│
├── App_Demo/                           # Khung mã nguồn ứng dụng minh họa 4 module
│   ├── README.md                       # Mô tả chi tiết 4 module và hướng dẫn tích hợp
│   ├── tv1_checkin_app/                # (TV1) Module Cổng kiểm soát Check-in & Dashboard lấp đầy
│   ├── tv2_pt_app/                     # (TV2) Module Đặt lịch HLV PT & Điều chuyển nhân sự
│   ├── tv3_member_app/                 # (TV3) Module Hồ sơ Hội viên, POS Bán hàng & Tích điểm
│   └── tv4_inventory_app/              # (TV4) Module Quản lý Tồn kho & Thống kê Doanh thu
│
└── Docs_PhanCong/                      # Tài liệu phân rã công việc & Quy chế phối hợp Git
    ├── README.md                       # Quy ước đặt tên đối tượng SQL, quy tắc Git & Deadline
    ├── cv1.md                          # Hướng dẫn chi tiết nhiệm vụ của TV1
    ├── cv2.md                          # Hướng dẫn chi tiết nhiệm vụ của TV2
    ├── cv3.md                          # Hướng dẫn chi tiết nhiệm vụ của TV3
    └── cv4.md                          # Hướng dẫn chi tiết nhiệm vụ của TV4
```

---

## ⚡ Hướng dẫn Thực thi Tuần tự Bộ Scripts SQL

1. Mở **SQL Server Management Studio (SSMS)** và kết nối tới SQL Server instance.
2. Mở file `Database_Scripts/01_Create_Schema.sql` và bấm **Execute (F5)** để tạo CSDL `FitLifeHub`, 20 bảng và 63 ràng buộc tĩnh.
3. Mở file `Database_Scripts/02_Seed_Data.sql` và thực thi để sinh dữ liệu mẫu $\ge$ 70.000 dòng.
4. Chạy tuần tự hoặc độc lập các file từ `03_VanDe1_CheckIn.sql` đến `08_Kho_Va_ThongKe.sql`.

---

## 🛡️ Quy tắc Phối hợp Git - Chống Xung đột (Zero Merge Conflict)
* Mỗi thành viên chỉ thao tác và commit trên các file được phân công (`tvX.tex`, script SQL tương ứng, module app riêng).
* Không tự ý chỉnh sửa file của thành viên khác.
* Nhóm trưởng phụ trách việc tổng hợp tại `main.tex` và các tài liệu chung.

