using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Authorize]
public sealed class AuditsController(IAuditService auditService) : ControllerBase
{
    [HttpGet("api/audits")]
    public async Task<ActionResult<IReadOnlyList<AuditResponse>>> GetAudits()
        => await Read(() => auditService.GetAuditsAsync(User));

    [HttpGet("api/audits/{id:guid}")]
    public async Task<ActionResult<AuditResponse>> GetById(Guid id)
        => await Read(() => auditService.GetByIdAsync(User, id));

    [HttpGet("api/audits/business/report")]
    public async Task<ActionResult<IReadOnlyList<AuditReportResponse>>> GetBusinessReport()
        => await Read(() => auditService.GetBusinessReportAsync(User));

    [HttpGet("api/audits/my")]
    public async Task<ActionResult<IReadOnlyList<AuditResponse>>> GetMy()
        => await Read(() => auditService.GetMyAuditsAsync(User));

    [HttpPost("api/audits/sync/push")]
    public async Task<ActionResult<AuditSyncPushResponse>> Push(AuditSyncPushRequest request)
        => await Write(() => auditService.PushSyncAsync(User, request));

    [HttpPost("api/audit-items/sync/push")]
    public async Task<ActionResult<AuditItemSyncPushResponse>> PushItems(AuditItemSyncPushRequest request)
        => await Write(() => auditService.PushItemsSyncAsync(User, request));

    [HttpPost("api/audits/sync/pull")]
    public async Task<ActionResult<AuditSyncPullResponse>> Pull(AuditSyncPullRequest request)
        => await Write(() => auditService.PullSyncAsync(User, request));

    [HttpPost("api/audit-items/sync/pull")]
    public async Task<ActionResult<AuditItemSyncPullResponse>> PullItems(AuditItemSyncPullRequest request)
        => await Write(() => auditService.PullItemsSyncAsync(User, request));

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
