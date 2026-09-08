using MediatR;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Pharmacy.Commands.CompleteReservation;

/// <summary>Pharmacy owner marks a reservation as sold/completed.</summary>
public sealed record CompleteReservationCommand(Guid ReservationId) : IRequest<PharmacyReservationDto>;
