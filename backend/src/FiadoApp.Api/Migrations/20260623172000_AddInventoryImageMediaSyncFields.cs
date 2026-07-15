using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    public partial class AddInventoryImageMediaSyncFields : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ProductRemoteId",
                table: "ProductImages",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FileName",
                table: "ProductImages",
                type: "nvarchar(260)",
                maxLength: 260,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ContentHash",
                table: "ProductImages",
                type: "nvarchar(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ContentBase64",
                table: "ProductImages",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "HasContent",
                table: "ProductImages",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_ProductRemoteId",
                table: "ProductImages",
                columns: new[] { "BusinessId", "ProductRemoteId" });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_ProductRemoteId",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "ProductRemoteId",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "FileName",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "ContentHash",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "ContentBase64",
                table: "ProductImages");

            migrationBuilder.DropColumn(
                name: "HasContent",
                table: "ProductImages");
        }
    }
}
