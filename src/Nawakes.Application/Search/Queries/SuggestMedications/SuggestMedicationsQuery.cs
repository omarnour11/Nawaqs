using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Search.Queries.SuggestMedications;

/// <summary>Autocomplete suggestions for medication names (from in-stock items at approved pharmacies).</summary>
public sealed record SuggestMedicationsQuery(string Prefix, int Take = 8)
    : IRequest<IReadOnlyList<string>>;

public sealed class SuggestMedicationsQueryValidator : AbstractValidator<SuggestMedicationsQuery>
{
    public SuggestMedicationsQueryValidator()
    {
        RuleFor(x => x.Prefix).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Take).InclusiveBetween(1, 20);
    }
}

public sealed class SuggestMedicationsQueryHandler(IApplicationDbContext context)
    : IRequestHandler<SuggestMedicationsQuery, IReadOnlyList<string>>
{
    public async Task<IReadOnlyList<string>> Handle(SuggestMedicationsQuery request, CancellationToken cancellationToken)
    {
        var prefix = request.Prefix.Trim().ToUpperInvariant();
        if (prefix.Length < 2) return [];

        var names = await context.InventoryItems
            .AsNoTracking()
            .Where(i => i.Status == InventoryStatus.InStock &&
                        i.Pharmacy.VerificationStatus == VerificationStatus.Approved &&
                        i.MedicationNameNormalized.Contains(prefix))
            .Select(i => i.MedicationName)
            .Distinct()
            .OrderBy(n => n)
            .Take(request.Take)
            .ToListAsync(cancellationToken);

        return names;
    }
}
