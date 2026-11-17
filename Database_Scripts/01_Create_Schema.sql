USE master;
GO

IF DB_ID(N'FitLifeHub') IS NOT NULL
BEGIN
    ALTER DATABASE FitLifeHub SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE FitLifeHub;
END
GO

CREATE DATABASE FitLifeHub;
GO

USE FitLifeHub;
GO

/* ============================================================================
   PHẦN 1: TẠO 20 BẢNG QUAN HỆ (KHÓA CHÍNH & KHÓA NGOẠI)
============================================================================ */

-- 1. CHI_NHANH
CREATE TABLE CHI_NHANH (
    MaCN         VARCHAR(10)   NOT NULL,
    TenCN        NVARCHAR(100) NOT NULL,
    DiaChi       NVARCHAR(255) NOT NULL,
    SoDienThoai  VARCHAR(20)   NOT NULL,
    GioMoCua     TIME          NOT NULL,
    GioDongCua   TIME          NOT NULL,
    TrangThai    NVARCHAR(20)  NOT NULL DEFAULT N'Hoạt động',

    CONSTRAINT PK_CHI_NHANH PRIMARY KEY (MaCN)
);
GO

-- 2. DICH_VU
CREATE TABLE DICH_VU (
    MaDV       VARCHAR(10)   NOT NULL,
    TenDV      NVARCHAR(100) NOT NULL,
    LoaiDV     NVARCHAR(30)  NOT NULL,
    MoTa       NVARCHAR(255) NULL,
    TrangThai  NVARCHAR(20)  NOT NULL DEFAULT N'Đang cung cấp',

    CONSTRAINT PK_DICH_VU PRIMARY KEY (MaDV)
);
GO

-- 3. CHI_NHANH_DICH_VU
CREATE TABLE CHI_NHANH_DICH_VU (
    MaCN         VARCHAR(10) NOT NULL,
    MaDV         VARCHAR(10) NOT NULL,
    NgayBatDau   DATE        NOT NULL,
    NgayKetThuc  DATE        NULL,

    CONSTRAINT PK_CHI_NHANH_DICH_VU PRIMARY KEY (MaCN, MaDV),
    CONSTRAINT FK_CNDV_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN),
    CONSTRAINT FK_CNDV_DICHVU FOREIGN KEY (MaDV) REFERENCES DICH_VU(MaDV)
);
GO

-- 4. HANG_HOI_VIEN
CREATE TABLE HANG_HOI_VIEN (
    MaHang           VARCHAR(10)    NOT NULL,
    TenHang          NVARCHAR(30)   NOT NULL,
    ChiTieuToiThieu  DECIMAL(18, 2) NOT NULL,
    MoTa             NVARCHAR(255)  NULL,

    CONSTRAINT PK_HANG_HOI_VIEN PRIMARY KEY (MaHang)
);
GO

-- 5. HOI_VIEN
CREATE TABLE HOI_VIEN (
    MaHV            BIGINT IDENTITY(1,1) NOT NULL,
    HoTen           NVARCHAR(100)        NOT NULL,
    SoDienThoai     VARCHAR(20)          NOT NULL,
    Email           VARCHAR(254)         NULL,
    CCCD            VARCHAR(20)          NOT NULL,
    GioiTinh        NVARCHAR(20)         NULL,
    NgaySinh        DATE                 NULL,
    NgayDangKy      DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    TrangThai       NVARCHAR(20)         NOT NULL DEFAULT N'Hoạt động',
    DiemTichLuy     INT                  NOT NULL DEFAULT 0,
    TongChiTieuNam  DECIMAL(18, 2)       NOT NULL DEFAULT 0,
    MaHang          VARCHAR(10)          NOT NULL DEFAULT 'SILVER',

    CONSTRAINT PK_HOI_VIEN PRIMARY KEY (MaHV),
    CONSTRAINT FK_HOIVIEN_HANG FOREIGN KEY (MaHang) REFERENCES HANG_HOI_VIEN(MaHang)
);
GO

-- 6. GOI_DICH_VU
CREATE TABLE GOI_DICH_VU (
    MaGoi         VARCHAR(10)    NOT NULL,
    TenGoi        NVARCHAR(100)  NOT NULL,
    LoaiGoi       NVARCHAR(30)   NOT NULL,
    ThoiHanThang  INT            NULL,
    SoBuoiPT      INT            NULL,
    GiaTien       DECIMAL(18, 2) NOT NULL,
    TrangThai     NVARCHAR(20)   NOT NULL DEFAULT N'Đang kinh doanh',

    CONSTRAINT PK_GOI_DICH_VU PRIMARY KEY (MaGoi)
);
GO

