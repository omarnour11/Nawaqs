using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.Pharmacies.Commands.RatePharmacy;

/// <summary>Upserts the caller's 1–5 star rating for a pharmacy.</summary>
public sealed record RatePharmacyCommand(Guid PharmacyId, int Score, string? Comment) : IRequest;

public sealed class RatePharmacyCommandValidator : AbstractValidator<RatePharmacyCommand>
{
    public RatePharmacyCommandValidator()
    {
        RuleFor(x => x.PharmacyId).NotEmpty();
        RuleFor(x => x.Score).InclusiveBetween(1, 5).WithMessage("Rating must be between 1 and 5 stars.");
        RuleFor(x => x.Comment).MaximumLength(1000);
    }
}

public sealed class RatePharmacyCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<RatePharmacyCommand>
{
    public async Task Handle(RatePharmacyCommand request, CancellationToken cancellationToken)
    {
        var pharmacyExists = await context.Pharmacies
            .AnyAsync(p => p.Id == request.PharmacyId, cancellationToken);
        if (!pharmacyExists)
            throw new NotFoundException(nameof(Domain.Entities.Pharmacy), request.PharmacyId);

        var existing = await context.Ratings
            .FirstOrDefaultAsync(r => r.UserId == currentUser.UserId && r.PharmacyId == request.PharmacyId, cancellationToken);

        if (existing is not null)
        {
            existing.Score = request.Score;
            existing.Comment = request.Comment?.Trim();
        }
        else
        {
            context.Ratings.Add(new Domain.Entities.PharmacyRating
            {
                UserId = currentUser.UserId,
                PharmacyId = request.PharmacyId,
                Score = request.Score,
                Comment = request.Comment?.Trim()
            });
        }

        await context.SaveChangesAsync(cancellationToken);
    }
}
