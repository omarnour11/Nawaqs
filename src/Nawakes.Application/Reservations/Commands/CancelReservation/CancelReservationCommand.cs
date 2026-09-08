using MediatR;

namespace Nawakes.Application.Reservations.Commands.CancelReservation;

/// <summary>
/// Cancels an Active reservation. Enforces the 15-minute lock-in window:
/// patients cannot cancel within 15 minutes of creation to prevent abuse.
/// </summary>
public sealed record CancelReservationCommand(Guid ReservationId) : IRequest;
