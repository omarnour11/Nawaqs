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

        return reservations.Select(r => new ReservationDto(
            r.Id,
            r.InventoryItemId,
            r.InventoryItem.PharmacyId,
            r.InventoryItem.Pharmacy.Name,
            r.InventoryItem.MedicationName,
            r.Status.ToString(),
            r.ExpiresAt,
            r.CreatedAt,
            r.ReservationCode
        )).ToList();
    }
}
