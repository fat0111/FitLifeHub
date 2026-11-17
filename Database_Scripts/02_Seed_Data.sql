USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 02_Seed_Data.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ      : Phát sinh Dữ liệu quy mô lớn (>= 70.000 dòng/bảng)
                 Đảm bảo toàn vẹn khóa ngoại (FK) và 52 ràng buộc tĩnh
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV4:
-- - Trong quá trình nạp dữ liệu khối lượng lớn (Bulk Data Insertion), có thể cân nhắc
--   tạm thời vô hiệu hóa non-clustered index để tăng tốc độ ghi:
--   ALTER INDEX ALL ON <TenBang> DISABLE;
-- - Sau khi nạp xong, tiến hành Rebuild lại toàn bộ index:
--   ALTER INDEX ALL ON <TenBang> REBUILD;


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV4:
-- - Khi import dữ liệu lịch sử (ví dụ: CHECK_IN, THANH_TOAN, LICH_SU_KHO), có thể tạm thời
--   tắt trigger nếu không muốn kích hoạt tính toán tự động trong lúc nạp:
--   DISABLE TRIGGER ALL ON <TenBang>;
--   (Sau khi nạp xong: ENABLE TRIGGER ALL ON <TenBang>;)
-- - Lưu ý kiểm tra các ràng buộc CHECK và UNIQUE tĩnh trong 01_Create_Schema.sql:
--   + CCCD hội viên (12 số, UNIQUE - RBTV01, RBTV19)
--   + Số điện thoại (bắt đầu bằng 0, đúng 10 số - RBTV15)
--   + Giá tiền, số lượng không âm


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV4:
-- 1. Thứ tự nạp dữ liệu bắt buộc tuân theo phân cấp Khóa ngoại (FK) của 20 bảng:
--    Nhóm 1 (Danh mục gốc, không có FK cha):
--      1. HANG_HOI_VIEN      (3 dòng: SILVER, GOLD, PLATINUM)
--      2. CHI_NHANH          (12 chi nhánh: CN001 đến CN012)
--      3. DICH_VU            (5 dịch vụ: Gym, Yoga, GroupX, PT, Spa)
--      4. SAN_PHAM           (~30 - 50 sản phẩm)
--      5. GOI_DICH_VU        (~15 - 20 gói dịch vụ)
--    Nhóm 2 (Có FK cấp 1):
--      6. CHI_NHANH_DICH_VU  (12 CN x 5 DV = 60 dòng)
--      7. NHAN_VIEN          (~150 - 500 nhân viên; ChucVu: HLV, Lễ tân, Quản lý chi nhánh, Nhân viên bán hàng)
--      8. LICH_SU_CONG_TAC   (~250 - 600 dòng; mỗi NV có ít nhất 1 đợt, một số chuyển chi nhánh)
--      9. HOI_VIEN           (30.000 - 70.000 dòng; CCCD và SĐT hợp lệ)
--      10. TON_KHO           (12 CN x 30-50 SP = 360 - 600 dòng tồn ban đầu)
--    Nhóm 3 (Bảng giao dịch lớn >= 70.000 - 150.000 dòng):
--      11. DANG_KY_GOI       (>= 75.000 dòng; NgayKetThuc >= NgayBatDau)
--      12. HOA_DON           (>= 80.000 dòng; phân bổ các năm 2024 - 2026)
--      13. CHI_TIET_HOA_DON  (>= 120.000 dòng; đúng 1 trong 2: MaGoi hoặc MaSP khác NULL)
--      14. THANH_TOAN        (>= 80.000 dòng; nếu VNPay/Thẻ thì MaGiaoDichNgoai khác NULL)
--      15. CHECK_IN          (>= 150.000 dòng; KetQuaXacThuc IN (N'Hợp lệ', N'Từ chối'))
--      16. LICH_HEN_PT       (>= 75.000 dòng; ThoiGianKetThuc > ThoiGianBatDau, không trùng lịch HLV)
--    Nhóm 4 (Bảng nhật ký / phụ thuộc):
--      17. LICH_SU_SU_DUNG_PT(>= 70.000 dòng; UNIQUE MaLich)
--      18. LICH_SU_KHO       (>= 70.000 dòng; Nhập > 0, Xuất < 0)
--      19. LICH_SU_DIEM      (>= 60.000 dòng; Cộng > 0 kèm MaHD, Trừ < 0)
--      20. LICH_SU_HANG      (>= 70.000 dòng; UNIQUE MaHV, NamXetHang)
--
-- 2. Phương pháp nạp: TV4 có thể dùng script Python (pyodbc với fast_executemany = True),
--    BULK INSERT từ các file .csv, hoặc viết vòng lặp WHILE / CTE Tally Table trong T-SQL.
--
-- [TV4 VIẾT CODE STORED PROCEDURE HOẶC LỆNH NẠP DỮ LIỆU TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV4:
-- - Viết các câu lệnh kiểm tra số lượng dòng (Row Count) của 20 bảng sau khi nạp:
--   SELECT COUNT(*) AS TongSoDong FROM <TenBang>;
-- - Bật SET STATISTICS TIME, IO ON để đo thời gian truy vấn kiểm tra dữ liệu lớn.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV4 VIẾT CÁC CÂU LỆNH KIỂM THỬ SỐ LƯỢNG VÀ TOÀN VẸN FK TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
