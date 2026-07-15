using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/sync/inventory/images")]
[Route("api/sync/inventory_images")]
public sealed class InventoryImagesSyncController(
    FiadoDbContext dbContext,
    ILogger<InventoryImagesSyncController> logger) : ControllerBase
{
    [HttpPost("push")]
    public async Task<ActionResult<InventoryImagePushResponse>> Push(InventoryImagePushRequest request)
    {
        if (!ModelState.IsValid)
        {
            var requestSummary = HttpContext.Items.TryGetValue(
                InventoryImagePushDiagnostics.RequestSummaryItemKey,
                out var summary)
                ? summary?.ToString() ?? "unavailable"
                : "unavailable";
            foreach (var entry in ModelState.Where(entry => entry.Value?.Errors.Count > 0))
            {
                foreach (var error in entry.Value!.Errors)
                {
                    logger.LogWarning(
                        "[inventory-images-push-validation-failed] endpoint={Endpoint} field={Field} error={Error} requestSummary={RequestSummary}",
                        Request.Path,
                        entry.Key,
                        error.ErrorMessage.Length > 0 ? error.ErrorMessage : error.Exception?.Message ?? "validation error",
                        requestSummary);
                }
            }
            return ValidationProblem(ModelState);
        }

        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(User, "sync inventory images");
        var errors = new List<string>();
        var accepted = 0;

        var images = request.Images
            .Concat(request.Changes.Select(change => change.Payload))
            .Take(25)
            .ToList();

        foreach (var item in images)
        {
            var error = await ApplyMetadataAsync(businessId, item);
            if (error is null)
            {
                accepted++;
            }
            else
            {
                errors.Add(error);
            }
        }

        stopwatch.Stop();
        logger.LogInformation(
            "[sync-inventory-images-push] businessId={BusinessId} count={Count} accepted={Accepted} rejected={Rejected} elapsedMs={ElapsedMs}",
            businessId,
            images.Count,
            accepted,
            images.Count - accepted,
            stopwatch.ElapsedMilliseconds);

        return Ok(new InventoryImagePushResponse
        {
            Accepted = accepted,
            Rejected = images.Count - accepted,
            Errors = errors,
            ServerTime = DateTime.UtcNow
        });
    }

    [HttpPost("pull")]
    public async Task<ActionResult<InventoryImagePullResponse>> Pull(InventoryImagePullRequest request)
    {
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(User, "sync inventory images");
        var limit = Math.Clamp(request.Limit, 1, 25);
        var productUuids = request.ProductUuids
            .Append(request.ProductUuid)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x!.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        var query = dbContext.ProductImages.AsNoTracking()
            .Where(x => x.BusinessId == businessId);
        if (request.Since is not null)
        {
            query = query.Where(x => x.UpdatedAt > request.Since || (x.DeletedAt != null && x.DeletedAt > request.Since));
        }
        if (productUuids.Count > 0)
        {
            query = query.Where(x => x.ProductRemoteId != null && productUuids.Contains(x.ProductRemoteId));
        }
        if (request.OnlyMissingContent)
        {
            query = query.Where(x => x.HasContent);
        }

        var rows = await query
            .OrderBy(x => x.UpdatedAt)
            .ThenBy(x => x.Order)
            .Take(limit + 1)
            .ToListAsync();
        var hasMore = rows.Count > limit;
        var images = rows.Take(limit).Select(x => Map(x, includeContent: request.Content && limit <= 10)).ToList();

        stopwatch.Stop();
        logger.LogInformation(
            "[sync-inventory-images-pull] businessId={BusinessId} since={Since} productUuid={ProductUuid} count={Count} elapsedMs={ElapsedMs}",
            businessId,
            request.Since,
            productUuids.Count == 1 ? productUuids[0] : "*",
            images.Count,
            stopwatch.ElapsedMilliseconds);

        return Ok(new InventoryImagePullResponse
        {
            Images = images,
            HasMore = hasMore,
            ServerTime = DateTime.UtcNow
        });
    }

    [HttpGet("{imageUuid}/content")]
    public async Task<ActionResult<InventoryImageContentResponse>> GetContent(string imageUuid)
    {
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(User, "sync inventory image content");
        var image = await dbContext.ProductImages.AsNoTracking()
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == imageUuid);
        if (image is null) return NotFound(new { message = "Imagen no encontrada." });

        stopwatch.Stop();
        logger.LogInformation(
            "[sync-inventory-image-content] imageUuid={ImageUuid} sizeBytes={SizeBytes} status={Status} elapsedMs={ElapsedMs}",
            imageUuid,
            image.SizeBytes,
            image.HasContent ? "ok" : "missing",
            stopwatch.ElapsedMilliseconds);

        return Ok(new InventoryImageContentResponse
        {
            ImageUuid = image.RemoteId ?? image.Id.ToString(),
            ProductUuid = image.ProductRemoteId,
            ContentBase64 = image.ContentBase64,
            ContentHash = image.ContentHash,
            MimeType = image.MimeType,
            SizeBytes = image.SizeBytes
        });
    }

    [HttpPost("content/push")]
    public async Task<ActionResult<InventoryImageContentResponse>> PushContent(InventoryImageContentPushRequest request)
    {
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(User, "sync inventory image content");
        if (string.IsNullOrWhiteSpace(request.ImageUuid))
        {
            return BadRequest(new { message = "imageUuid requerido." });
        }

        var image = await dbContext.ProductImages
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == request.ImageUuid);
        if (image is null) return NotFound(new { message = "Imagen no encontrada." });

        image.ContentBase64 = request.ContentBase64;
        image.ContentHash = request.ContentHash;
        image.MimeType = request.MimeType ?? image.MimeType;
        image.SizeBytes = request.SizeBytes > 0 ? request.SizeBytes : image.SizeBytes;
        image.HasContent = !string.IsNullOrWhiteSpace(request.ContentBase64);
        image.UpdatedAt = DateTime.UtcNow;
        image.LastSyncedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        stopwatch.Stop();
        logger.LogInformation(
            "[sync-inventory-image-content] imageUuid={ImageUuid} sizeBytes={SizeBytes} status={Status} elapsedMs={ElapsedMs}",
            request.ImageUuid,
            image.SizeBytes,
            "pushed",
            stopwatch.ElapsedMilliseconds);

        return Ok(new InventoryImageContentResponse
        {
            ImageUuid = image.RemoteId ?? image.Id.ToString(),
            ProductUuid = image.ProductRemoteId,
            ContentHash = image.ContentHash,
            MimeType = image.MimeType,
            SizeBytes = image.SizeBytes
        });
    }

    private async Task<string?> ApplyMetadataAsync(Guid businessId, InventoryImageMetadataDto item)
    {
        if (string.IsNullOrWhiteSpace(item.Uuid)) return "Imagen requiere uuid.";
        if (string.IsNullOrWhiteSpace(item.ProductUuid)) return $"Imagen {item.Uuid} requiere productUuid.";
        var product = await dbContext.Products
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == item.ProductUuid);
        if (product is null) return $"Producto {item.ProductUuid} no existe para imagen {item.Uuid}.";

        var image = await dbContext.ProductImages
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.RemoteId == item.Uuid);
        image ??= new ProductImage
        {
            BusinessId = businessId,
            ProductId = product.Id,
            RemoteId = item.Uuid,
            CreatedAt = item.CreatedAt ?? DateTime.UtcNow
        };

        image.ProductId = product.Id;
        image.ProductRemoteId = item.ProductUuid;
        image.FileName = item.FileName;
        image.LocalPath = string.Empty;
        image.MimeType = item.MimeType;
        image.SizeBytes = item.SizeBytes;
        image.ContentHash = item.ContentHash;
        image.Width = item.Width;
        image.Height = item.Height;
        image.Order = item.SortOrder;
        image.DeletedAt = item.DeletedAt;
        image.SyncStatus = item.DeletedAt is null ? "synced" : "deleted";
        image.UpdatedAt = item.UpdatedAt ?? DateTime.UtcNow;
        image.LastSyncedAt = DateTime.UtcNow;
        if (!string.IsNullOrWhiteSpace(item.ContentBase64))
        {
            image.ContentBase64 = item.ContentBase64;
            image.HasContent = true;
        }

        if (dbContext.Entry(image).State == EntityState.Detached)
        {
            dbContext.ProductImages.Add(image);
        }
        await dbContext.SaveChangesAsync();
        return null;
    }

    private static InventoryImageMetadataDto Map(ProductImage image, bool includeContent)
    {
        return new InventoryImageMetadataDto
        {
            Uuid = image.RemoteId ?? image.Id.ToString(),
            ProductUuid = image.ProductRemoteId ?? string.Empty,
            ServerId = image.Id,
            BusinessId = image.BusinessId,
            FileName = image.FileName,
            MimeType = image.MimeType,
            SizeBytes = image.SizeBytes,
            ContentHash = image.ContentHash,
            Width = image.Width,
            Height = image.Height,
            IsCover = image.Order == 0,
            SortOrder = image.Order,
            CreatedAt = image.CreatedAt,
            UpdatedAt = image.UpdatedAt,
            DeletedAt = image.DeletedAt,
            HasContent = image.HasContent,
            ContentBase64 = includeContent ? image.ContentBase64 : null
        };
    }
}
