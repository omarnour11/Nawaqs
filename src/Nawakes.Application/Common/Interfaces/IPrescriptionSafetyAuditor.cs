using Nawakes.Application.Search.Commands.ParseMultimodal;

namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Clinical severity level for prescription safety warnings.
/// </summary>
public enum SafetyAlertSeverity
{
    Critical,
    Warning,
    Nominal
}

/// <summary>
/// Safety alert representing a drug-drug interaction, allergy conflict, or clinical timing advisory.
/// </summary>
public sealed record SafetyAlertDto(
    string Id,
    SafetyAlertSeverity Severity,
    string Category,
    string Title,
    string Description,
    IReadOnlyList<string> InvolvedDrugs);

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
}

