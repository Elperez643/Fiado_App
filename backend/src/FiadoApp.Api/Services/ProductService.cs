using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class ProductService(FiadoDbContext dbContext) : IProductService
{
    private const long MaxImageSizeBytes = 2 * 1024 * 1024;
    private static readonly HashSet<string> AllowedMimeTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/png",
        "image/jpeg",
        "image/jpg"
    };

    public async Task<ProductResponse> CreateAsync(ClaimsPrincipal user, ProductCreateRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        ValidateProductAmounts(request.Quantity, request.PurchasePrice, request.SalePrice, request.ProfitMarginPercent);
        await EnsureProductIsValidAsync(businessId, request.Name, request.CodeReference, null);

        var now = DateTime.UtcNow;
        var product = new Product
        {
            BusinessId = businessId,
            Name = request.Name.Trim(),
            CodeReference = NormalizeOptional(request.CodeReference),
            Category = NormalizeOptional(request.Category),
            Location = NormalizeOptional(request.Location),
            Description = NormalizeOptional(request.Description),
            Quantity = request.Quantity,
            PurchasePrice = request.PurchasePrice,
            SalePrice = request.SalePrice,
            ProfitMarginPercent = request.ProfitMarginPercent,
            MinimumStock = request.MinimumStock,
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now,
            LastSyncedAt = now,
            SyncStatus = "synced"
        };

        dbContext.Products.Add(product);
        await dbContext.SaveChangesAsync();
        return Map(product);
    }

    public async Task<ProductResponse> UpdateAsync(ClaimsPrincipal user, Guid id, ProductUpdateRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var product = await FindProductForBusinessAsync(businessId, id);
        ValidateProductAmounts(request.Quantity, request.PurchasePrice, request.SalePrice, request.ProfitMarginPercent);
        await EnsureProductIsValidAsync(businessId, request.Name, request.CodeReference, id);

        var now = DateTime.UtcNow;
        product.Name = request.Name.Trim();
        product.CodeReference = NormalizeOptional(request.CodeReference);
        product.Category = NormalizeOptional(request.Category);
        product.Location = NormalizeOptional(request.Location);
        product.Description = NormalizeOptional(request.Description);
        product.Quantity = request.Quantity;
        product.PurchasePrice = request.PurchasePrice;
        product.SalePrice = request.SalePrice;
        product.ProfitMarginPercent = request.ProfitMarginPercent;
        product.MinimumStock = request.MinimumStock;
        product.IsActive = request.IsActive;
        product.DeletedAt = request.IsActive ? null : now;
        product.UpdatedAt = now;
        product.LastSyncedAt = now;
        product.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return Map(product);
    }

    public async Task<ProductResponse> GetByIdAsync(ClaimsPrincipal user, Guid id)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        return Map(await FindProductForBusinessAsync(businessId, id));
    }

    public async Task<IReadOnlyList<ProductResponse>> GetByBusinessAsync(ClaimsPrincipal user)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        return await dbContext.Products
            .AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.IsActive && x.DeletedAt == null)
            .OrderBy(x => x.Name)
            .Select(x => Map(x))
            .ToListAsync();
    }

    public async Task<ProductSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, ProductSyncPushRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var response = new ProductSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.Products)
        {
            try
            {
                response.Results.Add(await ApplyProductPushItemAsync(businessId, item));
            }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
            {
                response.Results.Add(new ProductSyncPushItemResponse
                {
                    LocalId = item.LocalId,
                    ServerId = item.ServerId,
                    Status = "failed",
                    Error = ex.Message
                });
            }
        }

        return response;
    }

    public async Task<ProductSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, ProductSyncPullRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var query = dbContext.Products.AsNoTracking().Where(x => x.BusinessId == businessId);

        if (request.LastSyncAt is not null)
        {
            query = query.Where(x =>
                x.UpdatedAt > request.LastSyncAt.Value ||
                (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt.Value));
        }

        return new ProductSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Products = await query.OrderBy(x => x.UpdatedAt).Select(x => Map(x)).ToListAsync()
        };
    }

    public async Task<IReadOnlyList<ProductImageResponse>> GetImagesByProductAsync(ClaimsPrincipal user, Guid productId)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        _ = await FindProductForBusinessAsync(businessId, productId);

        return await dbContext.ProductImages
            .AsNoTracking()
            .Where(x => x.BusinessId == businessId && x.ProductId == productId && x.DeletedAt == null)
            .OrderBy(x => x.Order)
            .Select(x => MapImage(x))
            .ToListAsync();
    }

    public async Task<ProductImageSyncPushResponse> PushImagesSyncAsync(ClaimsPrincipal user, ProductImageSyncPushRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var response = new ProductImageSyncPushResponse { ServerTime = DateTime.UtcNow };

        foreach (var item in request.Images)
        {
            try
            {
                response.Results.Add(await ApplyImagePushItemAsync(businessId, item));
            }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
            {
                response.Results.Add(new ProductImageSyncPushItemResponse
                {
                    LocalId = item.LocalId,
                    ServerId = item.ServerId,
                    ProductServerId = item.ProductServerId,
                    Status = "failed",
                    Error = ex.Message
                });
            }
        }

        return response;
    }

    public async Task<ProductImageSyncPullResponse> PullImagesSyncAsync(ClaimsPrincipal user, ProductImageSyncPullRequest request)
    {
        var businessId = GetBusinessIdForBusinessUser(user);
        var query = dbContext.ProductImages.AsNoTracking().Where(x => x.BusinessId == businessId);

        if (request.LastSyncAt is not null)
        {
            query = query.Where(x =>
                x.UpdatedAt > request.LastSyncAt.Value ||
                (x.DeletedAt != null && x.DeletedAt > request.LastSyncAt.Value));
        }

        return new ProductImageSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            Images = await query.OrderBy(x => x.UpdatedAt).Select(x => MapImage(x)).ToListAsync()
        };
    }

    private async Task<ProductSyncPushItemResponse> ApplyProductPushItemAsync(Guid businessId, ProductSyncPushItemRequest item)
    {
        return item.Operation.Trim().ToLowerInvariant() switch
        {
            "create" => await ApplyProductCreatePushAsync(businessId, item),
            "update" => await ApplyProductUpdatePushAsync(businessId, item),
            "delete" => await ApplyProductDeletePushAsync(businessId, item),
            _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
        };
    }

    private async Task<ProductSyncPushItemResponse> ApplyProductCreatePushAsync(Guid businessId, ProductSyncPushItemRequest item)
    {
        var existingByLocalId = await dbContext.Products
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.LocalId == item.LocalId);

        if (existingByLocalId is not null)
        {
            return await UpdateProductFromPushAsync(existingByLocalId, item, "updated");
        }

        await EnsureProductIsValidAsync(businessId, item.Name, item.CodeReference, null);
        ValidateProductAmounts(item.Quantity, item.PurchasePrice, item.SalePrice, item.ProfitMarginPercent);
        var now = DateTime.UtcNow;
        var product = new Product
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            Name = item.Name.Trim(),
            CodeReference = NormalizeOptional(item.CodeReference),
            Category = NormalizeOptional(item.Category),
            Location = NormalizeOptional(item.Location),
            Description = NormalizeOptional(item.Description),
            Quantity = item.Quantity,
            PurchasePrice = item.PurchasePrice,
            SalePrice = item.SalePrice,
            ProfitMarginPercent = item.ProfitMarginPercent,
            MinimumStock = item.MinimumStock,
            IsActive = true,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt,
            UpdatedAt = now,
            LastSyncedAt = now,
            SyncStatus = "synced"
        };

        dbContext.Products.Add(product);
        await dbContext.SaveChangesAsync();
        return BuildProductPushResult(item.LocalId, product.Id, "created", product.UpdatedAt);
    }

    private async Task<ProductSyncPushItemResponse> ApplyProductUpdatePushAsync(Guid businessId, ProductSyncPushItemRequest item)
    {
        var product = await FindProductForPushAsync(businessId, item.ServerId, item.LocalId);
        return await UpdateProductFromPushAsync(product, item, "updated");
    }

    private async Task<ProductSyncPushItemResponse> ApplyProductDeletePushAsync(Guid businessId, ProductSyncPushItemRequest item)
    {
        var product = await FindProductForPushAsync(businessId, item.ServerId, item.LocalId);
        var now = DateTime.UtcNow;
        product.IsActive = false;
        product.DeletedAt = now;
        product.UpdatedAt = now;
        product.LastSyncedAt = now;
        product.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildProductPushResult(item.LocalId, product.Id, "deleted", product.UpdatedAt);
    }

    private async Task<ProductSyncPushItemResponse> UpdateProductFromPushAsync(Product product, ProductSyncPushItemRequest item, string status)
    {
        await EnsureProductIsValidAsync(product.BusinessId, item.Name, item.CodeReference, product.Id);
        ValidateProductAmounts(item.Quantity, item.PurchasePrice, item.SalePrice, item.ProfitMarginPercent);
        var now = DateTime.UtcNow;
        product.LocalId = item.LocalId;
        product.Name = item.Name.Trim();
        product.CodeReference = NormalizeOptional(item.CodeReference);
        product.Category = NormalizeOptional(item.Category);
        product.Location = NormalizeOptional(item.Location);
        product.Description = NormalizeOptional(item.Description);
        product.Quantity = item.Quantity;
        product.PurchasePrice = item.PurchasePrice;
        product.SalePrice = item.SalePrice;
        product.ProfitMarginPercent = item.ProfitMarginPercent;
        product.MinimumStock = item.MinimumStock;
        product.IsActive = true;
        product.DeletedAt = null;
        product.UpdatedAt = now;
        product.LastSyncedAt = now;
        product.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildProductPushResult(item.LocalId, product.Id, status, product.UpdatedAt);
    }

    private async Task<ProductImageSyncPushItemResponse> ApplyImagePushItemAsync(Guid businessId, ProductImageSyncPushItemRequest item)
    {
        return item.Operation.Trim().ToLowerInvariant() switch
        {
            "create" => await ApplyImageCreatePushAsync(businessId, item),
            "update" => await ApplyImageUpdatePushAsync(businessId, item),
            "delete" => await ApplyImageDeletePushAsync(businessId, item),
            _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
        };
    }

    private async Task<ProductImageSyncPushItemResponse> ApplyImageCreatePushAsync(Guid businessId, ProductImageSyncPushItemRequest item)
    {
        var existing = await dbContext.ProductImages
            .FirstOrDefaultAsync(x => x.BusinessId == businessId && x.LocalId == item.LocalId);
        if (existing is not null)
        {
            return await UpdateImageFromPushAsync(existing, item, "updated");
        }

        var product = await FindProductForPushAsync(businessId, item.ProductServerId, item.ProductLocalId);
        ValidateImageMetadata(item);
        await EnsureImageLimitAsync(businessId, product.Id, null);

        var now = DateTime.UtcNow;
        var image = new ProductImage
        {
            BusinessId = businessId,
            ProductId = product.Id,
            LocalId = item.LocalId,
            LocalPath = item.LocalPath.Trim(),
            RemoteUrl = NormalizeOptional(item.RemoteUrl),
            StorageKey = NormalizeOptional(item.StorageKey),
            Order = item.Order,
            MimeType = NormalizeOptional(item.MimeType),
            SizeBytes = item.SizeBytes,
            Width = item.Width,
            Height = item.Height,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt,
            UpdatedAt = now,
            LastSyncedAt = now,
            SyncStatus = "synced"
        };

        dbContext.ProductImages.Add(image);
        await dbContext.SaveChangesAsync();
        return BuildImagePushResult(item.LocalId, image.Id, product.Id, "created", image.UpdatedAt);
    }

    private async Task<ProductImageSyncPushItemResponse> ApplyImageUpdatePushAsync(Guid businessId, ProductImageSyncPushItemRequest item)
    {
        var image = await FindImageForPushAsync(businessId, item);
        return await UpdateImageFromPushAsync(image, item, "updated");
    }

    private async Task<ProductImageSyncPushItemResponse> ApplyImageDeletePushAsync(Guid businessId, ProductImageSyncPushItemRequest item)
    {
        var image = await FindImageForPushAsync(businessId, item);
        var now = DateTime.UtcNow;
        image.DeletedAt = now;
        image.UpdatedAt = now;
        image.LastSyncedAt = now;
        image.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildImagePushResult(item.LocalId, image.Id, image.ProductId, "deleted", image.UpdatedAt);
    }

    private async Task<ProductImageSyncPushItemResponse> UpdateImageFromPushAsync(ProductImage image, ProductImageSyncPushItemRequest item, string status)
    {
        ValidateImageMetadata(item);
        var product = await FindProductForPushAsync(image.BusinessId, item.ProductServerId, item.ProductLocalId);
        await EnsureImageLimitAsync(image.BusinessId, product.Id, image.Id);

        var now = DateTime.UtcNow;
        image.ProductId = product.Id;
        image.LocalId = item.LocalId;
        image.LocalPath = item.LocalPath.Trim();
        image.RemoteUrl = NormalizeOptional(item.RemoteUrl);
        image.StorageKey = NormalizeOptional(item.StorageKey);
        image.Order = item.Order;
        image.MimeType = NormalizeOptional(item.MimeType);
        image.SizeBytes = item.SizeBytes;
        image.Width = item.Width;
        image.Height = item.Height;
        image.DeletedAt = null;
        image.UpdatedAt = now;
        image.LastSyncedAt = now;
        image.SyncStatus = "synced";

        await dbContext.SaveChangesAsync();
        return BuildImagePushResult(item.LocalId, image.Id, product.Id, status, image.UpdatedAt);
    }

    private async Task<Product> FindProductForPushAsync(Guid businessId, Guid? serverId, int localId)
    {
        var query = dbContext.Products.Where(x => x.BusinessId == businessId);
        var product = serverId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == serverId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == localId);

        return product ?? throw new KeyNotFoundException("Producto no encontrado para este negocio.");
    }

    private async Task<ProductImage> FindImageForPushAsync(Guid businessId, ProductImageSyncPushItemRequest item)
    {
        var query = dbContext.ProductImages.Where(x => x.BusinessId == businessId);
        var image = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);

        return image ?? throw new KeyNotFoundException("Imagen de producto no encontrada para este negocio.");
    }

    private async Task<Product> FindProductForBusinessAsync(Guid businessId, Guid id)
    {
        var product = await dbContext.Products.FirstOrDefaultAsync(x => x.Id == id && x.BusinessId == businessId);
        return product ?? throw new KeyNotFoundException("Producto no encontrado para este negocio.");
    }

    private async Task EnsureProductIsValidAsync(Guid businessId, string name, string? codeReference, Guid? currentProductId)
    {
        var normalizedName = name.Trim();
        if (string.IsNullOrWhiteSpace(normalizedName))
        {
            throw new InvalidOperationException("El nombre del producto es obligatorio.");
        }

        var normalizedCode = NormalizeOptional(codeReference);
        var nameLower = normalizedName.ToLower();
        var codeLower = normalizedCode?.ToLower();
        var exists = await dbContext.Products.AnyAsync(x =>
            x.BusinessId == businessId &&
            x.IsActive &&
            (currentProductId == null || x.Id != currentProductId) &&
            (x.Name.ToLower() == nameLower ||
                (codeLower != null && x.CodeReference != null && x.CodeReference.ToLower() == codeLower)));

        if (exists)
        {
            throw new InvalidOperationException("Ya existe un producto activo con ese nombre o codigo en este negocio.");
        }
    }

    private static void ValidateProductAmounts(int quantity, decimal purchasePrice, decimal salePrice, decimal profitMarginPercent)
    {
        if (quantity < 0 || purchasePrice < 0 || salePrice < 0 || profitMarginPercent < 0)
        {
            throw new InvalidOperationException("La cantidad, costo, precio y porcentaje no pueden ser negativos.");
        }
    }

    private async Task EnsureImageLimitAsync(Guid businessId, Guid productId, Guid? currentImageId)
    {
        var count = await dbContext.ProductImages.CountAsync(x =>
            x.BusinessId == businessId &&
            x.ProductId == productId &&
            x.DeletedAt == null &&
            (currentImageId == null || x.Id != currentImageId));

        if (count >= 3)
        {
            throw new InvalidOperationException("Solo se permiten hasta 3 imagenes por producto.");
        }
    }

    private static void ValidateImageMetadata(ProductImageSyncPushItemRequest item)
    {
        if (string.IsNullOrWhiteSpace(item.LocalPath) && string.IsNullOrWhiteSpace(item.RemoteUrl))
        {
            throw new InvalidOperationException("La imagen requiere localPath o remoteUrl.");
        }

        if (item.SizeBytes > MaxImageSizeBytes)
        {
            throw new InvalidOperationException("Cada imagen debe pesar maximo 2 MB.");
        }

        var mimeType = NormalizeOptional(item.MimeType);
        if (mimeType is not null && !AllowedMimeTypes.Contains(mimeType))
        {
            throw new InvalidOperationException("Formato no permitido. Usa PNG o JPEG.");
        }
    }

    private static ProductSyncPushItemResponse BuildProductPushResult(int localId, Guid serverId, string status, DateTime serverUpdatedAt)
    {
        return new ProductSyncPushItemResponse
        {
            LocalId = localId,
            ServerId = serverId,
            Status = status,
            ServerUpdatedAt = serverUpdatedAt
        };
    }

    private static ProductImageSyncPushItemResponse BuildImagePushResult(int localId, Guid serverId, Guid productServerId, string status, DateTime serverUpdatedAt)
    {
        return new ProductImageSyncPushItemResponse
        {
            LocalId = localId,
            ServerId = serverId,
            ProductServerId = productServerId,
            Status = status,
            ServerUpdatedAt = serverUpdatedAt
        };
    }

    private static ProductResponse Map(Product product)
    {
        return new ProductResponse
        {
            Id = product.Id,
            LocalId = product.LocalId,
            RemoteId = product.RemoteId,
            BusinessId = product.BusinessId,
            Name = product.Name,
            CodeReference = product.CodeReference,
            Category = product.Category,
            Location = product.Location,
            Description = product.Description,
            Quantity = product.Quantity,
            PurchasePrice = product.PurchasePrice,
            SalePrice = product.SalePrice,
            ProfitMarginPercent = product.ProfitMarginPercent,
            MinimumStock = product.MinimumStock,
            IsActive = product.IsActive,
            CreatedAt = product.CreatedAt,
            UpdatedAt = product.UpdatedAt,
            DeletedAt = product.DeletedAt,
            LastSyncedAt = product.LastSyncedAt
        };
    }

    private static ProductImageResponse MapImage(ProductImage image)
    {
        return new ProductImageResponse
        {
            Id = image.Id,
            LocalId = image.LocalId,
            RemoteId = image.RemoteId,
            BusinessId = image.BusinessId,
            ProductId = image.ProductId,
            LocalPath = image.LocalPath,
            RemoteUrl = image.RemoteUrl,
            StorageKey = image.StorageKey,
            Order = image.Order,
            MimeType = image.MimeType,
            SizeBytes = image.SizeBytes,
            Width = image.Width,
            Height = image.Height,
            CreatedAt = image.CreatedAt,
            UpdatedAt = image.UpdatedAt,
            DeletedAt = image.DeletedAt,
            LastSyncedAt = image.LastSyncedAt
        };
    }

    private static Guid GetBusinessIdForBusinessUser(ClaimsPrincipal user)
    {
        var role = user.FindFirstValue(ClaimTypes.Role);
        if (string.Equals(role, "Personal", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("El usuario Personal no puede acceder a productos de negocio.");
        }

        if (!string.Equals(role, "Negocio", StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(role, "Colaborador", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Rol no autorizado para productos de negocio.");
        }

        var businessIdValue = user.FindFirstValue("business_id");
        if (!Guid.TryParse(businessIdValue, out var businessId))
        {
            throw new UnauthorizedAccessException("El usuario autenticado no tiene negocio asociado.");
        }

        return businessId;
    }

    private static string? NormalizeOptional(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }
}
