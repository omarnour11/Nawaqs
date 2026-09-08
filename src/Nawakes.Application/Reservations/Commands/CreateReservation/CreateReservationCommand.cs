using MediatR;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Reservations.Commands.CreateReservation;

/// <summary>Places a 2-hour hold on an inventory item for the calling patient.</summary>
public sealed record CreateReservationCommand(Guid InventoryItemId) : IRequest<ReservationDto>;
