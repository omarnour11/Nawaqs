using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Admin.Queries.GetPatients;

public sealed record GetPatientsQuery(
    string? Search = null,
    int PageNumber = 1,
    int PageSize = 30)
    : IRequest<PagedPatientsResult>;

public sealed record PatientSummaryDto(
    Guid Id,
    string Email,
    string? FullName,
    string? Phone,
    DateTime RegisteredAt,
    int ReservationCount,
    int ComplaintCount);

public sealed record PagedPatientsResult(
    IReadOnlyList<PatientSummaryDto> Items,
    int TotalCount,
    int PageNumber,
    int PageSize,
    int TotalPages);

public sealed class GetPatientsQueryValidator : AbstractValidator<GetPatientsQuery>
{
    public GetPatientsQueryValidator()
    {
        RuleFor(x => x.PageNumber).GreaterThanOrEqualTo(1);
        RuleFor(x => x.PageSize).InclusiveBetween(1, 200);
        RuleFor(x => x.Search).MaximumLength(200).When(x => x.Search is not null);
    }
}

public sealed class GetPatientsQueryHandler(IUserDirectory users, IApplicationDbContext context)
    : IRequestHandler<GetPatientsQuery, PagedPatientsResult>
{
    public async Task<PagedPatientsResult> Handle(
        GetPatientsQuery request, CancellationToken cancellationToken)
    {
        // Delegate to UserDirectory which has direct access to Identity tables
        var result = await users.GetPatientPageAsync(
            request.Search,
            request.PageNumber,
            request.PageSize,
            cancellationToken);

        // Enrich with reservation/complaint counts from the domain context
        var ids = result.Items.Select(p => p.Id).ToList();

        var reservationCounts = await context.Reservations
            .AsNoTracking()
            .Where(r => ids.Contains(r.UserId))
            .GroupBy(r => r.UserId)
            .Select(g => new { UserId = g.Key, Count = g.Count() })
            .ToListAsync(cancellationToken);

        var reportCounts = await context.Reports
            .AsNoTracking()
            .Where(r => ids.Contains(r.UserId))
            .GroupBy(r => r.UserId)
            .Select(g => new { UserId = g.Key, Count = g.Count() })
            .ToListAsync(cancellationToken);

        var rMap = reservationCounts.ToDictionary(x => x.UserId, x => x.Count);
        var cMap = reportCounts.ToDictionary(x => x.UserId, x => x.Count);

        var enriched = result.Items
            .Select(p => p with
            {
                ReservationCount = rMap.GetValueOrDefault(p.Id, 0),
                ComplaintCount = cMap.GetValueOrDefault(p.Id, 0)
            })
            .ToList();

        return new PagedPatientsResult(
            enriched, result.TotalCount, result.PageNumber, result.PageSize, result.TotalPages);
    }
}
