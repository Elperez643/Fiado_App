using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/credit-cycles")]
public sealed class CreditCyclesController(ICreditCycleService creditCycleService) : ControllerBase
{
    [HttpGet("client/{clientId:guid}")]
    public async Task<ActionResult<IReadOnlyList<CreditCycleResponse>>> GetByClient(Guid clientId)
    {
        return await Read(() => creditCycleService.GetByClientAsync(User, clientId));
    }

    [HttpGet("accounts-receivable")]
    public async Task<ActionResult<IReadOnlyList<CreditCycleResponse>>> GetAccountsReceivable()
    {
        return await Read(() => creditCycleService.GetAccountsReceivableAsync(User));
    }

    [HttpGet("overdue-45")]
    public async Task<ActionResult<IReadOnlyList<CreditCycleResponse>>> GetOverdue45()
    {
        return await Read(() => creditCycleService.GetOverdue45Async(User));
    }

    [HttpGet("blocked-60")]
    public async Task<ActionResult<IReadOnlyList<CreditCycleResponse>>> GetBlocked60()
    {
        return await Read(() => creditCycleService.GetBlocked60Async(User));
    }

    [HttpPost("sync/push")]
    public async Task<ActionResult<CreditCycleSyncPushResponse>> Push(CreditCycleSyncPushRequest request)
    {
        return await Write(() => creditCycleService.PushSyncAsync(User, request));
    }

    [HttpPost("sync/pull")]
    public async Task<ActionResult<CreditCycleSyncPullResponse>> Pull(CreditCycleSyncPullRequest request)
    {
        return await Write(() => creditCycleService.PullSyncAsync(User, request));
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
