using MediatR;

namespace Nawakes.Application.Search.Commands.ParseMultimodal;

public sealed record ParseMultimodalQueryCommand(
    string RawText,
    string InputType,
    string? ImageBase64 = null) : IRequest<ParsedMedicationDto>;

public sealed record ParsePrescriptionImageCommand(
    byte[] ImageBytes,
    string ContentType,
    string? OcrHintText = null) : IRequest<ParsedMedicationDto>;

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
    string? ErrorMessage = null);

public sealed record ParsedCandidateDto(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    int Quantity = 1,
    string? ActiveIngredient = null,
    bool RequiresDisambiguation = false,
    IReadOnlyList<ParsedCandidateDto>? Alternatives = null);

