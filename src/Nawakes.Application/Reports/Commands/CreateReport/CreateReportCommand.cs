using MediatR;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Reports.Commands.CreateReport;

public sealed record CreateReportCommand(
    Guid PharmacyId,
    ReportType Type,
    string MedicationName,
    decimal? ReportedPrice,
    string? Description) : IRequest<Guid>;
