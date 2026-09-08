using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.BackgroundJobs;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class TrustScoreRecalculationJobTests
{
    private readonly ApplicationDbContext _context;
    private readonly TrustScoreRecalculationJob _job;

    public TrustScoreRecalculationJobTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _job = new TrustScoreRecalculationJob(_context, NullLogger<TrustScoreRecalculationJob>.Instance);
    }

    [Fact]
    public async Task Recalculate_CalculatesCorrectlyAndClamps()
    {
        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { GeoPoint = new Point(0,0){SRID=4326}, TrustScore = 50m }; // Starts at 50 to test overwrite
        
        // Base is 100
        // 2 inaccurate (-10)
        // 1 found (+2)
        // Total expected: 92
        
        var r1 = new Report { Pharmacy = pharmacy, Type = ReportType.Inaccurate, CreatedAt = DateTime.UtcNow.AddDays(-2) };
        var r2 = new Report { Pharmacy = pharmacy, Type = ReportType.Inaccurate, CreatedAt = DateTime.UtcNow.AddDays(-5) };
        var r3 = new Report { Pharmacy = pharmacy, Type = ReportType.Found, CreatedAt = DateTime.UtcNow.AddDays(-1) };
        
        // Old report, should be ignored
        var r4 = new Report { Pharmacy = pharmacy, Type = ReportType.Inaccurate, CreatedAt = DateTime.UtcNow.AddDays(-40) };

        _context.Pharmacies.Add(pharmacy);
        _context.Reports.AddRange(r1, r2, r3, r4);
        await _context.SaveChangesAsync();

        await _job.RecalculateAsync(pharmacy.Id, CancellationToken.None);

        var inDb = await _context.Pharmacies.FindAsync(pharmacy.Id);
        inDb!.TrustScore.Should().Be(92m);
    }
}
