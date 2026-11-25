USE FitLifeHub;
GO

/* ============================================================================
   FILE        : 06_VanDe4_HangHoiVien.sql
   DỰ ÁN       : FitLife Hub - Quản lý chuỗi phòng tập (CSC12002)
   VẤN ĐỀ 4    : Tối ưu hóa Tích điểm Loyalty và Xét hạng Hội viên O(1)
                 bằng cơ chế Denormalization và Trigger thời gian thực
   VẤN ĐỀ 3    : (Nhánh Doanh thu) Phân vùng bảng HOA_DON theo thời gian
   PHỤ TRÁCH   : Thành viên 3

   TIẾN ĐỘ THEO LÁT:
     [a] Function + sp_TaoHoaDon / sp_ThemChiTietHoaDon / sp_ThanhToanHoaDon /
         sp_DoiDiemThuong ............................ XONG (file này)
     [b] Trigger trg_CapNhatThanhToan_Va_Loyalty .... XONG
     [c] Partition + Index 1-3 ....................... CHƯA
     [d] KB08: sp_BaoCaoDoanhThu, sp_TopGoiDichVuBanChay ... CHƯA

   Chạy SAU 01_Create_Schema.sql. Có thể chạy lại nhiều lần (CREATE OR ALTER).

   Giỏ hàng (@GioHang) là chuỗi JSON dạng mảng, mỗi phần tử là một dòng:
     [ {"MaGoi":"G01","SoLuong":1}, {"MaSP":"SP01","SoLuong":3} ]
   Mỗi dòng có đúng một trong hai khóa MaGoi hoặc MaSP (khớp RBTV53).
============================================================================ */

-- ============================================================================
-- PHẦN 1: PARTITION & INDEX
-- ============================================================================
-- Partition Function/Scheme pf_HoaDon_TheoQuy, ps_HoaDon_TheoQuy, Clustered Index
-- phân vùng trên HOA_DON(NgayLap), IX_HOA_DON_BaoCaoDoanhThu,
-- IX_CHI_TIET_HOA_DON_TopBanChay, IX_THANH_TOAN_KiemTraTongTien
-- (kèm index hỗ trợ CHI_TIET_HOA_DON(MaHD) cho khóa ngoại).

-- [LÁT C - CHƯA VIẾT]


-- ============================================================================
-- PHẦN 2: FUNCTION & TRIGGER
-- ============================================================================

/* --- 2.1. FUNCTION fn_TinhDiemLoyalty ---------------------------------------
   Quy tắc: 1 điểm = 100.000 VNĐ  ->  FLOOR(ThanhTien / 100000)
   Dùng trong Trigger (lát b) và để hiển thị điểm dự kiến ở màn hình thu ngân. */
CREATE OR ALTER FUNCTION dbo.fn_TinhDiemLoyalty (@ThanhTien DECIMAL(18, 2))
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE
               WHEN ISNULL(@ThanhTien, 0) <= 0 THEN 0
               ELSE CAST(FLOOR(@ThanhTien / 100000) AS INT)
           END;
END;
GO

/* --- 2.2. TRIGGER trg_CapNhatThanhToan_Va_Loyalty (AFTER INSERT, UPDATE) ----
   Gom RBTV81, RBTV64, RBTV90, RBTV92-95 vào một Trigger duy nhất trên THANH_TOAN. */

/* Điều kiện kích hoạt: giao dịch có TrangThaiTT = N'Thành công' và tổng các
   giao dịch thành công của hóa đơn >= HOA_DON.ThanhTien.

   Thiết kế:
   - Set-based: xử lý đúng khi một câu INSERT/UPDATE chạm nhiều dòng/nhiều hóa đơn.
   - Idempotent: bước 1 chỉ chuyển các hóa đơn đang 'Chờ thanh toán'. Hóa đơn nào
     thực sự được chuyển sang 'Đã thanh toán' mới đi tiếp vào @Done, nên chạy lại
     Trigger (UPDATE thêm ghi chú, hai giao dịch chen nhau) không cộng điểm hai lần.
     Unique index RBTV06 là chốt chặn cuối.
   - Chi phí O(1) cho mỗi hóa đơn: chỉ cộng dồn lên dòng HOI_VIEN, không quét lại
     hóa đơn 12 tháng (giải quyết Vấn đề 4).
   - Cập nhật HOI_VIEN trước LICH_SU_HANG: khóa dòng hội viên giữ đến hết giao dịch
     nên hai thanh toán cùng hội viên không đụng nhau khi ghi LICH_SU_HANG. */
