using System.Net;
using FluentAssertions;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Moq;
using Nawakes.API.Controllers;
using Nawakes.Application.Search.Commands.ParseMultimodal;
using Nawakes.Application.Search.Commands.ParsePrescriptionImage;
using Xunit;

namespace Nawakes.Application.Tests.Search;

public sealed class PrescriptionOcrAdversarialTests
{
    private readonly Mock<ISender> _mediatorMock;
    private readonly SearchController _controller;

    public PrescriptionOcrAdversarialTests()
    {
        _mediatorMock = new Mock<ISender>();
        _controller = new SearchController(_mediatorMock.Object);
    }

    private static IFormFile CreateMockFormFile(byte[] content, string fileName, string? contentType)
    {
        var stream = new MemoryStream(content);
        return new FormFile(stream, 0, content.Length, "file", fileName)
        {
            Headers = new HeaderDictionary(),
            ContentType = contentType!
        };
    }

    private static string? GetMessage(object? value)
    {
        if (value is null) return null;
        var prop = value.GetType().GetProperty("Message");
        return prop?.GetValue(value) as string;
    }

    // ── Challenge 1: Empty file / 0-byte file ──────────────────────────────────

    [Fact]
    public async Task Challenge_NullFile_Returns400WithArabicErrorMessage()
    {
        // Act
        var result = await _controller.ParsePrescriptionImage(null!, null, CancellationToken.None);

        // Assert
        var badRequest = result.Result.Should().BeOfType<BadRequestObjectResult>().Subject;
        badRequest.StatusCode.Should().Be(StatusCodes.Status400BadRequest);

        var message = GetMessage(badRequest.Value);
        message.Should().Be("الملف غير موجود أو فارغ.");
    }

    [Fact]
    public async Task Challenge_ZeroByteFile_Returns400WithArabicErrorMessage()
    {
        // Arrange: 0-byte file
        var file = CreateMockFormFile([], "prescription.jpg", "image/jpeg");

        // Act
        var result = await _controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        // Assert
        var badRequest = result.Result.Should().BeOfType<BadRequestObjectResult>().Subject;
        badRequest.StatusCode.Should().Be(StatusCodes.Status400BadRequest);

        var message = GetMessage(badRequest.Value);
        message.Should().Be("الملف غير موجود أو فارغ.");
    }

    // ── Challenge 2: Oversized file (> 10MB) ───────────────────────────────────

    [Fact]
    public async Task Challenge_OversizedFile_GreaterThan10MB_Returns400WithArabicErrorMessage()
    {
        // Arrange: 10MB + 1 byte
        var largeStream = new MemoryStream();
        largeStream.SetLength(10 * 1024 * 1024 + 1);
        var file = new FormFile(largeStream, 0, largeStream.Length, "file", "rx_huge.jpg")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/jpeg"
        };

        // Act
        var result = await _controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        // Assert
        var badRequest = result.Result.Should().BeOfType<BadRequestObjectResult>().Subject;
        badRequest.StatusCode.Should().Be(StatusCodes.Status400BadRequest);