-- 7. NHAN_VIEN
CREATE TABLE NHAN_VIEN (
    MaNV         BIGINT IDENTITY(1,1) NOT NULL,
    HoTen        NVARCHAR(100)        NOT NULL,
    SoDienThoai  VARCHAR(20)          NOT NULL,
    ChucVu       NVARCHAR(50)         NOT NULL,
    LuongCoBan   DECIMAL(18, 2)       NOT NULL,
    NgayVaoLam   DATE                 NOT NULL,
    TrangThai    NVARCHAR(20)         NOT NULL DEFAULT N'Đang làm',
    MaCNHienTai  VARCHAR(10)          NOT NULL,

    CONSTRAINT PK_NHAN_VIEN PRIMARY KEY (MaNV),
    CONSTRAINT FK_NHANVIEN_CHINHANH FOREIGN KEY (MaCNHienTai) REFERENCES CHI_NHANH(MaCN)
);
GO

-- 8. LICH_SU_CONG_TAC
CREATE TABLE LICH_SU_CONG_TAC (
    MaLSCT       BIGINT IDENTITY(1,1) NOT NULL,
    ChucVu       NVARCHAR(50)         NOT NULL,
    LuongCoBan   DECIMAL(18, 2)       NOT NULL,
    NgayBatDau   DATE                 NOT NULL,
    NgayKetThuc  DATE                 NULL,
    MaNV         BIGINT               NOT NULL,
    MaCN         VARCHAR(10)          NOT NULL,

    CONSTRAINT PK_LICH_SU_CONG_TAC PRIMARY KEY (MaLSCT),
    CONSTRAINT FK_LSCT_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT FK_LSCT_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN)
);
GO

-- 9. SAN_PHAM
CREATE TABLE SAN_PHAM (
    MaSP       VARCHAR(10)    NOT NULL,
    TenSP      NVARCHAR(100)  NOT NULL,
    LoaiSP     NVARCHAR(50)   NOT NULL,
    DonViTinh  NVARCHAR(20)   NOT NULL,
    GiaBan     DECIMAL(18, 2) NOT NULL,
    TrangThai  NVARCHAR(20)   NOT NULL DEFAULT N'Đang kinh doanh',

    CONSTRAINT PK_SAN_PHAM PRIMARY KEY (MaSP)
);
GO

-- 10. TON_KHO
CREATE TABLE TON_KHO (
    MaCN            VARCHAR(10) NOT NULL,
    MaSP            VARCHAR(10) NOT NULL,
    SoLuongTon      INT         NOT NULL DEFAULT 0,
    MucTonToiThieu  INT         NOT NULL DEFAULT 5,
    NgayCapNhat     DATETIME2   NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_TON_KHO PRIMARY KEY (MaCN, MaSP),
    CONSTRAINT FK_TONKHO_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN),
    CONSTRAINT FK_TONKHO_SANPHAM FOREIGN KEY (MaSP) REFERENCES SAN_PHAM(MaSP)
);
GO

-- 11. HOA_DON
CREATE TABLE HOA_DON (
    MaHD       BIGINT IDENTITY(1,1) NOT NULL,
    NgayLap    DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    TongTien   DECIMAL(18, 2)       NOT NULL DEFAULT 0,
    GiamGia    DECIMAL(18, 2)       NOT NULL DEFAULT 0,
    ThanhTien  DECIMAL(18, 2)       NOT NULL DEFAULT 0,
    TrangThai  NVARCHAR(20)         NOT NULL DEFAULT N'Chờ thanh toán',
    MaCN       VARCHAR(10)          NOT NULL,
    MaNV       BIGINT               NOT NULL,
    MaHV       BIGINT               NULL,

    CONSTRAINT PK_HOA_DON PRIMARY KEY NONCLUSTERED (MaHD),
    CONSTRAINT FK_HOADON_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN),
    CONSTRAINT FK_HOADON_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT FK_HOADON_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV)
);
GO

-- 12. CHI_TIET_HOA_DON
CREATE TABLE CHI_TIET_HOA_DON (
    MaCTHD     BIGINT IDENTITY(1,1) NOT NULL,
    SoLuong    INT                  NOT NULL,
    DonGia     DECIMAL(18, 2)       NOT NULL,
    ThanhTien  DECIMAL(18, 2)       NOT NULL,
    MaHD       BIGINT               NOT NULL,
    MaGoi      VARCHAR(10)          NULL,
    MaSP       VARCHAR(10)          NULL,

    CONSTRAINT PK_CHI_TIET_HOA_DON PRIMARY KEY (MaCTHD),
    CONSTRAINT FK_CTHD_HOADON FOREIGN KEY (MaHD) REFERENCES HOA_DON(MaHD),
    CONSTRAINT FK_CTHD_GOIDV FOREIGN KEY (MaGoi) REFERENCES GOI_DICH_VU(MaGoi),
    CONSTRAINT FK_CTHD_SANPHAM FOREIGN KEY (MaSP) REFERENCES SAN_PHAM(MaSP)
);
GO

