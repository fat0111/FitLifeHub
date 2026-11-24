USE FitLifeHub;
GO

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================

-- 1. Index 1 (Tối ưu cảnh báo hàng dưới mức tồn tối thiểu - KB09):
--    Hỗ trợ truy vấn lọc sản phẩm theo chi nhánh và so sánh SoLuongTon <= MucTonToiThieu
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TON_KHO_CanhBaoMucTon' AND object_id = OBJECT_ID('dbo.TON_KHO'))
    DROP INDEX IX_TON_KHO_CanhBaoMucTon ON dbo.TON_KHO;
GO

CREATE NONCLUSTERED INDEX IX_TON_KHO_CanhBaoMucTon
ON dbo.TON_KHO (MaCN, SoLuongTon, MucTonToiThieu)
INCLUDE (MaSP, NgayCapNhat);
GO

-- 2. Index 2 (Tối ưu truy xuất lịch sử xuất/nhập kho theo chi nhánh, sản phẩm và thời gian - KB09):
--    Composite Covering Index giúp bao phủ toàn bộ cột thông tin giao dịch kho mà không cần Key Lookup
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_LICH_SU_KHO_TruyXuatLichSu' AND object_id = OBJECT_ID('dbo.LICH_SU_KHO'))
    DROP INDEX IX_LICH_SU_KHO_TruyXuatLichSu ON dbo.LICH_SU_KHO;
GO

CREATE NONCLUSTERED INDEX IX_LICH_SU_KHO_TruyXuatLichSu
ON dbo.LICH_SU_KHO (MaCN, MaSP, ThoiGian DESC)
INCLUDE (LoaiGiaoDich, SoLuongThayDoi, MaNV, MaHD);
GO

-- 3. Index 3 (Tối ưu lọc hội viên đang có gói hiệu lực sắp hết hạn - KB10):
--    Filtered Covering Index chỉ đánh chỉ mục trên các gói N'Đang hiệu lực' để giảm kích thước B-Tree
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DANG_KY_GOI_HoiVienSapHetHan' AND object_id = OBJECT_ID('dbo.DANG_KY_GOI'))
    DROP INDEX IX_DANG_KY_GOI_HoiVienSapHetHan ON dbo.DANG_KY_GOI;
GO

CREATE NONCLUSTERED INDEX IX_DANG_KY_GOI_HoiVienSapHetHan
ON dbo.DANG_KY_GOI (TrangThai, NgayKetThuc)
INCLUDE (MaHV, MaGoi, SoBuoiConLai)
WHERE TrangThai = N'Đang hiệu lực';
GO


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================