CREATE OR ALTER TRIGGER dbo.trg_CapNhatThanhToan_Va_Loyalty
ON dbo.THANH_TOAN
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Hóa đơn có giao dịch thành công trong lần ghi này
    DECLARE @MaHDs TABLE (MaHD BIGINT PRIMARY KEY);

    INSERT INTO @MaHDs (MaHD)
    SELECT DISTINCT MaHD
    FROM inserted
    WHERE TrangThaiTT = N'Thành công';

    IF NOT EXISTS (SELECT 1 FROM @MaHDs) RETURN;

    -- (1) RBTV81: chốt hóa đơn đã trả đủ. Chỉ các hóa đơn thực sự vừa chuyển trạng thái
    --     mới được ghi vào @Done.
    DECLARE @Done TABLE (
        MaHD      BIGINT         NOT NULL PRIMARY KEY,
        MaHV      BIGINT         NULL,
        ThanhTien DECIMAL(18, 2) NOT NULL,
        Diem      INT            NOT NULL DEFAULT 0
    );

    UPDATE h
    SET h.TrangThai = N'Đã thanh toán'
    OUTPUT inserted.MaHD, inserted.MaHV, inserted.ThanhTien INTO @Done (MaHD, MaHV, ThanhTien)
    FROM dbo.HOA_DON h
    JOIN @MaHDs x ON x.MaHD = h.MaHD
    WHERE h.TrangThai = N'Chờ thanh toán'
      AND h.ThanhTien > 0
      AND (SELECT SUM(t.SoTien)
           FROM dbo.THANH_TOAN t
           WHERE t.MaHD = h.MaHD AND t.TrangThaiTT = N'Thành công') >= h.ThanhTien;

    IF NOT EXISTS (SELECT 1 FROM @Done) RETURN;

    -- (2) RBTV64: kích hoạt gói đăng ký của hóa đơn, tính lại ngày theo ngày thanh toán
    DECLARE @Hom DATE = CAST(SYSDATETIME() AS DATE);

    UPDATE d
    SET d.TrangThai   = N'Đang hiệu lực',
        d.NgayBatDau  = @Hom,
        d.NgayKetThuc = ISNULL(DATEADD(MONTH, g.ThoiHanThang, @Hom),
                               DATEADD(DAY, DATEDIFF(DAY, d.NgayBatDau, d.NgayKetThuc), @Hom))
    FROM dbo.DANG_KY_GOI d
    JOIN @Done x ON x.MaHD = d.MaHD
    JOIN dbo.GOI_DICH_VU g ON g.MaGoi = d.MaGoi
    WHERE d.TrangThai = N'Tạm dừng';

    -- Từ đây chỉ còn hóa đơn gắn hội viên
    IF NOT EXISTS (SELECT 1 FROM @Done WHERE MaHV IS NOT NULL) RETURN;

    -- (3) RBTV90: ghi LICH_SU_DIEM (hóa đơn dưới 100.000 đ được 0 điểm nên không ghi,
    --     vì RBTV58 yêu cầu điểm cộng > 0)
    UPDATE @Done
    SET Diem = dbo.fn_TinhDiemLoyalty(ThanhTien)
    WHERE MaHV IS NOT NULL;

    INSERT INTO dbo.LICH_SU_DIEM (LoaiGiaoDich, SoDiem, GhiChu, MaHV, MaHD)
    SELECT N'Cộng', Diem, CONCAT(N'Tích điểm hóa đơn #', MaHD), MaHV, MaHD
    FROM @Done
    WHERE MaHV IS NOT NULL AND Diem > 0;

    -- (4) RBTV92 + RBTV93: cộng dồn DiemTichLuy và TongChiTieuNam trên HOI_VIEN.
    --     Gộp theo hội viên để một câu UPDATE xử lý được nhiều hóa đơn cùng hội viên.
    DECLARE @HV TABLE (MaHV BIGINT NOT NULL PRIMARY KEY, Diem INT NOT NULL, ChiTieu DECIMAL(18, 2) NOT NULL);

    INSERT INTO @HV (MaHV, Diem, ChiTieu)
    SELECT MaHV, SUM(Diem), SUM(ThanhTien)
    FROM @Done
    WHERE MaHV IS NOT NULL
    GROUP BY MaHV;

    UPDATE hv
    SET hv.DiemTichLuy   = hv.DiemTichLuy + m.Diem,
        hv.TongChiTieuNam = hv.TongChiTieuNam + m.ChiTieu
    FROM dbo.HOI_VIEN hv
    JOIN @HV m ON m.MaHV = hv.MaHV;

    -- (5) RBTV94: nâng hạng theo ngưỡng chi tiêu cao nhất đạt được (chỉ nâng, không hạ)
    UPDATE hv
    SET hv.MaHang = nh.MaHang
    FROM dbo.HOI_VIEN hv
    JOIN @HV m ON m.MaHV = hv.MaHV
    JOIN dbo.HANG_HOI_VIEN cur ON cur.MaHang = hv.MaHang
    CROSS APPLY (SELECT TOP (1) h.MaHang, h.ChiTieuToiThieu
                 FROM dbo.HANG_HOI_VIEN h
                 WHERE h.ChiTieuToiThieu <= hv.TongChiTieuNam
                 ORDER BY h.ChiTieuToiThieu DESC) nh
    WHERE nh.ChiTieuToiThieu > cur.ChiTieuToiThieu;

    -- (6) RBTV95: ghi nhận/cập nhật LICH_SU_HANG của năm hiện tại (mỗi hội viên một
    --     dòng mỗi năm theo RBTV04): cập nhật dòng có sẵn, thiếu thì thêm mới.
    DECLARE @Nam INT = YEAR(SYSDATETIME());

    UPDATE ls
    SET ls.TongChiTieu = hv.TongChiTieuNam,
        ls.MaHang      = hv.MaHang,
        ls.NgayCapNhat = SYSDATETIME()
    FROM dbo.LICH_SU_HANG ls
    JOIN dbo.HOI_VIEN hv ON hv.MaHV = ls.MaHV
    JOIN @HV m ON m.MaHV = hv.MaHV
    WHERE ls.NamXetHang = @Nam;

    INSERT INTO dbo.LICH_SU_HANG (NamXetHang, TongChiTieu, MaHV, MaHang)
    SELECT @Nam, hv.TongChiTieuNam, hv.MaHV, hv.MaHang
    FROM dbo.HOI_VIEN hv
    JOIN @HV m ON m.MaHV = hv.MaHV
    WHERE NOT EXISTS (SELECT 1 FROM dbo.LICH_SU_HANG ls
                      WHERE ls.MaHV = hv.MaHV AND ls.NamXetHang = @Nam);