-- 13. THANH_TOAN
CREATE TABLE THANH_TOAN (
    MaTT             BIGINT IDENTITY(1,1) NOT NULL,
    ThoiGianTT       DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    SoTien           DECIMAL(18, 2)       NOT NULL,
    HinhThucTT       NVARCHAR(30)         NOT NULL,
    MaGiaoDichNgoai  VARCHAR(100)         NULL,
    TrangThaiTT      NVARCHAR(20)         NOT NULL DEFAULT N'Đang xử lý',
    MaHD             BIGINT               NOT NULL,

    CONSTRAINT PK_THANH_TOAN PRIMARY KEY (MaTT),
    CONSTRAINT FK_THANHTOAN_HOADON FOREIGN KEY (MaHD) REFERENCES HOA_DON(MaHD)
);
GO

-- 14. DANG_KY_GOI
CREATE TABLE DANG_KY_GOI (
    MaDK          BIGINT IDENTITY(1,1) NOT NULL,
    NgayBatDau    DATE                 NOT NULL,
    NgayKetThuc   DATE                 NOT NULL,
    SoBuoiConLai  INT                  NULL,
    TrangThai     NVARCHAR(20)         NOT NULL DEFAULT N'Đang hiệu lực',
    MaHV          BIGINT               NOT NULL,
    MaGoi         VARCHAR(10)          NOT NULL,
    MaHD          BIGINT               NULL,

    CONSTRAINT PK_DANG_KY_GOI PRIMARY KEY (MaDK),
    CONSTRAINT FK_DKGOI_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV),
    CONSTRAINT FK_DKGOI_GOIDV FOREIGN KEY (MaGoi) REFERENCES GOI_DICH_VU(MaGoi),
    CONSTRAINT FK_DKGOI_HOADON FOREIGN KEY (MaHD) REFERENCES HOA_DON(MaHD)
);
GO

-- 15. LICH_SU_KHO
CREATE TABLE LICH_SU_KHO (
    MaGiaoDichKho   BIGINT IDENTITY(1,1) NOT NULL,
    LoaiGiaoDich    NVARCHAR(20)         NOT NULL,
    SoLuongThayDoi  INT                  NOT NULL,
    ThoiGian        DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    GhiChu          NVARCHAR(255)        NULL,
    MaCN            VARCHAR(10)          NOT NULL,
    MaSP            VARCHAR(10)          NOT NULL,
    MaNV            BIGINT               NOT NULL,
    MaHD            BIGINT               NULL,

    CONSTRAINT PK_LICH_SU_KHO PRIMARY KEY (MaGiaoDichKho),
    CONSTRAINT FK_LSKHO_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN),
    CONSTRAINT FK_LSKHO_SANPHAM FOREIGN KEY (MaSP) REFERENCES SAN_PHAM(MaSP),
    CONSTRAINT FK_LSKHO_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT FK_LSKHO_HOADON FOREIGN KEY (MaHD) REFERENCES HOA_DON(MaHD)
);
GO

-- 16. CHECK_IN
CREATE TABLE CHECK_IN (
    MaCheckIn      BIGINT IDENTITY(1,1) NOT NULL,
    ThoiGianVao    DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    ThoiGianRa     DATETIME2            NULL,
    MaThietBi      VARCHAR(30)          NULL,
    KetQuaXacThuc  NVARCHAR(20)         NOT NULL,
    MaHV           BIGINT               NOT NULL,
    MaCN           VARCHAR(10)          NOT NULL,

    CONSTRAINT PK_CHECK_IN PRIMARY KEY NONCLUSTERED (MaCheckIn),
    CONSTRAINT FK_CHECKIN_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV),
    CONSTRAINT FK_CHECKIN_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN)
);
GO

-- 17. LICH_HEN_PT
CREATE TABLE LICH_HEN_PT (
    MaLich           BIGINT IDENTITY(1,1) NOT NULL,
    ThoiGianBatDau   DATETIME2            NOT NULL,
    ThoiGianKetThuc  DATETIME2            NOT NULL,
    TrangThai        NVARCHAR(20)         NOT NULL DEFAULT N'Đã đặt',
    MaHV             BIGINT               NOT NULL,
    MaNV             BIGINT               NOT NULL,
    MaCN             VARCHAR(10)          NOT NULL,
    MaDK             BIGINT               NOT NULL,

    CONSTRAINT PK_LICH_HEN_PT PRIMARY KEY (MaLich),
    CONSTRAINT FK_LICHHEN_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV),
    CONSTRAINT FK_LICHHEN_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHAN_VIEN(MaNV),
    CONSTRAINT FK_LICHHEN_CHINHANH FOREIGN KEY (MaCN) REFERENCES CHI_NHANH(MaCN),
    CONSTRAINT FK_LICHHEN_DKGOI FOREIGN KEY (MaDK) REFERENCES DANG_KY_GOI(MaDK)
);
GO

