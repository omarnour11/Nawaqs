using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Caching;
using Nawakes.Infrastructure.Identity;
using Nawakes.Infrastructure.Notifications;
using Nawakes.Infrastructure.NLP;
using Nawakes.Infrastructure.Persistence;
using Nawakes.Infrastructure.Persistence.Interceptors;
using Nawakes.Infrastructure.Persistence.Repositories;
using Nawakes.Infrastructure.Persistence.Seed;
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
                    sql.EnableRetryOnFailure(maxRetryCount: 5, maxRetryDelay: TimeSpan.FromSeconds(10), errorNumbersToAdd: null);
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
        var redisConn = configuration.GetConnectionString("Redis");
        if (!string.IsNullOrWhiteSpace(redisConn))
        {
            services.AddStackExchangeRedisCache(opts =>
            {
                opts.Configuration = redisConn;
                opts.InstanceName = "Nawakes:";
            });
        }
        else
        {
            services.AddDistributedMemoryCache();
        }
        services.AddMemoryCache();                                            // IMemoryCache for in-process catalog warm-up
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
        services.AddScoped<IUserDirectory, UserDirectory>();
        services.AddSingleton<IJwtTokenGenerator, JwtTokenGenerator>();

        // ── Security ────────────────────────────────────────────────────
        services.AddSingleton<IEncryptionService, AesEncryptionService>();

        // ── NLP / Clinical Prescription Matching ──────────────────────────────
        // ClinicalMatchingOptions: Singleton — weights don't change at runtime.
        services.AddSingleton(new Nawakes.Application.Common.Models.ClinicalMatchingOptions());
        // EgyptianDialectNormalizerService: Scoped — accesses DbContext per request.
        services.AddScoped<IEgyptianDialectNormalizer, EgyptianDialectNormalizerService>();
        // ClinicalPrescriptionMatcher: Singleton — owns the IMemoryCache catalog warm-up.
        // Uses IServiceScopeFactory internally to safely resolve the scoped DbContext
        services.AddScoped<IClinicalPrescriptionMatcher>(sp =>
            new ClinicalPrescriptionMatcher(
                sp.GetRequiredService<IServiceScopeFactory>(),
                sp.GetRequiredService<IEgyptianDialectNormalizer>(),
                sp.GetRequiredService<IMemoryCache>(),
                sp.GetRequiredService<ILogger<ClinicalPrescriptionMatcher>>(),
                sp.GetRequiredService<Nawakes.Application.Common.Models.ClinicalMatchingOptions>()));
        // Bilingual Sig Decoder & Clinical Safety Auditor
        services.AddSingleton<ISigDecoderService, SigDecoderService>();
        services.AddSingleton<IPrescriptionSafetyAuditor, PrescriptionSafetyAuditor>();
        services.AddSingleton<IPrescriptionSanitizationService, PrescriptionSanitizationService>();

        // ── Gemini Flash AI (High Accuracy Prescription Parsing with 1400 Daily Quota) ─
        services.Configure<Nawakes.Application.Common.Models.GeminiOptions>(
            configuration.GetSection(Nawakes.Application.Common.Models.GeminiOptions.SectionName));
        services.AddHttpClient<IGeminiPrescriptionService, GeminiPrescriptionService>();

        // ── Secondary Cloud OCR (Azure AI Vision 4.0 Read API Failover) ────
        services.Configure<Nawakes.Application.Common.Models.AzureVisionOptions>(
            configuration.GetSection(Nawakes.Application.Common.Models.AzureVisionOptions.SectionName));
        services.AddHttpClient<ISecondaryOcrService, AzureVisionOcrService>();

        // ── Notifications ───────────────────────────────────────────────
        services.AddScoped<INotificationService, FcmNotificationService>();

        // ── Background Jobs ─────────────────────────────────────────────
        services.AddScoped<InventoryAvailabilityNotificationJob>();
        services.AddScoped<OfferWindowExpiryJob>();
        services.AddScoped<CheckCabinetDepletionJob>();
        services.AddScoped<StaleInventoryDecayJob>();
        services.AddScoped<IReservationJobScheduler, HangfireReservationJobScheduler>();
        services.AddScoped<IInventoryJobScheduler, HangfireInventoryJobScheduler>();
        services.AddScoped<ITrustScoreJobScheduler, HangfireTrustScoreJobScheduler>();
        services.AddScoped<IOfferWindowScheduler, HangfireOfferWindowScheduler>();

        // ── Catalog Seeding ──────────────────────────────────────────
        services.AddScoped<EdaDrugSeeder>();

        return services;
    }
}
