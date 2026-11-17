using FluentAssertions;
using Nawakes.Application.Common.Security;
using Xunit;

namespace Nawakes.Application.Tests.Safety;

public sealed class ClinicalSafetyRulesTests
{
    [Theory]
    [InlineData("Penicillin G 1.2M vial", null, true)]
    [InlineData("حقن بنسلين طويل المفعول", null, true)]
    [InlineData("Ceftriaxone 1g vial", null, true)]
    [InlineData("روسيفين حقن", "Ceftriaxone", true)]
    [InlineData("Unasyn 1.5g IM/IV", "Ampicillin/Sulbactam", true)]
    [InlineData("Ferrosac ampoules", "Iron Sucrose", true)]
    [InlineData("Panadol Extra 500mg", "Paracetamol", false)]
    [InlineData("Cataflam 50mg", "Diclofenac Potassium", false)]
    [InlineData("Concor 5mg", "Bisoprolol", false)]
    public void RequiresInPersonAllergyTest_ShouldAccuratelyIdentifyHighRiskInjectables(
        string medicationName, string? activeIngredient, bool expected)
    {
        var result = ClinicalSafetyRules.RequiresInPersonAllergyTest(medicationName, activeIngredient);
        result.Should().Be(expected);
    }

    [Theory]
    [InlineData("Roaccutane 20mg", "Isotretinoin", true)]
    [InlineData("كيوراكني 10 مجم", "Isotretinoin", true)]
    [InlineData("Marevan 3mg", "Warfarin", true)]
    [InlineData("ماريفان أقراص", "Warfarin", true)]
    [InlineData("Unitrexate 2.5mg", "Methotrexate", true)]
    [InlineData("Lipitor 20mg", "Atorvastatin", true)]
    [InlineData("Crestor 10mg", "Rosuvastatin", true)]
    [InlineData("Capoten 25mg", "Captopril", true)]
    [InlineData("Tritace 5mg", "Ramipril", true)]
    [InlineData("Diovan 160mg", "Valsartan", true)]
    [InlineData("Cytotec 200mcg", "Misoprostol", true)]
    [InlineData("Propecia 1mg", "Finasteride", true)]
    [InlineData("Paracetamol 500mg", "Paracetamol", false)]
    [InlineData("Augmentin 1g", "Amoxicillin/Clavulanate", false)]
    [InlineData("Erythrocin 500mg", "Erythromycin", false)]
    public void IsContraindicatedInPregnancy_ShouldFlagTeratogenicDrugs(
        string medicationName, string? activeIngredient, bool expected)
    {
        var result = ClinicalSafetyRules.IsContraindicatedInPregnancy(medicationName, activeIngredient);
        result.Should().Be(expected);
    }
}
