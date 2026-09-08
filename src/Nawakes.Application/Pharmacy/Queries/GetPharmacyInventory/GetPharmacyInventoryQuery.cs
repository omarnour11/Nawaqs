using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Pharmacy.Queries.GetPharmacyInventory;

public sealed record PharmacyInventoryItemDto(
    Guid Id,
    string MedicationName,
    decimal Price,
    string Status,
    DateTime CreatedAt,
    DateTime? LastUpdatedAt);

public sealed record GetPharmacyInventoryQuery : IRequest<IReadOnlyList<PharmacyInventoryItemDto>>;

public sealed class GetPharmacyInventoryQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetPharmacyInventoryQuery, IReadOnlyList<PharmacyInventoryItemDto>>
{
    public async Task<IReadOnlyList<PharmacyInventoryItemDto>> Handle(GetPharmacyInventoryQuery request, CancellationToken cancellationToken)
    {
        var pharmacyId = await context.Pharmacies
            .Where(p => p.OwnerId == currentUser.UserId)
            .Select(p => p.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (pharmacyId == Guid.Empty)
            return [];

        var inventory = await context.InventoryItems
            .Where(i => i.PharmacyId == pharmacyId)
            .OrderBy(i => i.MedicationName)
            .Select(i => new PharmacyInventoryItemDto(
                i.Id,
                i.MedicationName,
                i.Price,
                i.Status.ToString(),
                i.CreatedAt,
                i.UpdatedAt
            ))
            .ToListAsync(cancellationToken);

        return inventory;
    }
}
