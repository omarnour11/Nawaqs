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
        var now = DateTime.UtcNow;

        var subscriptionRows = await context.Subscriptions
            .AsNoTracking()
            .Where(s => s.IsActive && s.QueueStatus == QueueStatus.Waiting)
            .GroupBy(s => s.MedicationName)
            .Select(g => new
            {
                MedicationName = g.Key,
                Count = g.Count(),
                Oldest = g.Min(s => s.CreatedAt),
            })
            .ToListAsync(cancellationToken);

        var shortageRows = await context.ShortageRequests
            .AsNoTracking()
            .Where(r => r.Status == ShortageRequestStatus.Open && r.ExpiresAt > now)
            .GroupBy(r => r.MedicationName)
            .Select(g => new
            {
                MedicationName = g.Key,
                Count = g.Count(),
                Oldest = g.Min(r => r.CreatedAt),
            })
            .ToListAsync(cancellationToken);

        var merged = subscriptionRows
            .Concat(shortageRows)
            .GroupBy(r => r.MedicationName, StringComparer.OrdinalIgnoreCase)
            .Select(g => new ShortageDemandRow(
                g.Key,
                string.Empty,
                g.Sum(x => x.Count),
                g.Min(x => x.Oldest)))
            .OrderByDescending(r => r.WaitingCount)
            .ThenBy(r => r.MedicationName)
            .ToList();

        return new ShortageDemandResponse(merged, now);
    }
}
