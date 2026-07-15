using FiadoApp.Api.DTOs;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FiadoApp.Api.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    IAuthService authService,
    ILogger<AuthController> logger) : ControllerBase
{
    [HttpPost("register/personal")]
    public async Task<ActionResult<AuthResponse>> RegisterPersonal(RegisterPersonalRequest request)
    {
        return await ExecuteAuthActionAsync(
            "register-personal",
            request.Phone,
            "Personal",
            request.DeviceId,
            () => authService.RegisterPersonalAsync(request));
    }

    [HttpPost("register/business")]
    public async Task<ActionResult<AuthResponse>> RegisterBusiness(RegisterBusinessRequest request)
    {
        return await ExecuteAuthActionAsync(
            "register-business",
            request.Phone,
            "Negocio",
            request.DeviceId,
            () => authService.StartBusinessRegistrationAsync(request));
    }

    [HttpPost("register/business/start")]
    public async Task<ActionResult<AuthResponse>> StartBusinessRegistration(RegisterBusinessRequest request)
    {
        return await ExecuteAuthActionAsync(
            "register-business-start",
            request.Phone,
            "Negocio",
            request.DeviceId,
            () => authService.StartBusinessRegistrationAsync(request));
    }

    [Authorize]
    [HttpPost("register/collaborator")]
    public async Task<ActionResult<AuthResponse>> RegisterCollaborator(RegisterCollaboratorRequest request)
    {
        return await ExecuteAuthActionAsync(
            "register-collaborator",
            request.Phone,
            "Colaborador",
            null,
            () => authService.RegisterCollaboratorAsync(request, User));
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request)
    {
        return await ExecuteAuthActionAsync(
            "login",
            request.Phone,
            null,
            request.DeviceId,
            () => authService.LoginAsync(request));
    }

    [HttpPost("link-local-user")]
    public async Task<ActionResult<AuthResponse>> LinkLocalUser(LinkLocalUserRequest request)
    {
        return await ExecuteAuthActionAsync(
            "link-local-user",
            request.Phone,
            request.Role,
            request.DeviceId,
            () => authService.LinkLocalUserAsync(request));
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<CurrentUserResponse>> Me()
    {
        try
        {
            return Ok(await authService.GetCurrentUserAsync(User));
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new { message = ex.Message });
        }
    }

    private async Task<ActionResult<AuthResponse>> ExecuteAuthActionAsync(
        string endpoint,
        string phone,
        string? role,
        string? deviceId,
        Func<Task<AuthResponse>> action)
    {
        try
        {
            logger.LogInformation(
                "[auth-{Endpoint}] attempted phone={Phone} role={Role} deviceId={DeviceId}",
                endpoint,
                MaskPhone(phone),
                role ?? "unknown",
                string.IsNullOrWhiteSpace(deviceId) ? "missing" : deviceId);
            var response = await action();
            logger.LogInformation(
                "[auth-{Endpoint}] success phone={Phone} userId={UserId} businessId={BusinessId} role={Role} deviceId={DeviceId} sessionVersion={SessionVersion} tokenEmitted={TokenEmitted}",
                endpoint,
                MaskPhone(phone),
                response.User.UserId,
                response.User.BusinessId,
                response.User.Role,
                response.DeviceId ?? deviceId ?? "missing",
                response.SessionVersion,
                !string.IsNullOrWhiteSpace(response.Token));
            return Ok(response);
        }
        catch (UnauthorizedAccessException ex)
        {
            logger.LogWarning(
                ex,
                "[auth-{Endpoint}] failure phone={Phone} role={Role} deviceId={DeviceId} error={Error}",
                endpoint,
                MaskPhone(phone),
                role ?? "unknown",
                string.IsNullOrWhiteSpace(deviceId) ? "missing" : deviceId,
                ex.Message);
            return Unauthorized(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            logger.LogWarning(
                ex,
                "[auth-{Endpoint}] failure phone={Phone} role={Role} deviceId={DeviceId} error={Error}",
                endpoint,
                MaskPhone(phone),
                role ?? "unknown",
                string.IsNullOrWhiteSpace(deviceId) ? "missing" : deviceId,
                ex.Message);
            return BadRequest(new { message = ex.Message });
        }
    }

    private static string MaskPhone(string phone)
    {
        var normalized = phone.Trim();
        if (normalized.Length <= 4) return "****";
        return $"***{normalized[^4..]}";
    }
}
