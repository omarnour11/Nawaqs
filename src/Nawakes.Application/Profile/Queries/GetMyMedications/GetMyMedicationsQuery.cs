using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Profile.Queries.GetMyMedications;

public sealed record GetMyMedicationsQuery : IRequest<IReadOnlyList<PatientMedicationDto>>;

public sealed record PatientMedicationDto(
    Guid Id,
    string MedicationName,
    string? Strength,
    string? Form,
    string? DoseSchedule,
    decimal? UnitsPerDay,
    bool IsActive,
    string? Notes,
    DateTime CreatedAt);

public sealed class GetMyMedicationsQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetMyMedicationsQuery, IReadOnlyList<PatientMedicationDto>>
{
    public async Task<IReadOnlyList<PatientMedicationDto>> Handle(
        GetMyMedicationsQuery request, CancellationToken cancellationToken)
    {
        return await context.PatientMedications
            .AsNoTracking()
            .Where(m => m.UserId == currentUser.UserId)
            .OrderByDescending(m => m.IsActive)
            .ThenByDescending(m => m.CreatedAt)
            .Select(m => new PatientMedicationDto(
                m.Id, m.MedicationName, m.Strength, m.Form, m.DoseSchedule,
                m.UnitsPerDay, m.IsActive, m.Notes, m.CreatedAt))
            .ToListAsync(cancellationToken);
    }
}
