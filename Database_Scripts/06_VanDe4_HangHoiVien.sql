USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 06_VanDe4_HangHoiVien.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 4    : Tối ưu hóa Tích điểm Loyalty và Xét hạng Hội viên O(1)
                 bằng cơ chế Denormalization và Trigger thời gian thực
   VẤN ĐỀ 3    : (Nhánh Doanh thu) Phân vùng bảng HOA_DON theo thời gian
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Gợi ý cho TV3:
-- 1. Partition Function & Partition Scheme cho bảng HOA_DON:
--    - Partition Function: pf_HoaDon_TheoQuy (DATETIME2) chia các mốc theo từng quý (hoặc năm)
--    - Partition Scheme: ps_HoaDon_TheoQuy ánh xạ vào filegroup (ví dụ: ALL TO ([PRIMARY]))
--    - Chuyển đổi bảng HOA_DON sang lưu trữ phân vùng: Tạo Clustered Index phân vùng trên cột NgayLap
--      để SQL Server kích hoạt cơ chế Partition Elimination khi chạy báo cáo doanh thu theo quý/năm.
--
-- 2. Index 1 (Tối ưu truy vấn báo cáo doanh thu theo chi nhánh & thời gian):
--    - Tên đề xuất: IX_HOA_DON_BaoCaoDoanhThu
--    - Bảng: HOA_DON
--    - Cột khóa: (MaCN, NgayLap)
--    - INCLUDE: (ThanhTien, GiamGia)
--    - Điều kiện lọc: WHERE TrangThai = N'Đã thanh toán'
--
-- 3. Index 2 (Tối ưu thống kê top gói dịch vụ/sản phẩm bán chạy):
--    - Tên đề xuất: IX_CHI_TIET_HOA_DON_TopBanChay
--    - Bảng: CHI_TIET_HOA_DON
--    - Cột khóa: (MaGoi, MaSP)
--    - INCLUDE: (MaHD, SoLuong, ThanhTien)
--
-- 4. Index 3 (Tối ưu kiểm tra tổng tiền đã thanh toán của hóa đơn):
--    - Tên đề xuất: IX_THANH_TOAN_KiemTraTongTien
--    - Bảng: THANH_TOAN
--    - Cột khóa: (MaHD, TrangThaiTT)
--    - INCLUDE: (SoTien)
--    - Điều kiện lọc: WHERE TrangThaiTT = N'Thành công'

-- [TV3 VIẾT CODE PARTITION VÀ INDEX TẠI ĐÂY]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================
-- Gợi ý cho TV3:
-- 1. Hàm fn_TinhDiemLoyalty:
--    - Tham số: @ThanhTien DECIMAL(18,2)
--    - Trả về: INT (Điểm tích lũy tính được, ví dụ: FLOOR(@ThanhTien / 100000))
--
-- 2. Trigger trg_CapNhatThanhToan_Va_Loyalty trên bảng THANH_TOAN (AFTER INSERT, UPDATE):
--    - Lưu ý kiến trúc: TUYỆT ĐỐI KHÔNG cài Trigger trên bảng CHI_TIET_HOA_DON để tránh Trigger
--      dây chuyền (Cascade Trigger). Gom toàn bộ 6 ràng buộc vào 1 Trigger duy nhất trên THANH_TOAN:
--      + Điều kiện kích hoạt: Khi giao dịch chuyển sang TrangThaiTT = N'Thành công' và tổng thanh
--        toán của hóa đơn đạt đủ >= HOA_DON.ThanhTien:
--        * RBTV81: Cập nhật HOA_DON.TrangThai = N'Đã thanh toán'
--        * RBTV64: Tự động kích hoạt các bản ghi DANG_KY_GOI tương ứng sang TrangThai = N'Đang hiệu lực'
--        * RBTV90: Gọi fn_TinhDiemLoyalty và chèn bản ghi vào LICH_SU_DIEM (LoaiGiaoDich = N'Cộng')
--        * RBTV92: Đảm bảo mỗi hóa đơn chỉ được cộng điểm đúng một lần
--        * RBTV93, RBTV94: Cộng trực tiếp HOI_VIEN.DiemTichLuy và TongChiTieuNam với chi phí O(1)
--        * RBTV95: Tự động xét thăng hạng hội viên (Silver -> Gold -> Platinum) dựa trên TongChiTieuNam
--                  và ngưỡng chi tiêu từ HANG_HOI_VIEN. Nếu thăng hạng, ghi bản ghi vào LICH_SU_HANG.

