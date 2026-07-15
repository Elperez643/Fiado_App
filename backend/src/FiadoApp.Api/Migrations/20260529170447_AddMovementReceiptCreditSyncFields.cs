using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddMovementReceiptCreditSyncFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "ReferenceCode",
                table: "DebtItems",
                newName: "CodeReference");

            migrationBuilder.RenameColumn(
                name: "Limit45Date",
                table: "CreditCycles",
                newName: "DueDate45");

            migrationBuilder.RenameColumn(
                name: "Limit30Date",
                table: "CreditCycles",
                newName: "DueDate30");

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Receipts",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "ReceiptCode",
                table: "Receipts",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)");

            migrationBuilder.AlterColumn<string>(
                name: "ClientPhone",
                table: "Receipts",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ClientName",
                table: "Receipts",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "BusinessName",
                table: "Receipts",
                type: "nvarchar(180)",
                maxLength: 180,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ClientId",
                table: "Receipts",
                type: "uniqueidentifier",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"));

            migrationBuilder.Sql("""
UPDATE r
SET ClientId = m.ClientId
FROM Receipts r
INNER JOIN Movements m ON r.MovementId = m.Id
WHERE r.ClientId = '00000000-0000-0000-0000-000000000000'
""");

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "Receipts",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "Receipts",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "Receipts",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Movements",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Concept",
                table: "Movements",
                type: "nvarchar(260)",
                maxLength: 260,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "Movements",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "Movements",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "Movements",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "Movements",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ProductName",
                table: "DebtItems",
                type: "nvarchar(180)",
                maxLength: 180,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "CodeReference",
                table: "DebtItems",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "DebtItems",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "DebtItems",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "DebtItems",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "CreditReminders",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "CreditReminders",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Channel",
                table: "CreditReminders",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "CreditCycles",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)");

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "CreditCycles",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "CreditCycles",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CreditExceptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RemoteId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    BusinessId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreditCycleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ClientId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    MovementId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    Date = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LocalId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SyncStatus = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CreditExceptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CreditExceptions_Clients_ClientId",
                        column: x => x.ClientId,
                        principalTable: "Clients",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CreditExceptions_CreditCycles_CreditCycleId",
                        column: x => x.CreditCycleId,
                        principalTable: "CreditCycles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CreditExceptions_Movements_MovementId",
                        column: x => x.MovementId,
                        principalTable: "Movements",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_BusinessId_ClientId_Date",
                table: "Receipts",
                columns: new[] { "BusinessId", "ClientId", "Date" });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_ClientId",
                table: "Receipts",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_BusinessId_ClientId_Date",
                table: "CreditExceptions",
                columns: new[] { "BusinessId", "ClientId", "Date" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_ClientId",
                table: "CreditExceptions",
                column: "ClientId");

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_CreditCycleId",
                table: "CreditExceptions",
                column: "CreditCycleId");

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_MovementId",
                table: "CreditExceptions",
                column: "MovementId");

            migrationBuilder.AddForeignKey(
                name: "FK_Receipts_Clients_ClientId",
                table: "Receipts",
                column: "ClientId",
                principalTable: "Clients",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Receipts_Clients_ClientId",
                table: "Receipts");

            migrationBuilder.DropTable(
                name: "CreditExceptions");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_BusinessId_ClientId_Date",
                table: "Receipts");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_ClientId",
                table: "Receipts");

            migrationBuilder.DropColumn(
                name: "ClientId",
                table: "Receipts");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "Receipts");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "Receipts");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "Receipts");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "Movements");

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "Movements");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "Movements");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "Movements");

            migrationBuilder.RenameColumn(
                name: "CodeReference",
                table: "DebtItems",
                newName: "ReferenceCode");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "DebtItems");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "DebtItems");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "DebtItems");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "CreditCycles");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "CreditCycles");

            migrationBuilder.RenameColumn(
                name: "DueDate45",
                table: "CreditCycles",
                newName: "Limit45Date");

            migrationBuilder.RenameColumn(
                name: "DueDate30",
                table: "CreditCycles",
                newName: "Limit30Date");

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Receipts",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "ReceiptCode",
                table: "Receipts",
                type: "nvarchar(450)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(80)",
                oldMaxLength: 80);

            migrationBuilder.AlterColumn<string>(
                name: "ClientPhone",
                table: "Receipts",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ClientName",
                table: "Receipts",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(160)",
                oldMaxLength: 160);

            migrationBuilder.AlterColumn<string>(
                name: "BusinessName",
                table: "Receipts",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(180)",
                oldMaxLength: 180,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "Movements",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Concept",
                table: "Movements",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(260)",
                oldMaxLength: 260,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ProductName",
                table: "DebtItems",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(180)",
                oldMaxLength: 180);

            migrationBuilder.AlterColumn<string>(
                name: "ReferenceCode",
                table: "DebtItems",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(80)",
                oldMaxLength: 80,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "Type",
                table: "CreditReminders",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "CreditReminders",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Channel",
                table: "CreditReminders",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "CreditCycles",
                type: "nvarchar(450)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(32)",
                oldMaxLength: 32);
        }
    }
}
