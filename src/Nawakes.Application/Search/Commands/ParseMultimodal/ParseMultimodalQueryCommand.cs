using MediatR;

namespace Nawakes.Application.Search.Commands.ParseMultimodal;

public sealed record ParseMultimodalQueryCommand(
    string RawText,
    string InputType) : IRequest<ParsedMedicationDto>;

public sealed record ParsedMedicationDto(
    string ResolvedName,
    string? Strength,
    string? DosageForm,
    decimal Confidence,
    bool RequiresDisambiguation,
    IReadOnlyList<ParsedCandidateDto> Candidates);

public sealed record ParsedCandidateDto(
    string TradeName,
    string? Strength,
    string? DosageForm,
    decimal Confidence);
