using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Nawakes.Infrastructure.NLP;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class PrescriptionSanitizationServiceTests
{
    private readonly PrescriptionSanitizationService _sanitizer =
        new(NullLogger<PrescriptionSanitizationService>.Instance);

    [Theory]
    [InlineData("عيادة الأمل لجراحة العظام - دكتور أحمد سامي")]
    [InlineData("Dr. Mohamed Mostafa - Consultant Cardiologist")]
    [InlineData("مستشفى المعادي الدولي - تليفون: 01012345678")]
    [InlineData("اسم المريض: محمود السيد - السن: 45 سنة")]
    [InlineData("عنوان العيادة: 15 شارع مصدق، الدقي، الجيزة")]
    [InlineData("رقم القيد بالنقابة: 48920")]
    public void ContainsPii_WithIdentifiablePhysicianOrPatientTokens_ShouldReturnTrue(string piiSample)
    {
        // Act
        var result = _sanitizer.ContainsPii(piiSample);

        // Assert
        result.Should().BeTrue();
    }

    [Theory]
    [InlineData("Concor 5mg tab 1x1 PO")]
    [InlineData("Augmentin 1g tablet - bid pc")]
    [InlineData("Panadol Extra 500mg - قرص كل 8 ساعات بعد الأكل")]
    [InlineData("Glucophage 1000mg tab")]
    public void ContainsPii_PureMedicationOrders_ShouldReturnFalse(string medSample)
    {
        // Act
        var result = _sanitizer.ContainsPii(medSample);

        // Assert
        result.Should().BeFalse();
    }

    [Fact]
    public void RedactPii_MixedPrescription_ShouldStripHeaderAndFooterWhilePreservingMedications()
    {
        // Arrange
        var mixedText = """
            عيادة الدكتور طارق حسني
            استشاري أمراض القلب والأوعية الدموية
            عنوان: 20 شارع النيل، العجوزة، الجيزة
            تليفون: 01099887766

            Rx:
            1. Concor 5mg - قرص واحد يومياً
            2. Lipitor 20mg - قرص مساءً
            3. Plavix 75mg - قرص بعد الغداء

            اسم المريض: عماد عبد الرحمن
            السن: 58 سنة
            التاريخ: 12/10/2026
            توقيع الطبيب: ط.ح
            """;

        // Act
        var redacted = _sanitizer.RedactPii(mixedText);

        // Assert
        redacted.Should().NotContain("دكتور طارق حسني");
        redacted.Should().NotContain("استشاري");
        redacted.Should().NotContain("01099887766");
        redacted.Should().NotContain("عماد عبد الرحمن");
        redacted.Should().Contain("Concor");
        redacted.Should().Contain("Lipitor");
        redacted.Should().Contain("Plavix");
    }

    [Fact]
    public void SanitizePrescription_PngImage_ShouldCalculateCorrectMedicationCropWindow()
    {
        // Arrange: Valid 800x1200 PNG header
        var pngBytes = new byte[64];
        // Signature
        pngBytes[0] = 0x89; pngBytes[1] = 0x50; pngBytes[2] = 0x4E; pngBytes[3] = 0x47;
        pngBytes[4] = 0x0D; pngBytes[5] = 0x0A; pngBytes[6] = 0x1A; pngBytes[7] = 0x0A;
        // IHDR chunk
        pngBytes[12] = (byte)'I'; pngBytes[13] = (byte)'H'; pngBytes[14] = (byte)'D'; pngBytes[15] = (byte)'R';
        // Width = 800 (0x00000320)
        pngBytes[16] = 0x00; pngBytes[17] = 0x00; pngBytes[18] = 0x03; pngBytes[19] = 0x20;
        // Height = 1200 (0x000004B0)
        pngBytes[20] = 0x00; pngBytes[21] = 0x00; pngBytes[22] = 0x04; pngBytes[23] = 0xB0;

        // Act
        var result = _sanitizer.SanitizePrescription(pngBytes, "image/png", headerRatio: 0.20, footerRatio: 0.18);

        // Assert
        result.IsCompliantWithLaw151.Should().BeTrue();
        result.OriginalWidth.Should().Be(800);
        result.OriginalHeight.Should().Be(1200);
        result.CropX.Should().Be(0);
        result.CropY.Should().Be(240); // 1200 * 0.20
        result.CropHeight.Should().Be(744); // 1200 * (1 - 0.20 - 0.18) = 744
        result.CropWidth.Should().Be(800);
    }

    [Fact]
    public void SanitizePrescription_EmptyBytes_ShouldReturnNonCompliant()
    {
        // Act
        var result = _sanitizer.SanitizePrescription([], "image/jpeg");

        // Assert
        result.IsCompliantWithLaw151.Should().BeFalse();
        result.SanitizedImageBytes.Should().BeEmpty();
    }
}
