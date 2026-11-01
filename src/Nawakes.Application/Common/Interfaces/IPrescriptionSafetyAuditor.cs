using System.Text.Json.Serialization;
using Nawakes.Application.Search.Commands.ParseMultimodal;

namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Clinical severity level for prescription safety warnings.
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum SafetyAlertSeverity
{
    Critical,
    Warning,
    Nominal
}

/// <summary>
/// Input medication model for safety and interaction auditing.
/// </summary>
public sealed record SafetyMedicationInput(
    string TradeName,
    string? ActiveIngredient = null,
    string? Strength = null,
    string? RawSig = null);

/// <summary>
/// Safety alert representing a drug-drug interaction, allergy conflict, or clinical timing advisory.
/// </summary>
public sealed record SafetyAlertDto
{
    public string Id { get; init; }
    public SafetyAlertSeverity Severity { get; init; }
    public string Category { get; init; }
    public string Title { get; init; }
    public string Description { get; init; }
    public IReadOnlyList<string> InvolvedDrugs { get; init; }
    public string Recommendation { get; init; }

    public SafetyAlertDto(
        string Id,
        SafetyAlertSeverity Severity,
        string Category,
        string Title,
        string Description,
        IReadOnlyList<string> InvolvedDrugs,
        string? Recommendation = null)
    {
        this.Id = Id;
        this.Severity = Severity;
        this.Category = Category;
        this.Title = Title;
        this.Description = Description;
        this.InvolvedDrugs = InvolvedDrugs;
        this.Recommendation = !string.IsNullOrWhiteSpace(Recommendation) ? Recommendation : Description;
    }

    public string AlertCode => Id;
    public string Message => Title;
    public string RecommendationText => Recommendation;
    public IReadOnlyList<string> InteractingSubstances => InvolvedDrugs;
}

/// <summary>
/// Clinical safety auditor for prescriptions. Evaluates drug-drug interactions,
/// patient allergy cross-reactivities, and clinical timing rules.
/// </summary>
public interface IPrescriptionSafetyAuditor
{
    /// <summary>
    /// Audits candidate medications in a prescription for contraindications, interactions, and allergies.
    /// </summary>
    IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
        IReadOnlyList<ParsedCandidateDto> candidates,
        IReadOnlyList<string>? patientAllergies = null);

    /// <summary>
    /// Audits input medications in a prescription for contraindications, interactions, and allergies.
    /// </summary>
    IReadOnlyList<SafetyAlertDto> AuditPrescriptionSafety(
        IReadOnlyList<SafetyMedicationInput> medications,
        IReadOnlyList<string>? patientAllergies = null);

    /// <summary>
    /// Async overload for auditing medications in a prescription.
    /// </summary>
    Task<IReadOnlyList<SafetyAlertDto>> AuditPrescriptionSafetyAsync(
        IReadOnlyList<SafetyMedicationInput> medications,
        IReadOnlyList<string>? patientAllergies = null,
        CancellationToken cancellationToken = default);
}
