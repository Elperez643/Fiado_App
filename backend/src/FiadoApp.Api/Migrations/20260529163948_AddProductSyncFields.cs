using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddProductSyncFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_ReferenceCode",
                table: "Products");

            migrationBuilder.RenameColumn(
                name: "ReferenceCode",
                table: "Products",
                newName: "CodeReference");

            migrationBuilder.RenameColumn(
                name: "StoragePath",
                table: "ProductImages",
                newName: "LocalPath");

            migrationBuilder.RenameColumn(
                name: "SortOrder",
                table: "ProductImages",
                newName: "Order");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "Products",
                type: "nvarchar(180)",
                maxLength: 180,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "Category",
                table: "Products",
                type: "nvarchar(120)",
                maxLength: 120,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "CodeReference",
                table: "Products",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(450)",
                oldNullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "Products",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "Products",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "Products",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "MimeType",
                table: "ProductImages",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "LocalPath",
                table: "ProductImages",
                type: "nvarchar(1024)",
                maxLength: 1024,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AddColumn<DateTime>(
                name: "DeletedAt",
                table: "ProductImages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastSyncedAt",
                table: "ProductImages",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteId",
                table: "ProductImages",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RemoteUrl",
                table: "ProductImages",
                type: "nvarchar(2048)",
                maxLength: 2048,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "StorageKey",
                table: "ProductImages",
                type: "nvarchar(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_CodeReference",
                table: "Products",
                columns: new[] { "BusinessId", "CodeReference" });

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_Name",
                table: "Products",
                columns: new[] { "BusinessId", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_ProductId_Order",
                table: "ProductImages",
                columns: new[] { "BusinessId", "ProductId", "Order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_CodeReference",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_Name",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_ProductId_Order",
                table: "ProductImages");

            migrationBuilder.RenameColumn(
                name: "CodeReference",
                table: "Products",
                newName: "ReferenceCode");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "Products");

            migrationBuilder.DropColumn(
                name: "DeletedAt",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "LastSyncedAt",
                table: "ProductImages");

            migrationBuilder.RenameColumn(
                name: "LocalPath",
                table: "ProductImages",
                newName: "StoragePath");

            migrationBuilder.DropColumn(
                name: "RemoteId",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "RemoteUrl",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "StorageKey",
                table: "ProductImages");

            migrationBuilder.RenameColumn(
                name: "Order",
                table: "ProductImages",
                newName: "SortOrder");

            migrationBuilder.AlterColumn<string>(
                name: "Name",
                table: "Products",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(180)",
                oldMaxLength: 180);

            migrationBuilder.AlterColumn<string>(
                name: "Category",
                table: "Products",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(120)",
                oldMaxLength: 120,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "ReferenceCode",
                table: "Products",
                type: "nvarchar(450)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(80)",
                oldMaxLength: 80,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "MimeType",
                table: "ProductImages",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(80)",
                oldMaxLength: 80,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "StoragePath",
                table: "ProductImages",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(1024)",
                oldMaxLength: 1024);

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_ReferenceCode",
                table: "Products",
                columns: new[] { "BusinessId", "ReferenceCode" });
        }
    }
}