-- 1. Trigger trg_CapNhatTonKho trên bảng LICH_SU_KHO (AFTER INSERT):
--    Gom 2 ràng buộc toàn vẹn RBTV86 & RBTV87 vào 1 Trigger duy nhất xử lý theo tập hợp (Set-based):
--    + RBTV86: Kiểm tra tồn kho không âm (TON_KHO.SoLuongTon + Tồn biến động < 0 -> ROLLBACK)
--    + RBTV87: Tự động đồng bộ dữ liệu dẫn xuất TON_KHO.SoLuongTon và NgayCapNhat = SYSDATETIME()
CREATE OR ALTER TRIGGER dbo.trg_CapNhatTonKho
ON dbo.LICH_SU_KHO
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    -- 1. Kiểm tra nếu chưa có dòng tồn kho khởi tạo tại chi nhánh cho sản phẩm tương ứng
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN dbo.TON_KHO tk WITH (UPDLOCK)
            ON tk.MaCN = i.MaCN AND tk.MaSP = i.MaSP
        WHERE tk.MaSP IS NULL
    )
    BEGIN
        RAISERROR(N'Lỗi RBTV86/RBTV87: Sản phẩm chưa được khởi tạo danh mục tồn kho tại chi nhánh này.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- 2. RBTV86: Kiểm tra nếu số lượng tồn sau khi cộng/trừ biến động bị âm (< 0)
    --    Gom nhóm theo (MaCN, MaSP) để đảm bảo an toàn cả khi INSERT nhiều dòng cùng lúc
    IF EXISTS (
        SELECT 1
        FROM dbo.TON_KHO tk WITH (UPDLOCK)
        INNER JOIN (
            SELECT MaCN, MaSP, SUM(SoLuongThayDoi) AS TongThayDoi
            FROM inserted
            GROUP BY MaCN, MaSP
        ) delta
            ON tk.MaCN = delta.MaCN AND tk.MaSP = delta.MaSP
        WHERE tk.SoLuongTon + delta.TongThayDoi < 0
    )
    BEGIN
        RAISERROR(N'Lỗi RBTV86: Không đủ số lượng tồn kho tại chi nhánh để thực hiện giao dịch xuất/điều chỉnh.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- 3. RBTV87: Tự động cập nhật số lượng tồn kho hiện tại và thời gian cập nhật
    UPDATE tk
    SET tk.SoLuongTon  = tk.SoLuongTon + delta.TongThayDoi,
        tk.NgayCapNhat = SYSDATETIME()
    FROM dbo.TON_KHO tk
    INNER JOIN (
        SELECT MaCN, MaSP, SUM(SoLuongThayDoi) AS TongThayDoi
        FROM inserted
        GROUP BY MaCN, MaSP
    ) delta
        ON tk.MaCN = delta.MaCN AND tk.MaSP = delta.MaSP;
END;
GO


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. KỊCH BẢN 9 (KB09) - NGHIỆP VỤ KHO & BÁO CÁO TỒN KHO
-- ----------------------------------------------------------------------------

-- 1.1. Thủ tục sp_GiaoDichKho:
--      Thực hiện giao dịch Nhập / Xuất / Điều chỉnh kho, kiểm tra RBTV88 & RBTV89,
--      và chèn vào LICH_SU_KHO để kích hoạt Trigger trg_CapNhatTonKho (RBTV86, RBTV87).
CREATE OR ALTER PROCEDURE dbo.sp_GiaoDichKho
    @MaCN            VARCHAR(10),
    @MaSP            VARCHAR(10),
    @MaNV            BIGINT,
    @LoaiGiaoDich    NVARCHAR(20),
    @SoLuongThayDoi  INT,
    @MaHD            BIGINT       = NULL,
    @GhiChu          NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ThoiDiemGD DATETIME2 = SYSDATETIME();
    DECLARE @NgayGD     DATE      = CAST(@ThoiDiemGD AS DATE);

    BEGIN TRY
        -- Kiểm tra miền giá trị loại giao dịch và dấu số lượng thay đổi (RBTV39, RBTV56, RBTV57)
        IF @LoaiGiaoDich NOT IN (N'Nhập', N'Xuất', N'Điều chỉnh')
        BEGIN
            RAISERROR(N'Lỗi RBTV39: Loại giao dịch kho chỉ nhận giá trị ''Nhập'', ''Xuất'' hoặc ''Điều chỉnh''.', 16, 1);
            RETURN;
        END;

        IF (@LoaiGiaoDich = N'Nhập' AND @SoLuongThayDoi <= 0)
            OR (@LoaiGiaoDich = N'Xuất' AND @SoLuongThayDoi >= 0)
            OR (@LoaiGiaoDich = N'Điều chỉnh' AND @SoLuongThayDoi = 0)
        BEGIN
            RAISERROR(N'Lỗi RBTV56: Dấu của SoLuongThayDoi không khớp với LoaiGiaoDich (Nhập > 0, Xuất < 0, Điều chỉnh <> 0).', 16, 1);
            RETURN;
        END;

        IF @LoaiGiaoDich IN (N'Nhập', N'Điều chỉnh') AND @MaHD IS NOT NULL
        BEGIN
            RAISERROR(N'Lỗi RBTV57: Giao dịch Nhập hoặc Điều chỉnh kho không được gắn với Mã hóa đơn (MaHD phải là NULL).', 16, 1);
            RETURN;
        END;

        -- Kiểm tra sản phẩm tồn tại và đang kinh doanh (đối với Nhập/Xuất bán hàng)
        IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaSP = @MaSP)
        BEGIN
            RAISERROR(N'Lỗi: Mã sản phẩm không tồn tại trong hệ thống.', 16, 1);
            RETURN;
        END;

        -- RBTV89 (Thẩm quyền nhân viên kho):
        -- Nhân viên thực hiện giao dịch (@MaNV) phải đang làm việc tại chính chi nhánh @MaCN phát sinh giao dịch
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.NHAN_VIEN nv
            INNER JOIN dbo.LICH_SU_CONG_TAC lsct
                ON nv.MaNV = lsct.MaNV
            WHERE nv.MaNV        = @MaNV
              AND nv.TrangThai   = N'Đang làm'
              AND nv.MaCNHienTai = @MaCN
              AND lsct.MaCN      = @MaCN
              AND lsct.NgayBatDau <= @NgayGD
              AND (lsct.NgayKetThuc IS NULL OR lsct.NgayKetThuc >= @NgayGD)
        )
        BEGIN
            RAISERROR(N'Lỗi RBTV89: Nhân viên thực hiện giao dịch kho không làm việc tại chi nhánh phát sinh giao dịch ở thời điểm hiện tại.', 16, 1);
            RETURN;
        END;

        -- RBTV88 (Đối chiếu xuất kho bán hàng):
        -- Khi LoaiGiaoDich = N'Xuất' và có đính kèm @MaHD, sản phẩm @MaSP, chi nhánh @MaCN
        -- và số lượng xuất ABS(@SoLuongThayDoi) phải khớp chính xác với dòng chi tiết trong CHI_TIET_HOA_DON của hóa đơn đã thanh toán đó.
        IF @LoaiGiaoDich = N'Xuất' AND @MaHD IS NOT NULL
        BEGIN
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.HOA_DON hd
                INNER JOIN dbo.CHI_TIET_HOA_DON cthd
                    ON hd.MaHD = cthd.MaHD
                WHERE hd.MaHD        = @MaHD
                  AND hd.MaCN        = @MaCN
                  AND hd.TrangThai   = N'Đã thanh toán'
                  AND cthd.MaSP      = @MaSP
                  AND cthd.SoLuong   = ABS(@SoLuongThayDoi)
            )
            BEGIN
                RAISERROR(N'Lỗi RBTV88: Giao dịch xuất kho theo hóa đơn không khớp với chi nhánh, trạng thái thanh toán, mã sản phẩm hoặc số lượng trên CHI_TIET_HOA_DON.', 16, 1);
                RETURN;
            END;

            -- Chống xuất kho trùng lặp nhiều lần cho cùng 1 sản phẩm trên cùng 1 hóa đơn
            IF EXISTS (
                SELECT 1
                FROM dbo.LICH_SU_KHO
                WHERE MaHD         = @MaHD
                  AND MaSP         = @MaSP
                  AND LoaiGiaoDich = N'Xuất'
            )
            BEGIN
                RAISERROR(N'Lỗi RBTV88: Sản phẩm trong hóa đơn này đã được xuất kho trước đó.', 16, 1);
                RETURN;
            END;
        END;

        BEGIN TRANSACTION;

        -- Chèn giao dịch vào LICH_SU_KHO (kích hoạt Trigger trg_CapNhatTonKho kiểm tra RBTV86 và cập nhật RBTV87)
        INSERT INTO dbo.LICH_SU_KHO (
            LoaiGiaoDich,
            SoLuongThayDoi,
            ThoiGian,
            GhiChu,
            MaCN,
            MaSP,
            MaNV,
            MaHD
        )
        VALUES (
            @LoaiGiaoDich,
            @SoLuongThayDoi,
            @ThoiDiemGD,
            @GhiChu,
            @MaCN,
            @MaSP,
            @MaNV,
            @MaHD
        );

        DECLARE @MaGDKhoMoi BIGINT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        -- Trả về thông tin giao dịch vừa thực hiện và số lượng tồn kho mới nhất sau khi Trigger cập nhật
        SELECT
            lsk.MaGiaoDichKho,
            lsk.MaCN,
            cn.TenCN,
            lsk.MaSP,
            sp.TenSP,
            lsk.LoaiGiaoDich,
            lsk.SoLuongThayDoi,
            tk.SoLuongTon      AS SoLuongTonMoi,
            tk.MucTonToiThieu,
            lsk.MaNV,
            lsk.MaHD,
            lsk.ThoiGian,
            lsk.GhiChu
        FROM dbo.LICH_SU_KHO lsk
        INNER JOIN dbo.TON_KHO tk   ON lsk.MaCN = tk.MaCN AND lsk.MaSP = tk.MaSP
        INNER JOIN dbo.CHI_NHANH cn ON lsk.MaCN = cn.MaCN
        INNER JOIN dbo.SAN_PHAM sp  ON lsk.MaSP = sp.MaSP
        WHERE lsk.MaGiaoDichKho = @MaGDKhoMoi;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrMsg  NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev  INT            = ERROR_SEVERITY();
        DECLARE @ErrStat INT            = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrStat);
    END CATCH;
