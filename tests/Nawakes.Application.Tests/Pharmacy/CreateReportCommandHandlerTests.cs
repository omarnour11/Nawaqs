using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reports.Commands.CreateReport;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class CreateReportCommandHandlerTests
{
    private readonly Mock<ICurrentUserService> _currentUserMock = new();
    private readonly Mock<ITrustScoreJobScheduler> _jobSchedulerMock = new();
    private readonly ApplicationDbContext _context;

    public CreateReportCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());
    }

    [Fact]
    public async Task Create_Success_ShouldSaveAndScheduleJob()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { GeoPoint = new Point(0,0){SRID=4326} };
        _context.Pharmacies.Add(pharmacy);
        await _context.SaveChangesAsync();

        var handler = new CreateReportCommandHandler(_context, _currentUserMock.Object, _jobSchedulerMock.Object);
        var command = new CreateReportCommand(pharmacy.Id, ReportType.Inaccurate, "Panadol", null, "Not found");

        var resultId = await handler.Handle(command, CancellationToken.None);

        resultId.Should().NotBeEmpty();

        var inDb = await _context.Reports.FindAsync(resultId);
        inDb.Should().NotBeNull();
        inDb!.MedicationName.Should().Be("Panadol");

        _jobSchedulerMock.Verify(j => j.ScheduleTrustScoreRecalculation(pharmacy.Id), Times.Once);
    }

    [Fact]
    public async Task Create_RateLimit_ShouldThrowConflict()
    {
        var userId = Guid.NewGuid();
        _currentUserMock.Setup(u => u.UserId).Returns(userId);

        var pharmacy = new Nawakes.Domain.Entities.Pharmacy { GeoPoint = new Point(0,0){SRID=4326} };
        
        var existingReport = new Report 
        { 
            UserId = userId, 
            Pharmacy = pharmacy, 
            MedicationName = "panadol", 
            CreatedAt = DateTime.UtcNow.AddHours(-1) 
        };
        
        _context.Pharmacies.Add(pharmacy);
        _context.Reports.Add(existingReport);
        await _context.SaveChangesAsync();

        var handler = new CreateReportCommandHandler(_context, _currentUserMock.Object, _jobSchedulerMock.Object);
        var command = new CreateReportCommand(pharmacy.Id, ReportType.Inaccurate, "Panadol", null, "Not found");

        var act = () => handler.Handle(command, CancellationToken.None);
        await act.Should().ThrowAsync<ConflictException>();
    }
}
