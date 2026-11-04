-- ═══════════════════════════════════════════════════════════════════════════
-- Nawaqs TEST DATA: 50 real-world pharmacies (6th of October + Giza area)
-- + 1000 inventory items drawn from the EDA registry, with real-looking
-- price variance (matched / above / below official price) for testing
-- EDA badges, nearest/cheapest/trust sorting, and limited-stock states.
-- Idempotent-ish: re-running skips pharmacies whose owner user already exists.
-- Cleanup with scripts/cleanup_test_data.sql
-- ═══════════════════════════════════════════════════════════════════════════
USE NawakesDb;
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
DECLARE @Now DATETIME2 = SYSUTCDATETIME();

DECLARE @Hash NVARCHAR(MAX) = (SELECT TOP 1 PasswordHash FROM AspNetUsers WHERE NormalizedUserName = 'PHARMACY@NAWAQS.COM');

-- ── 1) Owner users (AspNetUsers + Patient role NOT needed; PharmacyOwner role) ──
DECLARE @OwnerRole BIT = (SELECT COUNT(*) FROM AspNetRoles WHERE NormalizedName = 'PHARMACYOWNER');
IF @OwnerRole = 0 THROW 50000, 'PharmacyOwner role missing — run the app seeder first.', 1;
DECLARE @RoleId UNIQUEIDENTIFIER = (SELECT Id FROM AspNetRoles WHERE NormalizedName = 'PHARMACYOWNER');

;WITH Digits AS (
    SELECT TOP 50 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N FROM sys.all_objects
)
INSERT INTO AspNetUsers (Id, Role, UserName, NormalizedUserName, Email, NormalizedEmail, EmailConfirmed, PasswordHash, PhoneNumber, PhoneNumberConfirmed, TwoFactorEnabled, LockoutEnabled, AccessFailedCount, SecurityStamp, ConcurrencyStamp, CreatedAt, UpdatedAt, IsDeleted, AllowPharmacistViewActiveMedications)
SELECT
    NEWID(),
    'PharmacyOwner',
    'test-pharmacy' + CAST(N AS VARCHAR) + '@nawaqs.com',
    UPPER('test-pharmacy' + CAST(N AS VARCHAR) + '@nawaqs.com'),
    'test-pharmacy' + CAST(N AS VARCHAR) + '@nawaqs.com',
    UPPER('test-pharmacy' + CAST(N AS VARCHAR) + '@nawaqs.com'),
    1, @Hash, '01000000' + RIGHT('00' + CAST(N AS VARCHAR), 2),
    0, 0, 1, 0, NEWID(), NEWID(), @Now, @Now, 0, 1
FROM Digits d
WHERE NOT EXISTS (SELECT 1 FROM AspNetUsers WHERE NormalizedUserName = UPPER('test-pharmacy' + CAST(d.N AS VARCHAR) + '@nawaqs.com'));

-- Role assignments
INSERT INTO AspNetUserRoles (UserId, RoleId)
SELECT u.Id, @RoleId
FROM AspNetUsers u
WHERE u.NormalizedUserName LIKE 'TEST-PHARMACY%@NAWAQS.COM'
  AND NOT EXISTS (SELECT 1 FROM AspNetUserRoles ur WHERE ur.UserId = u.Id AND ur.RoleId = @RoleId);

