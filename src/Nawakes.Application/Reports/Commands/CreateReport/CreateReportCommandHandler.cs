using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;

namespace Nawakes.Application.Reports.Commands.CreateReport;

public sealed class CreateReportCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ITrustScoreJobScheduler jobScheduler)
    : IRequestHandler<CreateReportCommand, Guid>
{
    public async Task<Guid> Handle(CreateReportCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.Id == request.PharmacyId, cancellationToken);

        if (pharmacy is null)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), request.PharmacyId);

        var normalizedName = request.MedicationName.Trim().ToLowerInvariant();
        var oneDayAgo = DateTime.UtcNow.AddHours(-24);

        // Rate limiting: one report per pharmacy per medication per 24 hours
        var recentReportExists = await context.Reports
            .AnyAsync(r => r.PharmacyId == pharmacy.Id 
                        && r.UserId == currentUser.UserId 
                        && r.MedicationName.ToLower() == normalizedName 
                        && r.CreatedAt >= oneDayAgo, cancellationToken);
        if (recentReportExists)
            throw new ConflictException("You can only submit one report per medication per pharmacy every 24 hours.");

        var report = new Report
        {
            UserId = currentUser.UserId,
            PharmacyId = pharmacy.Id,
            Type = request.Type,
            MedicationName = request.MedicationName.Trim(),
            ReportedPrice = request.ReportedPrice,
            Description = request.Description
        };

        context.Reports.Add(report);
        await context.SaveChangesAsync(cancellationToken);

        jobScheduler.ScheduleTrustScoreRecalculation(pharmacy.Id);

        return report.Id;
    }
}