END;
GO


-- ============================================================================
-- PHẦN 3: STORED PROCEDURE
-- ============================================================================

/* --- 3.1. sp_ThemChiTietHoaDon ----------------------------------------------
   Thêm các dòng (gói/sản phẩm) vào một hóa đơn ĐANG CHỜ THANH TOÁN.
   Cài đặt: RBTV80, RBTV82 (đơn giá hiện hành, cộng dồn tổng tiền),
            RBTV83 (chỉ bán hàng/gói 'Đang kinh doanh'),
            RBTV84 (khóa hóa đơn đã chốt),
            RBTV60-63 (mỗi dòng gói sinh một DANG_KY_GOI ở trạng thái chờ
            kích hoạt = N'Tạm dừng'; Trigger chuyển sang 'Đang hiệu lực' khi
            hóa đơn thanh toán đủ - RBTV64).
   Không dùng Trigger trên CHI_TIET_HOA_DON để tránh kích hoạt dây chuyền. */
CREATE OR ALTER PROCEDURE dbo.sp_ThemChiTietHoaDon
    @MaHD    BIGINT,
    @GioHang NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Kiểm tra định dạng giỏ hàng trước khi mở giao dịch
        IF ISNULL(ISJSON(@GioHang), 0) <> 1 OR LEFT(LTRIM(@GioHang), 1) <> N'['
           OR NOT EXISTS (SELECT 1 FROM OPENJSON(@GioHang))
        BEGIN
            THROW 50010, N'Giỏ hàng phải là mảng JSON hợp lệ và không được rỗng.', 1;
        END;

        DECLARE @Cart TABLE (MaGoi VARCHAR(10) NULL, MaSP VARCHAR(10) NULL, SoLuong INT NULL);

        INSERT INTO @Cart (MaGoi, MaSP, SoLuong)
        SELECT MaGoi, MaSP, SoLuong
        FROM OPENJSON(@GioHang)
             WITH (MaGoi   VARCHAR(10) '$.MaGoi',
                   MaSP    VARCHAR(10) '$.MaSP',
                   SoLuong INT         '$.SoLuong');

        BEGIN TRANSACTION;

        -- Khóa dòng hóa đơn để không bị thanh toán/hủy chen ngang (RBTV84)
        DECLARE @TrangThai NVARCHAR(20), @MaHV BIGINT;

        SELECT @TrangThai = TrangThai, @MaHV = MaHV
        FROM dbo.HOA_DON WITH (UPDLOCK, HOLDLOCK)
        WHERE MaHD = @MaHD;

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50020, N'Hóa đơn không tồn tại.', 1;
        END;

        IF @TrangThai <> N'Chờ thanh toán'
        BEGIN
            DECLARE @MsgKhoa NVARCHAR(200) =
                CONCAT(N'RBTV84: Hóa đơn đã ở trạng thái "', @TrangThai, N'", không được thêm chi tiết.');
            THROW 50021, @MsgKhoa, 1;
        END;

        -- Mỗi dòng: đúng một trong MaGoi/MaSP, số lượng > 0 (RBTV53, RBTV33)
        IF EXISTS (SELECT 1 FROM @Cart
                   WHERE SoLuong IS NULL OR SoLuong <= 0
                      OR (MaGoi IS NULL AND MaSP IS NULL)
                      OR (MaGoi IS NOT NULL AND MaSP IS NOT NULL))
        BEGIN
            THROW 50011, N'Mỗi dòng giỏ hàng phải có đúng một MaGoi hoặc MaSP và SoLuong > 0.', 1;
        END;

        -- Gói/sản phẩm phải tồn tại
        IF EXISTS (SELECT 1
                   FROM @Cart c
                   LEFT JOIN dbo.GOI_DICH_VU g ON g.MaGoi = c.MaGoi
                   LEFT JOIN dbo.SAN_PHAM    s ON s.MaSP  = c.MaSP
                   WHERE (c.MaGoi IS NOT NULL AND g.MaGoi IS NULL)
                      OR (c.MaSP  IS NOT NULL AND s.MaSP  IS NULL))
        BEGIN
            THROW 50012, N'Có gói dịch vụ hoặc sản phẩm trong giỏ hàng không tồn tại.', 1;
        END;

        -- RBTV83: chỉ bán mặt hàng đang kinh doanh
        IF EXISTS (SELECT 1
                   FROM @Cart c
                   LEFT JOIN dbo.GOI_DICH_VU g ON g.MaGoi = c.MaGoi
                   LEFT JOIN dbo.SAN_PHAM    s ON s.MaSP  = c.MaSP
                   WHERE g.TrangThai <> N'Đang kinh doanh'
                      OR s.TrangThai <> N'Đang kinh doanh')
        BEGIN
            THROW 50013, N'RBTV83: Có gói hoặc sản phẩm không ở trạng thái "Đang kinh doanh".', 1;
        END;

        -- Mỗi dòng gói = 1 đăng ký gói, nên số lượng gói phải bằng 1
        IF EXISTS (SELECT 1 FROM @Cart WHERE MaGoi IS NOT NULL AND SoLuong <> 1)
        BEGIN
            THROW 50014, N'Mỗi dòng gói dịch vụ chỉ được mua với SoLuong = 1.', 1;
        END;

        -- RBTV60: đăng ký gói cần biết hội viên
        IF @MaHV IS NULL AND EXISTS (SELECT 1 FROM @Cart WHERE MaGoi IS NOT NULL)
        BEGIN
            THROW 50015, N'RBTV60: Hóa đơn có mua gói dịch vụ bắt buộc phải gắn hội viên.', 1;
        END;

        -- RBTV61: gói phải có ThoiHanThang để tính NgayKetThuc; chưa có thì báo lỗi
        IF EXISTS (SELECT 1
                   FROM @Cart c
                   JOIN dbo.GOI_DICH_VU g ON g.MaGoi = c.MaGoi
                   WHERE g.ThoiHanThang IS NULL)
        BEGIN
            THROW 50016, N'RBTV61: Gói dịch vụ chưa có ThoiHanThang nên không tính được ngày kết thúc.', 1;
        END;

        -- RBTV82: lấy đơn giá hiện hành; RBTV54: ThanhTien = SoLuong * DonGia
        DECLARE @Them TABLE (ThanhTien DECIMAL(18, 2));

        INSERT INTO dbo.CHI_TIET_HOA_DON (SoLuong, DonGia, ThanhTien, MaHD, MaGoi, MaSP)
        OUTPUT INSERTED.ThanhTien INTO @Them (ThanhTien)
        SELECT c.SoLuong,
               COALESCE(g.GiaTien, s.GiaBan),
               c.SoLuong * COALESCE(g.GiaTien, s.GiaBan),
               @MaHD, c.MaGoi, c.MaSP
        FROM @Cart c
        LEFT JOIN dbo.GOI_DICH_VU g ON g.MaGoi = c.MaGoi
        LEFT JOIN dbo.SAN_PHAM    s ON s.MaSP  = c.MaSP;

        -- RBTV80: cộng dồn tổng tiền (không quét lại toàn bộ chi tiết)
        DECLARE @TienThem DECIMAL(18, 2) = (SELECT SUM(ThanhTien) FROM @Them);

        UPDATE dbo.HOA_DON
        SET TongTien  = TongTien + @TienThem,
            ThanhTien = TongTien + @TienThem - GiamGia
        WHERE MaHD = @MaHD;

        -- RBTV60-63: sinh đăng ký gói ở trạng thái chờ kích hoạt.
        -- Ngày ở đây chỉ là tạm tính từ hôm nay; Trigger sẽ tính lại theo ngày
        -- thanh toán khi chuyển sang 'Đang hiệu lực' (RBTV64).
        DECLARE @Hom DATE = CAST(SYSDATETIME() AS DATE);

        INSERT INTO dbo.DANG_KY_GOI (NgayBatDau, NgayKetThuc, SoBuoiConLai, TrangThai, MaHV, MaGoi, MaHD)
        SELECT @Hom,
               DATEADD(MONTH, g.ThoiHanThang, @Hom),
               g.SoBuoiPT,                          -- NULL với gói không phải PT
               N'Tạm dừng',
               @MaHV, c.MaGoi, @MaHD
        FROM @Cart c
        JOIN dbo.GOI_DICH_VU g ON g.MaGoi = c.MaGoi;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* --- 3.2. sp_TaoHoaDon -------------------------------------------------------
   Tạo hóa đơn mới + toàn bộ giỏ hàng trong một giao dịch.
   Cài đặt: RBTV85 (nhân viên đang làm tại đúng chi nhánh lập hóa đơn),
            RBTV80/82/83/84/60-63 (gọi sp_ThemChiTietHoaDon), RBTV52 (giảm giá). */
