using Xunit;
using FluentAssertions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.NLP;

namespace Nawakes.Application.Tests.Reservations;

public sealed class ClinicalSafetyShieldTests
{
    private readonly PrescriptionSafetyAuditor _auditor = new();

    [Fact]
    public void AuditPrescriptionSafety_WhenDifferentTradeNamesShareActiveIngredient_ShouldReturnDuplicateIngredientWarning()
    {
        // Arrange: Concor 5mg and Bisonocor 5mg both contain Bisoprolol Fumarate
        var medications = new List<SafetyMedicationInput>
        {
            new("Concor 5mg", "Bisoprolol Fumarate", "5mg"),
            new("Bisonocor 5mg", "Bisoprolol Fumarate", "5mg")
        };

        // Act
        var alerts = _auditor.AuditPrescriptionSafety(medications);

        // Assert
        alerts.Should().Contain(a =>
            a.Id == "DUPLICATE_ACTIVE_INGREDIENT" &&
            a.Severity == SafetyAlertSeverity.Warning &&
            a.InvolvedDrugs.Contains("Concor 5mg") &&
            a.InvolvedDrugs.Contains("Bisonocor 5mg"));
    }

    [Fact]
    public void AuditPrescriptionSafety_WhenRenalPatientTakesNsaid_ShouldReturnCriticalChronicAlert()
    {
        // Arrange
        var medications = new List<SafetyMedicationInput>
        {
            new("Cataflam 50mg", "Diclofenac Potassium", "50mg")
        };
        var chronicConditions = new List<string> { "قصور كلوي مزمن (Renal Impairment)" };

        // Act
        var alerts = _auditor.AuditPrescriptionSafety(medications, patientAllergies: null, chronicConditions: chronicConditions);

        // Assert
        alerts.Should().Contain(a =>
            a.Id == "CHRONIC_RENAL_NSAID" &&
            a.Severity == SafetyAlertSeverity.Critical);
    }
}
