USE FitLifeHub;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- Tạm tắt toàn bộ Trigger (nếu đã cài đặt từ các file 03-08) để nạp dữ liệu lịch sử tốc độ cao
EXEC sp_MSforeachtable 'DISABLE TRIGGER ALL ON ?';
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seed_FitLifeHub_BigData
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartTime DATETIME2 = SYSDATETIME();
    PRINT N'1. Đang làm sạch dữ liệu cũ (nếu có) theo thứ tự ngược phân cấp FK...';

    -- Làm sạch từ bảng con đến bảng cha để có thể chạy lại script nhiều lần an toàn
    DELETE FROM LICH_SU_HANG;
    DELETE FROM LICH_SU_DIEM;
    DELETE FROM LICH_SU_KHO;
    DELETE FROM LICH_SU_SU_DUNG_PT;
    DELETE FROM LICH_HEN_PT;
    DELETE FROM CHECK_IN;
    DELETE FROM DANG_KY_GOI;
    DELETE FROM THANH_TOAN;
    DELETE FROM CHI_TIET_HOA_DON;
    DELETE FROM HOA_DON;
    DELETE FROM TON_KHO;
    DELETE FROM HOI_VIEN;
    DELETE FROM LICH_SU_CONG_TAC;
    DELETE FROM NHAN_VIEN;
    DELETE FROM CHI_NHANH_DICH_VU;
    DELETE FROM GOI_DICH_VU;
    DELETE FROM SAN_PHAM;
    DELETE FROM DICH_VU;
    DELETE FROM CHI_NHANH;

    -- Reset bộ đếm IDENTITY về 0 cho các bảng có cột tự tăng
    DBCC CHECKIDENT ('HOI_VIEN', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('NHAN_VIEN', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_SU_CONG_TAC', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('HOA_DON', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('CHI_TIET_HOA_DON', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('THANH_TOAN', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('DANG_KY_GOI', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_SU_KHO', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('CHECK_IN', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_HEN_PT', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_SU_SU_DUNG_PT', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_SU_DIEM', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('LICH_SU_HANG', RESEED, 0) WITH NO_INFOMSGS;

    /* ========================================================================
       BẢNG TẠM TALLY TABLE (1 -> 150.000) PHỤC VỤ PHÁT SINH DỮ LIỆU TẬP HỢP
    ======================================================================== */
    IF OBJECT_ID('tempdb..#Nums') IS NOT NULL DROP TABLE #Nums;
    CREATE TABLE #Nums (n INT NOT NULL PRIMARY KEY CLUSTERED);

    ;WITH
    E1(N) AS (SELECT 1 FROM (VALUES (1),(1),(1),(1),(1),(1),(1),(1),(1),(1)) v(n)),
    E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b),
    E4(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b),
    E6(N) AS (SELECT 1 FROM E4 a CROSS JOIN E2 b),
    Tally(n) AS (SELECT TOP (150000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM E6)
    INSERT INTO #Nums (n)
    SELECT n FROM Tally;

    /* ========================================================================
       NHÓM 1: CÁC BẢNG DANH MỤC GỐC (5 BẢNG)
    ======================================================================== */
    PRINT N'2. Đang nạp Nhóm 1: Bảng danh mục gốc (HANG_HOI_VIEN, CHI_NHANH, DICH_VU, SAN_PHAM, GOI_DICH_VU)...';

    -- 1.1. HANG_HOI_VIEN (3 dòng: SILVER, GOLD, PLATINUM - RBTV02, RBTV41a, RBTV41b)
    IF NOT EXISTS (SELECT 1 FROM HANG_HOI_VIEN WHERE MaHang = 'SILVER')
        INSERT INTO HANG_HOI_VIEN (MaHang, TenHang, ChiTieuToiThieu, MoTa)
        VALUES ('SILVER', N'Silver', 0, N'Hạng mặc định khi đăng ký hội viên');
    IF NOT EXISTS (SELECT 1 FROM HANG_HOI_VIEN WHERE MaHang = 'GOLD')
        INSERT INTO HANG_HOI_VIEN (MaHang, TenHang, ChiTieuToiThieu, MoTa)
        VALUES ('GOLD', N'Gold', 15000000, N'Tổng chi tiêu tích lũy trong năm từ 15.000.000 VNĐ');
    IF NOT EXISTS (SELECT 1 FROM HANG_HOI_VIEN WHERE MaHang = 'PLATINUM')
        INSERT INTO HANG_HOI_VIEN (MaHang, TenHang, ChiTieuToiThieu, MoTa)
        VALUES ('PLATINUM', N'Platinum', 40000000, N'Tổng chi tiêu tích lũy trong năm từ 40.000.000 VNĐ');

    -- 1.2. CHI_NHANH (12 chi nhánh: CN001 -> CN012 - RBTV14, RBTV15, RBTV43)
    INSERT INTO CHI_NHANH (MaCN, TenCN, DiaChi, SoDienThoai, GioMoCua, GioDongCua, TrangThai)
    VALUES
        ('CN001', N'FitLife Hub Quận 1',      N'120 Nguyễn Huệ, Quận 1, TP.HCM',               '0283811001', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN002', N'FitLife Hub Quận 3',      N'45 Võ Văn Tần, Quận 3, TP.HCM',                '0283811002', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN003', N'FitLife Hub Quận 5',      N'227 Nguyễn Văn Cừ, Quận 5, TP.HCM',            '0283811003', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN004', N'FitLife Hub Quận 7',      N'105 Nguyễn Thị Thập, Quận 7, TP.HCM',          '0283811004', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN005', N'FitLife Hub Bình Thạnh',  N'560 Điện Biên Phủ, Bình Thạnh, TP.HCM',        '0283811005', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN006', N'FitLife Hub Phú Nhuận',   N'198 Phan Xích Long, Phú Nhuận, TP.HCM',        '0283811006', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN007', N'FitLife Hub Tân Bình',    N'320 Cộng Hòa, Tân Bình, TP.HCM',               '0283811007', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN008', N'FitLife Hub Thủ Đức',     N'88 Võ Văn Ngân, TP. Thủ Đức, TP.HCM',          '0283811008', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN009', N'FitLife Hub Hoàn Kiếm',   N'54 Lý Thường Kiệt, Hoàn Kiếm, Hà Nội',         '0243811009', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN010', N'FitLife Hub Cầu Giấy',    N'210 Cầu Giấy, Quận Cầu Giấy, Hà Nội',          '0243811010', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN011', N'FitLife Hub Hải Châu',    N'75 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',        '0236811011', '05:00:00', '22:00:00', N'Hoạt động'),
        ('CN012', N'FitLife Hub Ninh Kiều',   N'150 Đại lộ Hòa Bình, Ninh Kiều, Cần Thơ',      '0292811012', '05:00:00', '22:00:00', N'Hoạt động');

    -- 1.3. DICH_VU (5 dịch vụ: Gym, Yoga, GroupX, PT, Spa - RBTV16a, RBTV16b)
    INSERT INTO DICH_VU (MaDV, TenDV, LoaiDV, MoTa, TrangThai)
    VALUES
        ('DV01', N'Tập luyện Gym & Cardio tiêu chuẩn',    N'Gym',    N'Sử dụng toàn bộ khu vực máy tập tạ và máy chạy bộ', N'Đang cung cấp'),
        ('DV02', N'Lớp Yoga trị liệu & Thiền định',       N'Yoga',   N'Các lớp Hatha, Vinyasa và Ashtanga Yoga với HLV',   N'Đang cung cấp'),
        ('DV03', N'Lớp nhảy & Thể dục nhóm GroupX',       N'GroupX', N'Zumba, BodyCombat, BodyPump và Cycling theo nhạc',  N'Đang cung cấp'),
        ('DV04', N'Huấn luyện viên cá nhân 1 kèm 1 (PT)', N'PT',     N'Tập luyện 1-1 chuyên sâu cùng Huấn luyện viên',     N'Đang cung cấp'),
        ('DV05', N'Thư giãn Spa & Xông hơi Sauna/Steam',  N'Spa',    N'Phòng xông hơi khô, ướt và bể sục phục hồi cơ',     N'Đang cung cấp');

    -- 1.4. SAN_PHAM (30 sản phẩm: SP001 -> SP030 - RBTV37a, RBTV37b)
    INSERT INTO SAN_PHAM (MaSP, TenSP, LoaiSP, DonViTinh, GiaBan, TrangThai)
    SELECT
        'SP' + RIGHT('000' + CAST(n AS VARCHAR(3)), 3) AS MaSP,
        CASE ((n - 1) / 6)
            WHEN 0 THEN N'Whey Protein Isolate Gold ' + CAST(n AS NVARCHAR(10))
            WHEN 1 THEN N'BCAA & EAA Phục hồi cơ ' + CAST(n AS NVARCHAR(10))
            WHEN 2 THEN N'Pre-Workout Tăng sức mạnh ' + CAST(n AS NVARCHAR(10))
            WHEN 3 THEN N'Bình nước Thể thao Shaker ' + CAST(n AS NVARCHAR(10))
            ELSE        N'Phụ kiện Thảm Yoga & Đai lưng ' + CAST(n AS NVARCHAR(10))
        END AS TenSP,
        CASE ((n - 1) / 6)
            WHEN 0 THEN N'Whey Protein'
            WHEN 1 THEN N'Thực phẩm bổ sung'
            WHEN 2 THEN N'Thực phẩm bổ sung'
            WHEN 3 THEN N'Bình nước'
            ELSE        N'Thảm Yoga & Phụ kiện'
        END AS LoaiSP,
        CASE
            WHEN n <= 18 THEN N'Hộp'
            WHEN n <= 24 THEN N'Bình'
            ELSE              N'Cái'
        END AS DonViTinh,
        CAST((150000 + (n * 50000)) AS DECIMAL(18, 2)) AS GiaBan,
        N'Đang kinh doanh' AS TrangThai
    FROM #Nums
    WHERE n <= 30;

    -- 1.5. GOI_DICH_VU (16 gói: GOI01 -> GOI16 - RBTV21, RBTV22, RBTV23, RBTV46, RBTV47, RBTV62)
    INSERT INTO GOI_DICH_VU (MaGoi, TenGoi, LoaiGoi, ThoiHanThang, SoBuoiPT, GiaTien, TrangThai)
    VALUES
        -- 4 gói Gym (Có ThoiHanThang > 0, SoBuoiPT IS NULL)
        ('GOI01', N'Gói Gym Tiêu chuẩn 1 Tháng',      N'Gym',  1,  NULL, 600000,   N'Đang kinh doanh'),
        ('GOI02', N'Gói Gym Tiêu chuẩn 3 Tháng',      N'Gym',  3,  NULL, 1500000,  N'Đang kinh doanh'),
        ('GOI03', N'Gói Gym Toàn diện 6 Tháng',       N'Gym',  6,  NULL, 2700000,  N'Đang kinh doanh'),
        ('GOI04', N'Gói Gym VIP 12 Tháng',            N'Gym',  12, NULL, 4800000,  N'Đang kinh doanh'),
        -- 4 gói Yoga (Có ThoiHanThang > 0, SoBuoiPT IS NULL)
        ('GOI05', N'Gói Yoga Cơ bản 1 Tháng',         N'Yoga', 1,  NULL, 700000,   N'Đang kinh doanh'),
        ('GOI06', N'Gói Yoga Nâng cao 3 Tháng',       N'Yoga', 3,  NULL, 1800000,  N'Đang kinh doanh'),
        ('GOI07', N'Gói Yoga Chuyên sâu 6 Tháng',     N'Yoga', 6,  NULL, 3300000,  N'Đang kinh doanh'),
        ('GOI08', N'Gói Yoga Master 12 Tháng',        N'Yoga', 12, NULL, 6000000,  N'Đang kinh doanh'),
        -- 4 gói PT 1-1 (LoaiGoi = N'PT', SoBuoiPT > 0, ThoiHanThang > 0)
        ('GOI09', N'Gói PT 1-1 Khởi động 12 Buổi',    N'PT',   2,  12,   4800000,  N'Đang kinh doanh'),
        ('GOI10', N'Gói PT 1-1 Tăng cơ 24 Buổi',      N'PT',   3,  24,   9000000,  N'Đang kinh doanh'),
        ('GOI11', N'Gói PT 1-1 Giảm mỡ 36 Buổi',      N'PT',   6,  36,   12600000, N'Đang kinh doanh'),
        ('GOI12', N'Gói PT 1-1 Chuyên nghiệp 50 Buổi',N'PT',   12, 50,   16000000, N'Đang kinh doanh'),
        -- 4 gói Spa (LoaiGoi = N'Spa', SoBuoiPT IS NULL)
        ('GOI13', N'Vé Spa & Sauna Lẻ 1 Tháng',       N'Spa',  1,  NULL, 500000,   N'Đang kinh doanh'),
        ('GOI14', N'Gói Spa Thư giãn 3 Tháng',        N'Spa',  3,  NULL, 1200000,  N'Đang kinh doanh'),
        ('GOI15', N'Gói Spa Phục hồi 6 Tháng',        N'Spa',  6,  NULL, 2200000,  N'Đang kinh doanh'),
        ('GOI16', N'Gói Spa Cao cấp 12 Tháng',        N'Spa',  12, NULL, 4000000,  N'Đang kinh doanh');


    /* ========================================================================
       NHÓM 2: CÁC BẢNG CÓ KHÓA NGOẠI CẤP 1 (5 BẢNG)
    ======================================================================== */
    PRINT N'3. Đang nạp Nhóm 2: CHI_NHANH_DICH_VU, NHAN_VIEN, LICH_SU_CONG_TAC, HOI_VIEN (70.000 dòng), TON_KHO...';

    -- 2.1. CHI_NHANH_DICH_VU (12 CN x 5 DV = 60 dòng - RBTV44)
    INSERT INTO CHI_NHANH_DICH_VU (MaCN, MaDV, NgayBatDau, NgayKetThuc)
    SELECT
        cn.MaCN,
        dv.MaDV,
        '2022-01-01' AS NgayBatDau,
        NULL AS NgayKetThuc
    FROM CHI_NHANH cn
    CROSS JOIN DICH_VU dv;

    -- 2.2. NHAN_VIEN (240 nhân viên: MaNV 1..240 - RBTV15, RBTV29, RBTV30, RBTV63)
    -- Phân bổ rõ ràng để kiểm soát RBTV11 và các kịch bản:
    --   + MaNV 1..12   : Quản lý chi nhánh (Mỗi chi nhánh CN001..CN012 có đúng 1 Quản lý)
    --   + MaNV 13..132 : 120 HLV (PT) (Mỗi chi nhánh có 10 HLV)
    --   + MaNV 133..180: 48 Lễ tân (Mỗi chi nhánh có 4 Lễ tân)
    --   + MaNV 181..240: 60 Nhân viên bán hàng (Mỗi chi nhánh có 5 NV bán hàng)
    SET IDENTITY_INSERT NHAN_VIEN ON;
    INSERT INTO NHAN_VIEN (MaNV, HoTen, SoDienThoai, ChucVu, LuongCoBan, NgayVaoLam, TrangThai, MaCNHienTai)
    SELECT
        n AS MaNV,
        CASE (n % 8)
            WHEN 0 THEN N'Nguyễn Văn '
            WHEN 1 THEN N'Trần Thị '
            WHEN 2 THEN N'Lê Hoàng '
            WHEN 3 THEN N'Phạm Minh '
            WHEN 4 THEN N'Đinh Tiến '
            WHEN 5 THEN N'Bùi Ngọc '
            WHEN 6 THEN N'Vũ Quốc '
            ELSE        N'Đặng Thu '
        END + N'Nhân Viên ' + CAST(n AS NVARCHAR(10)) AS HoTen,
        '091' + RIGHT('0000000' + CAST(n AS VARCHAR(7)), 7) AS SoDienThoai,
        CASE
            WHEN n <= 12  THEN N'Quản lý chi nhánh'
            WHEN n <= 132 THEN N'HLV'
            WHEN n <= 180 THEN N'Lễ tân'
            ELSE               N'Nhân viên bán hàng'
        END AS ChucVu,
        CASE
            WHEN n <= 12  THEN CAST(25000000 AS DECIMAL(18,2))
            WHEN n <= 132 THEN CAST(12000000 AS DECIMAL(18,2))
            WHEN n <= 180 THEN CAST(8500000  AS DECIMAL(18,2))
            ELSE               CAST(9500000  AS DECIMAL(18,2))
        END AS LuongCoBan,
        '2022-01-15' AS NgayVaoLam,
        N'Đang làm' AS TrangThai,
        'CN' + RIGHT('000' + CAST(((n - 1) % 12) + 1 AS VARCHAR(3)), 3) AS MaCNHienTai
    FROM #Nums
    WHERE n <= 240;
    SET IDENTITY_INSERT NHAN_VIEN OFF;

    -- 2.3. LICH_SU_CONG_TAC (360 dòng - RBTV09, RBTV10, RBTV11, RBTV29, RBTV59)
    -- + 120 dòng lịch sử quá khứ (cho 120 HLV MaNV 13..132 làm ở chi nhánh kế tiếp từ 2022-01-15 đến 2023-12-31)
    -- + 240 dòng đang hiệu lực (NgayKetThuc IS NULL) cho cả 240 NV từ 2024-01-01 đến nay tại MaCNHienTai
    INSERT INTO LICH_SU_CONG_TAC (ChucVu, LuongCoBan, NgayBatDau, NgayKetThuc, MaNV, MaCN)
    SELECT
        nv.ChucVu,
        nv.LuongCoBan - 1500000 AS LuongCoBan,
        '2022-01-15' AS NgayBatDau,
        '2023-12-31' AS NgayKetThuc,
        nv.MaNV,
        'CN' + RIGHT('000' + CAST((nv.MaNV % 12) + 1 AS VARCHAR(3)), 3) AS MaCN
    FROM NHAN_VIEN nv
    WHERE nv.MaNV BETWEEN 13 AND 132;

    INSERT INTO LICH_SU_CONG_TAC (ChucVu, LuongCoBan, NgayBatDau, NgayKetThuc, MaNV, MaCN)
    SELECT
        nv.ChucVu,
        nv.LuongCoBan,
        CASE WHEN nv.MaNV BETWEEN 13 AND 132 THEN '2024-01-01' ELSE '2022-01-15' END AS NgayBatDau,
        NULL AS NgayKetThuc,
        nv.MaNV,
        nv.MaCNHienTai AS MaCN
    FROM NHAN_VIEN nv;

    -- 2.4. HOI_VIEN (70.000 dòng: MaHV 1..70.000 - RBTV01, RBTV15, RBTV17, RBTV18, RBTV19, RBTV20, RBTV45)
    SET IDENTITY_INSERT HOI_VIEN ON;
    INSERT INTO HOI_VIEN (
        MaHV, HoTen, SoDienThoai, Email, CCCD, GioiTinh,
        NgaySinh, NgayDangKy, TrangThai, DiemTichLuy, TongChiTieuNam, MaHang
    )
    SELECT
        n AS MaHV,
        CASE (n % 10)
            WHEN 0 THEN N'Nguyễn Minh '
            WHEN 1 THEN N'Trần Ngọc '
            WHEN 2 THEN N'Lê Đình '
            WHEN 3 THEN N'Phạm Bá '
            WHEN 4 THEN N'Đinh Tiến '
            WHEN 5 THEN N'Bùi Quốc '
            WHEN 6 THEN N'Hoàng Thanh '
            WHEN 7 THEN N'Võ Gia '
            WHEN 8 THEN N'Đỗ Phương '
            ELSE        N'Dương Bảo '
        END + N'Hội Viên ' + CAST(n AS NVARCHAR(10)) AS HoTen,
        '098' + RIGHT('0000000' + CAST(n AS VARCHAR(7)), 7) AS SoDienThoai,
        'hoivien' + CAST(n AS VARCHAR(10)) + '@fitlifehub.vn' AS Email,
        '0790' + RIGHT('00000000' + CAST(n AS VARCHAR(8)), 8) AS CCCD,
        CASE WHEN n % 2 = 0 THEN N'Nam' ELSE N'Nữ' END AS GioiTinh,
        DATEADD(DAY, -(7300 + (n % 9000)), '2023-01-01') AS NgaySinh,
        DATEADD(DAY, (n % 700), '2023-01-01T08:00:00') AS NgayDangKy,
        CASE WHEN n % 25 = 0 THEN N'Ngưng' ELSE N'Hoạt động' END AS TrangThai,
        CASE
            WHEN n % 10 = 0 THEN 450
            WHEN n % 4  = 0 THEN 180
            ELSE                 35
        END AS DiemTichLuy,
        CASE
            WHEN n % 10 = 0 THEN CAST(45000000 AS DECIMAL(18,2))
            WHEN n % 4  = 0 THEN CAST(18000000 AS DECIMAL(18,2))
            ELSE                 CAST(3500000  AS DECIMAL(18,2))
        END AS TongChiTieuNam,
        CASE
            WHEN n % 10 = 0 THEN 'PLATINUM'
            WHEN n % 4  = 0 THEN 'GOLD'
            ELSE                 'SILVER'
        END AS MaHang
    FROM #Nums
    WHERE n <= 70000;
    SET IDENTITY_INSERT HOI_VIEN OFF;

    -- 2.5. TON_KHO (12 CN x 30 SP = 360 dòng - RBTV38)
    -- Thiết lập một số sản phẩm có SoLuongTon <= MucTonToiThieu để phục vụ demo cảnh báo tồn kho (KB09)
    INSERT INTO TON_KHO (MaCN, MaSP, SoLuongTon, MucTonToiThieu, NgayCapNhat)
    SELECT
        cn.MaCN,
        sp.MaSP,
        CASE
            WHEN (CAST(RIGHT(cn.MaCN, 3) AS INT) + CAST(RIGHT(sp.MaSP, 3) AS INT)) % 6 = 0
                THEN 5  -- Dưới hoặc bằng định mức tối thiểu (Cảnh báo đỏ)
            ELSE
                150 + ((CAST(RIGHT(cn.MaCN, 3) AS INT) * 17 + CAST(RIGHT(sp.MaSP, 3) AS INT) * 13) % 200)
        END AS SoLuongTon,
        10 AS MucTonToiThieu,
        '2026-10-01T08:00:00' AS NgayCapNhat
    FROM CHI_NHANH cn
    CROSS JOIN SAN_PHAM sp;


    /* ========================================================================
       NHÓM 3: CÁC BẢNG GIAO DỊCH LỚN (6 BẢNG: 75.000 -> 150.000 DÒNG)
    ======================================================================== */
    PRINT N'4. Đang nạp Nhóm 3: DANG_KY_GOI (75k), HOA_DON (80k), CHI_TIET_HOA_DON (120k), THANH_TOAN (80k), CHECK_IN (150k), LICH_HEN_PT (75k)...';

    -- 3.1. HOA_DON (80.000 dòng: MaHD 1..80.000 - RBTV31, RBTV32, RBTV51, RBTV52)
    -- Phân bổ:
    --   + MaHD 1..40.000     : Mua Gói dịch vụ (1 dòng CTHD gói = 1.500.000)
    --   + MaHD 40.001..80.000: Mua Gói dịch vụ + Sản phẩm (2 dòng CTHD: 1.500.000 + 300.000 = 1.800.000)
    --   + Thời gian NgayLap trải đều từ 2024-01-01 đến 2026-10-31 (phục vụ Partition theo Quý của TV3)
    SET IDENTITY_INSERT HOA_DON ON;
    INSERT INTO HOA_DON (MaHD, NgayLap, TongTien, GiamGia, ThanhTien, TrangThai, MaCN, MaNV, MaHV)
    SELECT
        n AS MaHD,
        DATEADD(MINUTE, (n * 17) % 1440, DATEADD(DAY, n % 1030, CAST('2024-01-01' AS DATETIME2))) AS NgayLap,
        CASE WHEN n <= 40000 THEN CAST(1500000 AS DECIMAL(18,2)) ELSE CAST(1800000 AS DECIMAL(18,2)) END AS TongTien,
        CAST(0 AS DECIMAL(18,2)) AS GiamGia,
        CASE WHEN n <= 40000 THEN CAST(1500000 AS DECIMAL(18,2)) ELSE CAST(1800000 AS DECIMAL(18,2)) END AS ThanhTien,
        N'Đã thanh toán' AS TrangThai,
        'CN' + RIGHT('000' + CAST(((n - 1) % 12) + 1 AS VARCHAR(3)), 3) AS MaCN,
        -- Chọn đúng Nhân viên bán hàng (MaNV 181..240) làm tại chi nhánh tương ứng
        180 + (((n - 1) % 5) * 12) + (((n - 1) % 12) + 1) AS MaNV,
        ((n - 1) % 70000) + 1 AS MaHV
    FROM #Nums
    WHERE n <= 80000;
    SET IDENTITY_INSERT HOA_DON OFF;

    -- 3.2. CHI_TIET_HOA_DON (120.000 dòng - RBTV33, RBTV53, RBTV54)
    -- + 80.000 dòng đầu (cho MaHD 1..80.000): Bán Gói dịch vụ (MaGoi IS NOT NULL, MaSP IS NULL)
    INSERT INTO CHI_TIET_HOA_DON (SoLuong, DonGia, ThanhTien, MaHD, MaGoi, MaSP)
    SELECT
        1 AS SoLuong,
        CAST(1500000 AS DECIMAL(18,2)) AS DonGia,
        CAST(1500000 AS DECIMAL(18,2)) AS ThanhTien,
        n AS MaHD,
        'GOI' + RIGHT('00' + CAST(((n - 1) % 16) + 1 AS VARCHAR(2)), 2) AS MaGoi,
        NULL AS MaSP
    FROM #Nums
    WHERE n <= 80000;

    -- + 40.000 dòng tiếp theo (cho MaHD 40.001..80.000): Bán Sản phẩm (MaGoi IS NULL, MaSP IS NOT NULL)
    --   Sử dụng SoLuong = 1, MaSP = 'SP' + ((n - 1) % 30) + 1 để khớp tuyệt đối với RBTV88 khi đối chiếu LICH_SU_KHO
    INSERT INTO CHI_TIET_HOA_DON (SoLuong, DonGia, ThanhTien, MaHD, MaGoi, MaSP)
    SELECT
        1 AS SoLuong,
        CAST(300000 AS DECIMAL(18,2)) AS DonGia,
        CAST(300000 AS DECIMAL(18,2)) AS ThanhTien,
        n AS MaHD,
        NULL AS MaGoi,
        'SP' + RIGHT('000' + CAST(((n - 1) % 30) + 1 AS VARCHAR(3)), 3) AS MaSP
    FROM #Nums
    WHERE n BETWEEN 40001 AND 80000;

    -- 3.3. THANH_TOAN (80.000 dòng: MaTT 1..80.000 - RBTV05, RBTV34, RBTV35, RBTV36, RBTV55)
    INSERT INTO THANH_TOAN (ThoiGianTT, SoTien, HinhThucTT, MaGiaoDichNgoai, TrangThaiTT, MaHD)
    SELECT
        DATEADD(MINUTE, 5, hd.NgayLap) AS ThoiGianTT,
        hd.ThanhTien AS SoTien,
        CASE (hd.MaHD % 3)
            WHEN 0 THEN N'Tiền mặt'
            WHEN 1 THEN N'VNPay'
            ELSE        N'Thẻ'
        END AS HinhThucTT,
        CASE (hd.MaHD % 3)
            WHEN 0 THEN NULL
            WHEN 1 THEN 'VNPAY_' + RIGHT('00000000' + CAST(hd.MaHD AS VARCHAR(8)), 8)
            ELSE        'CARD_'  + RIGHT('00000000' + CAST(hd.MaHD AS VARCHAR(8)), 8)
        END AS MaGiaoDichNgoai,
        N'Thành công' AS TrangThaiTT,
        hd.MaHD
    FROM HOA_DON hd;

    -- 3.4. DANG_KY_GOI (75.000 dòng: MaDK 1..75.000 - RBTV24, RBTV25, RBTV48)
    -- Thiết kế có chủ đích cho cả 4 thành viên:
    --   + MaDK 1..30.000     : Gói PT ('GOI09'..'GOI12'), SoBuoiConLai = 12, TrangThai = N'Đang hiệu lực' (Phục vụ TV2 đặt lịch PT)
    --   + MaDK 30.001..70.000: Gói Gym/Yoga ('GOI01'..'GOI08'), TrangThai = N'Đang hiệu lực',
    --                          trong đó MaDK 65.001..70.000 có NgayKetThuc sắp hết hạn trong 1..14 ngày tới tính từ GETDATE() (Phục vụ TV1 Check-in & TV4 KB10)
    --   + MaDK 70.001..75.000: Gói đã hết hạn trong quá khứ (TrangThai = N'Hết hạn')
    SET IDENTITY_INSERT DANG_KY_GOI ON;
    INSERT INTO DANG_KY_GOI (MaDK, NgayBatDau, NgayKetThuc, SoBuoiConLai, TrangThai, MaHV, MaGoi, MaHD)
    SELECT
        n AS MaDK,
        CASE
            WHEN n <= 65000 THEN CAST('2024-01-01' AS DATE)
            WHEN n <= 70000 THEN DATEADD(MONTH, -3, CAST(GETDATE() AS DATE))
            ELSE                 CAST('2023-01-01' AS DATE)
        END AS NgayBatDau,
        CASE
            WHEN n <= 65000 THEN CAST('2027-12-31' AS DATE)
            WHEN n <= 70000 THEN DATEADD(DAY, (n % 14) + 1, CAST(GETDATE() AS DATE)) -- Sắp hết hạn trong 1-14 ngày tới (KB10)
            ELSE                 CAST('2023-12-31' AS DATE)
        END AS NgayKetThuc,
        CASE
            WHEN n <= 30000 THEN 12
            ELSE                 NULL
        END AS SoBuoiConLai,
        CASE
            WHEN n <= 70000 THEN N'Đang hiệu lực'
            ELSE                 N'Hết hạn'
        END AS TrangThai,
        ((n - 1) % 70000) + 1 AS MaHV,
        CASE
            WHEN n <= 30000 THEN 'GOI' + RIGHT('00' + CAST(9 + ((n - 1) % 4) AS VARCHAR(2)), 2)  -- GOI09..GOI12 (PT)
            ELSE                 'GOI' + RIGHT('00' + CAST(1 + ((n - 1) % 8) AS VARCHAR(2)), 2)  -- GOI01..GOI08 (Gym/Yoga)
        END AS MaGoi,
        n AS MaHD
    FROM #Nums
    WHERE n <= 75000;
    SET IDENTITY_INSERT DANG_KY_GOI OFF;

    -- 3.5. CHECK_IN (150.000 dòng: MaCheckIn 1..150.000 - RBTV26, RBTV49)
    -- + Phân bổ qua các tháng 2024-2026 và đầy đủ 4 khung giờ (Sáng 06-10h, Trưa 11-16h, Cao điểm 17-19h, Tối 20-21h)
    -- + Chỉ gán check-in cho MaHV 1..60.000 để MaHV 60.001..70.000 không có lượt check-in 30 ngày gần nhất (phục vụ KB10 của TV4)
    SET IDENTITY_INSERT CHECK_IN ON;
    INSERT INTO CHECK_IN (MaCheckIn, ThoiGianVao, ThoiGianRa, MaThietBi, KetQuaXacThuc, MaHV, MaCN)
    SELECT
        n AS MaCheckIn,
        DATEADD(
            MINUTE,
            -- Tạo phân phối giờ cao điểm 17:00-20:00 chiếm tỷ trọng cao đúng mô tả đề bài
            CASE (n % 10)
                WHEN 0 THEN 360  + (n % 180) -- Sáng: 06:00 - 09:00
                WHEN 1 THEN 540  + (n % 120) -- Sáng muộn: 09:00 - 11:00
                WHEN 2 THEN 720  + (n % 180) -- Trưa/Chiều: 12:00 - 15:00
                WHEN 3 THEN 900  + (n % 120) -- Chiều: 15:00 - 17:00
                WHEN 9 THEN 1200 + (n % 90)  -- Tối: 20:00 - 21:30
                ELSE        1020 + (n % 175) -- Giờ cao điểm: 17:00 - 19:55 (50% tổng lưu lượng)
            END,
            DATEADD(DAY, n % 1030, CAST('2024-01-01' AS DATETIME2))
        ) AS ThoiGianVao,
        DATEADD(
            MINUTE,
            75 + (n % 45), -- Tập từ 75 đến 120 phút (ThoiGianRa > ThoiGianVao thỏa RBTV49)
            DATEADD(
                MINUTE,
                CASE (n % 10)
                    WHEN 0 THEN 360  + (n % 180)
                    WHEN 1 THEN 540  + (n % 120)
                    WHEN 2 THEN 720  + (n % 180)
                    WHEN 3 THEN 900  + (n % 120)
                    WHEN 9 THEN 1200 + (n % 90)
                    ELSE        1020 + (n % 175)
                END,
                DATEADD(DAY, n % 1030, CAST('2024-01-01' AS DATETIME2))
            )
        ) AS ThoiGianRa,
        'GATE_CN' + RIGHT('00' + CAST(((n - 1) % 12) + 1 AS VARCHAR(2)), 2) + '_0' + CAST((n % 4) + 1 AS VARCHAR(1)) AS MaThietBi,
        CASE WHEN n % 20 = 0 THEN N'Từ chối' ELSE N'Hợp lệ' END AS KetQuaXacThuc,
        ((n - 1) % 60000) + 1 AS MaHV,
        'CN' + RIGHT('000' + CAST(((n - 1) % 12) + 1 AS VARCHAR(3)), 3) AS MaCN
    FROM #Nums
    WHERE n <= 150000;
    SET IDENTITY_INSERT CHECK_IN OFF;

    -- 3.6. LICH_HEN_PT (75.000 dòng: MaLich 1..75.000 - RBTV27, RBTV50, RBTV07, RBTV08)
    -- Đảm bảo tuyệt đối KHÔNG có 2 lịch hẹn trùng HLV (MaNV) hoặc trùng Hội viên (MaHV) cùng khung giờ:
    --   + Có 120 HLV (MaNV 13..132). Với mỗi n (1..75.000):
    --     - HLV phụ trách: MaNV = 13 + ((n - 1) % 120)
    --     - Slot thứ k của HLV đó: k = (n - 1) / 120 (k chạy từ 0 đến 624)
    --     - Ngày hẹn: DATEADD(DAY, k / 5, '2023-06-01') (mỗi ngày tối đa 5 ca sáng/chiều/tối tách biệt)
    --     - Giờ bắt đầu ca: 07:00, 09:00, 14:00, 16:00, 18:00 (mỗi ca 1 tiếng -> không bao giờ chồng lấn!)
    --   + MaLich 1..70.000     : TrangThai = N'Đã hoàn thành' (Khớp với 70.000 dòng LICH_SU_SU_DUNG_PT)
    --   + MaLich 70.001..73.000: TrangThai = N'Đã đặt' (Phục vụ TV2 test sp_HoanThanhBuoiPT)
    --   + MaLich 73.001..75.000: TrangThai = N'Hủy'
    SET IDENTITY_INSERT LICH_HEN_PT ON;
    INSERT INTO LICH_HEN_PT (MaLich, ThoiGianBatDau, ThoiGianKetThuc, TrangThai, MaHV, MaNV, MaCN, MaDK)
    SELECT
        n AS MaLich,
        DATEADD(
            HOUR,
            CASE (((n - 1) / 120) % 5)
                WHEN 0 THEN 7
                WHEN 1 THEN 9
                WHEN 2 THEN 14
                WHEN 3 THEN 16
                ELSE        18
            END,
            DATEADD(DAY, ((n - 1) / 120) / 5, CAST('2023-06-01' AS DATETIME2))
        ) AS ThoiGianBatDau,
        DATEADD(
            HOUR,
            1 + CASE (((n - 1) / 120) % 5)
                WHEN 0 THEN 7
                WHEN 1 THEN 9
                WHEN 2 THEN 14
                WHEN 3 THEN 16
                ELSE        18
            END,
            DATEADD(DAY, ((n - 1) / 120) / 5, CAST('2023-06-01' AS DATETIME2))
        ) AS ThoiGianKetThuc,
        CASE
            WHEN n <= 70000 THEN N'Đã hoàn thành'
            WHEN n <= 73000 THEN N'Đã đặt'
            ELSE                 N'Hủy'
        END AS TrangThai,
        -- MaDK = ((n - 1) % 30000) + 1 thuộc về MaHV = ((n - 1) % 30000) + 1 (Gói PT hợp lệ)
        ((n - 1) % 30000) + 1 AS MaHV,
        13 + ((n - 1) % 120) AS MaNV,
        -- Khớp chi nhánh lịch sử công tác của HLV tại thời điểm diễn ra buổi tập (Trước 2024 vs Từ 2024)
        CASE
            WHEN DATEADD(DAY, ((n - 1) / 120) / 5, CAST('2023-06-01' AS DATE)) <= '2023-12-31'
                THEN 'CN' + RIGHT('000' + CAST(((13 + ((n - 1) % 120)) % 12) + 1 AS VARCHAR(3)), 3)
            ELSE
                'CN' + RIGHT('000' + CAST(((12 + ((n - 1) % 120)) % 12) + 1 AS VARCHAR(3)), 3)
        END AS MaCN,
        ((n - 1) % 30000) + 1 AS MaDK
    FROM #Nums
    WHERE n <= 75000;
    SET IDENTITY_INSERT LICH_HEN_PT OFF;


    /* ========================================================================
       NHÓM 4: CÁC BẢNG NHẬT KÝ / PHỤ THUỘC (4 BẢNG: 70.000 DÒNG/BẢNG)
    ======================================================================== */
    PRINT N'5. Đang nạp Nhóm 4: LICH_SU_SU_DUNG_PT (70k), LICH_SU_KHO (70k), LICH_SU_DIEM (70k), LICH_SU_HANG (70k)...';

    -- 4.1. LICH_SU_SU_DUNG_PT (70.000 dòng - RBTV03 UNIQUE MaLich, RBTV28 SoBuoiSuDung > 0)
    INSERT INTO LICH_SU_SU_DUNG_PT (ThoiDiemXacNhan, SoBuoiSuDung, GhiChu, MaLich, MaDK)
    SELECT
        DATEADD(MINUTE, 5, lh.ThoiGianKetThuc) AS ThoiDiemXacNhan,
        1 AS SoBuoiSuDung,
        N'Hoàn thành buổi tập PT 1-1 đúng lộ trình' AS GhiChu,
        lh.MaLich,
        lh.MaDK
    FROM LICH_HEN_PT lh
    WHERE lh.MaLich <= 70000;

    -- 4.2. LICH_SU_KHO (70.000 dòng - RBTV39, RBTV56, RBTV57, RBTV88, RBTV89)
    -- + 40.000 dòng Xuất kho bán hàng gắn với MaHD 40.001..80.000 (khớp MaCN, MaSP, MaNV và SoLuong = -1)
    -- + 30.000 dòng Nhập kho & Điều chỉnh kho (MaHD IS NULL theo RBTV57)
    INSERT INTO LICH_SU_KHO (LoaiGiaoDich, SoLuongThayDoi, ThoiGian, GhiChu, MaCN, MaSP, MaNV, MaHD)
    SELECT
        N'Xuất' AS LoaiGiaoDich,
        -1 AS SoLuongThayDoi,
        DATEADD(MINUTE, 2, hd.NgayLap) AS ThoiGian,
        N'Xuất kho bán lẻ theo hóa đơn #' + CAST(hd.MaHD AS NVARCHAR(20)) AS GhiChu,
        hd.MaCN,
        'SP' + RIGHT('000' + CAST(((hd.MaHD - 1) % 30) + 1 AS VARCHAR(3)), 3) AS MaSP,
        hd.MaNV,
        hd.MaHD
    FROM HOA_DON hd
    WHERE hd.MaHD BETWEEN 40001 AND 80000;

    INSERT INTO LICH_SU_KHO (LoaiGiaoDich, SoLuongThayDoi, ThoiGian, GhiChu, MaCN, MaSP, MaNV, MaHD)
    SELECT
        CASE WHEN n % 10 = 0 THEN N'Điều chỉnh' ELSE N'Nhập' END AS LoaiGiaoDich,
        CASE WHEN n % 10 = 0 THEN 5 ELSE 25 + (n % 30) END AS SoLuongThayDoi,
        DATEADD(HOUR, n % 24, DATEADD(DAY, n % 1000, CAST('2024-01-01T07:00:00' AS DATETIME2))) AS ThoiGian,
        CASE WHEN n % 10 = 0 THEN N'Kiểm kê định kỳ điều chỉnh kho' ELSE N'Nhập hàng bổ sung định kỳ về chi nhánh' END AS GhiChu,
        'CN' + RIGHT('000' + CAST(((n - 1) % 12) + 1 AS VARCHAR(3)), 3) AS MaCN,
        'SP' + RIGHT('000' + CAST(((n - 1) % 30) + 1 AS VARCHAR(3)), 3) AS MaSP,
        -- Nhân viên bán hàng thuộc đúng chi nhánh đó (RBTV89)
        180 + (((n - 1) % 5) * 12) + (((n - 1) % 12) + 1) AS MaNV,
        NULL AS MaHD
    FROM #Nums
    WHERE n <= 30000;

    -- 4.3. LICH_SU_DIEM (70.000 dòng - RBTV06 UNIQUE MaHD khi Cộng, RBTV40, RBTV58)
    -- + 60.000 dòng Cộng điểm từ MaHD 1..60.000 (SoDiem > 0, MaHD IS NOT NULL và duy nhất)
    -- + 10.000 dòng Trừ điểm đổi quà (SoDiem < 0, MaHD IS NULL)
    INSERT INTO LICH_SU_DIEM (ThoiGian, LoaiGiaoDich, SoDiem, GhiChu, MaHV, MaHD)
    SELECT
        DATEADD(MINUTE, 6, hd.NgayLap) AS ThoiGian,
        N'Cộng' AS LoaiGiaoDich,
        CAST(FLOOR(hd.ThanhTien / 100000) AS INT) AS SoDiem,
        N'Tích điểm tự động từ hóa đơn #' + CAST(hd.MaHD AS NVARCHAR(20)) AS GhiChu,
        hd.MaHV,
        hd.MaHD
    FROM HOA_DON hd
    WHERE hd.MaHD <= 60000;

    INSERT INTO LICH_SU_DIEM (ThoiGian, LoaiGiaoDich, SoDiem, GhiChu, MaHV, MaHD)
    SELECT
        DATEADD(DAY, n % 900, CAST('2024-03-01T10:00:00' AS DATETIME2)) AS ThoiGian,
        N'Trừ' AS LoaiGiaoDich,
        -10 AS SoDiem,
        N'Đổi điểm thưởng nhận voucher phụ kiện tập luyện' AS GhiChu,
        n AS MaHV,
        NULL AS MaHD
    FROM #Nums
    WHERE n <= 10000;

    -- 4.4. LICH_SU_HANG (70.000 dòng - RBTV04 UNIQUE (MaHV, NamXetHang), RBTV42 NamXetHang <= YEAR(GETDATE()))
    INSERT INTO LICH_SU_HANG (NamXetHang, TongChiTieu, NgayCapNhat, MaHV, MaHang)
    SELECT
        2025 AS NamXetHang,
        hv.TongChiTieuNam AS TongChiTieu,
        '2025-12-31T23:00:00' AS NgayCapNhat,
        hv.MaHV,
        hv.MaHang
    FROM HOI_VIEN hv;

    DROP TABLE #Nums;

    DECLARE @ElapsedSec INT = DATEDIFF(SECOND, @StartTime, SYSDATETIME());
    PRINT N'=== HOÀN TẤT NẠP DỮ LIỆU LỚN CHO 20 BẢNG TRONG ' + CAST(@ElapsedSec AS NVARCHAR(10)) + N' GIÂY! ===';
END;
GO

-- Thực thi thủ tục nạp dữ liệu
EXEC dbo.sp_Seed_FitLifeHub_BigData;
GO

-- Bật lại toàn bộ Trigger trên tất cả các bảng sau khi nạp xong
EXEC sp_MSforeachtable 'ENABLE TRIGGER ALL ON ?';
GO


-- ============================================================================
--  LỆNH EXEC TEST & ĐO HIỆU NĂNG (SET STATISTICS TIME, IO ON)
-- ============================================================================

/*
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT
    ROW_NUMBER() OVER (ORDER BY NhomThuTu, STT) AS [STT],
    TenBang AS [Tên Bảng],
    NhomBang AS [Phân Nhóm],
    SoDong AS [Số Lượng Dòng]
FROM (
    SELECT 1 AS NhomThuTu, 1  AS STT, N'HANG_HOI_VIEN'       AS TenBang, N'1. Danh mục gốc'      AS NhomBang, COUNT(*) AS SoDong FROM HANG_HOI_VIEN
    UNION ALL
    SELECT 1, 2,  N'CHI_NHANH',           N'1. Danh mục gốc',      COUNT(*) FROM CHI_NHANH
    UNION ALL
    SELECT 1, 3,  N'DICH_VU',             N'1. Danh mục gốc',      COUNT(*) FROM DICH_VU
    UNION ALL
    SELECT 1, 4,  N'SAN_PHAM',            N'1. Danh mục gốc',      COUNT(*) FROM SAN_PHAM
    UNION ALL
    SELECT 1, 5,  N'GOI_DICH_VU',         N'1. Danh mục gốc',      COUNT(*) FROM GOI_DICH_VU
    UNION ALL
    SELECT 2, 6,  N'CHI_NHANH_DICH_VU',   N'2. Danh mục & Hồ sơ',  COUNT(*) FROM CHI_NHANH_DICH_VU
    UNION ALL
    SELECT 2, 7,  N'NHAN_VIEN',           N'2. Danh mục & Hồ sơ',  COUNT(*) FROM NHAN_VIEN
    UNION ALL
    SELECT 2, 8,  N'LICH_SU_CONG_TAC',    N'2. Danh mục & Hồ sơ',  COUNT(*) FROM LICH_SU_CONG_TAC
    UNION ALL
    SELECT 2, 9,  N'HOI_VIEN',            N'2. Danh mục & Hồ sơ',  COUNT(*) FROM HOI_VIEN
    UNION ALL
    SELECT 2, 10, N'TON_KHO',             N'2. Danh mục & Hồ sơ',  COUNT(*) FROM TON_KHO
    UNION ALL
    SELECT 3, 11, N'HOA_DON',             N'3. Giao dịch lớn',     COUNT(*) FROM HOA_DON
    UNION ALL
    SELECT 3, 12, N'CHI_TIET_HOA_DON',    N'3. Giao dịch lớn',     COUNT(*) FROM CHI_TIET_HOA_DON
    UNION ALL
    SELECT 3, 13, N'THANH_TOAN',          N'3. Giao dịch lớn',     COUNT(*) FROM THANH_TOAN
    UNION ALL
    SELECT 3, 14, N'DANG_KY_GOI',         N'3. Giao dịch lớn',     COUNT(*) FROM DANG_KY_GOI
    UNION ALL
    SELECT 3, 15, N'CHECK_IN',            N'3. Giao dịch lớn',     COUNT(*) FROM CHECK_IN
    UNION ALL
    SELECT 3, 16, N'LICH_HEN_PT',         N'3. Giao dịch lớn',     COUNT(*) FROM LICH_HEN_PT
    UNION ALL
    SELECT 4, 17, N'LICH_SU_SU_DUNG_PT',  N'4. Nhật ký phụ thuộc', COUNT(*) FROM LICH_SU_SU_DUNG_PT
    UNION ALL
    SELECT 4, 18, N'LICH_SU_KHO',         N'4. Nhật ký phụ thuộc', COUNT(*) FROM LICH_SU_KHO
    UNION ALL
    SELECT 4, 19, N'LICH_SU_DIEM',        N'4. Nhật ký phụ thuộc', COUNT(*) FROM LICH_SU_DIEM
    UNION ALL
    SELECT 4, 20, N'LICH_SU_HANG',        N'4. Nhật ký phụ thuộc', COUNT(*) FROM LICH_SU_HANG
) AS ThongKe;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
*/
