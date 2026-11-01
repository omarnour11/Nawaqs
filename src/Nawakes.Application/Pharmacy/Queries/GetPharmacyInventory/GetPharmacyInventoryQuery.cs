using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Pharmacy.Queries.GetPharmacyInventory;

/// <summary>
/// Rich DTO returned to the pharmacy owner — includes Quantity and PatientNote
/// so the Flutter UI can display accurate stock levels without a second request.
/// Status is mapped from the enum value in-memory to avoid EF Core translation
/// failures with non-trivial enum-to-string conversions in SQL projections.
/// </summary>
public sealed record PharmacyInventoryItemDto(
    Guid Id,
    string MedicationName,
    decimal Price,
    int Quantity,
    string Status,
    string? PatientNote,
    DateTime? ExpiryDate,
    DateTime CreatedAt,
    DateTime? LastUpdatedAt);

/// <summary>
/// Result envelope for paged inventory queries.
/// </summary>
public sealed record PagedInventoryResult(
    IReadOnlyList<PharmacyInventoryItemDto> Items,
    int TotalCount,
    int PageNumber,
    int PageSize,
    int TotalPages);

/// <summary>
/// Returns a paginated, filtered, searchable view of the caller's pharmacy inventory.
/// Never materialises the full dataset — always uses OFFSET-FETCH at the database level.
/// </summary>
public sealed record GetPharmacyInventoryQuery(
    int PageNumber = 1,
    int PageSize = 50,
    string? Search = null,
    string? StatusFilter = null)
    : IRequest<PagedInventoryResult>;

public sealed class GetPharmacyInventoryQueryValidator : AbstractValidator<GetPharmacyInventoryQuery>
{
    public GetPharmacyInventoryQueryValidator()
    {
        RuleFor(x => x.PageNumber).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 500);
        RuleFor(x => x.Search).MaximumLength(300).When(x => x.Search is not null);
    }
}

public sealed class GetPharmacyInventoryQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetPharmacyInventoryQuery, PagedInventoryResult>
{
    public async Task<PagedInventoryResult> Handle(
        GetPharmacyInventoryQuery request, CancellationToken cancellationToken)
    {
        var pharmacyId = await context.Pharmacies
            .AsNoTracking()
            .Where(p => p.OwnerId == currentUser.UserId)
            .Select(p => p.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (pharmacyId == Guid.Empty)
            return new PagedInventoryResult([], 0, 1, request.PageSize, 0);

        var query = context.InventoryItems
            .AsNoTracking()
            .Where(i => i.PharmacyId == pharmacyId);

        // Optional search filter applied server-side
        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var prefix = request.Search.Trim().ToUpperInvariant();
            query = query.Where(i => i.MedicationNameNormalized.Contains(prefix));
        }

        // Optional status filter
        if (!string.IsNullOrWhiteSpace(request.StatusFilter) &&
            Enum.TryParse<Domain.Enums.InventoryStatus>(request.StatusFilter, ignoreCase: true, out var statusEnum))
        {
            query = query.Where(i => i.Status == statusEnum);
        }

        var totalCount = await query.CountAsync(cancellationToken);

        // Project only required columns — no navigation joins, no tracking
        var rawItems = await query
            .OrderByDescending(i => i.CreatedAt)
            .Skip((request.PageNumber - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(i => new
            {
                i.Id,
                i.MedicationName,
                i.Price,
                i.Quantity,
                i.Status,
                i.PatientNote,
                i.ExpiryDate,
                i.CreatedAt,
                UpdatedAt = (DateTime?)i.UpdatedAt
            })
            .ToListAsync(cancellationToken);

        // Map enum to string in-memory (avoids EF translation edge-cases)
        var items = rawItems
            .Select(i => new PharmacyInventoryItemDto(
                i.Id,
                i.MedicationName,
                i.Price,
                i.Quantity,
                i.Status.ToString(),
                i.PatientNote,
                i.ExpiryDate,
                i.CreatedAt,
                i.UpdatedAt))
            .ToList();

        var totalPages = (int)Math.Ceiling(totalCount / (double)request.PageSize);

        return new PagedInventoryResult(items, totalCount, request.PageNumber, request.PageSize, totalPages);
    }
}
