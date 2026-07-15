using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAuditAuthorizationSyncFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "ResolvedAt",
                table: "AuthorizationRequests",
                newName: "DecidedAt");

            migrationBuilder.RenameColumn(
                name: "EntityName",
                table: "AuthorizationRequests",
                newName: "Entity");

            migrationBuilder.RenameColumn(
                name: "BeforeDataJson",
                table: "AuthorizationRequests",
                newName: "DataBeforeJson");

            migrationBuilder.RenameColumn(
                name: "AfterDataJson",
                table: "AuthorizationRequests",
                newName: "DataAfterJson");

            migrationBuilder.RenameColumn(
                name: "Notes",
                table: "Audits",
                newName: "Observations");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "AuthorizationRequests",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "RequestType",
                table: "AuthorizationRequests",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Entity",
                table: "AuthorizationRequests",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "BusinessComment",
                table: "AuthorizationRequests",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "AuthorizationRequests",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "AuthorizationRequests",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "AuthorizationRequests",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Audits",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Audits",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Observations",
                table: "Audits",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "Audits",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "Audits",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "Audits",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ValidationStatus",
                table: "AuditItems",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Observation",
                table: "AuditItems",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "BusinessId",
                table: "AuditItems",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.Sql("""
                UPDATE ai
                SET ai.BusinessId = a.BusinessId
                FROM AuditItems ai
                INNER JOIN Audits a ON a.Id = ai.AuditId
                WHERE ai.BusinessId = '00000000-0000-0000-0000-000000000000'
                """);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "AuditItems",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "AuditItems",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "AuditItems",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_AuditItems_BusinessId_AuditId",
                table: "AuditItems",
                columns: new[] { "BusinessId", "AuditId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AuditItems_BusinessId_AuditId",
                table: "AuditItems");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "AuthorizationRequests");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "AuthorizationRequests");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "AuthorizationRequests");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "Audits");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "Audits");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "Audits");

            migrationBuilder.DropColumn(
                name: "BusinessId",
                table: "AuditItems");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "AuditItems");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "AuditItems");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "AuditItems");

            migrationBuilder.RenameColumn(
                name: "DecidedAt",
                table: "AuthorizationRequests",
                newName: "ResolvedAt");

            migrationBuilder.RenameColumn(
                name: "Entity",
                table: "AuthorizationRequests",
                newName: "EntityName");

            migrationBuilder.RenameColumn(
                name: "DataBeforeJson",
                table: "AuthorizationRequests",
                newName: "BeforeDataJson");

            migrationBuilder.RenameColumn(
                name: "DataAfterJson",
                table: "AuthorizationRequests",
                newName: "AfterDataJson");

            migrationBuilder.RenameColumn(
                name: "Observations",
                table: "Audits",
                newName: "Notes");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "AuthorizationRequests",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "RequestType",
                table: "AuthorizationRequests",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(64)",
                oldMaxLength: 64);

            migrationBuilder.AlterColumn<string>(
                name: "EntityName",
                table: "AuthorizationRequests",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(80)",
                oldMaxLength: 80);

            migrationBuilder.AlterColumn<string>(
                name: "BusinessComment",
                table: "AuthorizationRequests",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Audits",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Audits",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Notes",
                table: "Audits",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(1000)",
                oldMaxLength: 1000,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ValidationStatus",
                table: "AuditItems",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Observation",
                table: "AuditItems",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(1000)",
                oldMaxLength: 1000,
                oldNullable: true);
        }
    }
}
