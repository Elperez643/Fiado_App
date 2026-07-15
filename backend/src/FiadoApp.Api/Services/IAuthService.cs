using System.Security.Claims;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;

namespace FiadoApp.Api.Services;

public interface IAuthService
{
    Task<AuthResponse> RegisterPersonalAsync(RegisterPersonalRequest request);
    Task<AuthResponse> RegisterBusinessAsync(RegisterBusinessRequest request);
    Task<AuthResponse> StartBusinessRegistrationAsync(RegisterBusinessRequest request);
    Task<AuthResponse> RegisterCollaboratorAsync(RegisterCollaboratorRequest request, ClaimsPrincipal requester);
    Task<AuthResponse> LoginAsync(LoginRequest request);
    Task<AuthResponse> LinkLocalUserAsync(LinkLocalUserRequest request);
    Task<CurrentUserResponse> GetCurrentUserAsync(ClaimsPrincipal principal);
    string GenerateJwtToken(User user, DateTime expiresAt);
    Task ValidateActiveSessionAsync(ClaimsPrincipal principal);
}
