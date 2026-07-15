using System.Security.Claims;
using System.Text.Json;

namespace FiadoApp.Api.Services;

internal static class OperationalSyncMapper
{
    public static Guid BusinessId(ClaimsPrincipal user, string resource)
        => FinancialSyncMapper.GetBusinessIdForBusinessUser(user, resource);

    public static Guid UserId(ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(value, out var id) ? id : throw new UnauthorizedAccessException("Token sin usuario valido.");
    }

    public static string? Role(ClaimsPrincipal user) => user.FindFirstValue(ClaimTypes.Role);
    public static bool IsBusiness(ClaimsPrincipal user) => string.Equals(Role(user), "Negocio", StringComparison.OrdinalIgnoreCase);
    public static bool IsCollaborator(ClaimsPrincipal user) => string.Equals(Role(user), "Colaborador", StringComparison.OrdinalIgnoreCase);

    public static string? Text(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
        => FinancialSyncMapper.Text(payload, keys);
    public static Guid? GuidValue(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
        => FinancialSyncMapper.GuidValue(payload, keys);
    public static int IntValue(IReadOnlyDictionary<string, JsonElement> payload, int fallback = 0, params string[] keys)
        => FinancialSyncMapper.IntValue(payload, fallback, keys);
    public static DateTime DateValue(IReadOnlyDictionary<string, JsonElement> payload, DateTime fallback, params string[] keys)
        => FinancialSyncMapper.DateValue(payload, fallback, keys);
}
