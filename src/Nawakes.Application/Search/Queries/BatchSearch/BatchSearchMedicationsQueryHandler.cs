using MediatR;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Search.Queries.BatchSearch;

/// <summary>
/// Handles multi-item prescription search across nearby pharmacies.
/// Prioritizes pharmacies that have ALL requested medications in stock (Priority #1),
/// followed by partial fulfillments sorted by matched item count and distance.
/// </summary>
public sealed class BatchSearchMedicationsQueryHandler(
    IPharmacySearchRepository searchRepository,
    ILogger<BatchSearchMedicationsQueryHandler> logger)
    : IRequestHandler<BatchSearchMedicationsQuery, BatchSearchMedicationsResponse>
{
    public async Task<BatchSearchMedicationsResponse> Handle(
        BatchSearchMedicationsQuery request,
        CancellationToken cancellationToken)
    {
        var distinctItems = request.Items
            .Where(i => !string.IsNullOrWhiteSpace(i.Medication))
            .GroupBy(i => i.Medication.Trim(), StringComparer.OrdinalIgnoreCase)
            .Select(g => g.First())
            .ToList();

        if (distinctItems.Count == 0)
        {
            return new BatchSearchMedicationsResponse([], [], 0, request.RadiusKm);
        }

        // 1. Search for each medication across nearby pharmacies sequentially
        // (EF Core scoped DbContext does not support concurrent multithreaded queries)
        var searchResults = new List<(BatchSearchItemRequest Item, IReadOnlyList<PharmacySearchResultDto> Results)>();
        foreach (var item in distinctItems)
        {
            var results = await searchRepository.SearchAsync(
                medicationNameNormalized: Nawakes.Domain.Common.DrugNameNormalizer.NormalizeName(item.Medication),
                latitude: request.Lat,
                longitude: request.Lng,
                radiusKm: (double)request.RadiusKm,
                cancellationToken: cancellationToken);
            searchResults.Add((item, results));
        }

        // 2. Group inventory by pharmacy
        var pharmacyMap = new Dictionary<Guid, (BatchPharmacyResultDto BaseInfo, Dictionary<string, BatchSearchMedicationItemDto> ItemMap)>();

        foreach (var (item, list) in searchResults)
        {
            foreach (var r in list)
            {
                if (!pharmacyMap.TryGetValue(r.PharmacyId, out var entry))
                {
                    var baseDto = new BatchPharmacyResultDto(
                        r.PharmacyId,
                        r.PharmacyName,
                        r.AddressLine,
                        r.Phone,
                        r.TrustScore,
                        r.DistanceKm,
                        r.Latitude,
                        r.Longitude,
                        0,
                        distinctItems.Count,
                        false,
                        0m,
                        []);

                    entry = (baseDto, new Dictionary<string, BatchSearchMedicationItemDto>(StringComparer.OrdinalIgnoreCase));
                    pharmacyMap[r.PharmacyId] = entry;
                }

                // Add or update item for this pharmacy
                entry.ItemMap[item.Medication] = new BatchSearchMedicationItemDto(
                    item.Medication,
                    item.Quantity,
                    r.Status == "InStock" || r.Status == "Available",
                    r.Price,
                    r.Quantity,
                    r.InventoryItemId);
            }
        }

        // 3. Materialize and compute completeness for each pharmacy
        var complete = new List<BatchPharmacyResultDto>();
        var partial = new List<BatchPharmacyResultDto>();

        foreach (var entry in pharmacyMap.Values)
        {
            var baseInfo = entry.BaseInfo;
            var itemDetails = new List<BatchSearchMedicationItemDto>();
            var inStockCount = 0;
            var totalPrice = 0m;

            foreach (var req in distinctItems)
            {
                if (entry.ItemMap.TryGetValue(req.Medication, out var found))
                {
                    itemDetails.Add(found);
                    if (found.InStock)
                    {
                        inStockCount++;
                        totalPrice += found.Price * req.Quantity;
                    }
                }
                else
                {
                    itemDetails.Add(new BatchSearchMedicationItemDto(
                        req.Medication,
                        req.Quantity,
                        false,
                        0m,
                        0));
                }
            }

            var isComplete = inStockCount == distinctItems.Count;
            var finalized = baseInfo with
            {
                MatchedCount = inStockCount,
                IsCompleteMatch = isComplete,
                TotalEstimatedPrice = totalPrice,
                Items = itemDetails
            };

            if (isComplete)
            {
                complete.Add(finalized);
            }
            else if (inStockCount > 0)
            {
                partial.Add(finalized);
            }
        }

        // Priority #1: Complete match pharmacies closest to user
        var sortedComplete = complete
            .OrderBy(p => p.DistanceKm)
            .ThenByDescending(p => p.TrustScore)
            .ToList();

        // Secondary: Partial match pharmacies sorted by matched items count descending, then distance
        var sortedPartial = partial
            .OrderByDescending(p => p.MatchedCount)
            .ThenBy(p => p.DistanceKm)
            .ToList();

        logger.LogInformation(
            "Batch search for {Count} items resolved {CompleteCount} complete pharmacies and {PartialCount} partial pharmacies.",
            distinctItems.Count, sortedComplete.Count, sortedPartial.Count);

        return new BatchSearchMedicationsResponse(
            sortedComplete,
            sortedPartial,
            distinctItems.Count,
            request.RadiusKm);
    }
}
