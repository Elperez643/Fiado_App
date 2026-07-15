namespace FiadoApp.Api.Subscriptions;

public sealed record SubscriptionPlanPrice(
    string PlanId,
    string PlanName,
    string BillingCycle,
    decimal PriceUsd,
    int CollaboratorsLimit,
    int DiscountPercent,
    decimal OriginalMonthlyUsd);

public static class SubscriptionPlanCatalog
{
    public const string CurrencyCode = "USD";

    private static readonly IReadOnlyDictionary<string, PlanDefinition> Plans =
        new Dictionary<string, PlanDefinition>(StringComparer.OrdinalIgnoreCase)
        {
            ["basico"] = new("basico", "Basico", 4.99m, 3),
            ["crecimiento"] = new("crecimiento", "Crecimiento", 12.99m, 7),
            ["empresarial"] = new("empresarial", "Empresarial", 20.99m, 15)
        };

    public static SubscriptionPlanPrice PriceFor(string planId, string billingCycle)
    {
        var plan = Plan(planId);
        var cycle = NormalizeBillingCycle(billingCycle);
        var months = Months(cycle);
        var discount = DiscountPercent(cycle);
        var original = Money(plan.MonthlyUsd * months);
        var price = Money(original * (1 - discount / 100m));
        return new SubscriptionPlanPrice(
            plan.PlanId,
            plan.PlanName,
            cycle,
            price,
            plan.CollaboratorsLimit,
            discount,
            plan.MonthlyUsd);
    }

    public static string NormalizeBillingCycle(string billingCycle)
    {
        var normalized = billingCycle.Trim().ToLowerInvariant();
        return normalized is "mensual" or "trimestral" or "anual"
            ? normalized
            : throw new InvalidOperationException("Ciclo de facturacion no reconocido.");
    }

    private static PlanDefinition Plan(string planId)
    {
        return Plans.TryGetValue(planId.Trim(), out var plan)
            ? plan
            : throw new InvalidOperationException("Plan de suscripcion no reconocido.");
    }

    private static int Months(string billingCycle) => billingCycle switch
    {
        "trimestral" => 3,
        "anual" => 12,
        _ => 1
    };

    private static int DiscountPercent(string billingCycle) => billingCycle switch
    {
        "trimestral" => 10,
        "anual" => 20,
        _ => 0
    };

    private static decimal Money(decimal value) => Math.Floor(value * 100m) / 100m;

    private sealed record PlanDefinition(
        string PlanId,
        string PlanName,
        decimal MonthlyUsd,
        int CollaboratorsLimit);
}