-- ── 2) 50 pharmacies across 6th of October / Sheikh Zayed / Giza / Dokki / Mohandeseen / Haram ──
DECLARE @Pharmacies TABLE (N INT, Name NVARCHAR(200), Address NVARCHAR(300), City NVARCHAR(80), Lat FLOAT, Lng FLOAT, Trust DECIMAL(5,2), Phone NVARCHAR(20), Delivery BIT);
INSERT INTO @Pharmacies VALUES
 (1,  N'El Ezaby Pharmacy — El Hosary',            N'El Hosary Square, 6th of October City',        N'6th of October', 29.9989, 30.9722, 96, N'0228123401', 1),
 (2,  N'Seif Pharmacy — El Hosary',                N'El Hosary Sq, 6th of October City',            N'6th of October', 30.0002, 30.9701, 92, N'0228123402', 1),
 (3,  N'El Tarshouby Pharmacy — Arkan',            N'Arkan Plaza, Sheikh Zayed',                    N'Sheikh Zayed',   29.9920, 30.9500, 94, N'0228123403', 1),
 (4,  N'121 Pharmacy — Zayed',                     N'Beverly Hills, Sheikh Zayed City',             N'Sheikh Zayed',   29.9821, 30.9671, 91, N'0228123404', 1),
 (5,  N'Elysees Pharmacy — Zayed',                 N'Zayed 2000, 26 July Corridor',                 N'Sheikh Zayed',   29.9701, 30.9390, 88, N'0228123405', 1),
 (6,  N'Roshdy Pharmacy — Zayed',                  N'Palm Hills, Sheikh Zayed',                     N'Sheikh Zayed',   29.9755, 30.9431, 90, N'0228123406', 1),
 (7,  N'Christopher Pharmacy — Dahshour',          N'Dahshour St, 6th of October',                  N'6th of October', 29.9303, 30.9160, 85, N'0228123407', 0),
 (8,  N'Nagui Pharmacy — El Mehwar',               N'El Mehwar El Markazi, 6th of October',         N'6th of October', 29.9470, 30.9305, 87, N'0228123408', 1),
 (9,  N'El Aghmy Pharmacy — 7th District',         N'7th District, 6th of October City',            N'6th of October', 30.0105, 30.9689, 83, N'0228123409', 0),
 (10, N'El Hana Pharmacy — El Andalus',            N'El Andalus Garden, 6th of October',            N'6th of October', 29.9855, 30.9640, 89, N'0228123410', 1),
 (11, N'El Ezaby Pharmacy — Zewail',               N'Zewail City of Science, 6th of October',       N'6th of October', 30.0465, 30.9221, 93, N'0228123411', 1),
 (12, N'Seif Pharmacy — Zewail',                   N'Zewail City Gate 2, October',                  N'6th of October', 30.0449, 30.9247, 86, N'0228123412', 0),
 (13, N'El Nile Pharmacy — Zewail',                N'Zewail Housing, 6th of October',               N'6th of October', 30.0490, 30.9200, 82, N'0228123413', 0),
 (14, N'El Tawheed Pharmacy — Industrial',         N'Industrial Zone A2, 6th of October',           N'6th of October', 29.9350, 30.9745, 78, N'0228123414', 0),
 (15, N'El Shorouk Pharmacy — Industrial',         N'Industrial Zone B1, 6th of October',           N'6th of October', 29.9395, 30.9810, 80, N'0228123415', 0),
 (16, N'Al Fahd Pharmacy — Zayed Green',           N'Green Revolution St, Sheikh Zayed',            N'Sheikh Zayed',   29.9867, 30.9561, 92, N'0228123416', 1),
 (17, N'El Basha Pharmacy — Zayed',                N'Mansouria Rd, Sheikh Zayed',                   N'Sheikh Zayed',   29.9650, 30.9280, 79, N'0228123417', 0),
 (18, N'Al Shams Pharmacy — Dreamland',            N'Dreamland, 6th of October',                    N'6th of October', 29.9985, 30.9110, 84, N'0228123418', 1),
 (19, N'El Waha Pharmacy — Al Ekhlas',             N'El Ekhlas District, October',                  N'6th of October', 29.9955, 30.9825, 81, N'0228123419', 0),
 (20, N'Sedra Pharmacy — Sedra West',              N'Sedra West Compound, October',                 N'6th of October', 30.0255, 30.9385, 90, N'0228123420', 1),
 (21, N'Ezaby Express — Zayed Plaza',              N'Plaza Mall, Sheikh Zayed',                     N'Sheikh Zayed',   29.9900, 30.9440, 88, N'0228123421', 1),
 (22, N'El Amal Pharmacy — El Mohandessin',        N'Shehab St, Mohandessin, Giza',                 N'Giza',           30.1005, 31.2085, 90, N'0233442201', 1),
 (23, N'Ezaby — Mohandessin Baghdad St',           N'Baghdad St, Mohandessin, Giza',                N'Giza',           30.0990, 31.2160, 95, N'0233442202', 1),
 (24, N'Seif — Dokki Tahrir St',                   N'Tahrir St, Dokki, Giza',                       N'Giza',           30.0405, 31.2130, 93, N'0233442203', 1),
 (25, N'El Kobesi Pharmacy — Dokki',               N'Mosaddak St, Dokki, Giza',                     N'Giza',           30.0455, 31.2205, 88, N'0233442204', 1),
 (26, N'El Farid Pharmacy — Agouza',               N'Gameat El Dowal, Agouza, Giza',                N'Giza',           30.0825, 31.2160, 85, N'0233442205', 1),
 (27, N'El Demerdash Pharmacy — Boulak',           N'Boulak El Dakrour, Giza',                      N'Giza',           30.0330, 31.1950, 77, N'0233442206', 0),
 (28, N'El Tahrir Pharmacy — Haram',               N'King Faisal St, Haram, Giza',                  N'Giza',           29.9935, 31.1300, 82, N'0233442207', 1),
 (29, N'Ezaby — Haram, Faisal St',                 N'Faisal St, Haram, Giza',                       N'Giza',           29.9975, 31.1245, 94, N'0233442208', 1),
 (30, N'Roshdy — Pyramids Heights',                N'Pyramids Heights, Kerdasa Rd, Giza',           N'Giza',           30.0180, 31.0800, 87, N'0233442209', 1),
 (31, N'El Omrania Pharmacy — Omraniya',           N'Omraniya, Giza',                               N'Giza',           29.9980, 31.1740, 80, N'0233442210', 0),
 (32, N'El Manial Pharmacy — Giza Square',         N'Giza Square, Giza',                            N'Giza',           30.0125, 31.2050, 84, N'0233442211', 1),
 (33, N'Saba Nour Pharmacy — Imbaba',              N'Imbaba, Giza',                                 N'Giza',           30.0965, 31.1800, 76, N'0233442212', 0),
 (34, N'El Safa Pharmacy — Saft El Laban',         N'Saft El Laban, Giza',                          N'Giza',           30.0210, 31.1660, 78, N'0233442213', 0),
 (35, N'El Nahda Pharmacy — Nahda St',             N'El Nahda St, Giza',                            N'Giza',           29.9855, 31.1815, 81, N'0233442214', 1),
 (36, N'Ezaby — Faisal Melad',                     N'Faisal Melad St, Giza',                        N'Giza',           30.0140, 31.1390, 93, N'0233442215', 1),
 (37, N'El Seka El Hadid Pharmacy — Faisal',       N'El Seka El Hadid St, Faisal, Giza',            N'Giza',           30.0105, 31.1460, 79, N'0233442216', 0),
 (38, N'Seif — Lebanon Square',                    N'Lebanon Square, Mohandessin, Giza',            N'Giza',           30.1040, 31.2005, 91, N'0233442217', 1),
 (39, N'El Faransawy Pharmacy — Sudanh',           N'El Sudan St, Mohandessin, Giza',               N'Giza',           30.1030, 31.2130, 86, N'0233442218', 1),
 (40, N'El Badr Pharmacy — Kerdasa',               N'Kerdasa, Giza',                                N'Giza',           30.0335, 31.0690, 72, N'0233442219', 0),
 (41, N'El Zahraa Pharmacy — Hadayek October',     N'Hadayek 6th of October, Zone 2',               N'6th of October', 29.9880, 30.9975, 83, N'0228123422', 1),
 (42, N'El Gabry Pharmacy — Hadayek Zohour',       N'Hadayek El Zohour, October',                   N'6th of October', 29.9905, 31.0040, 77, N'0228123423', 0),
 (43, N'October Pharmacy — Media City',            N'Media Production City, October',               N'6th of October', 29.9930, 30.9470, 88, N'0228123424', 1),
 (44, N'El Sadat Pharmacy — El Hay El Motamayez',  N'El Hay El Motamayez, 6th of October',          N'6th of October', 30.0330, 30.9890, 85, N'0228123425', 1),
 (45, N'El Dawlia Pharmacy — Zayed Entrance',      N'Zayed Entrance 2, 26 July Corridor',           N'Sheikh Zayed',   29.9640, 30.9520, 84, N'0228123426', 1),
 (46, N'Al Borg Pharmacy — El Marwa Gardens',      N'El Marwa Gardens, October',                    N'6th of October', 30.0300, 30.9855, 80, N'0228123427', 0),
 (47, N'El Hazek Pharmacy — Monib',                N'Monib, Giza',                                  N'Giza',           29.9845, 31.1940, 74, N'0233442220', 0),
 (48, N'El Rayan Pharmacy — South Giza',           N'South Giza Agricultural Rd, Giza',             N'Giza',           29.9605, 31.1560, 76, N'0233442221', 0),
 (49, N'Ezaby — October Central Spine',            N'Central Spine, 6th of October',                N'6th of October', 29.9540, 30.9430, 92, N'0228123428', 1),
 (50, N'Seif Elite — October Lakeside',            N'Lakeside Compound, 6th of October',            N'6th of October', 29.9665, 30.9255, 95, N'0228123429', 1);