-- 18. LICH_SU_SU_DUNG_PT
CREATE TABLE LICH_SU_SU_DUNG_PT (
    MaSuDung         BIGINT IDENTITY(1,1) NOT NULL,
    ThoiDiemXacNhan  DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    SoBuoiSuDung     INT                  NOT NULL DEFAULT 1,
    GhiChu           NVARCHAR(255)        NULL,
    MaLich           BIGINT               NOT NULL,
    MaDK             BIGINT               NOT NULL,

    CONSTRAINT PK_LICH_SU_SU_DUNG_PT PRIMARY KEY (MaSuDung),
    CONSTRAINT FK_LSSDPT_LICHHEN FOREIGN KEY (MaLich) REFERENCES LICH_HEN_PT(MaLich),
    CONSTRAINT FK_LSSDPT_DKGOI FOREIGN KEY (MaDK) REFERENCES DANG_KY_GOI(MaDK)
);
GO

-- 19. LICH_SU_DIEM
CREATE TABLE LICH_SU_DIEM (
    MaLS_Diem     BIGINT IDENTITY(1,1) NOT NULL,
    ThoiGian      DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    LoaiGiaoDich  NVARCHAR(20)         NOT NULL,
    SoDiem        INT                  NOT NULL,
    GhiChu        NVARCHAR(255)        NULL,
    MaHV          BIGINT               NOT NULL,
    MaHD          BIGINT               NULL,

    CONSTRAINT PK_LICH_SU_DIEM PRIMARY KEY (MaLS_Diem),
    CONSTRAINT FK_LSD_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV),
    CONSTRAINT FK_LSD_HOADON FOREIGN KEY (MaHD) REFERENCES HOA_DON(MaHD)
);
GO

-- 20. LICH_SU_HANG
CREATE TABLE LICH_SU_HANG (
    MaLSHang     BIGINT IDENTITY(1,1) NOT NULL,
    NamXetHang   INT                  NOT NULL,
    TongChiTieu  DECIMAL(18, 2)       NOT NULL,
    NgayCapNhat  DATETIME2            NOT NULL DEFAULT SYSDATETIME(),
    MaHV         BIGINT               NOT NULL,
    MaHang       VARCHAR(10)          NOT NULL,

    CONSTRAINT PK_LICH_SU_HANG PRIMARY KEY (MaLSHang),
    CONSTRAINT FK_LSH_HOIVIEN FOREIGN KEY (MaHV) REFERENCES HOI_VIEN(MaHV),
    CONSTRAINT FK_LSH_HANG FOREIGN KEY (MaHang) REFERENCES HANG_HOI_VIEN(MaHang)
);
GO


/* ============================================================================
   PHẦN 2: CÀI ĐẶT TOÀN BỘ RBTV TĨNH (UNIQUE & CHECK) THEO BÁO CÁO ĐỢT 1
   Tổng cộng: 56 ràng buộc (8 UNIQUE / Filtered Index + 48 CHECK)
============================================================================ */

/* --- 2.1. NHÓM RÀNG BUỘC DUY NHẤT (UNIQUE / FILTERED INDEX) --- */

-- 1. RBTV01: CCCD hội viên duy nhất
ALTER TABLE HOI_VIEN
ADD CONSTRAINT UQ_HOIVIEN_CCCD_RBTV01 UNIQUE (CCCD);
GO

-- 2. RBTV02: Tên hạng hội viên duy nhất
ALTER TABLE HANG_HOI_VIEN
ADD CONSTRAINT UQ_HANGHV_TenHang_RBTV02 UNIQUE (TenHang);
GO

-- 3. RBTV03: Mỗi lịch hẹn chỉ được ghi nhận sử dụng một lần
ALTER TABLE LICH_SU_SU_DUNG_PT
ADD CONSTRAINT UQ_LSSDPT_MaLich_RBTV03 UNIQUE (MaLich);
GO

-- 4. RBTV04: Mỗi hội viên có một kết quả hạng cho mỗi năm xét hạng
ALTER TABLE LICH_SU_HANG
ADD CONSTRAINT UQ_LSH_MaHV_Nam_RBTV04 UNIQUE (MaHV, NamXetHang);
GO

