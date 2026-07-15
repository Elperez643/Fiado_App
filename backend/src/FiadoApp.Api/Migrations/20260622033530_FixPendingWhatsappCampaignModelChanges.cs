using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class FixPendingWhatsappCampaignModelChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "WhatsappCampaignPublications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RemoteId = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                    BusinessId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocalUuid = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    DateKey = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    Mode = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    ProductIdsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    RenderedImagePathsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    StatusTextsJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    Status = table.Column<string>(type: "nvarchar(48)", maxLength: 48, nullable: false),
                    CampaignStatus = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: false),
                    ConsumesQuota = table.Column<bool>(type: "bit", nullable: false),
                    QuotaUnits = table.Column<int>(type: "int", nullable: false),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DurationDays = table.Column<int>(type: "int", nullable: false),
                    OpenedWhatsappAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    ConfirmedByUserAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CanceledByUserAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    FailedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EstimatedExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Error = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LastSyncedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LocalId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    SyncStatus = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WhatsappCampaignPublications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WhatsappCampaignPublications_Businesses_BusinessId",
                        column: x => x.BusinessId,
                        principalTable: "Businesses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_CampaignStatus_Status",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "CampaignStatus", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_DateKey",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "DateKey" });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_LocalUuid",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "LocalUuid" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "WhatsappCampaignPublications");
        }
    }
}
