using System.Diagnostics;
using System.Data;
using System.Text;
using FiadoApp.Api.Data;
using FiadoApp.Api.Entities;
using FiadoApp.Api.Payments;
using FiadoApp.Api.Payments.Providers;
using FiadoApp.Api.Payments.Providers.Azul;
using FiadoApp.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

builder.Services.AddControllers().ConfigureApiBehaviorOptions(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var request = context.HttpContext.Request;
        if (InventoryImagePushDiagnostics.IsInventoryImagesPush(request))
        {
            var logger = context.HttpContext.RequestServices
                .GetRequiredService<ILoggerFactory>()
                .CreateLogger("InventoryImagesPushValidation");
            var requestSummary = context.HttpContext.Items.TryGetValue(
                InventoryImagePushDiagnostics.RequestSummaryItemKey,
                out var summary)
                ? summary?.ToString() ?? "unavailable"
                : "unavailable";
            foreach (var entry in context.ModelState.Where(entry => entry.Value?.Errors.Count > 0))
            {
                foreach (var error in entry.Value!.Errors)
                {
                    logger.LogWarning(
                        "[inventory-images-push-validation-failed] endpoint={Endpoint} field={Field} error={Error} requestSummary={RequestSummary}",
                        request.Path,
                        entry.Key,
                        error.ErrorMessage.Length > 0 ? error.ErrorMessage : error.Exception?.Message ?? "validation error",
                        requestSummary);
                }
            }
        }

        var details = context.HttpContext.RequestServices
            .GetRequiredService<ProblemDetailsFactory>()
            .CreateValidationProblemDetails(
                context.HttpContext,
                context.ModelState,
                statusCode: StatusCodes.Status400BadRequest);
        return new BadRequestObjectResult(details);
    };
});
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddCors(options =>
{
    options.AddPolicy("FiadoCors", policy =>
    {
        var configuredOrigins = builder.Configuration
            .GetSection("Cors:AllowedOrigins")
            .GetChildren()
            .Select(x => x.Value)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Cast<string>()
            .ToArray();
        if (configuredOrigins.Length > 0)
        {
            policy.WithOrigins(configuredOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod();
            return;
        }

        if (builder.Environment.IsDevelopment() ||
            builder.Environment.IsEnvironment("StagingLocal"))
        {
            policy.SetIsOriginAllowed(origin =>
                Uri.TryCreate(origin, UriKind.Absolute, out var uri) &&
                (uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                 uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase)))
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
    });
});
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Fiado App API",
        Version = "v1",
        Description = "Backend inicial para sincronizacion cloud de Fiado App."
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Ingresa el JWT usando el formato: Bearer {token}"
    });

    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecuritySchemeReference("Bearer", document, null),
            []
        }
    });
});

builder.Services.AddDbContext<FiadoDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("FiadoDb")));

var jwtKey = builder.Configuration["Jwt:Key"] ?? "dev-only-change-this-key";
if (!builder.Environment.IsDevelopment() &&
    (jwtKey.StartsWith("dev-only", StringComparison.OrdinalIgnoreCase) ||
     jwtKey.Length < 32))
{
    throw new InvalidOperationException("Jwt:Key debe configurarse con un secreto fuerte fuera del codigo para produccion.");
}
var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = signingKey
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddHealthChecks();
builder.Services.Configure<AzulPaymentOptions>(builder.Configuration.GetSection("Azul"));
builder.Services.AddScoped<PasswordHasher<User>>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IClientService, ClientService>();
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddScoped<IMovementService, MovementService>();
builder.Services.AddScoped<IReceiptService, ReceiptService>();
builder.Services.AddScoped<ICreditCycleService, CreditCycleService>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddScoped<IAuthorizationRequestService, AuthorizationRequestService>();
builder.Services.AddScoped<IClientScoreService, ClientScoreService>();
builder.Services.AddScoped<IWhatsappCampaignService, WhatsappCampaignService>();
builder.Services.AddScoped<IGenericSyncService, GenericSyncService>();
builder.Services.AddScoped<MockPaymentProvider>();
builder.Services.AddScoped<StripePaymentProvider>();
builder.Services.AddScoped<AzulPaymentProvider>();
builder.Services.AddScoped<IPaymentProvider>(sp =>
{
    var provider = sp.GetRequiredService<IConfiguration>()["Payments:Provider"];
    return provider?.Trim().ToLowerInvariant() switch
    {
        "azul" => sp.GetRequiredService<AzulPaymentProvider>(),
        "stripe" => sp.GetRequiredService<StripePaymentProvider>(),
        _ => sp.GetRequiredService<MockPaymentProvider>()
    };
});
builder.Services.AddScoped<IStripePaymentProvider, StripePaymentProvider>();
builder.Services.AddScoped<IAzulPaymentProvider, AzulPaymentProvider>();
builder.Services.AddScoped<IAzulPaymentService, AzulPaymentService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IStripeBillingService, StripeBillingService>();
builder.Services.AddScoped<ISubscriptionRenewalService, SubscriptionRenewalService>();