-- 5. RBTV05: Mã giao dịch ngoài không bị ghi nhận lặp (khi khác NULL)
CREATE UNIQUE NONCLUSTERED INDEX UQ_THANHTOAN_MaGDNgoai_RBTV05
ON THANH_TOAN(MaGiaoDichNgoai)
WHERE MaGiaoDichNgoai IS NOT NULL;
GO

-- 6. RBTV06: Mỗi hóa đơn chỉ được cộng điểm một lần
CREATE UNIQUE NONCLUSTERED INDEX UQ_LSD_CongDiemMoiHD_RBTV06
ON LICH_SU_DIEM(MaHD)
WHERE LoaiGiaoDich = N'Cộng' AND MaHD IS NOT NULL;
GO

-- 7. RBTV10: Mỗi nhân viên có tối đa một bản ghi công tác đang hiệu lực
CREATE UNIQUE NONCLUSTERED INDEX UQ_LSCT_DangHieuLuc_RBTV10
ON LICH_SU_CONG_TAC(MaNV)
WHERE NgayKetThuc IS NULL;
GO

-- 8. Khóa dự tuyển (MaNV, NgayBatDau) của LICH_SU_CONG_TAC (Mục 4.2.2)
ALTER TABLE LICH_SU_CONG_TAC
ADD CONSTRAINT UQ_LSCT_MaNV_NgayBatDau UNIQUE (MaNV, NgayBatDau);
GO


/* --- 2.2. NHÓM RÀNG BUỘC MIỀN GIÁ TRỊ & LIÊN THUỘC TÍNH (CHECK) --- */

-- 9. RBTV14: Trạng thái chi nhánh
ALTER TABLE CHI_NHANH
ADD CONSTRAINT CK_CHINHANH_TrangThai_RBTV14 CHECK (TrangThai IN (N'Hoạt động', N'Tạm ngưng', N'Đóng cửa'));
GO

-- 10. RBTV15 (Bảng 1/3): Định dạng số điện thoại chi nhánh
ALTER TABLE CHI_NHANH
ADD CONSTRAINT CK_CHINHANH_SDT_RBTV15 CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
GO

-- 11. RBTV15 (Bảng 2/3): Định dạng số điện thoại hội viên
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_SDT_RBTV15 CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
GO

