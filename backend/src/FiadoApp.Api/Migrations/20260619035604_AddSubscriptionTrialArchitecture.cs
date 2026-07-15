using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace FiadoApp.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSubscriptionTrialArchitecture : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Subscriptions",
                type: "nvarchar(48)",
                maxLength: 48,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)");

            migrationBuilder.AlterColumn<string>(
                name: "ProviderSubscriptionId",
                table: "Subscriptions",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "PaymentProvider",
                table: "Subscriptions",
                type: "nvarchar(40)",
                maxLength: 40,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(max)",
                oldNullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "CancelAtPeriodEnd",
                table: "Subscriptions",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "ProviderCustomerId",
                table: "Subscriptions",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CurrentBillingCycle",
                table: "Businesses",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "mensual");

            migrationBuilder.AddColumn<string>(
                name: "CurrentPlan",
                table: "Businesses",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "basico");

            migrationBuilder.AddColumn<bool>(
                name: "HasUsedTrial",
                table: "Businesses",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "PaymentMethodRequired",
                table: "Businesses",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<string>(
                name: "StripeCustomerId",
                table: "Businesses",
                type: "nvarchar(160)",
                maxLength: 160,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SubscriptionStatus",
                table: "Businesses",
                type: "nvarchar(48)",
                maxLength: 48,
                nullable: false,
                defaultValue: "payment_method_required");

            migrationBuilder.AddColumn<DateTime>(
                name: "TrialEndsAt",
                table: "Businesses",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "TrialStartedAt",
                table: "Businesses",
                type: "datetime2",
                nullable: true);

            migrationBuilder.Sql("""
                UPDATE Businesses
                SET CurrentPlan = 'basico'
                WHERE CurrentPlan = '';

                UPDATE Businesses
                SET CurrentBillingCycle = 'mensual'
                WHERE CurrentBillingCycle = '';

                UPDATE Subscriptions
                SET Status = 'trial_active'
                WHERE Status IN ('trial', 'trialing');

                UPDATE b
                SET
                    b.SubscriptionStatus = COALESCE(s.Status, 'payment_method_required'),
                    b.TrialStartedAt = s.TrialStartedAt,
                    b.TrialEndsAt = s.TrialEndsAt,
                    b.HasUsedTrial = CASE WHEN s.Id IS NULL THEN 0 ELSE 1 END,
                    b.PaymentMethodRequired = CASE WHEN s.Id IS NULL THEN 1 ELSE 0 END,
                    b.CurrentPlan = COALESCE(NULLIF(s.PlanId, ''), b.CurrentPlan),
                    b.CurrentBillingCycle = COALESCE(NULLIF(s.BillingCycle, ''), b.CurrentBillingCycle)
                FROM Businesses b
                OUTER APPLY (
                    SELECT TOP 1 *
                    FROM Subscriptions s
                    WHERE s.BusinessId = b.Id
                    ORDER BY s.CreatedAt DESC
                ) s;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CancelAtPeriodEnd",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "ProviderCustomerId",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "CurrentBillingCycle",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "CurrentPlan",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "HasUsedTrial",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "PaymentMethodRequired",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "StripeCustomerId",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "SubscriptionStatus",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "TrialEndsAt",
                table: "Businesses");

            migrationBuilder.DropColumn(
                name: "TrialStartedAt",
                table: "Businesses");

            migrationBuilder.AlterColumn<string>(
                name: "Status",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(48)",
                oldMaxLength: 48);

            migrationBuilder.AlterColumn<string>(
                name: "ProviderSubscriptionId",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(160)",
                oldMaxLength: 160,
                oldNullable: true);

            migrationBuilder.AlterColumn<string>(
                name: "PaymentProvider",
                table: "Subscriptions",
                type: "nvarchar(max)",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(40)",
                oldMaxLength: 40,
                oldNullable: true);
        }
    }
}