DECLARE @PharmacyOwner NVARCHAR(50) = (SELECT Id FROM AspNetRoles WHERE NormalizedName = 'PHARMACYOWNER');
INSERT INTO Pharmacies (Id, OwnerId, Name, AddressLine, City, Phone, GeoPoint, VerificationStatus, TrustScore, TrustScoreUpdatedAt, CreatedAt, UpdatedAt, IsDeleted, OffersDelivery, DeliveryFee, DeliveryPhone)
SELECT
    NEWID(),
    u.Id,
    p.Name,
    p.Address,
    p.City,
    p.Phone,
    geography::Point(p.Lat, p.Lng, 4326),
    1,                      -- VerificationStatus.Approved
    p.Trust,
    @Now,
    @Now,
    @Now,
    0,
    p.Delivery,
    CASE WHEN p.Delivery = 1 THEN 15.00 ELSE NULL END,
    CASE WHEN p.Delivery = 1 THEN p.Phone ELSE NULL END
FROM @Pharmacies p
JOIN AspNetUsers u ON u.NormalizedUserName = UPPER('test-pharmacy' + CAST(p.N AS VARCHAR) + '@nawaqs.com')
WHERE NOT EXISTS (SELECT 1 FROM Pharmacies ph WHERE ph.OwnerId = u.Id);