-- 12. RBTV15 (Bảng 3/3): Định dạng số điện thoại nhân viên
ALTER TABLE NHAN_VIEN
ADD CONSTRAINT CK_NHANVIEN_SDT_RBTV15 CHECK (SoDienThoai LIKE '0[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
GO

-- 13. RBTV16a: Loại dịch vụ
ALTER TABLE DICH_VU
ADD CONSTRAINT CK_DICHVU_LoaiDV_RBTV16 CHECK (LoaiDV IN (N'Gym', N'Yoga', N'GroupX', N'PT', N'Spa'));
GO

-- 14. RBTV16b: Trạng thái dịch vụ
ALTER TABLE DICH_VU
ADD CONSTRAINT CK_DICHVU_TrangThai_RBTV16 CHECK (TrangThai IN (N'Đang cung cấp', N'Ngừng cung cấp'));
GO

-- 15. RBTV17: Giới tính hội viên
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_GioiTinh_RBTV17 CHECK (GioiTinh IS NULL OR GioiTinh IN (N'Nam', N'Nữ'));
GO

-- 16. RBTV18: Định dạng email hội viên
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_Email_RBTV18 CHECK (Email IS NULL OR Email LIKE '%_@__%.__%');
GO

-- 17. RBTV19: Định dạng CCCD hội viên (12 chữ số)
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_CCCD_RBTV19 CHECK (CCCD LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]');
GO

-- 18. RBTV20: Trạng thái hội viên
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_TrangThai_RBTV20 CHECK (TrangThai IN (N'Hoạt động', N'Ngưng'));
GO

-- 19. RBTV21: Loại gói dịch vụ
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_LoaiGoi_RBTV21 CHECK (LoaiGoi IN (N'Gym', N'Yoga', N'PT', N'Spa'));
GO

-- 20. RBTV22: Số buổi PT của gói
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_SoBuoiPT_RBTV22 CHECK (SoBuoiPT IS NULL OR SoBuoiPT > 0);
GO

-- 21. RBTV23: Giá gói không âm
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_GiaTien_RBTV23 CHECK (GiaTien >= 0);
GO

-- 22. RBTV24: Số buổi còn lại không âm
ALTER TABLE DANG_KY_GOI
ADD CONSTRAINT CK_DKGOI_SoBuoiConLai_RBTV24 CHECK (SoBuoiConLai IS NULL OR SoBuoiConLai >= 0);
GO

-- 23. RBTV25: Trạng thái đăng ký gói
ALTER TABLE DANG_KY_GOI
ADD CONSTRAINT CK_DKGOI_TrangThai_RBTV25 CHECK (TrangThai IN (N'Đang hiệu lực', N'Hết hạn', N'Tạm dừng', N'Đã hủy'));
GO

-- 24. RBTV26: Kết quả xác thực check-in
ALTER TABLE CHECK_IN
ADD CONSTRAINT CK_CHECKIN_KetQua_RBTV26 CHECK (KetQuaXacThuc IN (N'Hợp lệ', N'Từ chối'));
GO

-- 25. RBTV27: Trạng thái lịch hẹn PT
ALTER TABLE LICH_HEN_PT
ADD CONSTRAINT CK_LICHHEN_TrangThai_RBTV27 CHECK (TrangThai IN (N'Đã đặt', N'Đã hoàn thành', N'Hủy'));
GO

-- 26. RBTV28: Số buổi sử dụng
ALTER TABLE LICH_SU_SU_DUNG_PT
ADD CONSTRAINT CK_LSSDPT_SoBuoi_RBTV28 CHECK (SoBuoiSuDung > 0);
GO

-- 27. RBTV29 (Bảng 1/2): Lương cơ bản dương (NHAN_VIEN)
ALTER TABLE NHAN_VIEN
ADD CONSTRAINT CK_NHANVIEN_Luong_RBTV29 CHECK (LuongCoBan > 0);
GO

-- 28. RBTV29 (Bảng 2/2): Lương cơ bản dương (LICH_SU_CONG_TAC)
ALTER TABLE LICH_SU_CONG_TAC
ADD CONSTRAINT CK_LSCT_Luong_RBTV29 CHECK (LuongCoBan > 0);
GO

-- 29. RBTV30: Trạng thái nhân viên
ALTER TABLE NHAN_VIEN
ADD CONSTRAINT CK_NHANVIEN_TrangThai_RBTV30 CHECK (TrangThai IN (N'Đang làm', N'Tạm nghỉ', N'Nghỉ việc'));
GO

-- 30. RBTV31: Các khoản tiền của hóa đơn không âm
ALTER TABLE HOA_DON
ADD CONSTRAINT CK_HOADON_Tien_RBTV31 CHECK (TongTien >= 0 AND GiamGia >= 0 AND ThanhTien >= 0);
GO

-- 31. RBTV32: Trạng thái hóa đơn
ALTER TABLE HOA_DON
ADD CONSTRAINT CK_HOADON_TrangThai_RBTV32 CHECK (TrangThai IN (N'Chờ thanh toán', N'Đã thanh toán', N'Thất bại', N'Đã hủy'));
GO

-- 32. RBTV33: Số lượng, đơn giá, thành tiền dòng chi tiết
ALTER TABLE CHI_TIET_HOA_DON
ADD CONSTRAINT CK_CTHD_SoLuong_Gia_RBTV33 CHECK (SoLuong > 0 AND DonGia >= 0 AND ThanhTien >= 0);
GO

-- 33. RBTV34: Số tiền thanh toán dương
ALTER TABLE THANH_TOAN
ADD CONSTRAINT CK_THANHTOAN_SoTien_RBTV34 CHECK (SoTien > 0);
GO

-- 34. RBTV35: Hình thức thanh toán
ALTER TABLE THANH_TOAN
ADD CONSTRAINT CK_THANHTOAN_HinhThuc_RBTV35 CHECK (HinhThucTT IN (N'Tiền mặt', N'VNPay', N'Thẻ'));
GO

-- 35. RBTV36: Trạng thái thanh toán
ALTER TABLE THANH_TOAN
ADD CONSTRAINT CK_THANHTOAN_TrangThai_RBTV36 CHECK (TrangThaiTT IN (N'Thành công', N'Thất bại', N'Đang xử lý', N'Đã hủy'));
GO

-- 36. RBTV37a: Giá bán sản phẩm không âm
ALTER TABLE SAN_PHAM
ADD CONSTRAINT CK_SANPHAM_GiaBan_RBTV37 CHECK (GiaBan >= 0);
GO

-- 37. RBTV37b: Trạng thái sản phẩm
ALTER TABLE SAN_PHAM
ADD CONSTRAINT CK_SANPHAM_TrangThai_RBTV37 CHECK (TrangThai IN (N'Đang kinh doanh', N'Ngừng kinh doanh'));
GO

-- 38. RBTV38: Tồn kho không âm và mức tồn tối thiểu dương
ALTER TABLE TON_KHO
ADD CONSTRAINT CK_TONKHO_SoLuong_RBTV38 CHECK (SoLuongTon >= 0 AND MucTonToiThieu > 0);
GO

-- 39. RBTV39: Loại giao dịch kho
ALTER TABLE LICH_SU_KHO
ADD CONSTRAINT CK_LSKHO_LoaiGD_RBTV39 CHECK (LoaiGiaoDich IN (N'Nhập', N'Xuất', N'Điều chỉnh'));
GO

-- 40. RBTV40: Loại giao dịch điểm
ALTER TABLE LICH_SU_DIEM
ADD CONSTRAINT CK_LSD_LoaiGD_RBTV40 CHECK (LoaiGiaoDich IN (N'Cộng', N'Trừ'));
GO

-- 41. RBTV41a: Tên hạng hội viên hợp lệ
ALTER TABLE HANG_HOI_VIEN
ADD CONSTRAINT CK_HANGHV_TenHang_RBTV41 CHECK (TenHang IN (N'Silver', N'Gold', N'Platinum'));
GO

-- 42. RBTV41b: Ngưỡng chi tiêu tối thiểu của hạng không âm
ALTER TABLE HANG_HOI_VIEN
ADD CONSTRAINT CK_HANGHV_ChiTieu_RBTV41 CHECK (ChiTieuToiThieu >= 0);
GO

-- 43. RBTV42: Tổng chi tiêu và năm xét hạng
ALTER TABLE LICH_SU_HANG
ADD CONSTRAINT CK_LSH_ChiTieu_Nam_RBTV42 CHECK (TongChiTieu >= 0 AND NamXetHang <= YEAR(GETDATE()));
GO

-- 44. RBTV43: Giờ mở cửa trước giờ đóng cửa
ALTER TABLE CHI_NHANH
ADD CONSTRAINT CK_CHINHANH_GioHoatDong_RBTV43 CHECK (GioMoCua < GioDongCua);
GO

-- 45. RBTV44: Ngày kết thúc cung cấp dịch vụ không trước ngày bắt đầu
ALTER TABLE CHI_NHANH_DICH_VU
ADD CONSTRAINT CK_CNDV_ThoiGian_RBTV44 CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);
GO

