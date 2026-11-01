using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Queries.GetActiveReservations;

public sealed record GetActiveReservationsQuery : IRequest<IReadOnlyList<PharmacyReservationDto>>;

/// <summary>
/// Returns active (and recently expired/completed) reservations for the calling
/// pharmacy owner's pharmacy. Patient names are anonymized, but clinical background
/// (chronic diseases, allergies, and consented active medications) is included
/// for pharmacist safety verification.
/// </summary>
public sealed class GetActiveReservationsQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IUserDirectory userDirectory)
    : IRequestHandler<GetActiveReservationsQuery, IReadOnlyList<PharmacyReservationDto>>
{
    public async Task<IReadOnlyList<PharmacyReservationDto>> Handle(
        GetActiveReservationsQuery request,
        CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException("Pharmacy", currentUser.UserId);

        var cutoff = DateTime.UtcNow.AddHours(-24);

        var reservations = await context.Reservations
            .AsNoTracking()
            .Include(r => r.InventoryItem)
            .Where(r => r.PharmacyId == pharmacy.Id &&
                        ((r.Status == ReservationStatus.Active && r.ExpiresAt > DateTime.UtcNow) ||
                         r.Status == ReservationStatus.Ready))
            .OrderByDescending(r => r.ExpiresAt)
            .ToListAsync(cancellationToken);

        var userIds = reservations.Select(r => r.UserId).Distinct().ToList();

        var summaries = await userDirectory.GetClinicalSummariesAsync(userIds, cancellationToken);

        var patientMeds = await context.PatientMedications
            .AsNoTracking()
            .Where(m => userIds.Contains(m.UserId) && m.IsActive)
            .ToListAsync(cancellationToken);

        var medsByUser = patientMeds.GroupBy(m => m.UserId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<string>)g.Select(m => $"{m.MedicationName} {(m.Strength ?? string.Empty)}".Trim()).ToList());

        var result = new List<PharmacyReservationDto>();
        foreach (var r in reservations)
        {
            summaries.TryGetValue(r.UserId, out var patient);
            var notes = patient?.MedicalHistoryNotes ?? string.Empty;

            string? chronicConditions = ExtractSection(notes, "أمراض:");
            string? allergies = ExtractSection(notes, "حساسية:");
            var allowMeds = patient?.AllowPharmacistViewActiveMedications ?? true;
            IReadOnlyList<string>? activeMeds = allowMeds ? medsByUser.GetValueOrDefault(r.UserId) : null;

            result.Add(new PharmacyReservationDto(
                r.Id,
                $"مريض #{r.UserId.ToString().Substring(r.UserId.ToString().Length - 4).ToUpper()}",
                r.InventoryItem.MedicationName,
                r.Status.ToString(),
                DateTime.SpecifyKind(r.ExpiresAt, DateTimeKind.Utc),
                DateTime.SpecifyKind(r.CreatedAt, DateTimeKind.Utc),
                r.ReservationCode,
                chronicConditions,
                allergies,
                allowMeds,
                activeMeds,
                r.ClinicalContraindicationReason,
                r.RecommendedAlternativeMedication));
        }

        return result;
    }

    private static string? ExtractSection(string notes, string prefix)
    {
        if (string.IsNullOrWhiteSpace(notes)) return null;
        foreach (var line in notes.Split('\n'))
        {
            var trimmed = line.Trim();
            if (trimmed.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            {
                var val = trimmed.Substring(prefix.Length).Trim();
                return string.IsNullOrWhiteSpace(val) ? null : val;
            }
        }
        return null;
    }
}
