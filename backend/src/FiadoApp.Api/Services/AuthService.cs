using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

namespace FiadoApp.Api.Services;

public sealed class AuthService(
    FiadoDbContext dbContext,
    PasswordHasher<User> passwordHasher,
    IConfiguration configuration,
    ILogger<AuthService> logger) : IAuthService
{
    public async Task<AuthResponse> RegisterPersonalAsync(RegisterPersonalRequest request)
    {
        var phone = NormalizePhone(request.Phone);
        await EnsurePhoneIsAvailableAsync(phone);

        var user = new User
        {
            Name = request.Name.Trim(),
            Phone = phone,
            UserType = "Personal"
        };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
        if (!string.IsNullOrWhiteSpace(request.DeviceId))
        {
            ActivateSession(user, request.DeviceId, request.DeviceInfo);
        }

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse> RegisterBusinessAsync(RegisterBusinessRequest request)
        => await StartBusinessRegistrationAsync(request);

    public async Task<AuthResponse> StartBusinessRegistrationAsync(RegisterBusinessRequest request)
    {
        var phone = NormalizePhone(request.Phone);
        await EnsurePhoneIsAvailableAsync(phone);

        await using var transaction = await dbContext.Database.BeginTransactionAsync();

        var user = new User
        {
            Name = request.OwnerName.Trim(),
            Phone = phone,
            UserType = "Negocio"
        };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
        if (!string.IsNullOrWhiteSpace(request.DeviceId))
        {
            ActivateSession(user, request.DeviceId, request.DeviceInfo);
        }

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        var business = new Business
        {
            Name = request.BusinessName.Trim(),
            Phone = phone,
            OwnerUserId = user.Id,
            SubscriptionStatus = "payment_method_required",
            PaymentMethodRequired = true,
            HasUsedTrial = false,
            CurrentPlan = "basico",
            CurrentBillingCycle = "mensual"
        };

        dbContext.Businesses.Add(business);
        await dbContext.SaveChangesAsync();

        user.BusinessId = business.Id;

        await dbContext.SaveChangesAsync();
        await transaction.CommitAsync();

        user.Business = business;
        var response = CreateAuthResponse(user);
        response.SubscriptionStatus = business.SubscriptionStatus;
        response.PaymentMethodRequired = true;
        response.Message = "Agrega una tarjeta para activar tu prueba gratis de 30 dias.";
        return response;
    }

    public async Task<AuthResponse> RegisterCollaboratorAsync(
        RegisterCollaboratorRequest request,
        ClaimsPrincipal requester)
    {
        var requesterUser = await GetUserFromPrincipalAsync(requester);
        if (!string.Equals(requesterUser.UserType, "Negocio", StringComparison.OrdinalIgnoreCase))
        {
            throw new UnauthorizedAccessException("Solo un usuario Negocio puede registrar colaboradores.");
        }

        var businessId = request.BusinessId ?? requesterUser.BusinessId;
        if (businessId is null || businessId != requesterUser.BusinessId)
        {
            throw new InvalidOperationException("El colaborador debe pertenecer al negocio autenticado.");
        }

        var businessExists = await dbContext.Businesses.AnyAsync(x => x.Id == businessId.Value);
        if (!businessExists)
        {
            throw new InvalidOperationException("El negocio indicado no existe.");
        }

        var phone = NormalizePhone(request.Phone);
        await EnsurePhoneIsAvailableAsync(phone);

        var user = new User
        {
            Name = request.Name.Trim(),
            Phone = phone,
            UserType = "Colaborador",
            BusinessId = businessId
        };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request)
    {
        var phone = NormalizePhone(request.Phone);
        var user = await dbContext.Users
            .Include(x => x.Business)
            .FirstOrDefaultAsync(x => x.Phone == phone);

        if (user is null || !user.IsActive)
        {
            throw new UnauthorizedAccessException("Credenciales invalidas.");
        }

        var result = passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (result == PasswordVerificationResult.Failed)
        {
            throw new UnauthorizedAccessException("Credenciales invalidas.");
        }

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
        }

        ActivateSession(user, request.DeviceId, request.DeviceInfo);
        await dbContext.SaveChangesAsync();

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse> LinkLocalUserAsync(LinkLocalUserRequest request)
    {
        // TODO: Endurecer este recovery local-first antes de produccion.
        // En staging permite crear en nube una cuenta que ya existe en SQLite.
        var phone = NormalizePhone(request.Phone);
        var role = NormalizeRole(request.Role);
        if (string.IsNullOrWhiteSpace(phone) ||
            string.IsNullOrWhiteSpace(request.Password) ||
            string.IsNullOrWhiteSpace(request.Name))
        {
            throw new InvalidOperationException("Datos incompletos para conectar la cuenta local.");
        }

        var existing = await dbContext.Users
            .Include(x => x.Business)
            .FirstOrDefaultAsync(x => x.Phone == phone);

        if (existing is not null)
        {
            if (!existing.IsActive)
            {
                throw new UnauthorizedAccessException("Credenciales invalidas.");
            }

            var result = passwordHasher.VerifyHashedPassword(
                existing,
                existing.PasswordHash,
                request.Password);
            if (result == PasswordVerificationResult.Failed)
            {
                throw new UnauthorizedAccessException("Credenciales invalidas.");
            }

            if (result == PasswordVerificationResult.SuccessRehashNeeded)
            {
                existing.PasswordHash = passwordHasher.HashPassword(existing, request.Password);
            }

            if (!string.IsNullOrWhiteSpace(request.DeviceId))
            {
                ActivateSession(existing, request.DeviceId, request.DeviceInfo);
            }
            await dbContext.SaveChangesAsync();

            return CreateAuthResponse(existing);
        }

        if (role == "Colaborador")
        {
            throw new InvalidOperationException(
                "La conexion cloud para colaboradores se completara en una proxima version.");
        }

        await using var transaction = await dbContext.Database.BeginTransactionAsync();
        var user = new User
        {
            Name = request.Name.Trim(),
            Phone = phone,
            UserType = role,
            SyncStatus = "synced"
        };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);

        dbContext.Users.Add(user);
        await dbContext.SaveChangesAsync();
        if (!string.IsNullOrWhiteSpace(request.DeviceId))
        {
            ActivateSession(user, request.DeviceId, request.DeviceInfo);
        }

        if (role == "Negocio")
        {
            var business = new Business
            {
                Name = string.IsNullOrWhiteSpace(request.BusinessName)
                    ? request.Name.Trim()
                    : request.BusinessName.Trim(),
                Phone = phone,
                OwnerUserId = user.Id,
                SubscriptionStatus = "payment_method_required",
                PaymentMethodRequired = true,
                HasUsedTrial = false,
                CurrentPlan = "basico",
                CurrentBillingCycle = "mensual",
                SyncStatus = "synced"
            };

            dbContext.Businesses.Add(business);
            await dbContext.SaveChangesAsync();
            user.BusinessId = business.Id;
            await dbContext.SaveChangesAsync();
            user.Business = business;
        }

        await dbContext.SaveChangesAsync();
        await transaction.CommitAsync();
        return CreateAuthResponse(user);
    }

    public async Task<CurrentUserResponse> GetCurrentUserAsync(ClaimsPrincipal principal)
    {
        var user = await GetUserFromPrincipalAsync(principal);
        return MapCurrentUser(user);
    }

    public string GenerateJwtToken(User user, DateTime expiresAt)
    {
        var key = configuration["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key no esta configurado.");
        var issuer = configuration["Jwt:Issuer"];
        var audience = configuration["Jwt:Audience"];
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key));
        var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Name),
            new(ClaimTypes.MobilePhone, user.Phone),
            new(ClaimTypes.Role, user.UserType),
            new("device_id", user.ActiveDeviceId ?? string.Empty),
            new("session_version", user.SessionVersion.ToString())
        };

        if (user.BusinessId is not null)
        {
            claims.Add(new Claim("business_id", user.BusinessId.Value.ToString()));
        }

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: credentials);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private AuthResponse CreateAuthResponse(User user)
    {
        var expiresAt = DateTime.UtcNow.AddMinutes(GetExpiresMinutes());

        return new AuthResponse
        {
            Token = GenerateJwtToken(user, expiresAt),
            ExpiresAt = expiresAt,
            User = MapCurrentUser(user),
            SubscriptionStatus = user.Business?.SubscriptionStatus,
            PaymentMethodRequired = user.Business?.PaymentMethodRequired ?? false,
            SessionVersion = user.SessionVersion,
            DeviceId = user.ActiveDeviceId
        };
    }

    private CurrentUserResponse MapCurrentUser(User user)
    {
        return new CurrentUserResponse
        {
            UserId = user.Id,
            Name = user.Name,
            Phone = user.Phone,
            Role = user.UserType,
            BusinessId = user.BusinessId,
            BusinessName = user.Business?.Name,
            IsActive = user.IsActive
        };
    }

    private async Task<User> GetUserFromPrincipalAsync(ClaimsPrincipal principal)
    {
        var userIdValue = principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue(JwtRegisteredClaimNames.Sub);

        if (!Guid.TryParse(userIdValue, out var userId))
        {
            throw new UnauthorizedAccessException("Token invalido.");
        }

        var user = await dbContext.Users
            .Include(x => x.Business)
            .FirstOrDefaultAsync(x => x.Id == userId);

        if (user is null || !user.IsActive)
        {
            throw new UnauthorizedAccessException("Usuario no encontrado o inactivo.");
        }

        return user;
    }

    public async Task ValidateActiveSessionAsync(ClaimsPrincipal principal)
    {
        var userIdValue = principal.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? principal.FindFirstValue(JwtRegisteredClaimNames.Sub);
        var tokenDeviceId = principal.FindFirstValue("device_id")?.Trim();
        var tokenSessionVersionValue = principal.FindFirstValue("session_version");

        if (!Guid.TryParse(userIdValue, out var userId) ||
            string.IsNullOrWhiteSpace(tokenDeviceId) ||
            !int.TryParse(tokenSessionVersionValue, out var tokenSessionVersion))
        {
            logger.LogWarning(
                "[sync-auth] userId={UserId} deviceId={DeviceId} claimSessionVersion={ClaimSessionVersion} activeDeviceId={ActiveDeviceId} activeSessionVersion={ActiveSessionVersion} valid=false",
                userIdValue,
                tokenDeviceId ?? "missing",
                tokenSessionVersionValue ?? "missing",
                "unknown",
                "unknown");
            throw new UnauthorizedAccessException("SESSION_REPLACED");
        }

        var user = await dbContext.Users.FirstOrDefaultAsync(x => x.Id == userId);
        if (user is null ||
            !user.IsActive ||
            string.IsNullOrWhiteSpace(user.ActiveDeviceId) ||
            !string.Equals(user.ActiveDeviceId, tokenDeviceId, StringComparison.Ordinal) ||
            user.SessionVersion != tokenSessionVersion)
        {
            logger.LogWarning(
                "[sync-auth] userId={UserId} deviceId={DeviceId} claimSessionVersion={ClaimSessionVersion} activeDeviceId={ActiveDeviceId} activeSessionVersion={ActiveSessionVersion} valid=false",
                userId,
                tokenDeviceId,
                tokenSessionVersion,
                user?.ActiveDeviceId ?? "missing",
                user?.SessionVersion.ToString() ?? "missing");
            throw new UnauthorizedAccessException("SESSION_REPLACED");
        }

        logger.LogInformation(
            "[sync-auth] userId={UserId} deviceId={DeviceId} claimSessionVersion={ClaimSessionVersion} activeDeviceId={ActiveDeviceId} activeSessionVersion={ActiveSessionVersion} valid=true",
            userId,
            tokenDeviceId,
            tokenSessionVersion,
            user.ActiveDeviceId,
            user.SessionVersion);
        user.LastSeenAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();
    }

    private static void ActivateSession(User user, string deviceId, string? deviceInfo)
    {
        var normalizedDeviceId = deviceId.Trim();
        if (string.IsNullOrWhiteSpace(normalizedDeviceId))
        {
            throw new InvalidOperationException("deviceId es obligatorio.");
        }

        user.ActiveDeviceId = normalizedDeviceId;
        user.SessionVersion += 1;
        user.LastLoginAt = DateTime.UtcNow;
        user.LastSeenAt = user.LastLoginAt;
        user.DeviceInfo = string.IsNullOrWhiteSpace(deviceInfo)
            ? null
            : deviceInfo.Trim();
    }

    private async Task EnsurePhoneIsAvailableAsync(string phone)
    {
        var exists = await dbContext.Users.AnyAsync(x => x.Phone == phone);
        if (exists)
        {
            throw new InvalidOperationException("Ya existe un usuario con ese telefono.");
        }
    }

    private static string NormalizePhone(string phone)
    {
        return phone.Trim();
    }

    private static string NormalizeRole(string role)
    {
        return role.Trim().ToLowerInvariant() switch
        {
            "personal" => "Personal",
            "colaborador" or "collaborator" => "Colaborador",
            _ => "Negocio"
        };
    }

    private int GetExpiresMinutes()
    {
        return int.TryParse(configuration["Jwt:ExpiresMinutes"], out var minutes)
            ? minutes
            : 1440;
    }
}
