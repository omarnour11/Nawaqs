using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Admin.Queries.GetReports;

public sealed record GetReportsQuery(bool PendingOnly = false) : IRequest<IReadOnlyList<AdminReportDto>>;

public sealed record AdminReportDto(
    Guid Id,
    Guid PharmacyId,
    string PharmacyName,
    string ReporterEmail,
    string Type,
    string Status,
    string? Description,
    string? MedicationName,
    decimal? ReportedPrice,
    DateTime CreatedAt,
    DateTime? ReviewedAt);

public sealed class GetReportsQueryHandler(IApplicationDbContext context, IUserDirectory users)
    : IRequestHandler<GetReportsQuery, IReadOnlyList<AdminReportDto>>
{
    public async Task<IReadOnlyList<AdminReportDto>> Handle(GetReportsQuery request, CancellationToken cancellationToken)
    {
        var query = context.Reports.AsNoTracking();

        if (request.PendingOnly)
            query = query.Where(r => r.Status == Domain.Enums.ReportStatus.Pending);

        var rows = await query
            .OrderBy(r => r.Status == Domain.Enums.ReportStatus.Pending ? 0 : 1)
            .ThenByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.Id,
                r.UserId,
                r.PharmacyId,
                PharmacyName = r.Pharmacy.Name,
                r.Type,
                r.Status,
                r.Description,
                r.MedicationName,
                r.ReportedPrice,
                r.CreatedAt,
                r.ReviewedAt
            })
            .ToListAsync(cancellationToken);

        var emails = await users.GetEmailsAsync(rows.Select(r => r.UserId).ToList(), cancellationToken);

        return rows.Select(r => new AdminReportDto(
            r.Id, r.PharmacyId, r.PharmacyName,
            emails.GetValueOrDefault(r.UserId, ""),
            r.Type.ToString(), r.Status.ToString(),
            r.Description, r.MedicationName, r.ReportedPrice, r.CreatedAt, r.ReviewedAt)).ToList();
    }
}
