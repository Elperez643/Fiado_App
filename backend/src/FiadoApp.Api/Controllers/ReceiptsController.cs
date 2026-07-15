using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/receipts")]
public sealed class ReceiptsController(IReceiptService receiptService) : ControllerBase
{
    [HttpGet("client/{clientId:guid}")]
    public async Task<ActionResult<IReadOnlyList<ReceiptResponse>>> GetByClient(Guid clientId)
    {
        return await Read(() => receiptService.GetByClientAsync(User, clientId));
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ReceiptResponse>> GetById(Guid id)
    {
        return await Read(() => receiptService.GetByIdAsync(User, id));
    }

    [HttpGet("code/{code}")]
    public async Task<ActionResult<ReceiptResponse>> GetByCode(string code)
    {
        return await Read(() => receiptService.GetByCodeAsync(User, code));
    }

    [HttpPost("sync/push")]
    public async Task<ActionResult<ReceiptSyncPushResponse>> Push(ReceiptSyncPushRequest request)
    {
        return await Write(() => receiptService.PushSyncAsync(User, request));
    }

    [HttpPost("sync/pull")]
    public async Task<ActionResult<ReceiptSyncPullResponse>> Pull(ReceiptSyncPullRequest request)
    {
        return await Write(() => receiptService.PullSyncAsync(User, request));
    }

    private async Task<ActionResult<T>> Read<T>(Func<Task<T>> action)
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

    private async Task<ActionResult<T>> Write<T>(Func<Task<T>> action)
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
