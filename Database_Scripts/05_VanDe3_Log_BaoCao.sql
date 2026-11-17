USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 05_VanDe3_Log_BaoCao.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 3    : Phân vùng bảng CHECK_IN (Partitioning) & Tối ưu Báo cáo lấp đầy
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV1:
-- 1. Partition Function & Partition Scheme cho bảng CHECK_IN:
--    - Partition Function: pf_CheckIn_TheoThang (DATETIME2) chia các mốc theo từng tháng/quý
--    - Partition Scheme: ps_CheckIn_TheoThang ánh xạ vào filegroup (ví dụ: ALL TO ([PRIMARY]))
--    - Chuyển đổi bảng CHECK_IN sang lưu trữ phân vùng: Tạo Clustered Index phân vùng trên cột ThoiGianVao
--      để SQL Server kích hoạt cơ chế Partition Elimination khi truy vấn báo cáo theo khoảng thời gian.
--
-- 2. Index 3 (Tối ưu báo cáo tỷ lệ lấp đầy theo chi nhánh và thời gian):
--    - Tên đề xuất: IX_CHECK_IN_BaoCaoLapDay
--    - Bảng: CHECK_IN
--    - Cột khóa: (MaCN, ThoiGianVao, KetQuaXacThuc)
--    - INCLUDE: (MaHV, ThoiGianRa)

-- [TV1 VIẾT CODE PARTITION VÀ INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV1:
-- - Lưu ý kiến trúc: Không sử dụng Trigger trên bảng CHECK_IN để bảo đảm tốc độ ghi
--   giờ cao điểm. Báo cáo tỷ lệ lấp đầy được tính toán trực tiếp thông qua truy vấn phân tích
--   đã được tối ưu bằng Partition Elimination và Covering Index.

-- [TV1 VIẾT CODE FUNCTION (NẾU CÓ) TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV1:
-- 1. Cài đặt Kịch bản 2 (KB02) - Thủ tục sp_TraCuuCheckInTrongNgay:
--    - Tham số: @MaCN VARCHAR(10), @Ngay DATE, @KhungGioTu TIME, @KhungGioDen TIME
--    - Nhiệm vụ: Truy xuất danh sách hội viên đã check-in thành công (KetQuaXacThuc = N'Hợp lệ')
--      kèm thông tin họ tên, hạng thành viên, thời gian vào và trạng thái đang tập (ThoiGianRa IS NULL)
--      hay đã ra về.
--
-- 2. Cài đặt Kịch bản 3 (KB03) - Thủ tục sp_ThongKeTyLeLapDay:
--    - Tham số: @MaCN VARCHAR(10) (hoặc NULL cho toàn hệ thống), @TuNgay DATE, @DenNgay DATE
--    - Nhiệm vụ: Thống kê số lượt tập hợp lệ phân bổ theo các khung giờ trong ngày
--      (Sáng 05h-11h, Trưa 11h-17h, Cao điểm 17h-20h, Tối 20h-22h) và tính tỷ lệ % lấp đầy
--      dựa trên sức chứa thiết kế giả định của chi nhánh.

-- [TV1 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV1:
-- - Chạy thử nghiệm sp_TraCuuCheckInTrongNgay (KB02).
-- - Chạy thử nghiệm sp_ThongKeTyLeLapDay (KB03).
-- - Bật SET STATISTICS TIME, IO ON và kiểm tra Execution Plan để chứng minh
--   truy vấn chỉ quét các partition cần thiết (Partition Elimination) thay vì quét toàn bộ bảng.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV1 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
