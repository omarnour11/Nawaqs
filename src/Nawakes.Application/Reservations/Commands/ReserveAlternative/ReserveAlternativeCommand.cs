using MediatR;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Reservations.Commands.ReserveAlternative;

/// <summary>Reserves the recommended alternative medication for a previously rejected/cancelled reservation.</summary>
public sealed record ReserveAlternativeCommand(Guid PriorReservationId) : IRequest<ReservationDto>;

