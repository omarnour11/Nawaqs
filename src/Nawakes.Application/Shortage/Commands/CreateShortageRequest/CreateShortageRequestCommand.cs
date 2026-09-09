using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;
using NetTopologySuite.Geometries;

namespace Nawakes.Application.Shortage.Commands.CreateShortageRequest;

/// <summary>
/// استغاثة دواء — patient broadcasts a live shortage request; nearby verified
/// pharmacies get notified, and the first to claim gets the fulfillment.
/// </summary>
public sealed record CreateShortageRequestCommand(
    string MedicationName,
    string? Strength,
    int QuantityNeeded,
    double Latitude,
    double Longitude,
    string? Notes) : IRequest<Guid>;

public sealed class CreateShortageRequestCommandValidator : AbstractValidator<CreateShortageRequestCommand>
{
    public CreateShortageRequestCommandValidator()
    {
        RuleFor(x => x.MedicationName).NotEmpty().MinimumLength(2).MaximumLength(300);
        RuleFor(x => x.Strength).MaximumLength(100);
        RuleFor(x => x.QuantityNeeded).InclusiveBetween(1, 100);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}

public sealed class CreateShortageRequestCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    ICacheService cache)
    : IRequestHandler<CreateShortageRequestCommand, Guid>
{
    public async Task<Guid> Handle(CreateShortageRequestCommand request, CancellationToken cancellationToken)
    {
        // One open request per medication per patient at a time
        var normalized = request.MedicationName.Trim().ToUpperInvariant();
        var hasOpen = await context.ShortageRequests.AnyAsync(
            r => r.UserId == currentUser.UserId &&
                 r.MedicationNameNormalized == normalized &&
                 r.Status == ShortageRequestStatus.Open &&
                 r.ExpiresAt > DateTime.UtcNow, cancellationToken);

        if (hasOpen)
            throw new Nawakes.Application.Common.Exceptions.ConflictException(
                "عندك طلب مفتوح لنفس الدواء بالفعل.");

        var req = new Domain.Entities.ShortageRequest
        {
            UserId = currentUser.UserId,
            MedicationName = request.MedicationName.Trim(),
            MedicationNameNormalized = normalized,
            Strength = request.Strength,
            QuantityNeeded = request.QuantityNeeded,
            GeoPoint = new Point(request.Longitude, request.Latitude) { SRID = 4326 },
            Status = ShortageRequestStatus.Open,
            Notes = request.Notes,
            ExpiresAt = DateTime.UtcNow.AddHours(6)
        };

        context.ShortageRequests.Add(req);
        await context.SaveChangesAsync(cancellationToken);

        // Invalidate pharmacy open-requests cache
        await cache.RemoveByPatternAsync("nawakes:shortage:open*", cancellationToken);
        return req.Id;
    }
}
