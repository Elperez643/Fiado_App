using System.Text.Json;
using System.Text.Json.Nodes;

namespace FiadoApp.Api.Services;

public static class InventoryImagePushDiagnostics
{
    public const string RequestSummaryItemKey = "InventoryImagesPush.SafeRequestSummary";

    public static bool IsInventoryImagesPush(HttpRequest request) =>
        HttpMethods.IsPost(request.Method) &&
        (request.Path.Equals("/api/sync/inventory/images/push", StringComparison.OrdinalIgnoreCase) ||
         request.Path.Equals("/api/sync/inventory_images/push", StringComparison.OrdinalIgnoreCase));

    public static string BuildSafeRequestSummary(
        string rawBody,
        long? contentLength,
        string? requestContentType)
    {
        if (string.IsNullOrWhiteSpace(rawBody))
        {
            return JsonSerializer.Serialize(new
            {
                contentLength,
                requestContentType,
                bodyLength = 0,
                imagesCount = 0,
                changesCount = 0,
                json = "empty"
            });
        }

        try
        {
            var root = JsonNode.Parse(rawBody);
            var imagesCount = root?["images"] is JsonArray images ? images.Count : 0;
            var changesCount = root?["changes"] is JsonArray changes ? changes.Count : 0;
            Redact(root, null);
            return JsonSerializer.Serialize(new
            {
                contentLength,
                requestContentType,
                bodyLength = rawBody.Length,
                imagesCount,
                changesCount,
                json = root
            });
        }
        catch (JsonException ex)
        {
            return JsonSerializer.Serialize(new
            {
                contentLength,
                requestContentType,
                bodyLength = rawBody.Length,
                parseError = ex.Message,
                rawBody = "omitted because JSON parsing failed"
            });
        }
    }

    private static void Redact(JsonNode? node, string? propertyName)
    {
        if (node is JsonObject obj)
        {
            foreach (var property in obj.ToList())
            {
                var key = property.Key;
                var value = property.Value;
                if (IsSecret(key))
                {
                    obj[key] = "[redacted]";
                }
                else if (IsImageContent(key) && value is JsonValue imageValue && imageValue.TryGetValue<string>(out var content))
                {
                    obj[key] = new JsonObject
                    {
                        ["length"] = content.Length,
                        ["prefix"] = content[..Math.Min(20, content.Length)]
                    };
                }
                else
                {
                    Redact(value, key);
                }
            }
            return;
        }

        if (node is JsonArray array)
        {
            foreach (var item in array) Redact(item, propertyName);
        }
    }

    private static bool IsImageContent(string key)
    {
        var normalized = key.Replace("_", string.Empty).ToLowerInvariant();
        return normalized.Contains("base64") ||
               normalized is "imagedata" or "imagecontent" or "contentdata";
    }

    private static bool IsSecret(string key)
    {
        var normalized = key.ToLowerInvariant();
        return normalized.Contains("token") || normalized.Contains("password");
    }
}
