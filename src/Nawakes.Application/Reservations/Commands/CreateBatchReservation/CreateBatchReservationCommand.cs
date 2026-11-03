using MediatR;
using Nawakes.Application.Reservations.Commands.CreateReservation;
using Nawakes.Application.Reservations.Dtos;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Reservations.Commands.CreateBatchReservation;

public sealed record BatchReservationStopItem(
    Guid InventoryItemId,
    FulfillmentType FulfillmentType = FulfillmentType.Pickup,
    string? DeliveryAddress = null,
    double? DeliveryLatitude = null,
    double? DeliveryLongitude = null,
    string? DeliveryContactPhone = null,
    string? DeliveryNotes = null);

public sealed record CreateBatchReservationCommand(
    IReadOnlyList<BatchReservationStopItem> Items,
    string? PrescriptionCropUrl = null,
    byte[]? PrescriptionCropBytes = null) : IRequest<BatchReservationResultDto>;

public sealed record BatchReservationFailureDto(
    Guid InventoryItemId,
    string ErrorMessage);

public sealed record BatchReservationResultDto(
    IReadOnlyList<ReservationDto> CreatedReservations,
    IReadOnlyList<BatchReservationFailureDto> FailedItems,
    bool IsAllSucceeded);

/// <summary>
/// Places coordinated 2-hour holds across multiple inventory items (single pharmacy or split-basket across 2 pharmacies).
/// Reuses CreateReservationCommand per item to preserve RowVersion optimistic concurrency and Hangfire expiry scheduling.
/// </summary>
public sealed class CreateBatchReservationCommandHandler(ISender mediator)
    : IRequestHandler<CreateBatchReservationCommand, BatchReservationResultDto>
{
    public async Task<BatchReservationResultDto> Handle(
        CreateBatchReservationCommand request,
        CancellationToken cancellationToken)
    {
        var distinctItems = request.Items
            .GroupBy(i => i.InventoryItemId)
            .Select(g => g.First())
            .ToList();

        var created = new List<ReservationDto>();
        var failed = new List<BatchReservationFailureDto>();

        foreach (var stop in distinctItems)
        {
            try
            {
                var reservation = await mediator.Send(
                    new CreateReservationCommand(
                        stop.InventoryItemId,
                        request.PrescriptionCropUrl,
                        request.PrescriptionCropBytes,
                        stop.FulfillmentType,
                        stop.DeliveryAddress,
                        stop.DeliveryLatitude,
                        stop.DeliveryLongitude,
                        stop.DeliveryContactPhone,
                        stop.DeliveryNotes),
                    cancellationToken);

                created.Add(reservation);
            }
            catch (Exception ex)
            {
                failed.Add(new BatchReservationFailureDto(stop.InventoryItemId, ex.Message));
            }
        }

        return new BatchReservationResultDto(
            created,
            failed,
            failed.Count == 0 && created.Count > 0);
    }
}
