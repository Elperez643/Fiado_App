/*
  OPTIONAL FUTURE ALTERNATIVE FOR LOCAL/STAGINGLOCAL ONLY.
  StagingLocal uses Windows Authentication by default; this script is not part
  of the current startup or migration flow.
  Never run this script against production and never reuse this password.

  Before running, SQL Server may need Mixed Mode enabled:
  SSMS > Server Properties > Security > SQL Server and Windows Authentication mode.
  Restart SQL Server (SQLEXPRESS) after changing the authentication mode.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [master];
GO

IF DB_ID(N'FiadoAppDb_StagingLocal') IS NULL
    THROW 51000, 'FiadoAppDb_StagingLocal does not exist. No changes were made.', 1;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'fiado_staginglocal_app')
BEGIN
    CREATE LOGIN [fiado_staginglocal_app]
        WITH PASSWORD = N'Fiado_StagingLocal_2026_App!',
             CHECK_POLICY = ON,
             CHECK_EXPIRATION = OFF,
             DEFAULT_DATABASE = [FiadoAppDb_StagingLocal];
    PRINT 'Created login fiado_staginglocal_app.';
END
ELSE
BEGIN
    ALTER LOGIN [fiado_staginglocal_app] ENABLE;
    ALTER LOGIN [fiado_staginglocal_app]
        WITH DEFAULT_DATABASE = [FiadoAppDb_StagingLocal];
    PRINT 'Login fiado_staginglocal_app already exists and is enabled.';
END
GO

USE [FiadoAppDb_StagingLocal];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'fiado_staginglocal_app')
BEGIN
    CREATE USER [fiado_staginglocal_app] FOR LOGIN [fiado_staginglocal_app];
    PRINT 'Created database user fiado_staginglocal_app.';
END
ELSE
BEGIN
    ALTER USER [fiado_staginglocal_app] WITH LOGIN = [fiado_staginglocal_app];
    PRINT 'Database user fiado_staginglocal_app already exists.';
END
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members drm
    INNER JOIN sys.database_principals role_principal
        ON role_principal.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals member_principal
        ON member_principal.principal_id = drm.member_principal_id
    WHERE role_principal.name = N'db_owner'
      AND member_principal.name = N'fiado_staginglocal_app'
)
BEGIN
    ALTER ROLE [db_owner] ADD MEMBER [fiado_staginglocal_app];
    PRINT 'Granted db_owner on FiadoAppDb_StagingLocal.';
END
ELSE
BEGIN
    PRINT 'db_owner membership already exists.';
END
GO

SELECT
    DB_NAME() AS DatabaseName,
    member_principal.name AS UserName,
    role_principal.name AS DatabaseRole
FROM sys.database_role_members drm
INNER JOIN sys.database_principals role_principal
    ON role_principal.principal_id = drm.role_principal_id
INNER JOIN sys.database_principals member_principal
    ON member_principal.principal_id = drm.member_principal_id
WHERE member_principal.name = N'fiado_staginglocal_app';
GO
