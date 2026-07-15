# Azure PostgreSQL Target

Future target architecture:

```text
Flutter + SQLite
        |
ASP.NET Core
        |
Azure Database for PostgreSQL Flexible Server
        |
Azure Storage Account / Blob Storage
        |
Azure Front Door / CDN / WAF
```

This document is architectural intent only. It does not authorize implementation in this task.

Decisions:

- SQLite remains the local Offline First database.
- PostgreSQL will replace SQL Server progressively in a dedicated migration project.
- Azure Database for PostgreSQL Flexible Server is the production database target.
- Heavy files do not belong in PostgreSQL.
- Blob Storage will store product images, business logos, receipt PDFs, campaign resources, and exported reports.
- Azure Front Door will distribute static/public content, protect origins, and provide WAF capabilities.
- Azure secrets must never be placed in Flutter.
- Use Managed Identity, backend-issued short-lived access, or tightly scoped temporary permissions.
- Existing test data is disposable unless explicitly promoted by a future task.

Migration requirements for the future project:

- Schema mapping from SQL Server to PostgreSQL.
- EF Core provider migration plan.
- Data migration scripts and rollback strategy.
- Storage migration for binary/file content.
- Updated deployment and secret management.
- Full sync, offline, multi-business, role, and security regression suite.
