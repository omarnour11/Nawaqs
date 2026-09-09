using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Entities;

namespace Nawakes.Application.Pharmacies.Commands.ToggleFavorite;

/// <summary>Adds/removes a pharmacy from the caller's favorites. Returns true if now favorited.</summary>
public sealed record ToggleFavoriteCommand(Guid PharmacyId) : IRequest<bool>;

public sealed class ToggleFavoriteCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<ToggleFavoriteCommand, bool>
{
    public async Task<bool> Handle(ToggleFavoriteCommand request, CancellationToken cancellationToken)
    {
        var existing = await context.Favorites
            .FirstOrDefaultAsync(f => f.UserId == currentUser.UserId && f.PharmacyId == request.PharmacyId, cancellationToken);

        if (existing is not null)
        {
            context.Favorites.Remove(existing);
            await context.SaveChangesAsync(cancellationToken);
            return false;
        }

        context.Favorites.Add(new FavoritePharmacy
        {
            UserId = currentUser.UserId,
            PharmacyId = request.PharmacyId
        });
        await context.SaveChangesAsync(cancellationToken);
        return true;
    }
}
