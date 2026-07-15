using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/products")]
public sealed class ProductsController(IProductService productService) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<ProductResponse>>> GetProducts()
    {
        return await ExecuteReadAsync(() => productService.GetByBusinessAsync(User));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ProductResponse>> GetProduct(Guid id)
    {
        return await ExecuteReadAsync(() => productService.GetByIdAsync(User, id));
    }

    [HttpPost]
    public async Task<ActionResult<ProductResponse>> CreateProduct(ProductCreateRequest request)
    {
        return await ExecuteWriteAsync(() => productService.CreateAsync(User, request));
    }

    [HttpPut("{id:guid}")]
    public async Task<ActionResult<ProductResponse>> UpdateProduct(Guid id, ProductUpdateRequest request)
    {
        return await ExecuteWriteAsync(() => productService.UpdateAsync(User, id, request));
    }

    [HttpPost("sync/push")]
    public async Task<ActionResult<ProductSyncPushResponse>> PushSync(ProductSyncPushRequest request)
    {
        return await ExecuteWriteAsync(() => productService.PushSyncAsync(User, request));
    }

    [HttpPost("sync/pull")]
    public async Task<ActionResult<ProductSyncPullResponse>> PullSync(ProductSyncPullRequest request)
    {
        return await ExecuteWriteAsync(() => productService.PullSyncAsync(User, request));
    }

    [HttpGet("{productId:guid}/images")]
    public async Task<ActionResult<IReadOnlyList<ProductImageResponse>>> GetImages(Guid productId)
    {
        return await ExecuteReadAsync(() => productService.GetImagesByProductAsync(User, productId));
    }

    [HttpPost("images/sync/push")]
    public async Task<ActionResult<ProductImageSyncPushResponse>> PushImagesSync(ProductImageSyncPushRequest request)
    {
        return await ExecuteWriteAsync(() => productService.PushImagesSyncAsync(User, request));
    }

    [HttpPost("images/sync/pull")]
    public async Task<ActionResult<ProductImageSyncPullResponse>> PullImagesSync(ProductImageSyncPullRequest request)
    {
        return await ExecuteWriteAsync(() => productService.PullImagesSyncAsync(User, request));
    }

    private async Task<ActionResult<T>> ExecuteReadAsync<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    private async Task<ActionResult<T>> ExecuteWriteAsync<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
