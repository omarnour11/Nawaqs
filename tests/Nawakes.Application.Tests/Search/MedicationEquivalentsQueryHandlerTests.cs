using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.GetMedicationEquivalents;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Persistence;
using NetTopologySuite.Geometries;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class MedicationEquivalentsQueryHandlerTests
{
    private readonly ApplicationDbContext _context;
    private readonly GetMedicationEquivalentsQueryHandler _handler;

    public MedicationEquivalentsQueryHandlerTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        SeedSampleDrugs();
        _handler = new GetMedicationEquivalentsQueryHandler(_context);
    }

    private void SeedSampleDrugs()
    {
        // 1. Bisoprolol group (Concor vs Biconcor vs Bisocard)
        var concor5 = new EgyptianDrugRegistry
        {
            TradeName = "Concor 5mg",
            TradeNameNormalized = "CONCOR 5MG",
            CommercialNameAr = "كونكور 5 مجم",
            CommercialNameArNormalized = "كونكور 5 مجم",
            ActiveIngredient = "Bisoprolol Fumarate",
            ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
            Strength = "5mg",
            DosageForm = "Tablet",
            OfficialPriceEGP = 40.5m,
            Manufacturer = "Merck",
            IsChronic = true
        };

        var biconcor5 = new EgyptianDrugRegistry
        {
            TradeName = "Biconcor 5mg",
            TradeNameNormalized = "BICONCOR 5MG",
            CommercialNameAr = "بيكونكور 5 مجم",
            CommercialNameArNormalized = "بيكونكور 5 مجم",
            ActiveIngredient = "Bisoprolol Fumarate",
            ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
            Strength = "5mg",
            DosageForm = "Tablet",
            OfficialPriceEGP = 28.0m,
            Manufacturer = "Amoun",
            IsChronic = true
        };

        var concor10 = new EgyptianDrugRegistry
        {
            TradeName = "Concor 10mg",
            TradeNameNormalized = "CONCOR 10MG",
            CommercialNameAr = "كونكور 10 مجم",
            CommercialNameArNormalized = "كونكور 10 مجم",
            ActiveIngredient = "Bisoprolol Fumarate",
            ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
            Strength = "10mg",
            DosageForm = "Tablet",
            OfficialPriceEGP = 56.0m,
            Manufacturer = "Merck",
            IsChronic = true
        };

        // 2. Paracetamol group (Panadol vs Cetal vs Abimol)
        var panadol = new EgyptianDrugRegistry
        {
            TradeName = "Panadol 500mg",
            TradeNameNormalized = "PANADOL 500MG",
            CommercialNameAr = "بانادول 500 مجم",
            CommercialNameArNormalized = "بانادول 500 مجم",
            ActiveIngredient = "Paracetamol",
            ActiveIngredientNormalized = "PARACETAMOL",
            Strength = "500mg",
            DosageForm = "Tablet",
            OfficialPriceEGP = 25.0m,
            Manufacturer = "GSK",
            IsChronic = false
        };

        var cetal = new EgyptianDrugRegistry
        {
            TradeName = "Cetal 500mg",
            TradeNameNormalized = "CETAL 500MG",
            CommercialNameAr = "سيتال 500 مجم",
            CommercialNameArNormalized = "سيتال 500 مجم",
            ActiveIngredient = "Paracetamol",
            ActiveIngredientNormalized = "PARACETAMOL",
            Strength = "500mg",
            DosageForm = "Tablet",
            OfficialPriceEGP = 15.0m,
            Manufacturer = "EIPICO",
            IsChronic = false
        };

        _context.EgyptianDrugRegistry.AddRange(concor5, biconcor5, concor10, panadol, cetal);

        // Add a pharmacy with in-stock inventory for Biconcor 5mg
        var pharmacy = new Nawakes.Domain.Entities.Pharmacy
        {
            Name = "صيدلية النواقص الكبرى",
            AddressLine = "شارع التحرير، الدقي",
            Phone = "01012345678",
            City = "Giza",
            VerificationStatus = VerificationStatus.Approved,
            GeoPoint = new Point(31.2089, 30.0385) { SRID = 4326 }
        };

        var inventoryItem = new InventoryItem
        {
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Biconcor 5mg",
            MedicationNameNormalized = "BICONCOR 5MG",
            Price = 28.0m,
            Quantity = 10,
            Status = InventoryStatus.InStock
        };

        var inventoryItem2 = new InventoryItem
        {
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Concor 10mg",
            MedicationNameNormalized = "CONCOR 10MG",
            Price = 56.0m,
            Quantity = 5,
            Status = InventoryStatus.InStock
        };

        var inventoryItem3 = new InventoryItem
        {
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Panadol 500mg",
            MedicationNameNormalized = "PANADOL 500MG",
            Price = 25.0m,
            Quantity = 8,
            Status = InventoryStatus.InStock
        };

        var inventoryItem4 = new InventoryItem
        {
            Pharmacy = pharmacy,
            PharmacyId = pharmacy.Id,
            MedicationName = "Cetal 500mg",
            MedicationNameNormalized = "CETAL 500MG",
            Price = 15.0m,
            Quantity = 12,
            Status = InventoryStatus.InStock
        };

        _context.Pharmacies.Add(pharmacy);
        _context.InventoryItems.AddRange(inventoryItem, inventoryItem2, inventoryItem3, inventoryItem4);
        _context.SaveChanges();
    }

    [Fact]
    public async Task Handle_TradeNameSearch_ReturnsExactBioequivalentsAndDosageAlternatives()
    {
        // Query for Concor 5mg near Cairo coordinates
        var query = new GetMedicationEquivalentsQuery(
            MedicationName: "Concor 5mg",
            Lat: 30.0385,
            Lng: 31.2089,
            RadiusKm: 10m);

        var result = await _handler.Handle(query, CancellationToken.None);

        result.Should().NotBeNull();
        result.IsActiveIngredientSearch.Should().BeFalse();
        result.Original.Should().NotBeNull();
        result.Original!.TradeName.Should().Be("Concor 5mg");
        result.Original.ActiveIngredient.Should().Be("Bisoprolol Fumarate");

        // Bioequivalents must contain Biconcor 5mg (same 5mg and Tablet)
        result.Bioequivalents.Should().NotBeNull();
        result.Bioequivalents.Should().Contain(b => b.EquivalentTradeName == "Biconcor 5mg");
        var biconcorMatch = result.Bioequivalents!.First(b => b.EquivalentTradeName == "Biconcor 5mg");
        biconcorMatch.IsExactBioequivalent.Should().BeTrue();
        biconcorMatch.PriceSavingPercent.Should().BeGreaterThan(0);
        biconcorMatch.PriceDifferenceEGP.Should().Be(12.5m); // 40.5 - 28.0 = 12.5 EGP saved

        // Therapeutic alternatives must contain Concor 10mg (different strength)
        result.TherapeuticAlternatives.Should().NotBeNull();
        result.TherapeuticAlternatives.Should().Contain(a => a.EquivalentTradeName == "Concor 10mg");
    }

    [Fact]
    public async Task Handle_ActiveIngredientSearch_InEnglish_ReturnsAllMatchingBrands()
    {
        // Query generic molecule "Paracetamol"
        var query = new GetMedicationEquivalentsQuery(
            MedicationName: "Paracetamol",
            Lat: 30.0385,
            Lng: 31.2089,
            RadiusKm: 10m);

        var result = await _handler.Handle(query, CancellationToken.None);

        result.Should().NotBeNull();
        result.IsActiveIngredientSearch.Should().BeTrue();
        result.ActiveIngredient.Should().Be("Paracetamol");
        result.TotalRegisteredInEgypt.Should().Be(2); // Panadol and Cetal

        // Should return both Panadol and Cetal
        result.AvailableEquivalents.Should().Contain(e => e.EquivalentTradeName == "Panadol 500mg");
        result.AvailableEquivalents.Should().Contain(e => e.EquivalentTradeName == "Cetal 500mg");
    }

    [Fact]
    public async Task Handle_ActiveIngredientSearch_InArabic_ResolvesToCorrectGenericMolecule()
    {
        // Query Arabic generic "باراسيتامول"
        var query = new GetMedicationEquivalentsQuery(
            MedicationName: "باراسيتامول",
            Lat: 30.0385,
            Lng: 31.2089,
            RadiusKm: 10m);

        var result = await _handler.Handle(query, CancellationToken.None);

        result.Should().NotBeNull();
        result.IsActiveIngredientSearch.Should().BeTrue();
        result.ActiveIngredientAr.Should().Be("باراسيتامول");
        result.TotalRegisteredInEgypt.Should().Be(2);
        result.AvailableEquivalents.Should().HaveCount(2);
    }

    [Fact]
    public async Task Handle_UnknownMedication_ReturnsEmptyListWithLegalDisclaimer()
    {
        var query = new GetMedicationEquivalentsQuery(
            MedicationName: "NonExistentDrug999",
            Lat: 30.0385,
            Lng: 31.2089,
            RadiusKm: 10m);

        var result = await _handler.Handle(query, CancellationToken.None);

        result.Should().NotBeNull();
        result.Original.Should().BeNull();
        result.AvailableEquivalents.Should().BeEmpty();
        result.LegalDisclaimer.Should().Contain("⚠️ تنبيه طبي");
    }
}
