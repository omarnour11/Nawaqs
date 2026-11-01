using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Admin.Queries.GetMedicineCatalog;

public sealed record GetMedicineCatalogQuery(
    string? Search = null,
    int PageNumber = 1,
    int PageSize = 50,
    bool? ChronicOnly = null)
    : IRequest<PagedMedicineCatalogResult>;

public sealed record MedicineCatalogItemDto(
    Guid Id,
    string TradeName,
    string? ActiveIngredient,
    string? Strength,
    string? DosageForm,
    decimal? OfficialPriceEGP,
    string? Manufacturer,
    string? EdaRegistrationNumber,
    bool IsChronic);

public sealed record PagedMedicineCatalogResult(
    IReadOnlyList<MedicineCatalogItemDto> Items,
    int TotalCount,
    int PageNumber,
    int PageSize,
    int TotalPages);

public sealed class GetMedicineCatalogQueryValidator : AbstractValidator<GetMedicineCatalogQuery>
{
    public GetMedicineCatalogQueryValidator()
    {
        RuleFor(x => x.PageNumber).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 500);
        RuleFor(x => x.Search).MaximumLength(300).When(x => x.Search is not null);
    }
}

public sealed class GetMedicineCatalogQueryHandler(IApplicationDbContext context)
    : IRequestHandler<GetMedicineCatalogQuery, PagedMedicineCatalogResult>
{
    public async Task<PagedMedicineCatalogResult> Handle(
        GetMedicineCatalogQuery request, CancellationToken cancellationToken)
    {
        var query = context.EgyptianDrugRegistry.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(request.Search))
        {
            var term = request.Search.Trim().ToUpperInvariant();
            query = query.Where(d =>
                d.TradeNameNormalized.Contains(term) ||
                (d.ActiveIngredientNormalized != null && d.ActiveIngredientNormalized.Contains(term)));
        }

        if (request.ChronicOnly.HasValue)
            query = query.Where(d => d.IsChronic == request.ChronicOnly.Value);

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(d => d.TradeName)
            .Skip((request.PageNumber - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(d => new MedicineCatalogItemDto(
                d.Id,
                d.TradeName,
                d.ActiveIngredient,
                d.Strength,
                d.DosageForm,
                d.OfficialPriceEGP,
                d.Manufacturer,
                d.EdaRegistrationNumber,
                d.IsChronic))
            .ToListAsync(cancellationToken);

        var totalPages = (int)Math.Ceiling(totalCount / (double)request.PageSize);

        return new PagedMedicineCatalogResult(items, totalCount, request.PageNumber, request.PageSize, totalPages);
    }
}
