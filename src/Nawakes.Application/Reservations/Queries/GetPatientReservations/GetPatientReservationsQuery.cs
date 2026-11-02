using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Reservations.Queries.GetPatientReservations;

public sealed record GetPatientReservationsQuery : IRequest<IReadOnlyList<ReservationDto>>;

public sealed class GetPatientReservationsQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetPatientReservationsQuery, IReadOnlyList<ReservationDto>>
{
    public async Task<IReadOnlyList<ReservationDto>> Handle(
        GetPatientReservationsQuery request,
        CancellationToken cancellationToken)
    {
        var reservations = await context.Reservations
            .AsNoTracking()
            .Include(r => r.InventoryItem)
            .ThenInclude(i => i.Pharmacy)
            .Where(r => r.UserId == currentUser.UserId)
            .OrderByDescending(r => r.CreatedAt)
            .ToListAsync(cancellationToken);

        return reservations.Select(r =>
        {
            var crop = r.PrescriptionCropUrl;
            if (string.IsNullOrWhiteSpace(crop) && r.PrescriptionCropBytes is { Length: > 0 })
            {
                crop = $"data:image/jpeg;base64,{Convert.ToBase64String(r.PrescriptionCropBytes)}";
            }

            return new ReservationDto(
                r.Id,
                r.InventoryItemId,
                r.InventoryItem.PharmacyId,
                r.InventoryItem.Pharmacy.Name,
                r.InventoryItem.Pharmacy.Phone,
                r.InventoryItem.MedicationName,
                r.Status.ToString(),
                DateTime.SpecifyKind(r.ExpiresAt, DateTimeKind.Utc),
                DateTime.SpecifyKind(r.CreatedAt, DateTimeKind.Utc),
                r.ReservationCode,
                r.ClinicalContraindicationReason,
                r.RecommendedAlternativeMedication,
                r.RecommendedAlternativeItemId,
                crop
            );
        }).ToList();
    }
}
