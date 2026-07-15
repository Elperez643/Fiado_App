using System.Security.Claims;
using System.Text.Json;

namespace FiadoApp.Api.Services;

internal static class FinancialSyncMapper
{
    public static Guid GetBusinessIdForBusinessUser(ClaimsPrincipal user, string resource)
    {
        var role = user.FindFirstValue(ClaimTypes.Role);
        if (string.Equals(role, "Personal", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException($"El usuario Personal no puede acceder a {resource} de negocio.");
        }

        if (!string.Equals(role, "Negocio", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(role, "Colaborador", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException($"Rol no autorizado para {resource} de negocio.");
        }

        var businessIdValue = user.FindFirstValue("business_id");
        if (!Guid.TryParse(businessIdValue, out var businessId))
        {
            throw new UnauthorizedAccessException("El usuario autenticado no tiene negocio asociado.");
        }

        return businessId;
    }

    public static string? Text(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (payload.TryGetValue(key, out var value) && value.ValueKind != JsonValueKind.Null)
            {
                var text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
                return string.IsNullOrWhiteSpace(text) ? null : text.Trim();
            }
        }

        return null;
    }

    public static Guid? GuidValue(IReadOnlyDictionary<string, JsonElement> payload, params string[] keys)
    {
        var text = Text(payload, keys);
        return Guid.TryParse(text, out var value) ? value : null;
    }

    public static int IntValue(IReadOnlyDictionary<string, JsonElement> payload, int fallback = 0, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (!payload.TryGetValue(key, out var value) || value.ValueKind == JsonValueKind.Null)
            {
                continue;
            }

            if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number))
            {
                return number;
            }

            if (int.TryParse(value.ToString(), out var parsed))
            {
                return parsed;
            }
        }

        return fallback;
    }

    public static decimal DecimalValue(IReadOnlyDictionary<string, JsonElement> payload, decimal fallback = 0, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (!payload.TryGetValue(key, out var value) || value.ValueKind == JsonValueKind.Null)
            {
                continue;
            }

            if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            {
                return number;
            }

            if (decimal.TryParse(value.ToString(), out var parsed))
            {
                return parsed;
            }
        }

        return fallback;
    }

    public static bool BoolValue(IReadOnlyDictionary<string, JsonElement> payload, bool fallback = false, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (!payload.TryGetValue(key, out var value) || value.ValueKind == JsonValueKind.Null)
            {
                continue;
            }

            if (value.ValueKind is JsonValueKind.True or JsonValueKind.False)
            {
                return value.GetBoolean();
            }

            var text = value.ToString();
            if (bool.TryParse(text, out var parsedBool))
            {
                return parsedBool;
            }
            if (int.TryParse(text, out var parsedInt))
            {
                return parsedInt != 0;
            }
        }

        return fallback;
    }

    public static DateTime DateValue(IReadOnlyDictionary<string, JsonElement> payload, DateTime fallback, params string[] keys)
    {
        var text = Text(payload, keys);
        return DateTime.TryParse(text, out var value) ? value : fallback;
    }
}