CREATE OR ALTER PROCEDURE dbo.sp_TaoHoaDon
    @MaCN    VARCHAR(10),
    @MaNV    BIGINT,
    @MaHV    BIGINT         = NULL,      -- NULL = khách vãng lai (chỉ mua sản phẩm)
    @GioHang NVARCHAR(MAX),
    @GiamGia DECIMAL(18, 2) = 0,
    @MaHD    BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @GiamGia < 0
        BEGIN
            THROW 50004, N'Giảm giá không được âm.', 1;
        END;

        BEGIN TRANSACTION;

        -- RBTV85: nhân viên phải đang làm việc tại chi nhánh lập hóa đơn
        IF NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN
                       WHERE MaNV = @MaNV AND MaCNHienTai = @MaCN AND TrangThai = N'Đang làm')
        BEGIN
            THROW 50001, N'RBTV85: Nhân viên không đang làm việc tại chi nhánh lập hóa đơn.', 1;
        END;

        IF @MaHV IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.HOI_VIEN WHERE MaHV = @MaHV AND TrangThai = N'Hoạt động')
        BEGIN
            THROW 50002, N'Hội viên không tồn tại hoặc không ở trạng thái "Hoạt động".', 1;
        END;

        -- Tạo hóa đơn rỗng (0 đồng hợp lệ với RBTV31/51/52), sau đó thêm chi tiết
        INSERT INTO dbo.HOA_DON (MaCN, MaNV, MaHV)
        VALUES (@MaCN, @MaNV, @MaHV);

        SET @MaHD = SCOPE_IDENTITY();

        EXEC dbo.sp_ThemChiTietHoaDon @MaHD = @MaHD, @GioHang = @GioHang;

        IF @GiamGia > 0
        BEGIN
            UPDATE dbo.HOA_DON
            SET GiamGia   = @GiamGia,
                ThanhTien = TongTien - @GiamGia
            WHERE MaHD = @MaHD
              AND @GiamGia <= TongTien;            -- RBTV52

            IF @@ROWCOUNT = 0
            BEGIN
                THROW 50003, N'RBTV52: Giảm giá không được vượt quá tổng tiền hóa đơn.', 1;
            END;
        END;

        COMMIT TRANSACTION;

        SELECT MaHD, NgayLap, TongTien, GiamGia, ThanhTien, TrangThai,
               DiemDuKien = dbo.fn_TinhDiemLoyalty(ThanhTien)
        FROM dbo.HOA_DON
        WHERE MaHD = @MaHD;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @MaHD = NULL;
        THROW;
    END CATCH;
