using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Admin.Queries.GetShortageDemand;

/// <summary>
/// Shortage demand heatmap (Phase 3, Slice 3.5): aggregates active waiting
/// subscribers by medication and city so suppliers can target deliveries.
/// </summary>
public sealed record GetShortageDemandReportQuery : IRequest<ShortageDemandResponse>;

public sealed record ShortageDemandResponse(
    IReadOnlyList<ShortageDemandRow> Rows,
    DateTime GeneratedAt);

public sealed record ShortageDemandRow(
    string MedicationName,
    string City,
    int WaitingCount,
    DateTime OldestWaitingSince);

public sealed class GetShortageDemandReportQueryHandler(IApplicationDbContext context)
    : IRequestHandler<GetShortageDemandReportQuery, ShortageDemandResponse>
{
    public async Task<ShortageDemandResponse> Handle(
        GetShortageDemandReportQuery request, CancellationToken cancellationToken)
    {
        var rows = await context.Subscriptions
            .Where(s => s.IsActive && s.QueueStatus == QueueStatus.Waiting)
            .GroupBy(s => s.MedicationName)
            .Select(g => new ShortageDemandRow(
                g.Key,
                string.Empty,
                g.Count(),
                g.Min(s => s.CreatedAt)))
            .OrderByDescending(r => r.WaitingCount)
            .ToListAsync(cancellationToken);

        return new ShortageDemandResponse(rows, DateTime.UtcNow);
    }
}
