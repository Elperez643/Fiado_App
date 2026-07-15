using FiadoApp.Api.Data;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(FiadoDbContext))]
    [Migration("20260530194500_AddProductCostMarginFields")]
    public partial class AddProductCostMarginFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "ProfitMarginPercent",
                table: "Products",
                type: "decimal(9,2)",
                precision: 9,
                scale: 2,
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ProfitMarginPercent",
                table: "Products");
        }
    }
}