END;
GO

/* --- 3.3. sp_ThanhToanHoaDon -------------------------------------------------
   Ghi nhận một giao dịch thanh toán (INSERT vào THANH_TOAN). Việc chốt hóa đơn,
   kích hoạt gói, cộng điểm, nâng hạng do Trigger (lát b) đảm nhiệm.

   @SoTien = NULL  -> thanh toán toàn bộ số tiền còn thiếu.
   @TrangThaiTT    -> mặc định 'Thành công' (tiền mặt tại quầy). Với VNPay/Thẻ có
                      thể truyền 'Đang xử lý' rồi UPDATE sang 'Thành công' sau;
                      Trigger xử lý cả INSERT lẫn UPDATE.
   RBTV55 (VNPay/Thẻ cần mã giao dịch ngoài) và RBTV05 (mã giao dịch ngoài duy
   nhất) đã có trong schema nên lỗi do CHECK/UNIQUE báo. */
CREATE OR ALTER PROCEDURE dbo.sp_ThanhToanHoaDon
    @MaHD            BIGINT,
    @HinhThucTT      NVARCHAR(30),
    @SoTien          DECIMAL(18, 2) = NULL,
    @MaGiaoDichNgoai VARCHAR(100)   = NULL,
    @TrangThaiTT     NVARCHAR(20)   = N'Thành công',
    @MaTT            BIGINT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @TrangThai NVARCHAR(20), @ThanhTien DECIMAL(18, 2);

        -- Khóa hóa đơn: hai quầy cùng thanh toán một hóa đơn sẽ được xếp hàng
        SELECT @TrangThai = TrangThai, @ThanhTien = ThanhTien
        FROM dbo.HOA_DON WITH (UPDLOCK, HOLDLOCK)
        WHERE MaHD = @MaHD;

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50030, N'Hóa đơn không tồn tại.', 1;
        END;

        IF @TrangThai <> N'Chờ thanh toán'
        BEGIN
            DECLARE @MsgDong NVARCHAR(200) =
                CONCAT(N'RBTV84: Hóa đơn đã ở trạng thái "', @TrangThai, N'", không thể thanh toán thêm.');
            THROW 50031, @MsgDong, 1;
        END;

        IF @ThanhTien <= 0
        BEGIN
            THROW 50032, N'Hóa đơn chưa có chi tiết hoặc có thành tiền bằng 0.', 1;
        END;

        DECLARE @DaTra DECIMAL(18, 2) =
            ISNULL((SELECT SUM(SoTien) FROM dbo.THANH_TOAN
                    WHERE MaHD = @MaHD AND TrangThaiTT = N'Thành công'), 0);
        DECLARE @ConThieu DECIMAL(18, 2) = @ThanhTien - @DaTra;

        SET @SoTien = ISNULL(@SoTien, @ConThieu);

        IF @SoTien <= 0 OR @SoTien > @ConThieu
        BEGIN
            DECLARE @MsgTien NVARCHAR(200) =
                CONCAT(N'Số tiền thanh toán phải lớn hơn 0 và không vượt số còn thiếu (', @ConThieu, N').');
            THROW 50033, @MsgTien, 1;
        END;

        INSERT INTO dbo.THANH_TOAN (SoTien, HinhThucTT, MaGiaoDichNgoai, TrangThaiTT, MaHD)
        VALUES (@SoTien, @HinhThucTT, @MaGiaoDichNgoai, @TrangThaiTT, @MaHD);

        SET @MaTT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        -- Kết quả sau khi Trigger chạy (nếu chưa có Trigger, hóa đơn vẫn 'Chờ thanh toán')
        SELECT h.MaHD,
               h.TrangThai,
               h.ThanhTien,
               DiemCong    = ISNULL((SELECT d.SoDiem FROM dbo.LICH_SU_DIEM d
                                     WHERE d.MaHD = h.MaHD AND d.LoaiGiaoDich = N'Cộng'), 0),
               hv.DiemTichLuy,
               hv.TongChiTieuNam,
               HangHienTai = hang.TenHang
        FROM dbo.HOA_DON h
        LEFT JOIN dbo.HOI_VIEN      hv   ON hv.MaHV    = h.MaHV
        LEFT JOIN dbo.HANG_HOI_VIEN hang ON hang.MaHang = hv.MaHang
        WHERE h.MaHD = @MaHD;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @MaTT = NULL;
        THROW;
    END CATCH;
