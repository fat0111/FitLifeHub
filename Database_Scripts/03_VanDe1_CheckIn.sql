USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 03_VanDe1_CheckIn.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 1    : Tối ưu Check-in < 50ms trong khung giờ cao điểm (17:00 - 20:00)
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV1:
-- 1. Index 1 (Tối ưu xác thực vào cổng < 50ms):
--    - Tên đề xuất: IX_DANG_KY_GOI_XacThucVaoCong
--    - Bảng: DANG_KY_GOI
--    - Cột khóa: (MaHV, TrangThai, NgayBatDau, NgayKetThuc)
--    - INCLUDE: (MaGoi)
--    - Điều kiện lọc: WHERE TrangThai = N'Đang hiệu lực'
--
-- 2. Index 2 (Tối ưu kiểm tra dịch vụ cung cấp tại chi nhánh):
--    - Tên đề xuất: IX_CHI_NHANH_DICH_VU_KiemTraDichVu
--    - Bảng: CHI_NHANH_DICH_VU
--    - Cột khóa: (MaCN, MaDV, NgayBatDau, NgayKetThuc)

-- [TV1 VIẾT CODE TẠO INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV1:
-- - Lưu ý kiến trúc: TUYỆT ĐỐI KHÔNG cài Trigger trên bảng CHECK_IN nhằm tối đa hóa
--   thông lượng ghi (INSERT) trong giờ cao điểm, tránh giữ khóa (Lock) lâu làm vượt ngưỡng 50ms.
-- - TV1 có thể tùy chọn tạo Inline Table-Valued Function hoặc Scalar Function hỗ trợ
--   kiểm tra nhanh nếu cần, hoặc thực hiện kiểm tra trực tiếp trong Stored Procedure.

-- [TV1 VIẾT CODE FUNCTION (NẾU CÓ) TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV1:
-- 1. Cài đặt Kịch bản 1 (KB01):
--    - Thủ tục sp_XuLyCheckIn:
--      + Tham số: @MaHV, @MaCN, @MaThietBi, @ThoiGianQuet
--      + Kiểm tra 5 ràng buộc động:
--        * RBTV12: Mỗi hội viên chỉ có tối đa 1 lượt check-in hợp lệ đang mở (ThoiGianRa IS NULL) tại một thời điểm
--        * RBTV66: Hội viên tồn tại và có TrangThai = N'Hoạt động'
--        * RBTV67: Hội viên có ít nhất 1 gói trong DANG_KY_GOI (kết với GOI_DICH_VU) thuộc loại 'Gym' hoặc 'Yoga',
--                  TrangThai = N'Đang hiệu lực', và NgayBatDau <= DATE(ThoiGianQuet) <= NgayKetThuc
--        * RBTV68: Chi nhánh quét thẻ đang 'Hoạt động' và có cung cấp dịch vụ tương ứng (CHI_NHANH_DICH_VU)
--        * RBTV69: ThoiGianQuet >= HOI_VIEN.NgayDangKy và nằm trong khung [GioMoCua, GioDongCua] của CHI_NHANH
--      + Ghi nhận log vào CHECK_IN:
--        Nếu hợp lệ: KetQuaXacThuc = N'Hợp lệ' (RBTV26)
--        Nếu không hợp lệ: KetQuaXacThuc = N'Từ chối' (RBTV26) kèm lý do
--
--    - Thủ tục sp_XuLyCheckOut:
--      + Tham số: @MaHV, @ThoiGianRa
--      + Cập nhật ThoiGianRa cho lượt check-in đang mở gần nhất của hội viên (thỏa RBTV49)

-- [TV1 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV1:
-- - Bật SET STATISTICS TIME, IO ON để đo Logical Reads, CPU Time, Elapsed Time.
-- - Chạy thử nghiệm sp_XuLyCheckIn và sp_XuLyCheckOut dưới tải đơn lẻ và vòng lặp.
-- - Kiểm chứng thời gian phản hồi đạt mục tiêu < 50ms.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV1 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
