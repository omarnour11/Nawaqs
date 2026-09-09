using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Queries.GetSalesLedger;

/// <summary>
/// سجل المبيعات — every order that left the pharmacy (completed reservations),
/// newest first, with daily aggregates for monitoring.
/// </summary>
public sealed record GetSalesLedgerQuery(int Take = 100) : IRequest<SalesLedgerDto>;

public sealed record SalesLedgerEntryDto(
    Guid ReservationId,
    Guid? ShortageRequestId,
    string MedicationName,
    decimal Price,
    int Quantity,
    string PatientContact,
    DateTime CompletedAt,
    string ReservationCode);

public sealed record SalesLedgerDto(
    int TotalCompleted,
    decimal TotalRevenue,
    int TodayCount,
    IReadOnlyList<SalesLedgerEntryDto> Entries);

public sealed class GetSalesLedgerQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IUserDirectory users)
    : IRequestHandler<GetSalesLedgerQuery, SalesLedgerDto>
{
    public async Task<SalesLedgerDto> Handle(GetSalesLedgerQuery request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken)
            ?? throw new Nawakes.Application.Common.Exceptions.NotFoundException(
                nameof(Domain.Entities.Pharmacy), currentUser.UserId);

        var today = DateTime.UtcNow.Date;

        var entries = await context.Reservations
            .AsNoTracking()
            .Include(r => r.InventoryItem)
            .Where(r => r.PharmacyId == pharmacy.Id &&
                        r.Status == ReservationStatus.Completed)
            .OrderByDescending(r => r.CompletedAt)
            .Take(request.Take)
            .Select(r => new
            {
                r.Id,
                r.UserId,
                r.InventoryItem.MedicationName,
                r.InventoryItem.Price,
                r.InventoryItem.Quantity,
                r.CompletedAt,
                r.ReservationCode
            })
            .ToListAsync(cancellationToken);

        // Resolve patient contact via IUserDirectory (Application layer never sees Identity tables)
        var contacts = await users.GetContactAsync(
            entries.Select(e => e.UserId).Distinct().ToList(), cancellationToken);

        var dtos = entries.Select(e => new SalesLedgerEntryDto(
            e.Id,
            ShortageRequestId: null,
            e.MedicationName,
            e.Price,
            e.Quantity,
            contacts.GetValueOrDefault(e.UserId, "—"),
            e.CompletedAt ?? DateTime.UtcNow,
            e.ReservationCode)).ToList();

        var totalRevenue = dtos.Sum(d => d.Price);
        var todayCount = dtos.Count(d => d.CompletedAt >= today);

        return new SalesLedgerDto(dtos.Count, totalRevenue, todayCount, dtos);
    }
}