END;
GO

/* --- 3.4. sp_DoiDiemThuong ---------------------------------------------------
   Hội viên tiêu điểm. @SoDiemDoi là số điểm DƯƠNG muốn đổi; LICH_SU_DIEM lưu
   số ÂM theo RBTV58.
   Cài đặt: RBTV13, RBTV91 (không trừ quá số dư). Dùng một câu UPDATE có điều
   kiện nên kiểm tra và trừ là một thao tác nguyên tử, không cần khóa thêm.
   Đổi điểm không làm thay đổi TongChiTieuNam hay hạng. */
CREATE OR ALTER PROCEDURE dbo.sp_DoiDiemThuong
    @MaHV      BIGINT,
    @SoDiemDoi INT,
    @GhiChu    NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @SoDiemDoi IS NULL OR @SoDiemDoi <= 0
        BEGIN
            THROW 50040, N'Số điểm đổi phải lớn hơn 0.', 1;
        END;

        BEGIN TRANSACTION;

        UPDATE dbo.HOI_VIEN
        SET DiemTichLuy = DiemTichLuy - @SoDiemDoi
        WHERE MaHV = @MaHV
          AND TrangThai = N'Hoạt động'
          AND DiemTichLuy >= @SoDiemDoi;           -- RBTV13, RBTV91

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 50041, N'RBTV91: Hội viên không tồn tại, không hoạt động hoặc không đủ điểm để đổi.', 1;
        END;

        INSERT INTO dbo.LICH_SU_DIEM (LoaiGiaoDich, SoDiem, GhiChu, MaHV, MaHD)
        VALUES (N'Trừ', -@SoDiemDoi, @GhiChu, @MaHV, NULL);

        COMMIT TRANSACTION;

        SELECT MaHV, DiemTichLuy FROM dbo.HOI_VIEN WHERE MaHV = @MaHV;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* --- 3.5. KỊCH BẢN 8 (KB08) --------------------------------------------------
   sp_BaoCaoDoanhThu     (@MaCN, @TuNgay DATE, @DenNgay DATE, @TheoLoai VARCHAR(10))
   sp_TopGoiDichVuBanChay (@MaCN, @TopN INT, @SoThang INT) */

