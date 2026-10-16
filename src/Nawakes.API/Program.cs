using System.Text;
using System.Threading.RateLimiting;
using Hangfire;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Nawakes.API.Extensions;
using Nawakes.API.Health;
using Nawakes.API.Middleware;
using Nawakes.Application;
using Nawakes.Infrastructure;
using Nawakes.Infrastructure.BackgroundJobs;
using Serilog;
using Serilog.Events;

var builder = WebApplication.CreateBuilder(args);

// ── Serilog Structured Logging (Slice 1.3) ──────────────────────────────
builder.Host.UseSerilog((ctx, lc) =>
{
    lc.MinimumLevel.Information()
      .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
      .MinimumLevel.Override("Microsoft.EntityFrameworkCore.Database.Command", LogEventLevel.Warning)
      .Enrich.FromLogContext()
      .Enrich.WithProperty("Application", "Nawakes.API")
      .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] [{TraceId}] {Message:lj}{NewLine}{Exception}");
});

// ── Application + Infrastructure layers ────────────────────────────────
builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);

// ── CORS ───────────────────────────────────────────────────────────────
builder.Services.AddCors(opts =>
    opts.AddPolicy("AllowAll", p =>
        p.AllowAnyOrigin()
         .AllowAnyHeader()
         .AllowAnyMethod()));

// ── Controllers ─────────────────────────────────────────────────────────
builder.Services.AddControllers();

// ── JWT Authentication ──────────────────────────────────────────────────
var jwtSettings = builder.Configuration.GetSection("Jwt");
var key = Encoding.UTF8.GetBytes(jwtSettings["SecretKey"]
    ?? throw new InvalidOperationException("JWT SecretKey is not configured."));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opts =>
    {
        opts.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer           = true,
            ValidateAudience         = true,
            ValidateLifetime         = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer              = jwtSettings["Issuer"],
            ValidAudience            = jwtSettings["Audience"],
            IssuerSigningKey         = new SymmetricSecurityKey(key),
            ClockSkew                = TimeSpan.FromSeconds(30)
        };
    });

builder.Services.AddAuthorization();

// ── Rate Limiting (Slice 1.4: 30 req/min IP, 60 req/min Auth) ───────────
builder.Services.AddRateLimiter(opts =>
{
    // Search: Sliding window with 60 req/min for auth users, 30 req/min for IP
    opts.AddPolicy("search", httpContext =>
    {
        var userId = httpContext.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userId))
        {
            return RateLimitPartition.GetSlidingWindowLimiter(
                partitionKey: $"user_{userId}",
                factory: _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 60,
                    Window = TimeSpan.FromMinutes(1),
                    SegmentsPerWindow = 6,
                    QueueLimit = 0
                });
        }

        var ip = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";
        return RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: $"ip_{ip}",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 6,
                QueueLimit = 0
            });
    });

    // Auth: 5 req/min per IP
    opts.AddFixedWindowLimiter("auth", limiter =>
    {
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.PermitLimit = 5;
        limiter.QueueLimit = 0;
        limiter.AutoReplenishment = true;
    });

    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    opts.OnRejected = async (ctx, token) =>
    {
        ctx.HttpContext.Response.Headers.RetryAfter = "60";
        await ctx.HttpContext.Response.WriteAsync("Rate limit exceeded. Retry after 60 seconds.", token);
    };
});

// ── Swagger / OpenAPI ────────────────────────────────────────────────────
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(opts =>
{
    opts.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Nawakes API",
        Version = "v1",
        Description = "Pharmacy Locator & Medicine Tracker — Phase 1 MVP"
    });

    opts.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header
    });

    opts.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            Array.Empty<string>()
        }
    });
});

// ── Health Checks (Slice 1.3) ───────────────────────────────────────────
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("sqlserver");

// ── HTTPS ────────────────────────────────────────────────────────────────
builder.Services.AddHsts(opts =>
{
    opts.Preload = true;
    opts.IncludeSubDomains = true;
    opts.MaxAge = TimeSpan.FromDays(365);
});

// ── Current User service ─────────────────────────────────────────────────
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<Nawakes.Application.Common.Interfaces.ICurrentUserService,
    Nawakes.API.Services.CurrentUserService>();

var app = builder.Build();

// ── Middleware pipeline ──────────────────────────────────────────────────
app.UseMiddleware<ExceptionHandlingMiddleware>();

// Serilog request logging enriched with ClientIp and UserId without sensitive search PII
app.UseSerilogRequestLogging(opts =>
{
    opts.EnrichDiagnosticContext = (diagCtx, httpContext) =>
    {
        diagCtx.Set("ClientIp", httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown");
        var userId = httpContext.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userId))
        {
            diagCtx.Set("UserId", userId);
        }
    };
});

app.UseRouting();

app.UseCors("AllowAll");

app.UseSwagger();
app.UseSwaggerUI(opts =>
{
    opts.SwaggerEndpoint("/swagger/v1/swagger.json", "Nawakes API v1");
    opts.RoutePrefix = "swagger";
});

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

// Hangfire dashboard — Admin role required
app.UseHangfireDashboard("/hangfire", new DashboardOptions
{
    Authorization = [new Nawakes.API.Middleware.HangfireAdminAuthFilter()]
});

// Register daily recurring stale inventory decay job (2:00 AM Cairo time)
RecurringJob.AddOrUpdate<StaleInventoryDecayJob>(
    "stale-inventory-decay",
    job => job.DecayStaleInventoryAsync(CancellationToken.None),
    Cron.Daily(2));

app.MapControllers();

// Health check endpoints (Slice 1.3)
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = _ => true
});
app.MapHealthChecks("/health");

await app.SeedDatabaseAsync();

app.Run();