-- ── 3) 1000 inventory items drawn from the EDA registry with realistic price variance ──
-- Prices: 50% match official (±2%), 30% above (5–25% over), 20% below official (5–15% under).
-- Status mix: 80% InStock with qty 5–40, 10% limited (1–4), 10% OutOfStock.
-- Skip entirely when test inventory already exists (idempotent re-runs).
DECLARE @TestPharmacies TABLE (Id UNIQUEIDENTIFIER, Rn INT);
INSERT INTO @TestPharmacies (Id, Rn)
SELECT Id, ROW_NUMBER() OVER (ORDER BY Name) FROM Pharmacies
WHERE OwnerId IN (SELECT Id FROM AspNetUsers WHERE NormalizedUserName LIKE 'TEST-PHARMACY%@NAWAQS.COM');

IF NOT EXISTS (
    SELECT 1 FROM InventoryItems
    WHERE PharmacyId IN (SELECT Id FROM @TestPharmacies)
)
BEGIN

DECLARE @Drugs TABLE (Rn INT IDENTITY(1,1), TradeName NVARCHAR(300), NameNorm NVARCHAR(300), OfficialPrice DECIMAL(18,2), DosageForm NVARCHAR(120));
INSERT INTO @Drugs (TradeName, NameNorm, OfficialPrice, DosageForm)
SELECT TradeName, TradeNameNormalized, ISNULL(OfficialPriceEGP, 25.00), ISNULL(DosageForm, N'Tablet')
FROM EgyptianDrugRegistry
WHERE TradeNameNormalized IS NOT NULL AND TradeNameNormalized <> '';

