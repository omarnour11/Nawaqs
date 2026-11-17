using MediatR;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Pharmacy.Commands.CompleteReservation;

/// <summary>Pharmacy owner marks a reservation as sold/completed with patient pickup code verification.</summary>
public sealed record CompleteReservationCommand(Guid ReservationId, string? ReservationCode = null) : IRequest<PharmacyReservationDto>;
