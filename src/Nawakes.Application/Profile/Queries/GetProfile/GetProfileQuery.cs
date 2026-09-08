using MediatR;

namespace Nawakes.Application.Profile.Queries.GetProfile;

public sealed record ProfileDto(
    Guid UserId,
    string Email,
    string? FullName,
    string? Phone,
    string? MedicalHistoryNotes,
    DateTime CreatedAt);

public sealed record GetProfileQuery : IRequest<ProfileDto>;

public sealed class GetProfileQueryHandler(
    Nawakes.Application.Common.Interfaces.IIdentityService identityService,
    Nawakes.Application.Common.Interfaces.ICurrentUserService currentUser)
    : IRequestHandler<GetProfileQuery, ProfileDto>
{
    public Task<ProfileDto> Handle(GetProfileQuery request, CancellationToken cancellationToken)
        => identityService.GetProfileAsync(currentUser.UserId, cancellationToken);
}
