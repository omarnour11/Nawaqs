using System.Security.Cryptography;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Interfaces;
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
/// Groups items by pharmacy so that medications ordered from the SAME pharmacy share ONE single unified reservation pickup code.
/// Reuses CreateReservationCommand per item to preserve RowVersion optimistic concurrency and Hangfire expiry scheduling.
/// </summary>
public sealed class CreateBatchReservationCommandHandler(
    ISender mediator,
    IApplicationDbContext context)
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

        var itemIds = distinctItems.Select(i => i.InventoryItemId).ToList();
        var inventoryItems = await context.InventoryItems
            .AsNoTracking()
            .Where(i => itemIds.Contains(i.Id))
            .Select(i => new { i.Id, i.PharmacyId })
            .ToListAsync(cancellationToken);

        var pharmacyLookup = inventoryItems.ToDictionary(i => i.Id, i => i.PharmacyId);

        // Group batch items by PharmacyId so each pharmacy gets a single unified order code
        var groupedByPharmacy = distinctItems
            .GroupBy(i => pharmacyLookup.TryGetValue(i.InventoryItemId, out var pId) ? pId : Guid.NewGuid())
            .ToList();

        var created = new List<ReservationDto>();
        var failed = new List<BatchReservationFailureDto>();

        foreach (var pharmacyGroup in groupedByPharmacy)
        {
            // Single unified pickup code shared across all medications from this pharmacy
            var unifiedPharmacyCode = GenerateCode();

            foreach (var stop in pharmacyGroup)
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
                            stop.DeliveryNotes,
                            ReservationCode: unifiedPharmacyCode),
                        cancellationToken);

                    created.Add(reservation);
                }
                catch (Exception ex)
                {
                    failed.Add(new BatchReservationFailureDto(stop.InventoryItemId, ex.Message));
                }
            }
        }

        return new BatchReservationResultDto(
            created,
            failed,
            failed.Count == 0 && created.Count > 0);
    }

    private static string GenerateCode()
    {
        Span<byte> bytes = stackalloc byte[3];
        RandomNumberGenerator.Fill(bytes);
        return $"NWQ-{bytes[0]:X2}{bytes[1]:X2}{bytes[2]:X2}";
    }
}