-- [TV3 VIẾT CODE FUNCTION VÀ TRIGGER TẠI ĐÂY]


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================
-- Gợi ý cho TV3:
-- 1. Cài đặt Kịch bản 7 (KB07) - Nghiệp vụ Hóa đơn & Thanh toán:
--    - Thủ tục sp_TaoHoaDon:
--      + Tham số: @MaCN, @MaNV, @MaHV, ...
--      + Kiểm tra danh sách ràng buộc động:
--        * RBTV85: Nhân viên lập hóa đơn (MaNV) phải đang làm việc tại chi nhánh (MaCN) lập hóa đơn
--        * RBTV83: Gói dịch vụ hoặc Sản phẩm đưa vào hóa đơn phải có TrangThai = N'Đang kinh doanh'
--        * RBTV84: Không cho phép thêm/sửa/xóa chi tiết khi HOA_DON có TrangThai là N'Đã thanh toán' hoặc N'Đã hủy'
--        * RBTV80, RBTV82: Tự động lấy đúng DonGia hiện hành từ GOI_DICH_VU.GiaTien hoặc SAN_PHAM.GiaBan,
--          đồng thời tính TongTien và ThanhTien cho HOA_DON
--        * RBTV60 - RBTV63: Nếu có mua gói dịch vụ, tự động sinh bản ghi DANG_KY_GOI (TrangThai ban đầu N'Tạm dừng'
--          hoặc chờ kích hoạt), tính NgayKetThuc = DATEADD(MONTH, ThoiHanThang, NgayBatDau), gán SoBuoiConLai = SoBuoiPT
--
--    - Thủ tục sp_ThanhToanHoaDon:
--      + Tham số: @MaHD, @HinhThucTT, @SoTien, @MaGiaoDichNgoai
--      + Thêm bản ghi vào THANH_TOAN với TrangThaiTT = N'Thành công' để kích hoạt Trigger tổng hợp
--
--    - Thủ tục sp_DoiDiemThuong:
--      + Tham số: @MaHV, @SoDiemDoi, @GhiChu
--      + Kiểm tra RBTV13, RBTV91: @SoDiemDoi > 0 và @SoDiemDoi <= HOI_VIEN.DiemTichLuy
--      + Trừ DiemTichLuy trên HOI_VIEN và ghi nhận LICH_SU_DIEM (LoaiGiaoDich = N'Trừ')
--
-- 2. Cài đặt Kịch bản 8 (KB08) - Báo cáo Doanh thu & Dịch vụ:
--    - Thủ tục sp_BaoCaoDoanhThu:
--      + Tham số: @MaCN (hoặc NULL cho toàn hệ thống), @TuNgay DATE, @DenNgay DATE, @TheoLoai VARCHAR(10)
--      + Tổng hợp TongTien, GiamGia, DoanhThuThucTe theo Ngày/Tháng/Quý/Năm
--
--    - Thủ tục sp_TopGoiDichVuBanChay:
--      + Tham số: @MaCN (hoặc NULL cho toàn hệ thống), @TopN INT, @SoThang INT
--      + Thống kê các gói dịch vụ/sản phẩm có doanh thu và lượt mua cao nhất trong khoảng thời gian

-- [TV3 VIẾT CODE STORED PROCEDURE TẠI ĐÂY]


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Gợi ý cho TV3:
-- - Test KB07: Lập hóa đơn mới, thanh toán và kiểm tra điểm tích lũy, hạng hội viên cập nhật O(1).
-- - Test KB08: Bật SET STATISTICS TIME, IO ON để đo Logical Reads, CPU Time của sp_BaoCaoDoanhThu
--   và sp_TopGoiDichVuBanChay trên tập dữ liệu lớn HOA_DON, chứng minh hiệu quả của Partition & Covering Index.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- [TV3 VIẾT CÁC LỆNH EXEC TEST TẠI ĐÂY]

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
