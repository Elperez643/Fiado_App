/*
QA stress data for SQL Server.

Safety:
- Runs inside a transaction and ROLLBACKs by default.
- Use only against a disposable/local QA database.
- Change the last ROLLBACK to COMMIT only after validating the target DB.
*/

SET NOCOUNT ON;

DECLARE @Clients int = 1000;
DECLARE @Products int = 500;
DECLARE @Movements int = 3000;
DECLARE @BusinessId uniqueidentifier = NEWID();
DECLARE @OwnerUserId uniqueidentifier = NEWID();
DECLARE @Now datetime2 = SYSUTCDATETIME();

BEGIN TRAN;

INSERT INTO Users
    (Id, Name, Phone, UserType, PasswordHash, IsActive, CreatedAt, UpdatedAt, SyncStatus)
VALUES
    (@OwnerUserId, 'QA Stress Owner', '8090000001', 'business', 'qa-only', 1, @Now, @Now, 'synced');

INSERT INTO Businesses
    (Id, Name, OwnerUserId, Phone, CreatedAt, UpdatedAt, SyncStatus)
VALUES
    (@BusinessId, 'QA Stress Business', @OwnerUserId, '8090000001', @Now, @Now, 'synced');

UPDATE Users SET BusinessId = @BusinessId WHERE Id = @OwnerUserId;

;WITH n AS (
    SELECT TOP (@Clients) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Clients
    (Id, RemoteId, BusinessId, Name, Phone, Address, Debt, IsActive, CreatedAt, UpdatedAt, SyncStatus)
SELECT
    NEWID(),
    CONCAT('qa-client-', i),
    @BusinessId,
    CONCAT('Cliente QA ', FORMAT(i, '000000')),
    CONCAT('809', FORMAT(i, '0000000')),
    CONCAT('Sector QA ', i),
    (i % 17) * 125.00,
    1,
    @Now,
    @Now,
    'synced'
FROM n;

;WITH n AS (
    SELECT TOP (@Products) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Products
    (Id, RemoteId, BusinessId, Name, Category, Description, Quantity, PurchasePrice, SalePrice, MinimumStock,
     CodeReference, IsActive, CreatedAt, UpdatedAt, SyncStatus)
SELECT
    NEWID(),
    CONCAT('qa-product-', i),
    @BusinessId,
    CONCAT('Producto QA ', FORMAT(i, '00000')),
    CONCAT('Categoria ', i % 12),
    'Producto generado para prueba de carga',
    20 + (i % 500),
    20.00 + (i % 50),
    35.00 + (i % 80),
    5,
    CONCAT('QA-P-', FORMAT(i, '000000')),
    1,
    @Now,
    @Now,
    'synced'
FROM n;

;WITH n AS (
    SELECT TOP (@Movements) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO Movements
    (Id, RemoteId, BusinessId, ClientId, ClientName, ClientPhone, Type, Amount, Concept, Date, IsActive, CreatedAt, UpdatedAt, SyncStatus)
SELECT
    NEWID(),
    CONCAT('qa-movement-', n.i),
    @BusinessId,
    c.Id,
    c.Name,
    c.Phone,
    CASE WHEN n.i % 5 = 0 THEN 'payment' ELSE 'debt' END,
    100.00 + (n.i % 900),
    CASE WHEN n.i % 5 = 0 THEN 'Pago QA' ELSE 'Deuda QA' END,
    DATEADD(MINUTE, -n.i, @Now),
    1,
    DATEADD(MINUTE, -n.i, @Now),
    DATEADD(MINUTE, -n.i, @Now),
    'synced'
FROM n
JOIN Clients c
    ON c.BusinessId = @BusinessId
   AND c.Phone = CONCAT('809', FORMAT(((n.i - 1) % @Clients) + 1, '0000000'));

PRINT CONCAT('Inserted QA rows for BusinessId=', @BusinessId);
PRINT 'Default action is ROLLBACK. Change to COMMIT only in a disposable QA DB.';

ROLLBACK TRAN;
