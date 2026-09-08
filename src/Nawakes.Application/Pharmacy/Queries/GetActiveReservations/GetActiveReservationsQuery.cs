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
/// pharmacy owner's pharmacy. Expired reservations are included for 24 hours, then excluded.
/// Patient names are anonymized.
/// </summary>
public sealed class GetActiveReservationsQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
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
                        (r.Status == ReservationStatus.Active ||
                         r.UpdatedAt >= cutoff))
            .OrderByDescending(r => r.Status == ReservationStatus.Active)
            .ThenByDescending(r => r.ExpiresAt)
            .Select(r => new PharmacyReservationDto(
                r.Id,
                $"Patient #{r.UserId.ToString().Substring(r.UserId.ToString().Length - 4).ToUpper()}",
                r.InventoryItem.MedicationName,
                r.Status.ToString(),
                r.ExpiresAt,
                r.CreatedAt,
                r.ReservationCode))
            .ToListAsync(cancellationToken);

        return reservations;
    }
}
