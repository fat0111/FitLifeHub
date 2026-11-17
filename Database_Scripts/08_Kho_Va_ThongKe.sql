USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 08_Kho_Va_ThongKe.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ      : Quản lý Nghiệp vụ Kho & Thống kê Hội viên, Chăm sóc Khách hàng
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV4:
-- 1. Index 1 (Tối ưu cảnh báo hàng dưới mức tồn tối thiểu):
--    - Tên đề xuất: IX_TON_KHO_CanhBaoMucTon
--    - Bảng: TON_KHO
--    - Cột khóa: (MaCN, SoLuongTon, MucTonToiThieu)
--    - INCLUDE: (MaSP, NgayCapNhat)
--
-- 2. Index 2 (Tối ưu truy xuất lịch sử xuất/nhập kho theo chi nhánh và thời gian):
--    - Tên đề xuất: IX_LICH_SU_KHO_TruyXuatLichSu
--    - Bảng: LICH_SU_KHO
--    - Cột khóa: (MaCN, MaSP, ThoiGian)
--    - INCLUDE: (LoaiGiaoDich, SoLuongThayDoi, MaNV, MaHD)
--
-- 3. Index 3 (Tối ưu lọc hội viên sắp hết hạn gói tập):
--    - Tên đề xuất: IX_DANG_KY_GOI_HoiVienSapHetHan
--    - Bảng: DANG_KY_GOI
--    - Cột khóa: (TrangThai, NgayKetThuc)
--    - INCLUDE: (MaHV, MaGoi, SoBuoiConLai)
--    - Điều kiện lọc: WHERE TrangThai = N'Đang hiệu lực'

-- [TV4 VIẾT CODE TẠO INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV4:
-- 1. Trigger trg_CapNhatTonKho trên bảng LICH_SU_KHO (AFTER INSERT):
--    - Gom 2 ràng buộc RBTV86 & RBTV87:
--      + RBTV86: Kiểm tra nếu TON_KHO.SoLuongTon + inserted.SoLuongThayDoi < 0
--        thì RAISERROR(N'Không đủ số lượng tồn kho tại chi nhánh.', 16, 1) và ROLLBACK TRANSACTION.
--      + RBTV87: Nếu hợp lệ, tự động cập nhật TON_KHO:
--        UPDATE TON_KHO
--        SET SoLuongTon = TON_KHO.SoLuongTon + inserted.SoLuongThayDoi,
--            NgayCapNhat = GETDATE()
--        FROM TON_KHO tk
--        JOIN inserted i ON tk.MaCN = i.MaCN AND tk.MaSP = i.MaSP;

-- [TV4 VIẾT CODE TRIGGER TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV4:
-- 1. Cài đặt Kịch bản 9 (KB09) - Nghiệp vụ Kho & Báo cáo Tồn kho:
--    - Thủ tục sp_GiaoDichKho:
--      + Tham số: @MaCN, @MaSP, @MaNV, @LoaiGiaoDich, @SoLuongThayDoi, @MaHD = NULL, @GhiChu = NULL
--      + Kiểm tra danh sách ràng buộc động:
--        * RBTV89: Nhân viên thực hiện giao dịch (MaNV) phải đang làm việc tại chi nhánh (MaCN) phát sinh giao dịch
--        * RBTV88: Nếu LoaiGiaoDich = N'Xuất' và có kèm MaHD, kiểm tra sản phẩm MaSP và số lượng xuất
--          phải khớp chính xác với dòng chi tiết trong CHI_TIET_HOA_DON của hóa đơn đó
--        * Chèn bản ghi vào LICH_SU_KHO để kích hoạt Trigger trg_CapNhatTonKho (RBTV86, RBTV87)
--
--    - Thủ tục sp_BaoCaoTonKho:
--      + Tham số: @MaCN VARCHAR(10) = NULL, @ChiBaoCaoDuoiDinhMuc BIT = 0
--      + Truy xuất danh sách sản phẩm tồn kho tại chi nhánh kèm cảnh báo (CanhBao = 1 nếu SoLuongTon <= MucTonToiThieu)
--
-- 2. Cài đặt Kịch bản 10 (KB10) - Thống kê Hội viên & Chăm sóc Khách hàng:
--    - Thủ tục sp_ThongKeHoiVienSapHetHan:
--      + Tham số: @SoNgayToi INT = 15, @SoNgayKhongTap INT = 30
--      + Truy vấn tìm danh sách hội viên:
--        * Có gói tập sẽ hết hạn trong vòng @SoNgayToi ngày tới
--        * Hoặc hội viên đang có gói hiệu lực nhưng không có lượt CHECK_IN nào trong vòng @SoNgayKhongTap ngày gần nhất
--
--    - Thủ tục sp_ThongKePhanBoHangHoiVien:
--      + Thống kê số lượng và tỷ lệ % hội viên ở từng hạng (Silver, Gold, Platinum) trên toàn hệ thống
--      + Đọc trực tiếp từ HOI_VIEN.MaHang với tốc độ cực nhanh

-- [TV4 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV4:
-- - Test KB09: Thực hiện giao dịch nhập kho, xuất kho và xem sp_BaoCaoTonKho.
-- - Test KB10: Chạy sp_ThongKeHoiVienSapHetHan và sp_ThongKePhanBoHangHoiVien.
-- - Bật SET STATISTICS TIME, IO ON để đo hiệu năng truy vấn có và không có Index trên tập dữ liệu lớn.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV4 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
