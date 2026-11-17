USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 04_VanDe2_OverbookingPT.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 2    : Chống Overbooking lịch hẹn Huấn luyện viên cá nhân (PT)
                 bằng Transaction Concurrency Control & Lock
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Index 1 (Tối ưu kiểm tra trùng lịch HLV - RBTV07):
--    - Tên đề xuất: IX_LICH_HEN_PT_ChongTrungLichHLV
--    - Bảng: LICH_HEN_PT
--    - Cột khóa: (MaNV, ThoiGianBatDau, ThoiGianKetThuc)
--    - INCLUDE: (MaHV, TrangThai, MaCN)
--    - Điều kiện lọc: WHERE TrangThai <> N'Hủy'
--
-- 2. Index bổ trợ kiểm tra trùng lịch Hội viên (RBTV08):
--    - Tên đề xuất: IX_LICH_HEN_PT_ChongTrungLichHV
--    - Bảng: LICH_HEN_PT
--    - Cột khóa: (MaHV, ThoiGianBatDau, ThoiGianKetThuc)
--    - INCLUDE: (MaNV, TrangThai)
--    - Điều kiện lọc: WHERE TrangThai <> N'Hủy'

-- [TV2 VIẾT CODE TẠO INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Hàm fn_LayChiNhanhHLV:
--    - Tham số: @MaNV BIGINT, @ThoiDiem DATETIME2
--    - Trả về: VARCHAR(10) (Mã chi nhánh MaCN nơi HLV đang công tác tại thời điểm @ThoiDiem)
--    - Truy xuất bảng: LICH_SU_CONG_TAC (NgayBatDau <= @ThoiDiem AND (NgayKetThuc IS NULL OR NgayKetThuc >= @ThoiDiem))
--    - Ứng dụng: Dùng kiểm tra RBTV73 bên trong sp_DatLichPT
--
-- 2. Lưu ý kiến trúc: Không dùng Trigger cho quy trình kiểm tra đặt lịch để tránh
--    khóa dây chuyền (Cascade Lock) và Deadlock. Toàn bộ logic kiểm tra đặt lịch được đặt trong Stored Procedure.

-- [TV2 VIẾT CODE FUNCTION TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Cài đặt Kịch bản 4 (KB04) - Thủ tục sp_DatLichPT:
--    - Tham số: @MaHV, @MaNV, @MaCN, @MaDK, @ThoiGianBatDau, @ThoiGianKetThuc
--    - Mức cô lập: SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
--    - Sử dụng gợi ý khóa: WITH (UPDLOCK, HOLDLOCK) trên LICH_HEN_PT để khóa phạm vi (Range Lock)
--    - Kiểm tra danh sách ràng buộc động:
--      * RBTV07 & RBTV08: HLV và Hội viên không có 2 lịch hẹn còn hiệu lực (TrangThai <> N'Hủy')
--        chồng lấn thời gian (ThoiGianBatDau < @ThoiGianKetThuc AND ThoiGianKetThuc > @ThoiGianBatDau)
--      * RBTV70, RBTV71, RBTV72: Gói MaDK thuộc loại 'PT', đang hiệu lực, còn hạn, SoBuoiConLai > 0;
--        MaHV lịch hẹn trùng người sở hữu gói; MaNV có ChucVu = N'HLV' và TrangThai = N'Đang làm'
--      * RBTV73, RBTV74, RBTV75: HLV đang công tác tại chi nhánh MaCN tại thời điểm hẹn (gọi fn_LayChiNhanhHLV);
--        chi nhánh đang hoạt động, có cung cấp dịch vụ PT; khung giờ nằm trong [GioMoCua, GioDongCua]
--      * RBTV50: ThoiGianKetThuc > ThoiGianBatDau
--    - Nếu thỏa tất cả điều kiện: Chèn vào LICH_HEN_PT với TrangThai = N'Đã đặt', COMMIT
--    - Nếu không thỏa: ROLLBACK TRANSACTION và RAISERROR thông báo cụ thể

-- [TV2 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV2:
-- - Test 1: Đặt 1 lịch hẹn PT hợp lệ và đo thời gian.
-- - Test 2: Mô phỏng Overbooking (2 session đồng thời đặt cùng 1 HLV, cùng khung giờ).
--   Có thể dùng lệnh WAITFOR DELAY '00:00:05' trong transaction để kiểm chứng Session 2 bị chặn.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV2 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
