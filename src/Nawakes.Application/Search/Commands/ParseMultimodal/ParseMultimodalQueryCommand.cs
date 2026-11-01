using MediatR;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Search.Commands.ParseMultimodal;

public sealed record ParseMultimodalQueryCommand(
    string RawText,
    string InputType,
    string? ImageBase64 = null) : IRequest<ParsedMedicationDto>;

public sealed record ParsePrescriptionImageCommand(
    byte[] ImageBytes,
    string ContentType,
    string? OcrHintText = null,
    IReadOnlyList<string>? PatientAllergies = null) : IRequest<ParsedMedicationDto>;

public sealed record ParsedMedicationDto(
    string ResolvedName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    bool RequiresDisambiguation,
    IReadOnlyList<ParsedCandidateDto> Candidates,
    string? ActiveIngredient = null,
    bool IsSuccess = true,
    string? ErrorCode = null,
    string? ErrorMessage = null,
    string? RawSig = null,
    string? ArabicSig = null,
    decimal? PriceEgp = null,
    IReadOnlyList<SafetyAlertDto>? SafetyAlerts = null);

public sealed record ParsedCandidateDto(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    int Quantity = 1,
    string? ActiveIngredient = null,
    bool RequiresDisambiguation = false,
    IReadOnlyList<ParsedCandidateDto>? Alternatives = null,
    string? RawSig = null,
    string? ArabicSig = null,
    decimal? PriceEgp = null);

