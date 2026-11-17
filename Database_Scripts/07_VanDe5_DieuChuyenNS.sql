USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 07_VanDe5_DieuChuyenNS.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 5    : Quy trình Điều chuyển nhân sự & Phân bổ hoa hồng PT chính xác
                 theo lịch sử công tác quá khứ
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Index 1 (Tối ưu tra cứu lịch sử điều chuyển và tính lương hoa hồng PT theo thời gian):
--    - Tên đề xuất: IX_LICH_SU_CONG_TAC_DieuChuyenNS
--    - Bảng: LICH_SU_CONG_TAC
--    - Cột khóa: (MaNV, NgayBatDau, NgayKetThuc)
--    - INCLUDE: (MaCN, ChucVu, LuongCoBan)
--
-- 2. Index 2 (Tối ưu tra cứu lịch sử sử dụng buổi tập PT):
--    - Tên đề xuất: IX_LICH_SU_SU_DUNG_PT_TraCuuBuoiTap
--    - Bảng: LICH_SU_SU_DUNG_PT
--    - Cột khóa: (MaDK, ThoiDiemXacNhan)
--    - INCLUDE: (SoBuoiSuDung, MaLich)

-- [TV2 VIẾT CODE TẠO INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Trigger 1 (trg_SauKhiSuDungPT trên bảng LICH_SU_SU_DUNG_PT - AFTER INSERT):
--    - Giải quyết RBTV65:
--      + Tự động trừ số buổi còn lại: DANG_KY_GOI.SoBuoiConLai = SoBuoiConLai - inserted.SoBuoiSuDung
--      + Kiểm tra nếu SoBuoiConLai < 0: Báo lỗi và ROLLBACK TRANSACTION
--      + Nếu SoBuoiConLai = 0: Có thể cập nhật TrangThai = N'Hết hạn'
--
-- 2. Trigger 2 (trg_DongBoCongTac trên bảng LICH_SU_CONG_TAC - AFTER INSERT, UPDATE):
--    - Giải quyết RBTV78:
--      + Khi một bản ghi công tác mới nhất được thêm hoặc cập nhật (NgayKetThuc IS NULL),
--        tự động đồng bộ các thuộc tính ChucVu, LuongCoBan sang bảng NHAN_VIEN để phục vụ tra cứu nhanh.

-- [TV2 VIẾT CODE TRIGGER TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV2:
-- 1. Cài đặt Kịch bản 5 (KB05) - Xác nhận hoàn thành buổi tập PT:
--    - Thủ tục sp_HoanThanhBuoiPT:
--      + Tham số: @MaLich, @SoBuoiSuDung, @GhiChu
--      + Kiểm tra danh sách ràng buộc động:
--        * RBTV76: Lịch hẹn MaLich phải tồn tại trong LICH_HEN_PT với TrangThai = N'Đã đặt'
--        * Cập nhật LICH_HEN_PT.TrangThai = N'Đã hoàn thành'
--        * RBTV77: Thêm bản ghi vào LICH_SU_SU_DUNG_PT với ThoiDiemXacNhan = GETDATE()
--          (đảm bảo ThoiDiemXacNhan >= ThoiGianBatDau)
--        * Trigger trg_SauKhiSuDungPT sẽ tự động trừ SoBuoiConLai trên DANG_KY_GOI (RBTV65)
--
-- 2. Cài đặt Kịch bản 6 (KB06) - Điều chuyển nhân sự & Tính hoa hồng:
--    - Thủ tục sp_DieuChuyenNhanSu:
--      + Tham số: @MaNV, @MaCNMoi, @ChucVuMoi, @LuongCoBanMoi, @NgayChuyen
--      + Kiểm tra danh sách ràng buộc động:
--        * RBTV79: @NgayChuyen >= NHAN_VIEN.NgayVaoLam và > NgayBatDau của đợt công tác hiện tại
--        * RBTV09: Các giai đoạn công tác của nhân viên không được chồng lấn
--        * RBTV10: Nhân viên chỉ có tối đa 1 giai đoạn công tác đang hiệu lực (NgayKetThuc IS NULL)
--        * RBTV11: Mỗi chi nhánh tại một thời điểm chỉ có tối đa 1 Quản lý chi nhánh (ChucVu = N'Quản lý chi nhánh')
--      + Thực hiện nghiệp vụ:
--        * Đóng đợt công tác hiện tại: Cập nhật NgayKetThuc = DATEADD(DAY, -1, @NgayChuyen)
--        * Mở đợt công tác mới: Chèn bản ghi mới vào LICH_SU_CONG_TAC (NgayBatDau = @NgayChuyen, NgayKetThuc = NULL)
--        * Trigger trg_DongBoCongTac tự động đồng bộ sang NHAN_VIEN (RBTV78)
--
--    - Thủ tục sp_TinhLuongHoaHongPT:
--      + Tham số: @Thang INT, @Nam INT, @MaCN VARCHAR(10) = NULL
--      + Nghiệp vụ giải quyết Vấn đề 5:
--        * Kết nối LICH_SU_SU_DUNG_PT JOIN LICH_HEN_PT JOIN LICH_SU_CONG_TAC
--        * Điều kiện khớp chi nhánh công tác lịch sử:
--          CAST(LICH_HEN_PT.ThoiGianBatDau AS DATE) BETWEEN LICH_SU_CONG_TAC.NgayBatDau
--          AND ISNULL(LICH_SU_CONG_TAC.NgayKetThuc, '9999-12-31')
--        * Thống kê chính xác số buổi dạy, tính hoa hồng theo đơn giá buổi tập và phân bổ
--          đúng về chi nhánh nơi HLV thực sự công tác tại thời điểm diễn ra buổi tập.

-- [TV2 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV2:
-- - Test KB05: Xác nhận hoàn thành buổi tập và kiểm tra số buổi trừ trên DANG_KY_GOI.
-- - Test KB06: Điều chuyển 1 nhân viên sang chi nhánh mới, sau đó chạy sp_TinhLuongHoaHongPT
--   để kiểm chứng hoa hồng được phân bổ chính xác theo từng chi nhánh trong tháng.
-- - Bật SET STATISTICS TIME, IO ON để đo hiệu năng truy vấn có và không có Index.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV2 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