-- 46. RBTV45: Ngày sinh trước ngày đăng ký hội viên
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_NgaySinh_RBTV45 CHECK (NgaySinh IS NULL OR NgaySinh < CAST(NgayDangKy AS DATE));
GO

-- 47. RBTV46: Chỉ gói PT mới có số buổi PT
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_PT_RBTV46 CHECK (
    (LoaiGoi = N'PT' AND SoBuoiPT IS NOT NULL) OR
    (LoaiGoi <> N'PT' AND SoBuoiPT IS NULL)
);
GO

-- 48. RBTV47: Gói Gym và Yoga phải có thời hạn
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_ThoiHan_RBTV47 CHECK (
    (LoaiGoi NOT IN (N'Gym', N'Yoga') OR ThoiHanThang IS NOT NULL) AND
    (ThoiHanThang IS NULL OR ThoiHanThang > 0)
);
GO

-- 49. RBTV48: Ngày kết thúc đăng ký gói không trước ngày bắt đầu
ALTER TABLE DANG_KY_GOI
ADD CONSTRAINT CK_DKGOI_ThoiGian_RBTV48 CHECK (NgayKetThuc >= NgayBatDau);
GO

-- 50. RBTV49: Thời gian ra không trước thời gian vào
ALTER TABLE CHECK_IN
ADD CONSTRAINT CK_CHECKIN_ThoiGian_RBTV49 CHECK (ThoiGianRa IS NULL OR ThoiGianRa >= ThoiGianVao);
GO

-- 51. RBTV50: Thời điểm kết thúc lịch PT sau thời điểm bắt đầu
ALTER TABLE LICH_HEN_PT
ADD CONSTRAINT CK_LICHHEN_ThoiGian_RBTV50 CHECK (ThoiGianKetThuc > ThoiGianBatDau);
GO

-- 52. RBTV51: Thành tiền hóa đơn bằng tổng tiền trừ giảm giá
ALTER TABLE HOA_DON
ADD CONSTRAINT CK_HOADON_ThanhTien_RBTV51 CHECK (ThanhTien = TongTien - GiamGia);
GO

-- 53. RBTV52: Giảm giá không vượt tổng tiền
ALTER TABLE HOA_DON
ADD CONSTRAINT CK_HOADON_GiamGia_RBTV52 CHECK (GiamGia <= TongTien);
GO

