-- ═══════════════════════════════════════════════════════════════════════════
SET QUOTED_IDENTIFIER ON;
-- Nawaqs TEST DATA CLEANUP: removes the 50 test pharmacies (by test owner
-- accounts) and their inventory items. Real pharmacies and user accounts
-- created through the app are NOT touched.
-- ═══════════════════════════════════════════════════════════════════════════
USE NawakesDb;
GO

DECLARE @TestOwnerIds TABLE (Id UNIQUEIDENTIFIER PRIMARY KEY);
INSERT INTO @TestOwnerIds (Id)
SELECT Id FROM AspNetUsers WHERE NormalizedUserName LIKE 'TEST-PHARMACY%@NAWAQS.COM';

-- 1) Soft-delete reservations tied to test inventory (preserve history)
UPDATE r SET r.IsDeleted = 1, r.DeletedAt = SYSUTCDATETIME()
FROM Reservations r
JOIN InventoryItems i ON i.Id = r.InventoryItemId
WHERE i.PharmacyId IN (SELECT Id FROM Pharmacies WHERE OwnerId IN (SELECT Id FROM @TestOwnerIds));

-- 2) Hard-delete test inventory items
DELETE i FROM InventoryItems i
WHERE i.PharmacyId IN (SELECT Id FROM Pharmacies WHERE OwnerId IN (SELECT Id FROM @TestOwnerIds));

-- 3) Hard-delete test pharmacies
DELETE ph FROM Pharmacies ph
WHERE ph.OwnerId IN (SELECT Id FROM @TestOwnerIds);

-- 4) Delete test owner users + role links
DELETE ur FROM AspNetUserRoles ur
JOIN @TestOwnerIds t ON t.Id = ur.UserId;

DELETE FROM AspNetUsers WHERE Id IN (SELECT Id FROM @TestOwnerIds);

PRINT 'Cleanup done. Remaining counts:';
SELECT (SELECT COUNT(*) FROM Pharmacies) AS Pharmacies,
       (SELECT COUNT(*) FROM InventoryItems) AS InventoryItems;
GO
