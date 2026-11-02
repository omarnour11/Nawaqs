using MediatR;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Reservations.Commands.CreateReservation;

/// <summary>Places a 2-hour hold on an inventory item for the calling patient, attaching sanitized prescription image crop for multi-pharmacy safety verification and delivery options.</summary>
public sealed record CreateReservationCommand(
    Guid InventoryItemId,
    string? PrescriptionCropUrl = null,
    byte[]? PrescriptionCropBytes = null,
    FulfillmentType FulfillmentType = FulfillmentType.Pickup,
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null) : IRequest<ReservationDto>;
