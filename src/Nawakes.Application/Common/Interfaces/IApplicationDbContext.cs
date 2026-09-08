using Microsoft.EntityFrameworkCore;
using Nawakes.Domain.Entities;

namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Abstraction over EF Core DbContext. Application layer depends only on this interface,
/// keeping EF Core confined to Infrastructure. ApplicationUser is referenced by its Guid ID only.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<Nawakes.Domain.Entities.Pharmacy> Pharmacies { get; }
    DbSet<InventoryItem> InventoryItems { get; }
    DbSet<Reservation> Reservations { get; }
    DbSet<Subscription> Subscriptions { get; }
    DbSet<Report> Reports { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