DECLARE @PharmacyCount INT = (SELECT COUNT(*) FROM @TestPharmacies);
DECLARE @DrugCount INT = (SELECT COUNT(*) FROM @Drugs);

;WITH NumberRows AS (
    SELECT TOP (1000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS N FROM sys.all_objects a CROSS JOIN sys.all_objects b
),
Plans AS (
    SELECT
        n.N,
        (SELECT Id FROM @TestPharmacies WHERE Rn = ((n.N - 1) % @PharmacyCount + 1)) AS PharmacyId,
        (SELECT TradeName FROM @Drugs WHERE Rn = ((n.N * 13) % @DrugCount + 1))       AS TradeName,
        (SELECT OfficialPrice FROM @Drugs WHERE Rn = ((n.N * 13) % @DrugCount + 1))   AS Official,
        CASE
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 10 THEN 1      -- OutOfStock
            WHEN ABS(CHECKSUM(NEWID())) % 100 < 20 THEN 3      -- limited
            ELSE 0                                             -- InStock
        END AS StatusByte,
        ABS(CHECKSUM(NEWID())) % 36 + 5                        AS Qty,
        -- price variance roll: 0-49 match, 50-79 above, 80-99 below
        ABS(CHECKSUM(NEWID())) % 100                           AS PriceRoll,
        CAST(ABS(CHECKSUM(NEWID())) % 25 + 5 AS DECIMAL(5,1))  AS AbovePct,
        CAST(ABS(CHECKSUM(NEWID())) % 15 + 5 AS DECIMAL(5,1))  AS BelowPct,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 540 + 30, @Now)  AS Expiry
    FROM NumberRows n
)
INSERT INTO InventoryItems (Id, PharmacyId, MedicationName, MedicationNameNormalized, Price, Quantity, ExpiryDate, PatientNote, Barcode, ExternalPosSku, Status, CreatedAt, UpdatedAt, IsDeleted)
SELECT
    NEWID(),
    PharmacyId,
    TradeName,
    UPPER(LTRIM(RTRIM(TradeName))),
    CAST(
        CASE
            WHEN PriceRoll < 50  THEN Official * (1 + (PriceRoll % 5 - 2) * 0.01)   -- ±2%
            WHEN PriceRoll < 80  THEN Official * (1 + AbovePct / 100.0)             -- above official
            ELSE Official * (1 - BelowPct / 100.0)                                  -- below official
        END AS DECIMAL(18,2)),
    CASE StatusByte WHEN 1 THEN 0 WHEN 3 THEN ABS(CHECKSUM(NEWID())) % 4 + 1 ELSE Qty END,
    Expiry,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 10 = 0 THEN N'متبقي آخر شرائط — الدفع عند الاستلام' ELSE NULL END,
    NULL,
    NULL,
    StatusByte,
    @Now,
    @Now,
    0
FROM Plans;
END

PRINT 'Seeded test pharmacies + inventory. Counts:';
SELECT (SELECT COUNT(*) FROM Pharmacies WHERE OwnerId IN (SELECT Id FROM AspNetUsers WHERE NormalizedUserName LIKE 'TEST-PHARMACY%@NAWAQS.COM')) AS TestPharmacies,
       (SELECT COUNT(*) FROM InventoryItems WHERE PharmacyId IN (SELECT Id FROM @TestPharmacies)) AS TestItems;
