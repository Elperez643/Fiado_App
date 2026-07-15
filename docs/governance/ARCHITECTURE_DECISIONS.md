# Architecture Decisions

Current decisions:

- Flutter is the client framework for Android, iOS, Windows, and Web.
- Riverpod is used for state management.
- SQLite is the local database and remains required for Offline First behavior.
- ASP.NET Core is the backend framework.
- Entity Framework Core is the backend data access layer.
- Microsoft SQL Server is the current central database for development and testing.
- EF Core migrations are versioned source artifacts.
- The repository is a monorepository.
- The project uses five permanent Codex agent roles for task governance.
- The app must support a single active session model where applicable.
- The business model is multi-business and must preserve isolation.
- Synchronization is a core architectural capability, not an optional integration.

Future approved direction, not implemented in this task:

- PostgreSQL will progressively replace SQL Server.
- Production target is Azure Database for PostgreSQL Flexible Server.
- Azure Storage Account and Blob Storage will store files.
- Azure Front Door will provide CDN, WAF, and perimeter protection.
