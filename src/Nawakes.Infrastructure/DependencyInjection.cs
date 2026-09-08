using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Caching;
using Nawakes.Infrastructure.Identity;
using Nawakes.Infrastructure.Notifications;
using Nawakes.Infrastructure.Persistence;
using Nawakes.Infrastructure.Persistence.Interceptors;
using Nawakes.Infrastructure.Persistence.Repositories;
using Nawakes.Infrastructure.Security;

namespace Nawakes.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // ── EF Core with SQL Server + NetTopologySuite ──────────────────
        services.AddSingleton<AuditableEntityInterceptor>();

        services.AddDbContext<ApplicationDbContext>((sp, options) =>
        {
            options.UseSqlServer(
                configuration.GetConnectionString("DefaultConnection"),
                sql =>
                {
                    sql.UseNetTopologySuite();
                    sql.EnableRetryOnFailure(maxRetryCount: 3, maxRetryDelay: TimeSpan.FromSeconds(5), errorNumbersToAdd: null);
                    sql.CommandTimeout(30);
                });
            options.AddInterceptors(sp.GetRequiredService<AuditableEntityInterceptor>());
        });

        services.AddScoped<IApplicationDbContext>(sp => sp.GetRequiredService<ApplicationDbContext>());

        // ── ASP.NET Core Identity ───────────────────────────────────────
        services.AddIdentityCore<ApplicationUser>(opts =>
        {
            opts.Password.RequiredLength = 8;
            opts.Password.RequireDigit = true;
            opts.Password.RequireUppercase = false;
            opts.Password.RequireNonAlphanumeric = false;
            opts.Lockout.MaxFailedAccessAttempts = 5;
            opts.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
        })
        .AddRoles<ApplicationRole>()
        .AddEntityFrameworkStores<ApplicationDbContext>();

        // ── Cache ───────────────────────────────────────────────────────
        services.AddDistributedMemoryCache();
        services.AddScoped<ICacheService, RedisCacheService>();

        // ── Hangfire ────────────────────────────────────────────────────
        services.AddHangfire(cfg => cfg
            .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
            .UseSimpleAssemblyNameTypeSerializer()
            .UseRecommendedSerializerSettings()
            .UseSqlServerStorage(configuration.GetConnectionString("DefaultConnection")));

        services.AddHangfireServer(opts =>
        {
            opts.WorkerCount = Environment.ProcessorCount * 2;
            opts.Queues = ["critical", "default"];
        });

        // ── Repositories ────────────────────────────────────────────────
        services.AddScoped<IPharmacySearchRepository, PharmacySearchRepository>();
        services.AddScoped<IPharmacyRepository, PharmacyRepository>();

        // ── Identity Services ───────────────────────────────────────────
        services.AddScoped<IIdentityService, IdentityService>();
        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

        // ── Security ────────────────────────────────────────────────────
        services.AddSingleton<IEncryptionService, AesEncryptionService>();

        // ── Notifications ───────────────────────────────────────────────
        services.AddScoped<INotificationService, FcmNotificationService>();

        // ── Background Jobs ─────────────────────────────────────────────
        services.AddScoped<ReservationExpiryJob>();
        services.AddScoped<IReservationJobScheduler, HangfireReservationJobScheduler>();
        services.AddScoped<IInventoryJobScheduler, HangfireInventoryJobScheduler>();
        services.AddScoped<ITrustScoreJobScheduler, HangfireTrustScoreJobScheduler>();

        return services;
    }
}