-- [LÁT D - CHƯA VIẾT]
GO


-- ============================================================================
-- PHẦN 4: LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================
-- Test lát (a) và (b), toàn bộ nằm trong một giao dịch và ROLLBACK ở cuối,
-- không để lại dữ liệu.

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

BEGIN TRANSACTION;

DECLARE @nv BIGINT, @hv BIGINT, @hd BIGINT, @tt BIGINT;

INSERT INTO CHI_NHANH (MaCN, TenCN, DiaChi, SoDienThoai, GioMoCua, GioDongCua)
VALUES ('CN_TEST', N'Chi nhánh thử', N'1 Đường Thử', '0901234567', '06:00', '22:00');

INSERT INTO NHAN_VIEN (HoTen, SoDienThoai, ChucVu, LuongCoBan, NgayVaoLam, MaCNHienTai)
VALUES (N'Thu Ngân A', '0911111111', N'Lễ tân', 8000000, '2026-01-01', 'CN_TEST');
SET @nv = SCOPE_IDENTITY();

INSERT INTO HOI_VIEN (HoTen, SoDienThoai, CCCD, NgaySinh)
VALUES (N'Hội Viên A', '0922222222', '012345678901', '2000-01-01');
SET @hv = SCOPE_IDENTITY();

INSERT INTO GOI_DICH_VU (MaGoi, TenGoi, LoaiGoi, ThoiHanThang, GiaTien)
VALUES ('G_TEST', N'Gym 3 tháng', N'Gym', 3, 1500000);

