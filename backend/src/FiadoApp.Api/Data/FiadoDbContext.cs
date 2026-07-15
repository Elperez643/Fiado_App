using FiadoApp.Api.Entities;
using FiadoApp.Api.Payments;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Data;

public class FiadoDbContext(DbContextOptions<FiadoDbContext> options)
    : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Business> Businesses => Set<Business>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<Client> Clients => Set<Client>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ProductImage> ProductImages => Set<ProductImage>();
    public DbSet<Movement> Movements => Set<Movement>();
    public DbSet<DebtItem> DebtItems => Set<DebtItem>();
    public DbSet<Receipt> Receipts => Set<Receipt>();
    public DbSet<CreditCycle> CreditCycles => Set<CreditCycle>();
    public DbSet<CreditReminder> CreditReminders => Set<CreditReminder>();
    public DbSet<CreditException> CreditExceptions => Set<CreditException>();
    public DbSet<Audit> Audits => Set<Audit>();
    public DbSet<AuditItem> AuditItems => Set<AuditItem>();
    public DbSet<AuthorizationRequest> AuthorizationRequests => Set<AuthorizationRequest>();
    public DbSet<ClientScore> ClientScores => Set<ClientScore>();
    public DbSet<WhatsappCampaignPublication> WhatsappCampaignPublications => Set<WhatsappCampaignPublication>();
    public DbSet<SyncLog> SyncLogs => Set<SyncLog>();
    public DbSet<SubscriptionPayment> SubscriptionPayments => Set<SubscriptionPayment>();
    public DbSet<PaymentMethod> PaymentMethods => Set<PaymentMethod>();
    public DbSet<PaymentTransaction> PaymentTransactions => Set<PaymentTransaction>();
    public DbSet<PaymentWebhookLog> PaymentWebhookLogs => Set<PaymentWebhookLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(x => x.Phone).IsUnique();
            entity.HasIndex(x => new { x.Id, x.ActiveDeviceId });
            entity.Property(x => x.Name).HasMaxLength(160);
            entity.Property(x => x.Phone).HasMaxLength(32);
            entity.Property(x => x.UserType).HasMaxLength(32);
            entity.Property(x => x.ActiveDeviceId).HasMaxLength(128);
            entity.Property(x => x.DeviceInfo).HasMaxLength(260);

            entity.HasOne(x => x.Business)
                .WithMany(x => x.Members)
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Business>(entity =>
        {
            entity.Property(x => x.SubscriptionStatus).HasMaxLength(48);
            entity.Property(x => x.StripeCustomerId).HasMaxLength(160);
            entity.Property(x => x.CurrentPlan).HasMaxLength(64);
            entity.Property(x => x.CurrentBillingCycle).HasMaxLength(32);

            entity.HasOne(x => x.OwnerUser)
                .WithMany()
                .HasForeignKey(x => x.OwnerUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Client>(entity =>
        {
            entity.HasIndex(x => new { x.BusinessId, x.Phone }).IsUnique();
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Name).HasMaxLength(160);
            entity.Property(x => x.Phone).HasMaxLength(32);
            entity.Property(x => x.Address).HasMaxLength(260);
            entity.Property(x => x.Debt).HasPrecision(18, 2);

            entity.HasOne(x => x.Business)
                .WithMany(x => x.Clients)
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasIndex(x => new { x.BusinessId, x.Name });
            entity.HasIndex(x => new { x.BusinessId, x.CodeReference });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Name).HasMaxLength(180);
            entity.Property(x => x.CodeReference).HasMaxLength(80);
            entity.Property(x => x.Category).HasMaxLength(120);
            entity.Property(x => x.PurchasePrice).HasPrecision(18, 2);
            entity.Property(x => x.SalePrice).HasPrecision(18, 2);
            entity.Property(x => x.ProfitMarginPercent).HasPrecision(9, 2);

            entity.HasOne(x => x.Business)
                .WithMany(x => x.Products)
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ProductImage>(entity =>
        {
            entity.HasIndex(x => new { x.BusinessId, x.ProductId, x.Order });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });
            entity.HasIndex(x => new { x.BusinessId, x.ProductRemoteId });
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.ProductRemoteId).HasMaxLength(64);
            entity.Property(x => x.LocalPath).HasMaxLength(1024);
            entity.Property(x => x.RemoteUrl).HasMaxLength(2048);
            entity.Property(x => x.StorageKey).HasMaxLength(512);
            entity.Property(x => x.FileName).HasMaxLength(260);
            entity.Property(x => x.ContentHash).HasMaxLength(128);
            entity.Property(x => x.MimeType).HasMaxLength(80);

            entity.HasOne(x => x.Product)
                .WithMany(x => x.Images)
                .HasForeignKey(x => x.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Movement>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Type).HasMaxLength(32);
            entity.Property(x => x.Concept).HasMaxLength(260);
            entity.Property(x => x.Amount).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.BusinessId, x.Date });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany()
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany(x => x.Movements)
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<DebtItem>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.ProductName).HasMaxLength(180);
            entity.Property(x => x.CodeReference).HasMaxLength(80);
            entity.Property(x => x.UnitPrice).HasPrecision(18, 2);
            entity.Property(x => x.Subtotal).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Movement)
                .WithMany(x => x.DebtItems)
                .HasForeignKey(x => x.MovementId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Product)
                .WithMany()
                .HasForeignKey(x => x.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Receipt>(entity =>
        {
            entity.HasIndex(x => x.ReceiptCode).IsUnique();
            entity.HasIndex(x => new { x.BusinessId, x.ClientId, x.Date });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Type).HasMaxLength(32);
            entity.Property(x => x.ClientName).HasMaxLength(160);
            entity.Property(x => x.ClientPhone).HasMaxLength(32);
            entity.Property(x => x.BusinessName).HasMaxLength(180);
            entity.Property(x => x.ReceiptCode).HasMaxLength(80);
            entity.Property(x => x.Subtotal).HasPrecision(18, 2);
            entity.Property(x => x.Total).HasPrecision(18, 2);
            entity.Property(x => x.PreviousBalance).HasPrecision(18, 2);
            entity.Property(x => x.NewBalance).HasPrecision(18, 2);

            entity.HasOne(x => x.Movement)
                .WithMany(x => x.Receipts)
                .HasForeignKey(x => x.MovementId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany()
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Subscription>(entity =>
        {
            entity.Property(x => x.MonthlyPrice).HasPrecision(18, 2);
            entity.Property(x => x.OriginalPrice).HasPrecision(18, 2);
            entity.Property(x => x.FinalPrice).HasPrecision(18, 2);
            entity.Property(x => x.Status).HasMaxLength(48);
            entity.Property(x => x.PaymentProvider).HasMaxLength(40);
            entity.Property(x => x.ProviderSubscriptionId).HasMaxLength(160);
            entity.Property(x => x.ProviderCustomerId).HasMaxLength(160);
            entity.HasIndex(x => x.BusinessId);

            entity.HasOne(x => x.Business)
                .WithMany()
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CreditCycle>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.Property(x => x.TotalAmount).HasPrecision(18, 2);
            entity.Property(x => x.PaidAmount).HasPrecision(18, 2);
            entity.Property(x => x.PendingBalance).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.BusinessId, x.ClientId, x.Status });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany(x => x.CreditCycles)
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany(x => x.CreditCycles)
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CreditReminder>(entity =>
        {
            entity.Property(x => x.Type).HasMaxLength(32);
            entity.Property(x => x.Channel).HasMaxLength(32);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });

            entity.HasOne(x => x.CreditCycle)
                .WithMany(x => x.Reminders)
                .HasForeignKey(x => x.CreditCycleId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<CreditException>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Reason).HasMaxLength(500);
            entity.Property(x => x.Amount).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.BusinessId, x.ClientId, x.Date });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.CreditCycle)
                .WithMany()
                .HasForeignKey(x => x.CreditCycleId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany()
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Movement)
                .WithMany()
                .HasForeignKey(x => x.MovementId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<Audit>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.Type).HasMaxLength(32);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.Property(x => x.Observations).HasMaxLength(1000);
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany()
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Collaborator)
                .WithMany()
                .HasForeignKey(x => x.CollaboratorId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AuditItem>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.ValidationStatus).HasMaxLength(32);
            entity.Property(x => x.Observation).HasMaxLength(1000);
            entity.HasIndex(x => new { x.BusinessId, x.AuditId });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Audit)
                .WithMany(x => x.Items)
                .HasForeignKey(x => x.AuditId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Product)
                .WithMany()
                .HasForeignKey(x => x.ProductId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AuthorizationRequest>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.RequestType).HasMaxLength(64);
            entity.Property(x => x.Entity).HasMaxLength(80);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.Property(x => x.BusinessComment).HasMaxLength(500);
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany(x => x.AuthorizationRequests)
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Collaborator)
                .WithMany()
                .HasForeignKey(x => x.CollaboratorId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.ApprovedByUser)
                .WithMany()
                .HasForeignKey(x => x.ApprovedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<ClientScore>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.RiskLevel).HasMaxLength(32);
            entity.Property(x => x.SuggestedCreditLimit).HasPrecision(18, 2);
            entity.Property(x => x.PaymentCompliancePercent).HasPrecision(5, 2);
            entity.Property(x => x.TotalCredits).HasPrecision(18, 2);
            entity.Property(x => x.TotalPayments).HasPrecision(18, 2);
            entity.HasIndex(x => new { x.BusinessId, x.ClientId }).IsUnique();
            entity.HasIndex(x => new { x.BusinessId, x.Score });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany()
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(x => x.Client)
                .WithMany()
                .HasForeignKey(x => x.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<WhatsappCampaignPublication>(entity =>
        {
            entity.Property(x => x.RemoteId).HasMaxLength(64);
            entity.Property(x => x.LocalUuid).HasMaxLength(120);
            entity.Property(x => x.DateKey).HasMaxLength(16);
            entity.Property(x => x.Mode).HasMaxLength(32);
            entity.Property(x => x.Status).HasMaxLength(48);
            entity.Property(x => x.CampaignStatus).HasMaxLength(32);
            entity.HasIndex(x => new { x.BusinessId, x.LocalUuid }).IsUnique();
            entity.HasIndex(x => new { x.BusinessId, x.DateKey });
            entity.HasIndex(x => new { x.BusinessId, x.CampaignStatus, x.Status });
            entity.HasIndex(x => new { x.BusinessId, x.UpdatedAt });
            entity.HasIndex(x => new { x.BusinessId, x.DeletedAt });
            entity.HasIndex(x => new { x.BusinessId, x.LocalId });
            entity.HasIndex(x => new { x.BusinessId, x.RemoteId });

            entity.HasOne(x => x.Business)
                .WithMany()
                .HasForeignKey(x => x.BusinessId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<SyncLog>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.EntityType, x.Status, x.CreatedAt });
        });

        modelBuilder.Entity<PaymentMethod>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.BusinessId, x.IsDefault });
            entity.Property(x => x.Provider).HasMaxLength(40);
            entity.Property(x => x.ProviderCustomerId).HasMaxLength(160);
            entity.Property(x => x.ProviderPaymentMethodId).HasMaxLength(160);
            entity.Property(x => x.Brand).HasMaxLength(40);
            entity.Property(x => x.Last4).HasMaxLength(4);
        });

        modelBuilder.Entity<SubscriptionPayment>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.BusinessId, x.PaymentDate });
            entity.Property(x => x.AmountUsd).HasPrecision(18, 2);
            entity.Property(x => x.AmountDop).HasPrecision(18, 2);
            entity.Property(x => x.ExchangeRate).HasPrecision(18, 4);
            entity.Property(x => x.BillingCycle).HasMaxLength(32);
            entity.Property(x => x.Status).HasMaxLength(32);
            entity.Property(x => x.Provider).HasMaxLength(40);
            entity.Property(x => x.ProviderTransactionId).HasMaxLength(160);
        });

        modelBuilder.Entity<PaymentTransaction>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.PaymentId, x.CreatedAt });
            entity.Property(x => x.Provider).HasMaxLength(40);
            entity.Property(x => x.Status).HasMaxLength(32);
        });

        modelBuilder.Entity<PaymentWebhookLog>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.Provider, x.EventType, x.CreatedAt });
            entity.Property(x => x.Provider).HasMaxLength(40);
            entity.Property(x => x.EventType).HasMaxLength(120);
        });
    }
}