        var message = GetMessage(badRequest.Value);
        message.Should().Be("الحد الأقصى لحجم صورة الروشتة هو 10 ميجابايت.");
    }

    [Fact]
    public async Task Challenge_SignificantlyOversizedFile_15MB_Returns400WithArabicErrorMessage()
    {
        // Arrange: 15MB
        var largeStream = new MemoryStream();
        largeStream.SetLength(15 * 1024 * 1024);
        var file = new FormFile(largeStream, 0, largeStream.Length, "file", "giant_rx.png")
        {
            Headers = new HeaderDictionary(),
            ContentType = "image/png"
        };

        // Act
        var result = await _controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        // Assert
        var badRequest = result.Result.Should().BeOfType<BadRequestObjectResult>().Subject;
        badRequest.StatusCode.Should().Be(StatusCodes.Status400BadRequest);

        var message = GetMessage(badRequest.Value);
        message.Should().Be("الحد الأقصى لحجم صورة الروشتة هو 10 ميجابايت.");
    }

    // ── Challenge 3: Invalid file extension / MIME type ─────────────────────────

    [Theory]
    [InlineData("payload.exe", "application/x-msdownload")]
    [InlineData("prescription.txt", "text/plain")]
    [InlineData("document.pdf", "application/pdf")]
    [InlineData("script.sh", "application/x-sh")]
    [InlineData("exploit.bin", "application/octet-stream")]
    public async Task Challenge_InvalidExtensionAndMime_Returns400WithArabicErrorMessage(string fileName, string mime)
    {
        // Arrange
        var file = CreateMockFormFile([0x01, 0x02, 0x03], fileName, mime);

        // Act
        var result = await _controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        // Assert
        var badRequest = result.Result.Should().BeOfType<BadRequestObjectResult>().Subject;
        badRequest.StatusCode.Should().Be(StatusCodes.Status400BadRequest);

        var message = GetMessage(badRequest.Value);
        message.Should().Be("نوع الملف غير مدعوم. يرجى رفع صورة روشتة (PNG, JPG, WEBP).");
    }

    // ── Challenge 4: Valid image formats (.jpg, .jpeg, .png, .webp) ───────────

    [Theory]
    [InlineData("rx.jpg", "image/jpeg")]
    [InlineData("rx.jpeg", "image/jpeg")]
    [InlineData("rx.png", "image/png")]
    [InlineData("rx.webp", "image/webp")]
    [InlineData("RX_UPPER.JPG", "image/jpeg")]
    [InlineData("RX_UPPER.PNG", "image/png")]
    [InlineData("RX_UPPER.WEBP", "image/webp")]
    public async Task Challenge_ValidImageFormats_Returns200WithParsedMedicationDto(string fileName, string mime)
    {
        // Arrange
        var fakeBytes = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46 };
        var file = CreateMockFormFile(fakeBytes, fileName, mime);

        var expectedDto = new ParsedMedicationDto(
            ResolvedName: "Concor",
            Strength: "5mg",
            DosageForm: "Tablet",
            Confidence: 0.96m,
            RequiresDisambiguation: false,
            Candidates: [new ParsedCandidateDto("Concor", "5mg", "Tablet", 0.96m, 1, "Bisoprolol Fumarate")],
            ActiveIngredient: "Bisoprolol Fumarate",
            IsSuccess: true);

        _mediatorMock
            .Setup(m => m.Send(It.Is<ParsePrescriptionImageCommand>(cmd =>
                cmd.ImageBytes.Length == fakeBytes.Length &&
                cmd.ContentType == mime), It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedDto);

        // Act
        var result = await _controller.ParsePrescriptionImage(file, "hint", CancellationToken.None);

        // Assert
        var okResult = result.Result.Should().BeOfType<OkObjectResult>().Subject;
        okResult.StatusCode.Should().Be(StatusCodes.Status200OK);

        var returnedDto = okResult.Value.Should().BeAssignableTo<ParsedMedicationDto>().Subject;
        returnedDto.ResolvedName.Should().Be("Concor");
        returnedDto.ActiveIngredient.Should().Be("Bisoprolol Fumarate");
        returnedDto.IsSuccess.Should().BeTrue();
    }

    // ── Challenge 5: Ephemeral memory verification ────────────────────────────

    [Fact]
    public async Task Challenge_EphemeralMemoryProcessing_NoFilesWrittenToDisk()
    {
        // Arrange: record all files in wwwroot/uploads before request
        var uploadsDir = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads");
        var beforeFiles = Directory.Exists(uploadsDir)
            ? Directory.GetFiles(uploadsDir, "*.*", SearchOption.AllDirectories)
            : [];

        var sampleBytes = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };
        var file = CreateMockFormFile(sampleBytes, "prescription_ephemeral.png", "image/png");

        var expectedDto = new ParsedMedicationDto("Augmentin", "1g", "Tablet", 0.95m, false, []);
        _mediatorMock
            .Setup(m => m.Send(It.IsAny<ParsePrescriptionImageCommand>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedDto);

        // Act: execute valid parsing request
        var result = await _controller.ParsePrescriptionImage(file, null, CancellationToken.None);

        // Assert: response is 200
        result.Result.Should().BeOfType<OkObjectResult>();

        // Check file system: no files added to wwwroot/uploads
        var afterFiles = Directory.Exists(uploadsDir)
            ? Directory.GetFiles(uploadsDir, "*.*", SearchOption.AllDirectories)
            : [];

        afterFiles.Should().BeEquivalentTo(beforeFiles, "ephemeral processing must not persist uploaded prescription images to disk");
    }
}
