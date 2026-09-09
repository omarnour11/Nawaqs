using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Admin.Queries.GetDashboardStats;

public sealed record GetDashboardStatsQuery : IRequest<DashboardStatsDto>;

public sealed record DashboardStatsDto(
    int TotalPatients,
    int TotalPharmacies,
    int PendingApprovals,
    int ApprovedPharmacies,
    int RejectedPharmacies,
    int TotalInventoryItems,
    int InStockItems,
    int OutOfStockItems,
    int ActiveReservations,
    int CompletedReservations,
    int PendingReports,
    int TotalPatientsSubscriptions,
    decimal AverageTrustScore);

public sealed class GetDashboardStatsQueryHandler(IApplicationDbContext context, IUserDirectory users)
    : IRequestHandler<GetDashboardStatsQuery, DashboardStatsDto>
{
    public async Task<DashboardStatsDto> Handle(GetDashboardStatsQuery request, CancellationToken cancellationToken)
    {
        var stats = new DashboardStatsDto(
            TotalPatients: await users.CountByRoleAsync(UserRole.Patient, cancellationToken),
            TotalPharmacies: await context.Pharmacies.CountAsync(cancellationToken),
            PendingApprovals: await context.Pharmacies.CountAsync(p => p.VerificationStatus == VerificationStatus.Pending, cancellationToken),
            ApprovedPharmacies: await context.Pharmacies.CountAsync(p => p.VerificationStatus == VerificationStatus.Approved, cancellationToken),
            RejectedPharmacies: await context.Pharmacies.CountAsync(p => p.VerificationStatus == VerificationStatus.Rejected, cancellationToken),
            TotalInventoryItems: await context.InventoryItems.CountAsync(cancellationToken),
            InStockItems: await context.InventoryItems.CountAsync(i => i.Status == InventoryStatus.InStock, cancellationToken),
            OutOfStockItems: await context.InventoryItems.CountAsync(i => i.Status == InventoryStatus.OutOfStock, cancellationToken),
            ActiveReservations: await context.Reservations.CountAsync(r => r.Status == ReservationStatus.Active, cancellationToken),
            CompletedReservations: await context.Reservations.CountAsync(r => r.Status == ReservationStatus.Completed, cancellationToken),
            PendingReports: await context.Reports.CountAsync(r => r.Status == ReportStatus.Pending, cancellationToken),
            TotalPatientsSubscriptions: await context.Subscriptions.CountAsync(s => s.IsActive, cancellationToken),
            AverageTrustScore: await context.Pharmacies.AnyAsync(cancellationToken)
                ? await context.Pharmacies.AverageAsync(p => p.TrustScore, cancellationToken)
                : 0m);

        return stats;
    }
}
