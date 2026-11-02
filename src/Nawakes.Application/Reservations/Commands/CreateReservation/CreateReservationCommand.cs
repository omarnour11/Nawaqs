using MediatR;
using Nawakes.Application.Reservations.Dtos;

namespace Nawakes.Application.Reservations.Commands.CreateReservation;

/// <summary>Places a 2-hour hold on an inventory item for the calling patient, attaching sanitized prescription image crop for multi-pharmacy safety verification.</summary>
public sealed record CreateReservationCommand(
    Guid InventoryItemId,
    string? PrescriptionCropUrl = null,
    byte[]? PrescriptionCropBytes = null) : IRequest<ReservationDto>;