END;
GO

-- 1.2. Thủ tục sp_BaoCaoTonKho:
--      Liệt kê tồn kho hiện tại theo chi nhánh, đánh dấu cảnh báo các sản phẩm có SoLuongTon <= MucTonToiThieu
CREATE OR ALTER PROCEDURE dbo.sp_BaoCaoTonKho
    @MaCN                  VARCHAR(10) = NULL,
    @ChiBaoCaoDuoiDinhMuc  BIT         = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tk.MaCN,
        cn.TenCN,
        tk.MaSP,
        sp.TenSP,
        sp.LoaiSP,
        sp.DonViTinh,
        sp.GiaBan,
        tk.SoLuongTon,
        tk.MucTonToiThieu,
        (tk.SoLuongTon - tk.MucTonToiThieu) AS ChenhLechDinhMuc,
        CASE
            WHEN tk.SoLuongTon <= tk.MucTonToiThieu THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS CanhBao,
        CASE
            WHEN tk.SoLuongTon = 0                  THEN N'Hết hàng'
            WHEN tk.SoLuongTon <= tk.MucTonToiThieu THEN N'Cảnh báo: Dưới/Bằng định mức'
            ELSE                                         N'An toàn'
        END AS TrangThaiTonKho,
        tk.NgayCapNhat
    FROM dbo.TON_KHO tk
    INNER JOIN dbo.CHI_NHANH cn ON tk.MaCN = cn.MaCN
    INNER JOIN dbo.SAN_PHAM sp  ON tk.MaSP = sp.MaSP
    WHERE (@MaCN IS NULL OR tk.MaCN = @MaCN)
      AND (@ChiBaoCaoDuoiDinhMuc = 0 OR tk.SoLuongTon <= tk.MucTonToiThieu)
    ORDER BY
        CASE WHEN tk.SoLuongTon <= tk.MucTonToiThieu THEN 0 ELSE 1 END ASC,
        tk.SoLuongTon ASC,
        tk.MaCN ASC,
        tk.MaSP ASC;
