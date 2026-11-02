using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Auth.Commands.Register;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Auth;

public sealed class RegisterCommandHandlerTests
{
    private readonly ApplicationDbContext _context;
    private readonly Mock<IIdentityService> _identityMock = new();
    private readonly Mock<IJwtTokenGenerator> _jwtMock = new();
    private readonly Mock<IEncryptionService> _encryptionMock = new();
    private readonly RegisterCommandHandler _handler;

    public RegisterCommandHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new ApplicationDbContext(options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        _handler = new RegisterCommandHandler(
            _identityMock.Object,
            _jwtMock.Object,
            _encryptionMock.Object,
            _context);
    }

    [Fact]
    public async Task Handle_PharmacyOwnerRegistration_ShouldCreatePendingPharmacyAndReturnPharmacyRole()
    {
        var userId = Guid.NewGuid();
        _identityMock.Setup(i => i.RegisterAsync(
            "pharmacy@test.com",
            "Password123",
            "Dr. Tarek",
            null,
            null,
            "PharmacyOwner",
            null,
            null,
            null,
            null,
            It.IsAny<CancellationToken>()))
            .ReturnsAsync((true, userId.ToString(), null));

        _jwtMock.Setup(j => j.GenerateAccessToken(userId, "pharmacy@test.com", "PharmacyOwner"))
            .Returns("access-token-pharmacy");
        _jwtMock.Setup(j => j.GenerateRefreshToken())
            .Returns(("refresh-token-pharmacy", DateTime.UtcNow.AddDays(7)));

        var command = new RegisterCommand(
            Email: "pharmacy@test.com",
            Password: "Password123",
            FullName: "Dr. Tarek",
            FcmToken: null,
            Role: "PharmacyOwner",
            HealthQuestionnaire: null,
            Pharmacy: new RegisterPharmacyDto(
                Name: "صيدلية المستقبل",
                AddressLine: "10 شارع الجمهورية",
                City: "الجيزة",
                Phone: "01122334455",
                Latitude: 30.0131,
                Longitude: 31.2089,
                LicenseDocUrl: "LIC-554433",
                NationalIdDocUrl: null
            )
        );

        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.Role.Should().Be("PharmacyOwner");
        result.UserId.Should().Be(userId);
        result.AccessToken.Should().Be("access-token-pharmacy");

        // Verify Pharmacy created in database with Pending status
        var pharmacy = await _context.Pharmacies.FirstOrDefaultAsync(p => p.OwnerId == userId);
        pharmacy.Should().NotBeNull();
        pharmacy!.Name.Should().Be("صيدلية المستقبل");
        pharmacy.AddressLine.Should().Be("10 شارع الجمهورية");
        pharmacy.City.Should().Be("الجيزة");
        pharmacy.Phone.Should().Be("01122334455");
        pharmacy.VerificationStatus.Should().Be(VerificationStatus.Pending);
        pharmacy.GeoPoint.X.Should().Be(31.2089);
        pharmacy.GeoPoint.Y.Should().Be(30.0131);
    }

    [Fact]
    public async Task Handle_PatientRegistration_WithClinicalProfile_ShouldPassAttributesToIdentity()
    {
        var userId = Guid.NewGuid();
        _identityMock.Setup(i => i.RegisterAsync(
            "patient@test.com",
            "Password123",
            "أحمد محمود",
            null,
            null,
            "Patient",
            "ذكر",
            28,
            "حساسية الصدر",
            "البنسلين، السلفا",
            It.IsAny<CancellationToken>()))
            .ReturnsAsync((true, userId.ToString(), null));

        _jwtMock.Setup(j => j.GenerateAccessToken(userId, "patient@test.com", "Patient"))
            .Returns("access-token-patient");
        _jwtMock.Setup(j => j.GenerateRefreshToken())
            .Returns(("refresh-token-patient", DateTime.UtcNow.AddDays(7)));

        var command = new RegisterCommand(
            Email: "patient@test.com",
            Password: "Password123",
            FullName: "أحمد محمود",
            FcmToken: null,
            Role: "Patient",
            Gender: "ذكر",
            Age: 28,
            ChronicConditions: "حساسية الصدر",
            KnownAllergies: "البنسلين، السلفا"
        );

        var result = await _handler.Handle(command, CancellationToken.None);

        result.Should().NotBeNull();
        result.Role.Should().Be("Patient");
        result.UserId.Should().Be(userId);
        result.AccessToken.Should().Be("access-token-patient");

        _identityMock.Verify(i => i.RegisterAsync(
            "patient@test.com",
            "Password123",
            "أحمد محمود",
            null,
            null,
            "Patient",
            "ذكر",
            28,
            "حساسية الصدر",
            "البنسلين، السلفا",
            It.IsAny<CancellationToken>()), Times.Once);
    }
}
