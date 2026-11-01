using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Domain.Common;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.NLP;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Search;

/// <summary>
/// Evaluates multimodal parser accuracy on noisy, handwritten doctor prescriptions/recipes (روشتات أطباء).
/// Compares raw exact lookup (which fails on handwriting/OCR artifacts) against the intelligent
/// fuzzy pipeline (consonant skeleton, Levenshtein distance, clinical prefix stripping, dialect normalization).
/// </summary>
public sealed class DoctorPrescriptionFuzzyAccuracyTests
{
    private readonly ApplicationDbContext _context;
    private readonly EgyptianDialectNormalizerService _dialectNormalizer = new();
    private readonly ClinicalPrescriptionMatcher _matcher;
    private readonly ParseMultimodalQueryCommandHandler _handler;

    public DoctorPrescriptionFuzzyAccuracyTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        SeedMasterEdaCatalog();

        _matcher = new ClinicalPrescriptionMatcher(_context, _dialectNormalizer);

        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(false); // tests local fallback by default
        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParseMultimodalQueryCommandHandler>.Instance;
        _handler = new ParseMultimodalQueryCommandHandler(_matcher, mockGemini.Object, logger);
    }

    private void SeedMasterEdaCatalog()
    {
        _context.EgyptianDrugRegistry.AddRange(
            new EgyptianDrugRegistry
            {
                TradeName = "Concor",
                TradeNameNormalized = "CONCOR 5MG",
                ActiveIngredient = "Bisoprolol Fumarate",
                ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
                Strength = "5mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 40.5m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Augmentin",
                TradeNameNormalized = "AUGMENTIN 1G",
                ActiveIngredient = "Amoxicillin / Clavulanic Acid",
                ActiveIngredientNormalized = "AMOXICILLIN / CLAVULANIC ACID",
                Strength = "1g",
                DosageForm = "Tablet",
                OfficialPriceEGP = 99.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Glucophage",
                TradeNameNormalized = "GLUCOPHAGE 1000MG",
                ActiveIngredient = "Metformin Hydrochloride",
                ActiveIngredientNormalized = "METFORMIN HYDROCHLORIDE",
                Strength = "1000mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 60.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Panadol Extra",
                TradeNameNormalized = "PANADOL EXTRA",
                ActiveIngredient = "Paracetamol / Caffeine",
                ActiveIngredientNormalized = "PARACETAMOL / CAFFEINE",
                Strength = "500mg/65mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 35.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Ketolac",
                TradeNameNormalized = "KETOLAC 30MG/2ML",
                ActiveIngredient = "Ketorolac Tromethamine",
                ActiveIngredientNormalized = "KETOROLAC TROMETHAMINE",
                Strength = "30mg/2ml",
                DosageForm = "Injection",
                OfficialPriceEGP = 25.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Cataflam",
                TradeNameNormalized = "CATAFLAM 50MG",
                ActiveIngredient = "Diclofenac Potassium",
                ActiveIngredientNormalized = "DICLOFENAC POTASSIUM",
                Strength = "50mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 51.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Brufen",
                TradeNameNormalized = "BRUFEN 400MG",
                ActiveIngredient = "Ibuprofen",
                ActiveIngredientNormalized = "IBUPROFEN",
                Strength = "400mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 38.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Antinal",
                TradeNameNormalized = "ANTINAL 200MG",
                ActiveIngredient = "Nifuroxazide",
                ActiveIngredientNormalized = "NIFUROXAZIDE",
                Strength = "200mg",
                DosageForm = "Capsule",
                OfficialPriceEGP = 26.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Nexium",
                TradeNameNormalized = "NEXIUM 40MG",
                ActiveIngredient = "Esomeprazole",
                ActiveIngredientNormalized = "ESOMEPRAZOLE",
                Strength = "40mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 140.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Clexane",
                TradeNameNormalized = "CLEXANE 60MG",
                ActiveIngredient = "Enoxaparin Sodium",
                ActiveIngredientNormalized = "ENOXAPARIN SODIUM",
                Strength = "60mg",
                DosageForm = "Pre-filled Pen",
                OfficialPriceEGP = 180.0m,
                IsChronic = true
            }
        );
        _context.SaveChanges();
    }

    [Theory]
    [InlineData("R/ Concr 5 tab - 1x1 daily", "Concor", "5mg", "Tablet")]
    [InlineData("1- Augmntin 1g tab bid", "Augmentin", "1g", "Tablet")]
    [InlineData("R/ Glucofag 1000 mg 1x2 pc", "Glucophage", "1000mg", "Tablet")]
    [InlineData("Panadol Extr tab prn", "Panadol Extra", null, "Tablet")]
    [InlineData("Ketolac amp im stat", "Ketolac", null, "Injection")]
    [InlineData("Cataflm 50 mg", "Cataflam", "50mg", null)]
    [InlineData("Brufn 400 mg 1x3", "Brufen", "400mg", null)]
    [InlineData("Antinl 200 cap", "Antinal", "200mg", "Capsule")]
    [InlineData("كونكور ٥ مجم قرص يوميا", "Concor", "5mg", "Tablet")]
    [InlineData("كلكسان ستين حقنة", "Clexane", "60mg", "Pre-filled Pen")]
    public async Task ParseMultimodal_HandwrittenDoctorPrescription_ResolvesAccurately(
        string handwrittenRecipeLine, string expectedDrug, string? expectedStrength, string? expectedForm)
    {
        var result = await _handler.Handle(
            new ParseMultimodalQueryCommand(handwrittenRecipeLine, "ocr"),
            CancellationToken.None);

        result.Should().NotBeNull();
        result.ResolvedName.Should().Be(expectedDrug);
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.80m);

        if (expectedStrength != null)
        {
            result.Strength.Should().Be(expectedStrength);
        }

        if (expectedForm != null)
        {
            result.DosageForm.Should().Be(expectedForm);
        }
    }

    [Fact]
    public async Task ModelAccuracyComparison_FuzzySearchVsRawLookup_ProvesAccuracyIncrease()
    {
        // 10 realistic noisy handwritten prescription lines from clinic practice
        var samplePrescriptions = new List<(string NoisyRecipe, string ExpectedTradeName)>
        {
            ("R/ Concr 5 tab - 1x1", "Concor"),
            ("1. Augmntin 1g tab tid", "Augmentin"),
            ("R/ Glucofag 1000mg 1x2", "Glucophage"),
            ("Panadol Extr tab", "Panadol Extra"),
            ("Ketolac amp im stat", "Ketolac"),
            ("Cataflm 50 mg", "Cataflam"),
            ("Brufn 400 mg", "Brufen"),
            ("Antinl 200 cap", "Antinal"),
            ("كونكور خمسة قرص", "Concor"),
            ("كلكسان ستين حقنة", "Clexane")
        };

        int rawSuccessCount = 0;
        int fuzzySuccessCount = 0;

        foreach (var sample in samplePrescriptions)
        {
            // Simulation of raw un-anchored lookup without fuzzy pipeline
            var rawNorm = sample.NoisyRecipe.Trim().ToUpperInvariant();
            var rawExact = await _context.EgyptianDrugRegistry
                .AnyAsync(d => d.TradeNameNormalized == rawNorm || d.TradeName.ToUpper() == rawNorm);

            if (rawExact) rawSuccessCount++;

            // Intelligent fuzzy pipeline
            var result = await _handler.Handle(
                new ParseMultimodalQueryCommand(sample.NoisyRecipe, "ocr"),
                CancellationToken.None);

            if (result.ResolvedName.Equals(sample.ExpectedTradeName, StringComparison.OrdinalIgnoreCase))
            {
                fuzzySuccessCount++;
            }
        }

        double rawAccuracy = (double)rawSuccessCount / samplePrescriptions.Count * 100.0;
        double fuzzyAccuracy = (double)fuzzySuccessCount / samplePrescriptions.Count * 100.0;

        // Raw lookup fails 100% of the time on noisy handwritten prescription lines
        rawAccuracy.Should().Be(0.0, "Raw exact string lookup cannot handle handwriting noise or clinical abbreviations");

        // The fuzzy search pipeline achieves >= 90% accuracy on handwritten prescription lines
        fuzzyAccuracy.Should().BeGreaterThanOrEqualTo(90.0, "The multi-tier fuzzy pipeline should resolve handwritten prescription lines with >= 90% accuracy");
    }

    [Fact]
    public async Task DosageFeasibilityGate_WithFeasibleVsInfeasibleStrength_AppliesCorrectGating()
    {
        // Concor exists in 5mg in Egypt, but does NOT exist in 500mg
        var feasibleMatch = await _matcher.MatchPrescriptionAsync("Concr 5 tab");
        var infeasibleMatch = await _matcher.MatchPrescriptionAsync("Concr 500 tab");

        // Feasible match gets bonus and confidence >= 0.90
        feasibleMatch.ResolvedName.Should().Be("Concor");
        feasibleMatch.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);

        // Infeasible match has lower confidence or is penalized by the Feasibility Gate
        var concorCandidate = infeasibleMatch.Candidates.FirstOrDefault(c => c.TradeName == "Concor");
        if (concorCandidate != null)
        {
            concorCandidate.IsDosageFeasible.Should().BeFalse(
                "Concor 500mg is not manufactured/registered in Egypt, so the Feasibility Gate must flag it as infeasible");
        }
    }

    [Theory]
    [InlineData("Banadol Extr tab", "Panadol Extra")]  // P -> B swap in handwriting / Egyptian Arabic phonetics
    [InlineData("Glucofag 1000 mg", "Glucophage")]     // PH -> F swap
    [InlineData("Kataflm 50 mg", "Cataflam")]          // C -> K swap
    public async Task EgyptianPhonetics_SwappedCommonConsonants_ResolvesAccurately(
        string noisyPhoneticLine, string expectedResolvedDrug)
    {
        var result = await _matcher.MatchPrescriptionAsync(noisyPhoneticLine);

        result.Should().NotBeNull();
        result.ResolvedName.Should().Be(expectedResolvedDrug);
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.85m);
    }

    [Fact]
    public async Task GeminiAI_WhenQuotaAvailable_ResolvesWithHighConfidenceWithoutDisambiguation()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(true);
        mockGemini.Setup(g => g.ParsePrescriptionAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new GeminiPrescriptionResult("Concor", "5mg", "Tablet", 0.96m, true, false));

        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParseMultimodalQueryCommandHandler>.Instance;
        var handler = new ParseMultimodalQueryCommandHandler(_matcher, mockGemini.Object, logger);

        var result = await handler.Handle(
            new ParseMultimodalQueryCommand("dr handwritten scribbles cncr 5mg", "ocr"),
            CancellationToken.None);

        result.ResolvedName.Should().Be("Concor");
        result.Strength.Should().Be("5mg");
        result.Confidence.Should().BeGreaterThanOrEqualTo(0.95m);
        result.RequiresDisambiguation.Should().BeFalse(
            "High confidence verified Gemini AI match should not require human disambiguation");
    }

    [Fact]
    public async Task GeminiAI_When1400QuotaExhausted_GracefullyFailsOverToLocalEngineWithDisambiguation()
    {
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        // Daily quota limit reached (>= 1400)
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(false);

        var logger = Microsoft.Extensions.Logging.Abstractions.NullLogger<ParseMultimodalQueryCommandHandler>.Instance;
        var handler = new ParseMultimodalQueryCommandHandler(_matcher, mockGemini.Object, logger);

        var result = await handler.Handle(
            new ParseMultimodalQueryCommand("R/ Concr 5 tab 1x1", "ocr"),
            CancellationToken.None);

        // Fallback resolves via local ClinicalPrescriptionMatcher
        result.ResolvedName.Should().Be("Concor");
        result.Strength.Should().Be("5mg");
        result.RequiresDisambiguation.Should().BeTrue(
            "When AI quota is exhausted and running on local fallback, disambiguation card must be shown to the user");
        result.Candidates.Should().NotBeEmpty();
    }
}