END;
GO


-- ----------------------------------------------------------------------------
-- 2. KỊCH BẢN 10 (KB10) - THỐNG KÊ HỘI VIÊN & CHĂM SÓC KHÁCH HÀNG
-- ----------------------------------------------------------------------------

-- 2.1. Thủ tục sp_ThongKeHoiVienSapHetHan:
--      Tìm danh sách hội viên:
--      * Có gói tập sẽ hết hạn trong vòng @SoNgayToi ngày tới
--      * Hoặc hội viên đang có gói hiệu lực nhưng không có lượt CHECK_IN nào trong vòng @SoNgayKhongTap ngày gần nhất
CREATE OR ALTER PROCEDURE dbo.sp_ThongKeHoiVienSapHetHan
    @SoNgayToi       INT = 15,
    @SoNgayKhongTap  INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HomNay          DATE      = CAST(SYSDATETIME() AS DATE);
    DECLARE @MocHetHan       DATE      = DATEADD(DAY, @SoNgayToi, @HomNay);
    DECLARE @MocKhongCheckIn DATETIME2 = DATEADD(DAY, -@SoNgayKhongTap, SYSDATETIME());

    ;WITH GoiDangHieuLuc AS (
        -- Lọc các gói đang hiệu lực và còn hạn thông qua Filtered Index IX_DANG_KY_GOI_HoiVienSapHetHan
        SELECT
            dk.MaDK,
            dk.MaHV,
            dk.MaGoi,
            dk.NgayBatDau,
            dk.NgayKetThuc,
            dk.SoBuoiConLai,
            DATEDIFF(DAY, @HomNay, dk.NgayKetThuc) AS SoNgayConLai
        FROM dbo.DANG_KY_GOI dk
        WHERE dk.TrangThai = N'Đang hiệu lực'
          AND dk.NgayKetThuc >= @HomNay
    ),
    CheckInGanNhat AS (
        -- Lấy thời điểm check-in hợp lệ gần nhất của từng hội viên
        SELECT
            ci.MaHV,
            MAX(ci.ThoiGianVao) AS LanCheckInCuoi
        FROM dbo.CHECK_IN ci
        WHERE ci.KetQuaXacThuc = N'Hợp lệ'
        GROUP BY ci.MaHV
    )
    SELECT
        hv.MaHV,
        hv.HoTen,
        hv.SoDienThoai,
        hv.Email,
        hv.MaHang,
        g.MaDK,
        g.MaGoi,
        gdv.TenGoi,
        gdv.LoaiGoi,
        g.NgayBatDau,
        g.NgayKetThuc,
        g.SoNgayConLai,
        g.SoBuoiConLai,
        ci.LanCheckInCuoi,
        CASE
            WHEN ci.LanCheckInCuoi IS NULL THEN NULL
            ELSE DATEDIFF(DAY, CAST(ci.LanCheckInCuoi AS DATE), @HomNay)
        END AS SoNgayKhongDiTap,
        CASE
            WHEN g.NgayKetThuc <= @MocHetHan AND (ci.LanCheckInCuoi IS NULL OR ci.LanCheckInCuoi < @MocKhongCheckIn)
                THEN N'Sắp hết hạn (' + CAST(g.SoNgayConLai AS NVARCHAR(10)) + N' ngày) & Không tập > ' + CAST(@SoNgayKhongTap AS NVARCHAR(10)) + N' ngày'
            WHEN g.NgayKetThuc <= @MocHetHan
                THEN N'Sắp hết hạn gói tập (còn ' + CAST(g.SoNgayConLai AS NVARCHAR(10)) + N' ngày)'
            ELSE
                N'Có gói đang hiệu lực nhưng không check-in > ' + CAST(@SoNgayKhongTap AS NVARCHAR(10)) + N' ngày'
        END AS LyDoCanCSKH
    FROM GoiDangHieuLuc g
    INNER JOIN dbo.HOI_VIEN hv      ON g.MaHV  = hv.MaHV
    INNER JOIN dbo.GOI_DICH_VU gdv  ON g.MaGoi = gdv.MaGoi
    LEFT JOIN  CheckInGanNhat ci    ON g.MaHV  = ci.MaHV
    WHERE hv.TrangThai = N'Hoạt động'
      AND (
            g.NgayKetThuc <= @MocHetHan
            OR ci.LanCheckInCuoi IS NULL
            OR ci.LanCheckInCuoi < @MocKhongCheckIn
          )
    ORDER BY
        CASE WHEN g.NgayKetThuc <= @MocHetHan THEN 0 ELSE 1 END ASC,
        g.SoNgayConLai ASC,
        hv.MaHang DESC,
        hv.MaHV ASC;
