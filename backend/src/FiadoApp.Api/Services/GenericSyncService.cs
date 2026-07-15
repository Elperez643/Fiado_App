using System.Diagnostics;
using System.Security.Claims;
using System.Text.Json;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class GenericSyncService(
    FiadoDbContext dbContext,
    ILogger<GenericSyncService> logger) : IGenericSyncService
{
    private static readonly HashSet<string> AllowedModules = new(StringComparer.OrdinalIgnoreCase)
    {
        "clients",
        "movements",
        "inventory",
        "audits",
        "collaborators",
        "whatsapp"
    };

    public async Task<GenericSyncPushResponse> PushAsync(
        ClaimsPrincipal user,
        string module,
        GenericSyncPushRequest request)
    {
        var stopwatch = Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, $"sync {module}");
        var normalizedModule = ValidateModule(module);
        var deviceId = ValidateDeviceId(request.DeviceId);
        var errors = ValidateChanges(request);
        var accepted = 0;
        if (errors.Count == 0 && string.Equals(normalizedModule, "clients", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var change in request.Changes)
            {
                var error = await ApplyClientChangeAsync(businessId, change);
                if (error is null)
                {
                    accepted++;
                }
                else
                {
                    errors.Add(error);
                }
            }
        }
        else if (errors.Count == 0 && string.Equals(normalizedModule, "inventory", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var change in request.Changes)
            {
                var error = await ApplyInventoryChangeAsync(businessId, change);
                if (error is null)
                {
                    accepted++;
                }
                else
                {
                    errors.Add(error);
                }
            }
        }
        else if (errors.Count == 0)
        {
            accepted = request.Changes.Count;
        }
        stopwatch.Stop();

        var errorText = errors.Count == 0 ? null : string.Join("; ", errors);
        if (string.Equals(normalizedModule, "clients", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "[sync-clients-push] businessId={BusinessId} deviceId={DeviceId} count={Count} accepted={Accepted} rejected={Rejected} error={Error}",
                businessId,
                deviceId,
                request.Changes.Count,
                accepted,
                request.Changes.Count - accepted,
                errorText);
        }
        if (string.Equals(normalizedModule, "inventory", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "[sync-inventory-push] businessId={BusinessId} deviceId={DeviceId} count={Count} accepted={Accepted} rejected={Rejected} elapsedMs={ElapsedMs} error={Error}",
                businessId,
                deviceId,
                request.Changes.Count,
                accepted,
                request.Changes.Count - accepted,
                stopwatch.ElapsedMilliseconds,
                errorText);
        }
        logger.LogInformation(
            "[sync-v2] module={Module} businessId={BusinessId} deviceId={DeviceId} pushedCount={PushedCount} pulledCount={PulledCount} pendingCount={PendingCount} elapsedMs={ElapsedMs} status={Status} error={Error}",
            normalizedModule,
            businessId,
            deviceId,
            request.Changes.Count,
            0,
            0,
            stopwatch.ElapsedMilliseconds,
            errors.Count == 0 ? "accepted" : "rejected",
            errorText);

        return new GenericSyncPushResponse
        {
            Module = normalizedModule,
            Accepted = accepted,
            Rejected = request.Changes.Count - accepted,
            ServerTime = DateTime.UtcNow,
            Errors = errors
        };
    }

    public async Task<GenericSyncPullResponse> PullAsync(
        ClaimsPrincipal user,
        string module,
        GenericSyncPullRequest request)
    {
        var stopwatch = Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, $"sync {module}");
        var normalizedModule = ValidateModule(module);
        var deviceId = ValidateDeviceId(request.DeviceId);
        var changes = new List<object>();
        if (string.Equals(normalizedModule, "clients", StringComparison.OrdinalIgnoreCase))
        {
            changes.AddRange(await PullClientChangesAsync(businessId, request.LastPullAt));
        }
        if (string.Equals(normalizedModule, "inventory", StringComparison.OrdinalIgnoreCase))
        {
            changes.AddRange(await PullInventoryChangesAsync(businessId, request.LastPullAt));
        }
        stopwatch.Stop();

        if (string.Equals(normalizedModule, "clients", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "[sync-clients-pull] businessId={BusinessId} deviceId={DeviceId} since={Since} count={Count} error={Error}",
                businessId,
                deviceId,
                request.LastPullAt,
                changes.Count,
                null);
        }
        if (string.Equals(normalizedModule, "inventory", StringComparison.OrdinalIgnoreCase))
        {
            logger.LogInformation(
                "[sync-inventory-pull] businessId={BusinessId} deviceId={DeviceId} since={Since} count={Count} elapsedMs={ElapsedMs} error={Error}",
                businessId,
                deviceId,
                request.LastPullAt,
                changes.Count,
                stopwatch.ElapsedMilliseconds,
                null);
        }
        logger.LogInformation(
            "[sync-v2] module={Module} businessId={BusinessId} deviceId={DeviceId} pushedCount={PushedCount} pulledCount={PulledCount} pendingCount={PendingCount} elapsedMs={ElapsedMs} status={Status} error={Error}",
            normalizedModule,
            businessId,
            deviceId,
            changes.Count,
            0,
            0,
            stopwatch.ElapsedMilliseconds,
            "ok",
            null);

        return new GenericSyncPullResponse
        {
            Module = normalizedModule,
            Changes = changes,
            ServerTime = DateTime.UtcNow,
            HasMore = false
        };
    }

    private static string ValidateModule(string module)
    {
        var normalized = module.Trim().ToLowerInvariant();
        if (!AllowedModules.Contains(normalized))
        {
            throw new InvalidOperationException($"Modulo de sync no soportado: {module}");
        }
        return normalized;
    }

    private static string ValidateDeviceId(string? deviceId)
    {
        if (string.IsNullOrWhiteSpace(deviceId))
        {
            throw new InvalidOperationException("deviceId es obligatorio.");
        }
        return deviceId.Trim();
    }

    private static List<string> ValidateChanges(GenericSyncPushRequest request)
    {
        var errors = new List<string>();
        foreach (var change in request.Changes)
        {
            if (string.IsNullOrWhiteSpace(change.Uuid))
            {
                errors.Add("Cada cambio requiere uuid.");
            }
            if (string.IsNullOrWhiteSpace(change.EntityUuid))
            {
                errors.Add("Cada cambio requiere entityUuid.");
            }
            if (string.IsNullOrWhiteSpace(change.Operation))
            {
                errors.Add("Cada cambio requiere operation.");
            }
        }
        return errors;
    }

    private async Task<string?> ApplyClientChangeAsync(Guid businessId, GenericSyncChangeRequest change)
    {
        JsonElement? payload = change.Payload is JsonElement element ? element : null;
        var uuid = Text(payload, "uuid") ?? change.EntityUuid.Trim();
        if (string.IsNullOrWhiteSpace(uuid))
        {
            return "Cliente requiere uuid.";
        }

        var name = Text(payload, "nombre", "name") ?? string.Empty;
        var phone = Text(payload, "telefono", "phone") ?? string.Empty;
        if (string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(phone))
        {
            return $"Cliente {uuid} requiere nombre y telefono.";
        }

        var updatedAt = Date(payload, "updatedAt", "updated_at") ?? change.UpdatedAt ?? DateTime.UtcNow;
        var deletedAt = Date(payload, "deletedAt", "deleted_at");
        var normalizedPhone = phone.Trim();
        var existing = await dbContext.Clients
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == uuid);
        var phoneOwner = await dbContext.Clients
            .FirstOrDefaultAsync(x =>
                x.BusinessId == businessId &&
                x.Phone == normalizedPhone &&
                x.IsActive &&
                x.RemoteId != uuid);
        if (phoneOwner is not null)
        {
            return $"Ya existe un cliente con el telefono {normalizedPhone} en este negocio.";
        }

        if (existing is not null && existing.UpdatedAt > updatedAt)
        {
            return null;
        }

        var now = DateTime.UtcNow;
        var client = existing ?? new Client
        {
            BusinessId = businessId,
            RemoteId = uuid,
            CreatedAt = updatedAt
        };

        client.RemoteId = uuid;
        client.Name = name.Trim();
        client.Phone = normalizedPhone;
        client.Address = Text(payload, "direccion", "address");
        client.Debt = Decimal(payload, "deuda", "debt") ?? client.Debt;
        client.IsActive = deletedAt is null;
        client.DeletedAt = deletedAt;
        client.UpdatedAt = updatedAt > now ? now : updatedAt;
        client.LastSyncedAt = now;
        client.SyncStatus = "synced";

        if (existing is null)
        {
            dbContext.Clients.Add(client);
        }

        await dbContext.SaveChangesAsync();
        return null;
    }

    private async Task<List<object>> PullClientChangesAsync(Guid businessId, DateTime? since)
    {
        var query = dbContext.Clients.AsNoTracking().Where(x => x.BusinessId == businessId);
        if (since is not null)
        {
            query = query.Where(x => x.UpdatedAt > since || (x.DeletedAt != null && x.DeletedAt > since));
        }
        var rows = await query
            .OrderBy(x => x.UpdatedAt)
            .Select(x => new
            {
                uuid = x.RemoteId ?? x.Id.ToString(),
                serverId = x.Id,
                businessId = x.BusinessId,
                nombre = x.Name,
                telefono = x.Phone,
                direccion = x.Address,
                deuda = x.Debt,
                createdAt = x.CreatedAt,
                updatedAt = x.UpdatedAt,
                deletedAt = x.DeletedAt,
                syncVersion = 0
            })
            .ToListAsync();
        return rows.Cast<object>().ToList();
    }

    private async Task<string?> ApplyInventoryChangeAsync(Guid businessId, GenericSyncChangeRequest change)
    {
        var entityType = change.EntityType.Trim().ToLowerInvariant();
        if (entityType != "product")
        {
            return $"Tipo de inventario no soportado: {change.EntityType}";
        }

        JsonElement? payload = change.Payload is JsonElement element ? element : null;
        var uuid = Text(payload, "uuid", "legacyId", "legacy_id") ?? change.EntityUuid.Trim();
        if (string.IsNullOrWhiteSpace(uuid))
        {
            return "Producto requiere uuid.";
        }

        var operation = change.Operation.Trim().ToLowerInvariant();
        var updatedAt = Date(payload, "updatedAt", "updated_at") ?? change.UpdatedAt ?? DateTime.UtcNow;
        var deletedAt = Date(payload, "deletedAt", "deleted_at");
        var existing = await dbContext.Products
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == uuid);

        if (operation == "delete")
        {
            if (existing is null) return null;
            existing.IsActive = false;
            existing.DeletedAt = deletedAt ?? DateTime.UtcNow;
            existing.UpdatedAt = DateTime.UtcNow;
            existing.LastSyncedAt = DateTime.UtcNow;
            existing.SyncStatus = "synced";
            await dbContext.SaveChangesAsync();
            return null;
        }

        var name = Text(payload, "nombre", "name") ?? string.Empty;
        if (string.IsNullOrWhiteSpace(name))
        {
            return $"Producto {uuid} requiere nombre.";
        }

        var codeReference = Text(payload, "codigoReferencia", "codeReference", "codigo_referencia");
        var normalizedName = name.Trim();
        var normalizedCode = string.IsNullOrWhiteSpace(codeReference) ? null : codeReference.Trim();
        var duplicate = await dbContext.Products.FirstOrDefaultAsync(x =>
            x.BusinessId == businessId &&
            x.IsActive &&
            x.RemoteId != uuid &&
            (x.Name.ToLower() == normalizedName.ToLower() ||
                (normalizedCode != null && x.CodeReference != null && x.CodeReference.ToLower() == normalizedCode.ToLower())));
        if (duplicate is not null)
        {
            return "Ya existe un producto activo con ese nombre o codigo en este negocio.";
        }

        if (existing is not null && existing.UpdatedAt > updatedAt)
        {
            return null;
        }

        var now = DateTime.UtcNow;
        var product = existing ?? new Product
        {
            BusinessId = businessId,
            RemoteId = uuid,
            CreatedAt = updatedAt
        };

        product.RemoteId = uuid;
        product.Name = normalizedName;
        product.CodeReference = normalizedCode;
        product.Category = Text(payload, "categoria", "category");
        product.Description = Text(payload, "descripcion", "description");
        product.Location = Text(payload, "ubicacion", "location");
        product.MeasureType = Text(payload, "tipoMedida", "measureType");
        product.DemandLevel = Text(payload, "nivelDemanda", "demandLevel");
        product.Quantity = Int(payload, "cantidad", "quantity", "stock") ?? product.Quantity;
        product.PurchasePrice = Decimal(payload, "precioCompra", "purchasePrice", "costoUnitario", "unitCost", "precio_compra", "costo_unitario") ?? product.PurchasePrice;
        product.SalePrice = Decimal(payload, "precioVenta", "salePrice", "precio_venta") ?? product.SalePrice;
        product.ProfitMarginPercent = Decimal(payload, "porcentajeGanancia", "profitMarginPercent", "porcentaje_ganancia") ?? product.ProfitMarginPercent;
        product.MinimumStock = Int(payload, "stockMinimo", "minimumStock", "stock_minimo") ?? product.MinimumStock;
        product.IsKeyProduct = Bool(payload, "esClave", "isKeyProduct", "es_clave") ?? product.IsKeyProduct;
        product.IsActive = deletedAt is null;
        product.DeletedAt = deletedAt;
        product.UpdatedAt = updatedAt > now ? now : updatedAt;
        product.LastSyncedAt = now;
        product.SyncStatus = "synced";

        logger.LogInformation(
            "[sync-inventory-push] product uuid={Uuid} price={Price} cost={Cost} stock={Stock}",
            uuid,
            product.SalePrice,
            product.PurchasePrice,
            product.Quantity);

        if (existing is null)
        {
            dbContext.Products.Add(product);
        }

        await dbContext.SaveChangesAsync();
        return null;
    }

    private async Task<List<object>> PullInventoryChangesAsync(Guid businessId, DateTime? since)
    {
        var query = dbContext.Products.AsNoTracking().Where(x => x.BusinessId == businessId);
        if (since is not null)
        {
            query = query.Where(x => x.UpdatedAt > since || (x.DeletedAt != null && x.DeletedAt > since));
        }
        var rows = await query
            .OrderBy(x => x.UpdatedAt)
            .Select(x => new
            {
                entityType = "product",
                uuid = x.RemoteId ?? x.Id.ToString(),
                serverId = x.Id,
                businessId = x.BusinessId,
                nombre = x.Name,
                codigoReferencia = x.CodeReference,
                categoria = x.Category,
                descripcion = x.Description,
                ubicacion = x.Location,
                cantidad = x.Quantity,
                costoUnitario = x.PurchasePrice,
                precioCompra = x.PurchasePrice,
                precioVenta = x.SalePrice,
                porcentajeGanancia = x.ProfitMarginPercent,
                stockMinimo = x.MinimumStock,
                tipoMedida = x.MeasureType,
                nivelDemanda = x.DemandLevel,
                esClave = x.IsKeyProduct,
                imageCount = dbContext.ProductImages.Count(i =>
                    i.BusinessId == businessId &&
                    i.ProductRemoteId == (x.RemoteId ?? x.Id.ToString()) &&
                    i.DeletedAt == null),
                coverImageUuid = dbContext.ProductImages
                    .Where(i =>
                        i.BusinessId == businessId &&
                        i.ProductRemoteId == (x.RemoteId ?? x.Id.ToString()) &&
                        i.DeletedAt == null)
                    .OrderBy(i => i.Order)
                    .Select(i => i.RemoteId)
                    .FirstOrDefault(),
                imagesUpdatedAt = dbContext.ProductImages
                    .Where(i =>
                        i.BusinessId == businessId &&
                        i.ProductRemoteId == (x.RemoteId ?? x.Id.ToString()))
                    .Select(i => (DateTime?)i.UpdatedAt)
                    .Max(),
                createdAt = x.CreatedAt,
                updatedAt = x.UpdatedAt,
                deletedAt = x.DeletedAt,
                syncVersion = 0
            })
            .ToListAsync();

        foreach (var row in rows)
        {
            logger.LogInformation(
                "[sync-inventory-pull] product uuid={Uuid} price={Price} cost={Cost} stock={Stock}",
                row.uuid,
                row.precioVenta,
                row.costoUnitario,
                row.cantidad);
        }

        return rows.Cast<object>().ToList();
    }

    private static string? Text(JsonElement? payload, params string[] keys)
    {
        if (payload is null || payload.Value.ValueKind != JsonValueKind.Object) return null;
        foreach (var key in keys)
        {
            if (!payload.Value.TryGetProperty(key, out var value) || value.ValueKind == JsonValueKind.Null)
            {
                continue;
            }
            var text = value.ValueKind == JsonValueKind.String ? value.GetString() : value.ToString();
            if (!string.IsNullOrWhiteSpace(text)) return text.Trim();
        }
        return null;
    }

    private static DateTime? Date(JsonElement? payload, params string[] keys)
    {
        var text = Text(payload, keys);
        return DateTime.TryParse(text, out var value) ? value : null;
    }

    private static decimal? Decimal(JsonElement? payload, params string[] keys)
    {
        if (payload is null || payload.Value.ValueKind != JsonValueKind.Object) return null;
        foreach (var key in keys)
        {
            if (!payload.Value.TryGetProperty(key, out var value) || value.ValueKind == JsonValueKind.Null)
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
        return null;
    }

    private static int? Int(JsonElement? payload, params string[] keys)
    {
        if (payload is null || payload.Value.ValueKind != JsonValueKind.Object) return null;
        foreach (var key in keys)
        {
            if (!payload.Value.TryGetProperty(key, out var value) || value.ValueKind == JsonValueKind.Null)
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
        return null;
    }

    private static bool? Bool(JsonElement? payload, params string[] keys)
    {
        var text = Text(payload, keys);
        if (bool.TryParse(text, out var value)) return value;
        if (int.TryParse(text, out var number)) return number != 0;
        return null;
    }
}
