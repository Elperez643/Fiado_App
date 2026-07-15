using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
public sealed class MovementsController(IMovementService movementService) : ControllerBase
{
    [HttpGet("api/movements/client/{clientId:guid}")]
    public async Task<ActionResult<IReadOnlyList<MovementResponse>>> GetByClient(Guid clientId)
    {
        return await Read(() => movementService.GetByClientAsync(User, clientId));
    }

    [HttpPost("api/movements")]
    public async Task<ActionResult<MovementResponse>> Create(MovementCreateRequest request)
    {
        return await Write(() => movementService.CreateAsync(User, request));
    }

    [HttpPut("api/movements/{id:guid}")]
    public async Task<ActionResult<MovementResponse>> Update(Guid id, MovementUpdateRequest request)
    {
        return await Write(() => movementService.UpdateAsync(User, id, request));
    }

    [HttpPost("api/movements/sync/push")]
    public async Task<ActionResult<MovementSyncPushResponse>> Push(MovementSyncPushRequest request)
    {
        return await Write(() => movementService.PushSyncAsync(User, request));
    }

    [HttpPost("api/movements/sync/pull")]
    public async Task<ActionResult<MovementSyncPullResponse>> Pull(MovementSyncPullRequest request)
    {
        return await Write(() => movementService.PullSyncAsync(User, request));
    }

    [HttpGet("api/movements/{movementId:guid}/debt-items")]
    public async Task<ActionResult<IReadOnlyList<DebtItemResponse>>> GetDebtItems(Guid movementId)
    {
        return await Read(() => movementService.GetDebtItemsByMovementAsync(User, movementId));
    }

    [HttpPost("api/debt-items/sync/push")]
    public async Task<ActionResult<DebtItemSyncPushResponse>> PushDebtItems(DebtItemSyncPushRequest request)
    {
        return await Write(() => movementService.PushDebtItemsSyncAsync(User, request));
    }

    [HttpPost("api/debt-items/sync/pull")]
    public async Task<ActionResult<DebtItemSyncPullResponse>> PullDebtItems(DebtItemSyncPullRequest request)
    {
        return await Write(() => movementService.PullDebtItemsSyncAsync(User, request));
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