INSERT INTO SAN_PHAM (MaSP, TenSP, LoaiSP, DonViTinh, GiaBan)
VALUES ('SP_TEST', N'Nước suối', N'Đồ uống', N'Chai', 10000);

-- Kỳ vọng: TongTien = 1.500.000 + 3 x 10.000 = 1.530.000; DiemDuKien = 15
EXEC dbo.sp_TaoHoaDon
     @MaCN = 'CN_TEST', @MaNV = @nv, @MaHV = @hv,
     @GioHang = N'[{"MaGoi":"G_TEST","SoLuong":1},{"MaSP":"SP_TEST","SoLuong":3}]',
     @MaHD = @hd OUTPUT;

SELECT * FROM HOA_DON WHERE MaHD = @hd;
SELECT * FROM CHI_TIET_HOA_DON WHERE MaHD = @hd;
SELECT * FROM DANG_KY_GOI WHERE MaHD = @hd;     -- 1 dòng, 'Tạm dừng', kết thúc sau 3 tháng

-- Lát (b): thanh toán hai lần. Lần 1 chưa đủ tiền nên hóa đơn vẫn chờ.
EXEC dbo.sp_ThanhToanHoaDon @MaHD = @hd, @HinhThucTT = N'Tiền mặt', @SoTien = 500000, @MaTT = @tt OUTPUT;
SELECT TrangThai FROM HOA_DON WHERE MaHD = @hd;               -- 'Chờ thanh toán'

-- Lần 2 trả phần còn lại (1.030.000) nên Trigger chốt hóa đơn.
-- Kỳ vọng: 'Đã thanh toán', DiemCong = 15, DiemTichLuy = 15,
--          TongChiTieuNam = 1.530.000, hạng Silver
EXEC dbo.sp_ThanhToanHoaDon @MaHD = @hd, @HinhThucTT = N'Tiền mặt', @MaTT = @tt OUTPUT;
SELECT * FROM DANG_KY_GOI WHERE MaHD = @hd;                   -- 'Đang hiệu lực', bắt đầu hôm nay
SELECT * FROM LICH_SU_DIEM WHERE MaHV = @hv;                  -- 1 dòng 'Cộng' = 15
SELECT * FROM LICH_SU_HANG WHERE MaHV = @hv;                  -- 1 dòng, năm hiện tại, Silver

-- Nâng hạng: hóa đơn 14.000.000 đưa tổng chi tiêu lên 15.530.000 (>= ngưỡng Gold 15.000.000)
INSERT INTO GOI_DICH_VU (MaGoi, TenGoi, LoaiGoi, ThoiHanThang, GiaTien)
VALUES ('G_BIG', N'Gym 12 tháng', N'Gym', 12, 14000000);

DECLARE @hd2 BIGINT;
EXEC dbo.sp_TaoHoaDon
     @MaCN = 'CN_TEST', @MaNV = @nv, @MaHV = @hv,
     @GioHang = N'[{"MaGoi":"G_BIG","SoLuong":1}]',
     @MaHD = @hd2 OUTPUT;
EXEC dbo.sp_ThanhToanHoaDon @MaHD = @hd2, @HinhThucTT = N'Tiền mặt', @MaTT = @tt OUTPUT;

-- Kỳ vọng: DiemTichLuy = 15 + 140 = 155, hạng Gold; LICH_SU_HANG vẫn 1 dòng (đã cập nhật)
SELECT DiemTichLuy, TongChiTieuNam, MaHang FROM HOI_VIEN WHERE MaHV = @hv;
SELECT * FROM LICH_SU_HANG WHERE MaHV = @hv;

-- Đổi điểm: đổi 50 thì còn 105; đổi 500 phải bị từ chối (RBTV91).
-- Lưu ý: lỗi trong thủ tục sẽ ROLLBACK toàn bộ giao dịch test, nên để lệnh này ở cuối.
EXEC dbo.sp_DoiDiemThuong @MaHV = @hv, @SoDiemDoi = 50;
BEGIN TRY
    EXEC dbo.sp_DoiDiemThuong @MaHV = @hv, @SoDiemDoi = 500;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS Loi, ERROR_MESSAGE() AS ThongBao;   -- 50041
END CATCH;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/