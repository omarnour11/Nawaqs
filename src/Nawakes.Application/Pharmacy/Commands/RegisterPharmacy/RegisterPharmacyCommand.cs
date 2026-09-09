using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Pharmacy.Commands.RegisterPharmacy;

/// <summary>
/// Pharmacist onboarding: registers the pharmacy profile of a logged-in
/// PharmacyOwner, including documents and exact pin-dropped location.
/// Idempotent — updating an existing profile re-submits it for review.
/// </summary>
public sealed record RegisterPharmacyCommand(
    string Name,
    string AddressLine,
    string City,
    string Phone,
    double Latitude,
    double Longitude,
    string? LicenseDocUrl,
    string? NationalIdDocUrl) : IRequest<Guid>;

public sealed class RegisterPharmacyCommandValidator : AbstractValidator<RegisterPharmacyCommand>
{
    public RegisterPharmacyCommandValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.AddressLine).NotEmpty().MaximumLength(500);
        RuleFor(x => x.City).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Phone).NotEmpty().MaximumLength(20);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.LicenseDocUrl).MaximumLength(1000);
        RuleFor(x => x.NationalIdDocUrl).MaximumLength(1000);
    }
}

public sealed class RegisterPharmacyCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<RegisterPharmacyCommand, Guid>
{
    public async Task<Guid> Handle(RegisterPharmacyCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.OwnerId == currentUser.UserId, cancellationToken);

        if (pharmacy is null)
        {
            pharmacy = new Domain.Entities.Pharmacy
            {
                OwnerId = currentUser.UserId,
                VerificationStatus = VerificationStatus.Pending
            };
            context.Pharmacies.Add(pharmacy);
        }
        else if (pharmacy.VerificationStatus == VerificationStatus.Rejected)
        {
            // Resubmission re-enters the review queue
            pharmacy.VerificationStatus = VerificationStatus.Pending;
            pharmacy.RejectionReason = null;
        }

        pharmacy.Name = request.Name.Trim();
        pharmacy.AddressLine = request.AddressLine.Trim();
        pharmacy.City = request.City.Trim();
        pharmacy.Phone = request.Phone.Trim();
        pharmacy.LicenseDocUrl = request.LicenseDocUrl;
        pharmacy.NationalIdDocUrl = request.NationalIdDocUrl;
        pharmacy.GeoPoint = new NetTopologySuite.Geometries.Point(request.Longitude, request.Latitude) { SRID = 4326 };

        await context.SaveChangesAsync(cancellationToken);
        return pharmacy.Id;
    }
}
