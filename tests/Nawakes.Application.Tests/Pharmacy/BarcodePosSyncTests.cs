using Xunit;
using FluentAssertions;
using Nawakes.Application.Pharmacy.Commands.ScanBarcodeInventory;

namespace Nawakes.Application.Tests.Pharmacy;

public sealed class BarcodePosSyncTests
{
    [Fact]
    public void ParseGs1OrEanBarcode_WithEgyptianGs1DataMatrix_ShouldExtractCanonicalEan13AndExpiryDate()
    {
        // Arrange: AI(01) 06221000012345 + AI(17) 271231 (Dec 31, 2027) + AI(10) BATCH99
        var rawGs1 = "(01)06221000012345(17)271231(10)BATCH99";

        // Act
        var (gtin, expiry) = ScanBarcodeInventoryCommandHandler.ParseGs1OrEanBarcode(rawGs1);

        // Assert
        gtin.Should().Be("6221000012345");
        expiry.Should().Be(new DateTime(2027, 12, 31, 0, 0, 0, DateTimeKind.Utc));
    }

    [Fact]
    public void ParseGs1OrEanBarcode_WithStandardEan13_ShouldReturnTrimmedBarcode()
    {
        // Arrange
        var ean13 = " 6223001234567 ";

        // Act
        var (gtin, expiry) = ScanBarcodeInventoryCommandHandler.ParseGs1OrEanBarcode(ean13);

        // Assert
        gtin.Should().Be("6223001234567");
        expiry.Should().BeNull();
    }
}