END;
GO

-- 2.2. Thủ tục sp_ThongKePhanBoHangHoiVien:
--      Thống kê số lượng, tỷ lệ phần trăm hội viên, điểm tích lũy trung bình và tổng doanh thu năm
--      ở từng hạng (Silver, Gold, Platinum) trên toàn hệ thống (đọc trực tiếp trên HOI_VIEN.MaHang).
CREATE OR ALTER PROCEDURE dbo.sp_ThongKePhanBoHangHoiVien
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH ThongKeTheoHang AS (
        -- Gom nhóm trực tiếp trên HOI_VIEN trước khi JOIN với HANG_HOI_VIEN để loại bỏ hoàn toàn Worktable spool (0 Worktable logical reads)
        SELECT
            hv.MaHang,
            COUNT(*) AS SoLuongHoiVien,
            SUM(CASE WHEN hv.TrangThai = N'Hoạt động' THEN 1 ELSE 0 END) AS SoHoiVienDangHoatDong,
            AVG(CAST(hv.DiemTichLuy AS DECIMAL(18, 2))) AS DiemTichLuyTrungBinh,
            SUM(hv.TongChiTieuNam) AS TongChiTieuNamCuaHang
        FROM dbo.HOI_VIEN hv
        GROUP BY hv.MaHang
    ),
    TongToanHeThong AS (
        SELECT ISNULL(SUM(SoLuongHoiVien), 0) AS TongSoHoiVien
        FROM ThongKeTheoHang
    )
    SELECT
        hhv.MaHang,
        hhv.TenHang,
        hhv.ChiTieuToiThieu,
        ISNULL(tk.SoLuongHoiVien, 0) AS SoLuongHoiVien,
        ISNULL(tk.SoHoiVienDangHoatDong, 0) AS SoHoiVienDangHoatDong,
        CAST(
            CASE
                WHEN t.TongSoHoiVien = 0 THEN 0
                ELSE (ISNULL(tk.SoLuongHoiVien, 0) * 100.0) / t.TongSoHoiVien
            END
            AS DECIMAL(5, 2)
        ) AS TyLePhanTram,
        ISNULL(CAST(tk.DiemTichLuyTrungBinh AS DECIMAL(18, 2)), 0) AS DiemTichLuyTrungBinh,
        ISNULL(tk.TongChiTieuNamCuaHang, 0) AS TongChiTieuNamCuaHang,
        hhv.MoTa
    FROM dbo.HANG_HOI_VIEN hhv
    LEFT JOIN ThongKeTheoHang tk
        ON hhv.MaHang = tk.MaHang
    CROSS JOIN TongToanHeThong t
    ORDER BY
        hhv.ChiTieuToiThieu ASC;
