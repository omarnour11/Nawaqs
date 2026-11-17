using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Common;

namespace Nawakes.Application.Reservations.Queries.CheckReservationSafety;

public sealed record CheckReservationSafetyQuery(
    Guid? InventoryItemId = null,
    string? MedicationName = null) : IRequest<ReservationSafetyCheckResultDto>;

public sealed record ReservationSafetyCheckResultDto(
    string TargetMedicationName,
    string? TargetActiveIngredient,
    bool HasCriticalAlerts,
    bool HasWarnings,
    IReadOnlyList<string> DuplicateActiveIngredientMedications,
    IReadOnlyList<SafetyAlertDto> Alerts);

/// <summary>
/// Cross-checks a target medication against the calling patient's active regimen (PatientMedications),
/// EDA active ingredients (EgyptianDrugRegistry), KnownAllergies, and ChronicConditions before checkout.
/// </summary>
public sealed class CheckReservationSafetyQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IUserDirectory userDirectory,
    IPrescriptionSafetyAuditor safetyAuditor)
    : IRequestHandler<CheckReservationSafetyQuery, ReservationSafetyCheckResultDto>
{
    public async Task<ReservationSafetyCheckResultDto> Handle(
        CheckReservationSafetyQuery request,
        CancellationToken cancellationToken)
    {
        var medName = request.MedicationName?.Trim() ?? string.Empty;

        if (request.InventoryItemId.HasValue && request.InventoryItemId.Value != Guid.Empty)
        {
            var item = await context.InventoryItems
                .AsNoTracking()
                .FirstOrDefaultAsync(i => i.Id == request.InventoryItemId.Value, cancellationToken);
            if (item is not null)
            {
                medName = item.MedicationName;
            }
        }

        if (string.IsNullOrWhiteSpace(medName))
        {
            return new ReservationSafetyCheckResultDto(
                string.Empty,
                null,
                false,
                false,
                [],
                []);
        }

        // 1. Load patient's active medications from medical profile
        var activePatientMeds = await context.PatientMedications
            .AsNoTracking()
            .Where(m => m.UserId == currentUser.UserId && m.IsActive)
            .ToListAsync(cancellationToken);

        // 2. Load patient's clinical summary (allergies + chronic conditions)
        var clinicalMap = await userDirectory.GetClinicalSummariesAsync([currentUser.UserId], cancellationToken);
        clinicalMap.TryGetValue(currentUser.UserId, out var clinicalSummary);

        var allergies = ParseCommaList(clinicalSummary?.KnownAllergies);
        var chronicConditions = ParseCommaList(clinicalSummary?.ChronicConditions);

        // 3. Resolve ActiveIngredient from EgyptianDrugRegistry for target medication and active regimen
        var allMedNames = activePatientMeds
            .Select(m => m.MedicationName)
            .Append(medName)
            .Select(DrugNameNormalizer.NormalizeName)
            .Where(n => !string.IsNullOrWhiteSpace(n))
            .Distinct()
            .ToList();

        var edaEntries = await context.EgyptianDrugRegistry
            .AsNoTracking()
            .Where(d => allMedNames.Contains(d.TradeNameNormalized) ||
                        (d.CommercialNameArNormalized != null && allMedNames.Contains(d.CommercialNameArNormalized)))
            .ToListAsync(cancellationToken);

        string? ResolveActiveIngredient(string rawMedicationName)
        {
            var norm = DrugNameNormalizer.NormalizeName(rawMedicationName);
            var firstToken = norm.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? norm;

            var match = edaEntries.FirstOrDefault(d =>
                d.TradeNameNormalized.Equals(norm, StringComparison.OrdinalIgnoreCase) ||
                (d.CommercialNameArNormalized != null && d.CommercialNameArNormalized.Equals(norm, StringComparison.OrdinalIgnoreCase)) ||
                (firstToken.Length >= 3 && d.TradeNameNormalized.StartsWith(firstToken, StringComparison.OrdinalIgnoreCase)));

            return match?.ActiveIngredient;
        }

        var targetIngredient = ResolveActiveIngredient(medName);

        var inputs = new List<SafetyMedicationInput>
        {
            new(medName, targetIngredient)
        };

        var duplicateMeds = new List<string>();
        foreach (var pm in activePatientMeds)
        {
            var pmIngredient = ResolveActiveIngredient(pm.MedicationName);
            inputs.Add(new SafetyMedicationInput(pm.MedicationName, pmIngredient, pm.Strength, pm.DoseSchedule));

            if (!string.IsNullOrWhiteSpace(targetIngredient) &&
                !string.IsNullOrWhiteSpace(pmIngredient) &&
                targetIngredient.Equals(pmIngredient, StringComparison.OrdinalIgnoreCase) &&
                !pm.MedicationName.Equals(medName, StringComparison.OrdinalIgnoreCase))
            {
                duplicateMeds.Add(pm.MedicationName);
            }
        }

        var alerts = safetyAuditor.AuditPrescriptionSafety(inputs, allergies, chronicConditions);
        var alertList = alerts.ToList();

        if (clinicalSummary?.IsPregnant == true &&
            Nawakes.Application.Common.Security.ClinicalSafetyRules.IsContraindicatedInPregnancy(medName, targetIngredient))
        {
            alertList.Insert(0, new SafetyAlertDto(
                Id: "PREG_CONTRAINDICATION",
                Severity: SafetyAlertSeverity.Critical,
                Category: "PregnancyContraindication",
                Title: "تحذير خطير: تعارض مع الحمل",
                Description: $"دواء {medName} محظور تماماً أثناء الحمل لتسببه في تشوهات جنينية وأضرار جسيمة للجنين.",
                InvolvedDrugs: [medName],
                Recommendation: "يحظر تناول هذا الدواء أثناء الحمل ويجب استشارة الطبيب لوصف بديل آمن فوراً."));
        }

        if (Nawakes.Application.Common.Security.ClinicalSafetyRules.RequiresInPersonAllergyTest(medName, targetIngredient))
        {
            alertList.Add(new SafetyAlertDto(
                Id: "ALLERGY_TEST_MANDATORY",
                Severity: SafetyAlertSeverity.Warning,
                Category: "AllergyTestMandatory",
                Title: "يلزم كشف حساسية مسبق بالصيدلية",
                Description: $"دواء {medName} يتطلب إجراء اختبار حساسية بالجلد داخل الصيدلية تحت إشراف صيدلي معتمد تجنباً للصدمة التحسسية. خدمة التوصيل المنزلي غير مفعلة لهذا الدواء.",
                InvolvedDrugs: [medName],
                Recommendation: "يجب زيارة الصيدلية شخصياً لإجراء اختبار الحساسية واستلام الدواء مباشرة."));
        }

        var hasCritical = alertList.Any(a => a.Severity == SafetyAlertSeverity.Critical);
        var hasWarnings = alertList.Any(a => a.Severity == SafetyAlertSeverity.Warning) || duplicateMeds.Count > 0;

        return new ReservationSafetyCheckResultDto(
            TargetMedicationName: medName,
            TargetActiveIngredient: targetIngredient,
            HasCriticalAlerts: hasCritical,
            HasWarnings: hasWarnings,
            DuplicateActiveIngredientMedications: duplicateMeds,
            Alerts: alertList);
    }

    private static IReadOnlyList<string> ParseCommaList(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
            return [];

        return raw
            .Split([',', '،', ';', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .ToList();
    }
}
