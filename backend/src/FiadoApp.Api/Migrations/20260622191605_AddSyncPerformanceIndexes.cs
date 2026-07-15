using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSyncPerformanceIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AuthorizationRequests_BusinessId",
                table: "AuthorizationRequests");

            migrationBuilder.DropIndex(
                name: "IX_Audits_BusinessId",
                table: "Audits");

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_DeletedAt",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_LocalId",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_RemoteId",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_UpdatedAt",
                table: "WhatsappCampaignPublications",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_BusinessId_DeletedAt",
                table: "Receipts",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_BusinessId_LocalId",
                table: "Receipts",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_BusinessId_RemoteId",
                table: "Receipts",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Receipts_BusinessId_UpdatedAt",
                table: "Receipts",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_DeletedAt",
                table: "Products",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_LocalId",
                table: "Products",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_RemoteId",
                table: "Products",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Products_BusinessId_UpdatedAt",
                table: "Products",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_DeletedAt",
                table: "ProductImages",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_LocalId",
                table: "ProductImages",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_RemoteId",
                table: "ProductImages",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_ProductImages_BusinessId_UpdatedAt",
                table: "ProductImages",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Movements_BusinessId_DeletedAt",
                table: "Movements",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Movements_BusinessId_LocalId",
                table: "Movements",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_Movements_BusinessId_RemoteId",
                table: "Movements",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Movements_BusinessId_UpdatedAt",
                table: "Movements",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DebtItems_BusinessId_DeletedAt",
                table: "DebtItems",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_DebtItems_BusinessId_LocalId",
                table: "DebtItems",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_DebtItems_BusinessId_RemoteId",
                table: "DebtItems",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_DebtItems_BusinessId_UpdatedAt",
                table: "DebtItems",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditReminders_BusinessId_LocalId",
                table: "CreditReminders",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditReminders_BusinessId_UpdatedAt",
                table: "CreditReminders",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_BusinessId_LocalId",
                table: "CreditExceptions",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_BusinessId_RemoteId",
                table: "CreditExceptions",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditExceptions_BusinessId_UpdatedAt",
                table: "CreditExceptions",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditCycles_BusinessId_LocalId",
                table: "CreditCycles",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditCycles_BusinessId_RemoteId",
                table: "CreditCycles",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_CreditCycles_BusinessId_UpdatedAt",
                table: "CreditCycles",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientScores_BusinessId_DeletedAt",
                table: "ClientScores",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientScores_BusinessId_LocalId",
                table: "ClientScores",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_ClientScores_BusinessId_RemoteId",
                table: "ClientScores",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Clients_BusinessId_DeletedAt",
                table: "Clients",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Clients_BusinessId_LocalId",
                table: "Clients",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_Clients_BusinessId_RemoteId",
                table: "Clients",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Clients_BusinessId_UpdatedAt",
                table: "Clients",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AuthorizationRequests_BusinessId_DeletedAt",
                table: "AuthorizationRequests",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AuthorizationRequests_BusinessId_LocalId",
                table: "AuthorizationRequests",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_AuthorizationRequests_BusinessId_RemoteId",
                table: "AuthorizationRequests",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_AuthorizationRequests_BusinessId_UpdatedAt",
                table: "AuthorizationRequests",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Audits_BusinessId_DeletedAt",
                table: "Audits",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Audits_BusinessId_LocalId",
                table: "Audits",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_Audits_BusinessId_RemoteId",
                table: "Audits",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_Audits_BusinessId_UpdatedAt",
                table: "Audits",
                columns: new[] { "BusinessId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AuditItems_BusinessId_DeletedAt",
                table: "AuditItems",
                columns: new[] { "BusinessId", "DeletedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_AuditItems_BusinessId_LocalId",
                table: "AuditItems",
                columns: new[] { "BusinessId", "LocalId" });

            migrationBuilder.CreateIndex(
                name: "IX_AuditItems_BusinessId_RemoteId",
                table: "AuditItems",
                columns: new[] { "BusinessId", "RemoteId" });

            migrationBuilder.CreateIndex(
                name: "IX_AuditItems_BusinessId_UpdatedAt",
                table: "AuditItems",
                columns: new[] { "BusinessId", "UpdatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_DeletedAt",
                table: "WhatsappCampaignPublications");

            migrationBuilder.DropIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_LocalId",
                table: "WhatsappCampaignPublications");

            migrationBuilder.DropIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_RemoteId",
                table: "WhatsappCampaignPublications");

            migrationBuilder.DropIndex(
                name: "IX_WhatsappCampaignPublications_BusinessId_UpdatedAt",
                table: "WhatsappCampaignPublications");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_BusinessId_DeletedAt",
                table: "Receipts");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_BusinessId_LocalId",
                table: "Receipts");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_BusinessId_RemoteId",
                table: "Receipts");

            migrationBuilder.DropIndex(
                name: "IX_Receipts_BusinessId_UpdatedAt",
                table: "Receipts");

            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_DeletedAt",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_LocalId",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_RemoteId",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_Products_BusinessId_UpdatedAt",
                table: "Products");

            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_DeletedAt",
                table: "ProductImages");

            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_LocalId",
                table: "ProductImages");

            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_RemoteId",
                table: "ProductImages");

            migrationBuilder.DropIndex(
                name: "IX_ProductImages_BusinessId_UpdatedAt",
                table: "ProductImages");

            migrationBuilder.DropIndex(
                name: "IX_Movements_BusinessId_DeletedAt",
                table: "Movements");

            migrationBuilder.DropIndex(
                name: "IX_Movements_BusinessId_LocalId",
                table: "Movements");

            migrationBuilder.DropIndex(
                name: "IX_Movements_BusinessId_RemoteId",
                table: "Movements");

            migrationBuilder.DropIndex(
                name: "IX_Movements_BusinessId_UpdatedAt",
                table: "Movements");

            migrationBuilder.DropIndex(
                name: "IX_DebtItems_BusinessId_DeletedAt",
                table: "DebtItems");

            migrationBuilder.DropIndex(
                name: "IX_DebtItems_BusinessId_LocalId",
                table: "DebtItems");

            migrationBuilder.DropIndex(
                name: "IX_DebtItems_BusinessId_RemoteId",
                table: "DebtItems");

            migrationBuilder.DropIndex(
                name: "IX_DebtItems_BusinessId_UpdatedAt",
                table: "DebtItems");

            migrationBuilder.DropIndex(
                name: "IX_CreditReminders_BusinessId_LocalId",
                table: "CreditReminders");

            migrationBuilder.DropIndex(
                name: "IX_CreditReminders_BusinessId_UpdatedAt",
                table: "CreditReminders");

            migrationBuilder.DropIndex(
                name: "IX_CreditExceptions_BusinessId_LocalId",
                table: "CreditExceptions");

            migrationBuilder.DropIndex(
                name: "IX_CreditExceptions_BusinessId_RemoteId",
                table: "CreditExceptions");

            migrationBuilder.DropIndex(
                name: "IX_CreditExceptions_BusinessId_UpdatedAt",
                table: "CreditExceptions");

            migrationBuilder.DropIndex(
                name: "IX_CreditCycles_BusinessId_LocalId",
                table: "CreditCycles");

            migrationBuilder.DropIndex(
                name: "IX_CreditCycles_BusinessId_RemoteId",
                table: "CreditCycles");

            migrationBuilder.DropIndex(
                name: "IX_CreditCycles_BusinessId_UpdatedAt",
                table: "CreditCycles");

            migrationBuilder.DropIndex(
                name: "IX_ClientScores_BusinessId_DeletedAt",
                table: "ClientScores");

            migrationBuilder.DropIndex(
                name: "IX_ClientScores_BusinessId_LocalId",
                table: "ClientScores");

            migrationBuilder.DropIndex(
                name: "IX_ClientScores_BusinessId_RemoteId",
                table: "ClientScores");

            migrationBuilder.DropIndex(
                name: "IX_Clients_BusinessId_DeletedAt",
                table: "Clients");

            migrationBuilder.DropIndex(
                name: "IX_Clients_BusinessId_LocalId",
                table: "Clients");

            migrationBuilder.DropIndex(
                name: "IX_Clients_BusinessId_RemoteId",
                table: "Clients");

            migrationBuilder.DropIndex(
                name: "IX_Clients_BusinessId_UpdatedAt",
                table: "Clients");

            migrationBuilder.DropIndex(
                name: "IX_AuthorizationRequests_BusinessId_DeletedAt",
                table: "AuthorizationRequests");

            migrationBuilder.DropIndex(
                name: "IX_AuthorizationRequests_BusinessId_LocalId",
                table: "AuthorizationRequests");

            migrationBuilder.DropIndex(
                name: "IX_AuthorizationRequests_BusinessId_RemoteId",
                table: "AuthorizationRequests");

            migrationBuilder.DropIndex(
                name: "IX_AuthorizationRequests_BusinessId_UpdatedAt",
                table: "AuthorizationRequests");

            migrationBuilder.DropIndex(
                name: "IX_Audits_BusinessId_DeletedAt",
                table: "Audits");

            migrationBuilder.DropIndex(
                name: "IX_Audits_BusinessId_LocalId",
                table: "Audits");

            migrationBuilder.DropIndex(
                name: "IX_Audits_BusinessId_RemoteId",
                table: "Audits");

            migrationBuilder.DropIndex(
                name: "IX_Audits_BusinessId_UpdatedAt",
                table: "Audits");

            migrationBuilder.DropIndex(
                name: "IX_AuditItems_BusinessId_DeletedAt",
                table: "AuditItems");

            migrationBuilder.DropIndex(
                name: "IX_AuditItems_BusinessId_LocalId",
                table: "AuditItems");

            migrationBuilder.DropIndex(
                name: "IX_AuditItems_BusinessId_RemoteId",
                table: "AuditItems");

            migrationBuilder.DropIndex(
                name: "IX_AuditItems_BusinessId_UpdatedAt",
                table: "AuditItems");

            migrationBuilder.CreateIndex(
                name: "IX_AuthorizationRequests_BusinessId",
                table: "AuthorizationRequests",
                column: "BusinessId");

            migrationBuilder.CreateIndex(
                name: "IX_Audits_BusinessId",
                table: "Audits",
                column: "BusinessId");
        }
    }
}
