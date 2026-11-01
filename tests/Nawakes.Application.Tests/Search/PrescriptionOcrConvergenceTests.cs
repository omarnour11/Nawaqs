using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Moq;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Application.Search.Commands.ParsePrescriptionImage;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.NLP;
using Nawakes.Infrastructure.Persistence;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class PrescriptionOcrConvergenceTests
{
    private readonly ApplicationDbContext _context;
    private readonly EgyptianDialectNormalizerService _dialectNormalizer = new();
    private readonly ClinicalPrescriptionMatcher _matcher;
    private readonly SigDecoderService _sigDecoder = new();
    private readonly PrescriptionSafetyAuditor _safetyAuditor;

    public PrescriptionOcrConvergenceTests()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new ApplicationDbContext(
            options, new Nawakes.Infrastructure.Persistence.Interceptors.AuditableEntityInterceptor());

        SeedCatalog();

        _matcher = new ClinicalPrescriptionMatcher(_context, _dialectNormalizer);
        _safetyAuditor = new PrescriptionSafetyAuditor(NullLogger<PrescriptionSafetyAuditor>.Instance);
    }

    private void SeedCatalog()
    {
        _context.EgyptianDrugRegistry.AddRange(
            new EgyptianDrugRegistry
            {
                TradeName = "Concor",
                TradeNameNormalized = "CONCOR 5MG",
                CommercialNameAr = "كونكور",
                CommercialNameArNormalized = "كونكور 5 مجم",
                ActiveIngredient = "Bisoprolol Fumarate",
                ActiveIngredientNormalized = "BISOPROLOL FUMARATE",
                Strength = "5mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 40.5m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Amaryl",
                TradeNameNormalized = "AMARYL 2MG",
                CommercialNameAr = "أماريل",
                CommercialNameArNormalized = "اماريل 2 مجم",
                ActiveIngredient = "Glimepiride",
                ActiveIngredientNormalized = "GLIMEPIRIDE",
                Strength = "2mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 42.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Panadol Extra",
                TradeNameNormalized = "PANADOL EXTRA 500MG/65MG",
                CommercialNameAr = "بنادول اكسترا",
                CommercialNameArNormalized = "بنادول اكسترا",
                ActiveIngredient = "Paracetamol / Caffeine",
                ActiveIngredientNormalized = "PARACETAMOL / CAFFEINE",
                Strength = "500mg/65mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 45.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Milga Advance",
                TradeNameNormalized = "MILGA ADVANCE",
                CommercialNameAr = "ميلجا ادفانس",
                CommercialNameArNormalized = "ميلجا ادفانس",
                ActiveIngredient = "Benfotiamine / Pyridoxine / Cyanocobalamin",
                ActiveIngredientNormalized = "BENFOTIAMINE / PYRIDOXINE / CYANOCOBALAMIN",
                Strength = "Tablet",
                DosageForm = "Tablet",
                OfficialPriceEGP = 60.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Concor Plus",
                TradeNameNormalized = "CONCOR PLUS 5MG/12.5MG",
                CommercialNameAr = "كونكور بلس",
                CommercialNameArNormalized = "كونكور بلس",
                ActiveIngredient = "Bisoprolol / Hydrochlorothiazide",
                ActiveIngredientNormalized = "BISOPROLOL / HYDROCHLOROTHIAZIDE",
                Strength = "5mg/12.5mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 55.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Sirdalud",
                TradeNameNormalized = "SIRDALUD 2MG",
                CommercialNameAr = "سردالود",
                CommercialNameArNormalized = "سردالود",
                ActiveIngredient = "Tizanidine",
                ActiveIngredientNormalized = "TIZANIDINE",
                Strength = "2mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 31.5m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Ciprobay",
                TradeNameNormalized = "CIPROBAY 500MG",
                CommercialNameAr = "سيبروباي",
                CommercialNameArNormalized = "سيبروباي",
                ActiveIngredient = "Ciprofloxacin",
                ActiveIngredientNormalized = "CIPROFLOXACIN",
                Strength = "500mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 79.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Plavix",
                TradeNameNormalized = "PLAVIX 75MG",
                CommercialNameAr = "بلافيكس",
                CommercialNameArNormalized = "بلافيكس",
                ActiveIngredient = "Clopidogrel",
                ActiveIngredientNormalized = "CLOPIDOGREL",
                Strength = "75mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 205.0m,
                IsChronic = true
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Losec",
                TradeNameNormalized = "LOSEC 20MG",
                CommercialNameAr = "لوسك",
                CommercialNameArNormalized = "لوسك",
                ActiveIngredient = "Omeprazole",
                ActiveIngredientNormalized = "OMEPRAZOLE",
                Strength = "20mg",
                DosageForm = "Capsule",
                OfficialPriceEGP = 65.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Augmentin",
                TradeNameNormalized = "AUGMENTIN 1G",
                CommercialNameAr = "أوجمنتين",
                CommercialNameArNormalized = "اوجمنتين 1 جم",
                ActiveIngredient = "Amoxicillin / Clavulanic Acid",
                ActiveIngredientNormalized = "AMOXICILLIN / CLAVULANIC ACID",
                Strength = "1g",
                DosageForm = "Tablet",
                OfficialPriceEGP = 99.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Brufen",
                TradeNameNormalized = "BRUFEN 400MG",
                CommercialNameAr = "بروفين",
                CommercialNameArNormalized = "بروفين",
                ActiveIngredient = "Ibuprofen",
                ActiveIngredientNormalized = "IBUPROFEN",
                Strength = "400mg",
                DosageForm = "Tablet",
                OfficialPriceEGP = 38.0m,
                IsChronic = false
            },
            new EgyptianDrugRegistry
            {
                TradeName = "Alphintern",
                TradeNameNormalized = "ALPHINTERN",
                CommercialNameAr = "ألفانترن",
                CommercialNameArNormalized = "الفانترن",
                ActiveIngredient = "Chymotrypsin / Trypsin",
                ActiveIngredientNormalized = "CHYMOTRYPSIN / TRYPSIN",
                Strength = "Tablet",
                DosageForm = "Tablet",
                OfficialPriceEGP = 54.0m,
                IsChronic = false
            }
        );
        _context.SaveChanges();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 1. Multi-Item Prescription Disambiguation Bug Fix
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task MultiItemPrescription_DoesNotTriggerRequiresDisambiguation_WhenCandidatesAreDistinctMedications()
    {
        // Bug fix in ParsePrescriptionImageCommandHandler lines 104-106:
        // Multiple items in a valid multi-medication prescription should NOT trigger RequiresDisambiguation.
        var mockGemini = new Mock<IGeminiPrescriptionService>();
        mockGemini.Setup(g => g.IsDailyQuotaAvailable()).Returns(true);
        mockGemini.Setup(g => g.ParsePrescriptionFromImageBytesAsync(
                It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new GeminiPrescriptionResult(
                "Concor", "5mg", "Tablet", 0.95m, true, false,
                [
                    new GeminiMedicationItem("Concor", "5mg", "Tablet", 0.95m, 1, "1x1", "Bisoprolol Fumarate"),
                    new GeminiMedicationItem("Amaryl", "2mg", "Tablet", 0.92m, 1, "1x2", "Glimepiride")
                ]));

        var mockSecondary = new Mock<ISecondaryOcrService>();
        var handler = new ParsePrescriptionImageCommandHandler(
            mockGemini.Object,
            mockSecondary.Object,
            _matcher,
            _sigDecoder,
            _safetyAuditor,
            NullLogger<ParsePrescriptionImageCommandHandler>.Instance);

        var result = await handler.Handle(
            new ParsePrescriptionImageCommand(new byte[] { 1, 2, 3, 4 }, "image/jpeg"),
            CancellationToken.None);

        result.IsSuccess.Should().BeTrue();
        result.Candidates.Should().HaveCount(2);

        // Crucial invariant: 2 valid medications must NOT be marked as requiresDisambiguation
        result.RequiresDisambiguation.Should().BeFalse(
            "a valid multi-item prescription with multiple distinct verified drugs should never be flagged for disambiguation");

        // Verify Arabic dosage instructions were populated
        result.Candidates[0].ArabicSig.Should().NotBeNullOrEmpty();
        result.Candidates[0].PriceEgp.Should().Be(40.5m);

        result.Candidates[1].ArabicSig.Should().NotBeNullOrEmpty();
        result.Candidates[1].PriceEgp.Should().Be(42.0m);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2. Bilingual Sig Decoder (ISigDecoderService) Tests
    // ──────────────────────────────────────────────────────────────────────────

    [Theory]
    [InlineData("1x1", 1, 1, "مرة واحدة يومياً")]
    [InlineData("1x2", 1, 2, "مرتان يومياً")]
    [InlineData("1x3", 1, 3, "3 مرات يومياً")]
    [InlineData("1x4", 1, 4, "4 مرات يومياً")]
    public void SigDecoder_EgyptianDosageNotation_DecodesAccurately(
        string notation, int expectedDose, int expectedFreq, string expectedArabic)
    {
        var decoded = _sigDecoder.DecodeSig(notation);

        decoded.DoseQuantity.Should().Be(expectedDose);
        decoded.FrequencyPerDay.Should().Be(expectedFreq);
        decoded.ArabicText.Should().Contain(expectedArabic);
        decoded.ArabicInstructionSticker.Should().NotBeNullOrEmpty();
    }

    [Theory]
    [InlineData("QD", 1, "مرة واحدة يومياً")]
    [InlineData("BID", 2, "مرتان يومياً")]
    [InlineData("TID", 3, "3 مرات يومياً")]
    [InlineData("QID", 4, "4 مرات يومياً")]
    [InlineData("PRN", null, "عند اللزوم")]
    [InlineData("QHS", 1, "قبل النوم")]
    public void SigDecoder_StandardFrequencyAbbreviations_DecodesAccurately(
        string code, int? expectedFreq, string expectedArabic)
    {
        var decoded = _sigDecoder.DecodeSig(code);

        if (expectedFreq.HasValue)
        {
            decoded.FrequencyPerDay.Should().Be(expectedFreq.Value);
        }
        decoded.ArabicText.Should().Contain(expectedArabic);
    }

    [Theory]
    [InlineData("PO", "عن طريق الفم")]
    [InlineData("SL", "تحت اللسان")]
    [InlineData("IM", "حقن عضلي")]
    [InlineData("IV", "حقن وريدي")]
    [InlineData("TOP", "استخدام موضعي")]
    public void SigDecoder_RouteAbbreviations_DecodesToPatientFriendlyArabic(string route, string expectedArabic)
    {
        var decoded = _sigDecoder.DecodeSig($"1 tab {route} QD");

        decoded.RouteArabic.Should().Be(expectedArabic);
        decoded.ArabicInstructionSticker.Should().Contain(expectedArabic);
    }

    [Theory]
    [InlineData("AC", "قبل الأكل")]
    [InlineData("PC", "بعد الأكل")]
    [InlineData("على الريق", "على الريق")]
    [InlineData("قبل الأكل", "قبل الأكل")]
    [InlineData("بعد الأكل", "بعد الأكل")]
    [InlineData("قبل النوم", "قبل النوم")]
    public void SigDecoder_MealDirectives_DecodesAccurately(string directive, string expectedArabic)
    {
        var decoded = _sigDecoder.DecodeSig($"1 tab BID {directive}");

        decoded.TimingArabic.Should().Contain(expectedArabic);
        decoded.ArabicInstructionSticker.Should().Contain(expectedArabic);
    }

    [Fact]
    public void SigDecoder_ComplexPrescriptionSig_ProducesPatientFriendlyInstructionSticker()
    {
        // 1 tab PO TID PC
        var decoded = _sigDecoder.DecodeSig("1 tab PO TID PC");

        decoded.DoseQuantity.Should().Be(1);
        decoded.FrequencyPerDay.Should().Be(3);
        decoded.RouteArabic.Should().Be("عن طريق الفم");
        decoded.TimingArabic.Should().Be("بعد الأكل");

        // Sticker format: قرص واحد - عن طريق الفم - 3 مرات يومياً - بعد الأكل
        decoded.ArabicInstructionSticker.Should().Contain("عن طريق الفم");
        decoded.ArabicInstructionSticker.Should().Contain("3 مرات يومياً");
        decoded.ArabicInstructionSticker.Should().Contain("بعد الأكل");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 3. Prescription Safety Auditor (IPrescriptionSafetyAuditor) Tests
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task SafetyAuditor_SirdaludAndCipro_TriggersCriticalContraindication()
    {
        // Tizanidine + Ciprofloxacin is contraindicated (severe hypotension and CNS depression)
        var medications = new List<SafetyMedicationInput>
        {
            new("Sirdalud", "Tizanidine", "2mg", "1x1"),
            new("Ciprobay", "Ciprofloxacin", "500mg", "1x2")
        };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications);

        alerts.Should().Contain(a =>
            a.Severity == SafetyAlertSeverity.Critical &&
            a.Message.Contains("تفاعل دوائي خطير") &&
            a.InteractingSubstances.Contains("Tizanidine") &&
            a.InteractingSubstances.Contains("Ciprofloxacin"));
    }

    [Fact]
    public async Task SafetyAuditor_PlavixAndOmeprazole_TriggersCriticalInteraction()
    {
        // Clopidogrel + Omeprazole reduces antiplatelet efficacy via CYP2C19 inhibition
        var medications = new List<SafetyMedicationInput>
        {
            new("Plavix", "Clopidogrel", "75mg", "1x1"),
            new("Losec", "Omeprazole", "20mg", "1x1")
        };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications);

        alerts.Should().Contain(a =>
            a.Severity == SafetyAlertSeverity.Critical &&
            a.InteractingSubstances.Contains("Clopidogrel") &&
            a.InteractingSubstances.Contains("Omeprazole"));
    }

    [Fact]
    public async Task SafetyAuditor_PlavixAndBrufen_TriggersWarningBleedingRisk()
    {
        // Antiplatelet + NSAID increases GI bleeding risk
        var medications = new List<SafetyMedicationInput>
        {
            new("Plavix", "Clopidogrel", "75mg", "1x1"),
            new("Brufen", "Ibuprofen", "400mg", "1x3")
        };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications);

        alerts.Should().Contain(a =>
            a.Severity == SafetyAlertSeverity.Warning &&
            a.Message.Contains("خطر النزيف المعوي"));
    }

    [Fact]
    public async Task SafetyAuditor_PenicillinAllergyWithAugmentin_TriggersCriticalAllergyAlert()
    {
        var medications = new List<SafetyMedicationInput>
        {
            new("Augmentin", "Amoxicillin / Clavulanic Acid", "1g", "1x2")
        };

        var patientAllergies = new List<string> { "Penicillin" };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications, patientAllergies);

        alerts.Should().Contain(a =>
            a.Severity == SafetyAlertSeverity.Critical &&
            a.AlertCode == "ALLERGY_CONFLICT" &&
            a.Message.Contains("حساسية البنسلين"));
    }

    [Fact]
    public async Task SafetyAuditor_AlphinternTimingInstruction_YieldsAdvisoryAlert()
    {
        var medications = new List<SafetyMedicationInput>
        {
            new("Alphintern", "Chymotrypsin / Trypsin", "Tablet", "1x3")
        };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications);

        alerts.Should().Contain(a =>
            a.AlertCode == "TIMING_DIRECTIVE" &&
            a.Recommendation.Contains("قبل الأكل بساعة"));
    }

    [Fact]
    public async Task SafetyAuditor_SafePrescription_YieldsNominalStatus()
    {
        var medications = new List<SafetyMedicationInput>
        {
            new("Concor", "Bisoprolol Fumarate", "5mg", "1x1"),
            new("Amaryl", "Glimepiride", "2mg", "1x1")
        };

        var alerts = await _safetyAuditor.AuditPrescriptionSafetyAsync(medications);

        alerts.Should().ContainSingle(a =>
            a.Severity == SafetyAlertSeverity.Nominal &&
            a.AlertCode == "NOMINAL_SAFE");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 4. Compound 2-Word Brand Indexing & Official EGP Price Caching
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task ClinicalPrescriptionMatcher_Compound2WordBrand_MatchesAccuratelyAndPreservesPrice()
    {
        // "Panadol Extra" is a compound brand that shouldn't be split or confused with standard Panadol
        var match = await _matcher.MatchPrescriptionAsync("Panadol Extra 500mg");

        match.Should().NotBeNull();
        match.ResolvedName.Should().Be("Panadol Extra");
        match.ActiveIngredient.Should().Be("Paracetamol / Caffeine");
        match.PriceEgp.Should().Be(45.0m);
        match.Confidence.Should().BeGreaterThanOrEqualTo(0.90m);
    }

    [Fact]
    public async Task ClinicalPrescriptionMatcher_ArabicCompoundBrand_MatchesAccurately()
    {
        // "بنادول اكسترا"
        var match = await _matcher.MatchPrescriptionAsync("بنادول اكسترا");

        match.Should().NotBeNull();
        match.ResolvedName.Should().Be("Panadol Extra");
        match.PriceEgp.Should().Be(45.0m);
    }

    [Fact]
    public async Task ClinicalPrescriptionMatcher_MilgaAdvance_MatchesAccurately()
    {
        var match = await _matcher.MatchPrescriptionAsync("Milga Advance");

        match.Should().NotBeNull();
        match.ResolvedName.Should().Be("Milga Advance");
        match.PriceEgp.Should().Be(60.0m);
    }

    [Fact]
    public async Task ClinicalPrescriptionMatcher_ConcorPlus_MatchesCompoundOverSingleBrand()
    {
        var match = await _matcher.MatchPrescriptionAsync("Concor Plus");

        match.Should().NotBeNull();
        match.ResolvedName.Should().Be("Concor Plus");
        match.ActiveIngredient.Should().Contain("Hydrochlorothiazide");
        match.PriceEgp.Should().Be(55.0m);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. Egyptian Law 151 of 2020 PII Redaction
    // ──────────────────────────────────────────────────────────────────────────

    [Fact]
    public void PiiRedaction_FilterPiiStopwords_SuppressesDoctorPatientAndEgyptianLocations()
    {
        var rawOcrText = """
            عيادة الأمل التخصصية
            دكتور أحمد الشناوي - استشاري القلب والباطنة
            رقم القيد بنقابة الأطباء: 12345
            اسم المريض: محمد محمود
            العنوان: الدقي - الجيزة
            تاريخ: 15/10/2026

            Rx:
            Concor 5mg 1x1
            Amaryl 2mg 1x1
            """;

        var filtered = GeminiPrescriptionService.FilterPiiStopwords(rawOcrText);

        // Doctor / Patient / Syndicate / City information must be redacted
        filtered.Should().NotContain("أحمد الشناوي");
        filtered.Should().NotContain("استشاري");
        filtered.Should().NotContain("12345");
        filtered.Should().NotContain("محمد محمود");
        filtered.Should().NotContain("الدقي");
        filtered.Should().NotContain("الجيزة");

        // Prescribed medications must be preserved
        filtered.Should().Contain("Concor 5mg 1x1");
        filtered.Should().Contain("Amaryl 2mg 1x1");
    }
}