END;
GO


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- 1. Kiểm thử KB09 - Báo cáo tồn kho & Cảnh báo sản phẩm dưới mức tồn tối thiểu:
PRINT N'--- [TEST 1] Báo cáo các sản phẩm dưới mức tồn tối thiểu tại CN001 ---';
EXEC dbo.sp_BaoCaoTonKho @MaCN = 'CN001', @ChiBaoCaoDuoiDinhMuc = 1;
GO

-- 2. Kiểm thử KB09 - Giao dịch Nhập kho hợp lệ (MaNV = 181 là Nhân viên bán hàng tại CN001):
PRINT N'--- [TEST 2] Giao dịch Nhập kho bổ sung 20 sản phẩm SP005 tại CN001 ---';
EXEC dbo.sp_GiaoDichKho
    @MaCN           = 'CN001',
    @MaSP           = 'SP005',
    @MaNV           = 181,
    @LoaiGiaoDich   = N'Nhập',
    @SoLuongThayDoi = 20,
    @MaHD           = NULL,
    @GhiChu         = N'Nhập bổ sung hàng dưới định mức tại CN001';
GO

-- 3. Kiểm thử RBTV86 - Chặn xuất/điều chỉnh vượt quá số lượng tồn kho (Gây tồn kho âm -> ROLLBACK):
PRINT N'--- [TEST 3] Kiểm thử RBTV86: Cố tình điều chỉnh giảm vượt tồn kho hiện tại ---';
BEGIN TRY
    EXEC dbo.sp_GiaoDichKho
        @MaCN           = 'CN001',
        @MaSP           = 'SP005',
        @MaNV           = 181,
        @LoaiGiaoDich   = N'Điều chỉnh',
        @SoLuongThayDoi = -999999,
        @MaHD           = NULL,
        @GhiChu         = N'Test chặn tồn kho âm RBTV86';
END TRY
BEGIN CATCH
    PRINT N'-> [PASS RBTV86] Đã chặn thành công giao dịch làm âm kho: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 4. Kiểm thử RBTV89 - Chặn nhân viên chi nhánh khác thực hiện giao dịch kho tại CN001:
PRINT N'--- [TEST 4] Kiểm thử RBTV89: Nhân viên CN002 (MaNV = 182) thao tác kho tại CN001 ---';
BEGIN TRY
    EXEC dbo.sp_GiaoDichKho
        @MaCN           = 'CN001',
        @MaSP           = 'SP001',
        @MaNV           = 182,
        @LoaiGiaoDich   = N'Nhập',
        @SoLuongThayDoi = 10,
        @MaHD           = NULL,
        @GhiChu         = N'Test chặn sai thẩm quyền chi nhánh RBTV89';
END TRY
BEGIN CATCH
    PRINT N'-> [PASS RBTV89] Đã chặn thành công nhân viên sai chi nhánh: ' + ERROR_MESSAGE();
END CATCH;
GO

-- 5. Kiểm thử KB10 - Thống kê phân bổ hạng hội viên (Silver / Gold / Platinum):
PRINT N'--- [TEST 5] Thống kê tỷ lệ phân bổ hạng hội viên toàn hệ thống ---';
EXEC dbo.sp_ThongKePhanBoHangHoiVien;
GO

-- 6. Kiểm thử KB10 - Thống kê hội viên sắp hết hạn gói tập trong 15 ngày tới (Sử dụng Filtered Index):
PRINT N'--- [TEST 6] Danh sách hội viên sắp hết hạn gói tập trong 15 ngày tới ---';
EXEC dbo.sp_ThongKeHoiVienSapHetHan @SoNgayToi = 15, @SoNgayKhongTap = 30;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
