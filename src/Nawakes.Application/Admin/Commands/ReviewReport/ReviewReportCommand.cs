using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Admin.Commands.ReviewReport;

public sealed record ReviewReportCommand(Guid ReportId, bool Confirm, Guid AdminId) : IRequest;

public sealed class ReviewReportCommandHandler(IApplicationDbContext context)
    : IRequestHandler<ReviewReportCommand>
{
    public async Task Handle(ReviewReportCommand request, CancellationToken cancellationToken)
    {
        var report = await context.Reports
            .FirstOrDefaultAsync(r => r.Id == request.ReportId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Report), request.ReportId);

        if (report.Status != Domain.Enums.ReportStatus.Pending)
            throw new ConflictException("This report has already been reviewed.");

        report.Status = request.Confirm
            ? Domain.Enums.ReportStatus.Confirmed
            : Domain.Enums.ReportStatus.Rejected;
        report.ReviewedByAdminId = request.AdminId;
        report.ReviewedAt = DateTime.UtcNow;

        await context.SaveChangesAsync(cancellationToken);
    }
}