var app = builder.Build();
await VerifyStagingLocalSessionColumnsAsync(app);

if (app.Environment.IsDevelopment() || app.Environment.IsEnvironment("StagingLocal"))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
else
{
    app.UseExceptionHandler(errorApp =>
    {
        errorApp.Run(async context =>
        {
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new
            {
                message = "Ocurrio un error procesando la solicitud."
            });
        });
    });
}

if (builder.Configuration.GetValue("UseHttpsRedirection", true))
{
    app.UseHttpsRedirection();
}
app.UseCors("FiadoCors");
app.Use(async (context, next) =>
{
    if (!InventoryImagePushDiagnostics.IsInventoryImagesPush(context.Request))
    {
        await next();
        return;
    }

    context.Request.EnableBuffering();
    using var reader = new StreamReader(
        context.Request.Body,
        Encoding.UTF8,
        detectEncodingFromByteOrderMarks: false,
        leaveOpen: true);
    var body = await reader.ReadToEndAsync();
    context.Request.Body.Position = 0;
    context.Items[InventoryImagePushDiagnostics.RequestSummaryItemKey] =
        InventoryImagePushDiagnostics.BuildSafeRequestSummary(
            body,
            context.Request.ContentLength,
            context.Request.ContentType);
    await next();
});
app.UseAuthentication();
app.Use(async (context, next) =>
{
    if (context.User.Identity?.IsAuthenticated != true)
    {
        await next();
        return;
    }

    var authService = context.RequestServices.GetRequiredService<IAuthService>();
    try
    {
        await authService.ValidateActiveSessionAsync(context.User);
    }
    catch (UnauthorizedAccessException ex) when (ex.Message == "SESSION_REPLACED")
    {
        context.Response.StatusCode = StatusCodes.Status401Unauthorized;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new
        {
            code = "SESSION_REPLACED",
            message = "Tu cuenta se inicio en otro dispositivo. Para continuar aqui, inicia sesion nuevamente."
        });
        return;
    }

    await next();
});
app.UseAuthorization();
app.Use(async (context, next) =>
{
    var path = context.Request.Path.Value ?? string.Empty;
    var shouldLogSyncTiming =
        path.Contains("/sync/", StringComparison.OrdinalIgnoreCase) ||
        path.EndsWith("/sync", StringComparison.OrdinalIgnoreCase);
    if (!shouldLogSyncTiming)
    {
        await next();
        return;
    }

    var stopwatch = Stopwatch.StartNew();
    try
    {
        await next();
    }
    finally
    {
        stopwatch.Stop();
        app.Logger.LogInformation(
            "[sync-endpoint] {Method} {Path} status={StatusCode} elapsedMs={ElapsedMs}",
            context.Request.Method,
            path,
            context.Response.StatusCode,
            stopwatch.ElapsedMilliseconds);
    }
});

app.MapControllers();
app.MapGet("/health", (IHostEnvironment environment) => Results.Ok(new
{
    status = "ok",
    environment = environment.EnvironmentName
}));

app.Run();

static async Task VerifyStagingLocalSessionColumnsAsync(WebApplication app)
{
    if (!app.Environment.IsEnvironment("StagingLocal"))
    {
        return;
    }

    var requiredColumns = new[]
    {
        "ActiveDeviceId",
        "DeviceInfo",
        "LastLoginAt",
        "LastSeenAt",
        "SessionVersion"
    };

    try
    {
        await using var scope = app.Services.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<FiadoDbContext>();
        var connection = dbContext.Database.GetDbConnection();
        if (connection.State != ConnectionState.Open)
        {
            await connection.OpenAsync();
        }

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'Users';
            """;
        var existing = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            existing.Add(reader.GetString(0));
        }

        var missing = requiredColumns.Where(column => !existing.Contains(column)).ToArray();
        if (missing.Length > 0)
        {
            app.Logger.LogError(
                "Database schema missing required session columns. Run repair_staginglocal_single_active_session_columns.ps1. MissingColumns={MissingColumns}",
                string.Join(", ", missing));
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogError(
            ex,
            "Could not verify StagingLocal database session columns. Run diagnose_staginglocal_database.ps1.");
    }
}