-- 54. RBTV53: Mỗi dòng chi tiết bán đúng một gói hoặc đúng một sản phẩm
ALTER TABLE CHI_TIET_HOA_DON
ADD CONSTRAINT CK_CTHD_LoaiHang_RBTV53 CHECK (
    (MaGoi IS NOT NULL AND MaSP IS NULL) OR
    (MaGoi IS NULL AND MaSP IS NOT NULL)
);
GO

-- 55. RBTV54: Thành tiền dòng chi tiết bằng số lượng nhân đơn giá
ALTER TABLE CHI_TIET_HOA_DON
ADD CONSTRAINT CK_CTHD_ThanhTien_RBTV54 CHECK (ThanhTien = SoLuong * DonGia);
GO

-- 56. RBTV55: Thanh toán VNPay hoặc thẻ phải có mã giao dịch ngoài
ALTER TABLE THANH_TOAN
ADD CONSTRAINT CK_THANHTOAN_MaGDNgoai_RBTV55 CHECK (HinhThucTT NOT IN (N'VNPay', N'Thẻ') OR MaGiaoDichNgoai IS NOT NULL);
GO

-- 57. RBTV56: Dấu của số lượng thay đổi theo loại giao dịch kho
ALTER TABLE LICH_SU_KHO
ADD CONSTRAINT CK_LSKHO_DauSoLuong_RBTV56 CHECK (
    (LoaiGiaoDich = N'Nhập' AND SoLuongThayDoi > 0) OR
    (LoaiGiaoDich = N'Xuất' AND SoLuongThayDoi < 0) OR
    (LoaiGiaoDich = N'Điều chỉnh' AND SoLuongThayDoi <> 0)
);
GO

-- 58. RBTV57: Hóa đơn gắn với giao dịch kho
ALTER TABLE LICH_SU_KHO
ADD CONSTRAINT CK_LSKHO_MaHD_RBTV57 CHECK (LoaiGiaoDich NOT IN (N'Nhập', N'Điều chỉnh') OR MaHD IS NULL);
GO

-- 59. RBTV58: Dấu của số điểm theo loại giao dịch điểm
ALTER TABLE LICH_SU_DIEM
ADD CONSTRAINT CK_LSD_DauDiem_RBTV58 CHECK (
    (LoaiGiaoDich = N'Cộng' AND SoDiem > 0 AND MaHD IS NOT NULL) OR
    (LoaiGiaoDich = N'Trừ' AND SoDiem < 0)
);
GO

-- 60. RBTV59: Ngày kết thúc công tác không trước ngày bắt đầu
ALTER TABLE LICH_SU_CONG_TAC
ADD CONSTRAINT CK_LSCT_ThoiGian_RBTV59 CHECK (NgayKetThuc IS NULL OR NgayKetThuc >= NgayBatDau);
GO


/* --- 2.3. CÁC RÀNG BUỘC MIỀN GIÁ TRỊ BỔ SUNG (CHO CÁC CỘT TRẠNG THÁI/TỔNG HỢP) --- */

-- 61. Bổ sung miền giá trị cho các cột tổng hợp trên HOI_VIEN
ALTER TABLE HOI_VIEN
ADD CONSTRAINT CK_HOIVIEN_ChiTieu_Diem CHECK (TongChiTieuNam >= 0 AND DiemTichLuy >= 0);
GO

-- 62. Bổ sung miền giá trị trạng thái kinh doanh trên GOI_DICH_VU
ALTER TABLE GOI_DICH_VU
ADD CONSTRAINT CK_GOIDV_TrangThai CHECK (TrangThai IN (N'Đang kinh doanh', N'Ngừng kinh doanh'));
GO

-- 63. Bổ sung miền giá trị chức vụ trên NHAN_VIEN
ALTER TABLE NHAN_VIEN
ADD CONSTRAINT CK_NHANVIEN_ChucVu CHECK (ChucVu IN (N'HLV', N'Lễ tân', N'Quản lý chi nhánh', N'Nhân viên bán hàng'));
GO


/* ============================================================================
   DỮ LIỆU DANH MỤC HẠNG HỘI VIÊN MẶC ĐỊNH
============================================================================ */
INSERT INTO HANG_HOI_VIEN (MaHang, TenHang, ChiTieuToiThieu, MoTa)
VALUES
    ('SILVER',   N'Silver',   0,         N'Hạng mặc định khi đăng ký hội viên'),
    ('GOLD',     N'Gold',     15000000,  N'Tổng chi tiêu tích lũy trong năm từ 15.000.000 VNĐ'),
    ('PLATINUM', N'Platinum', 40000000,  N'Tổng chi tiêu tích lũy trong năm từ 40.000.000 VNĐ');
GO

PRINT N'=== KHỞI TẠO FITLIFEHUB (20 BẢNG & 63 RÀNG BUỘC TĨNH) THÀNH CÔNG! ===';
GO