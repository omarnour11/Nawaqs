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

        // 4. Smart Multi-Pharmacy Split-Basket Optimizer (up to 2 stops)
        var allCandidatePharmacies = sortedComplete.Concat(sortedPartial).Take(25).ToList();
        var splitPlans = BuildOptimalSplitPlans(
            distinctItems,
            allCandidatePharmacies,
            sortedComplete,
            request.OptimizationStrategy);

        logger.LogInformation(
            "Batch search for {Count} items resolved {CompleteCount} complete pharmacies, {PartialCount} partial pharmacies, and {SplitCount} optimal split plans.",
            distinctItems.Count, sortedComplete.Count, sortedPartial.Count, splitPlans.Count);

        return new BatchSearchMedicationsResponse(
            sortedComplete,
            sortedPartial,
            distinctItems.Count,
            request.RadiusKm,
            splitPlans);
    }

    private static IReadOnlyList<SplitBasketPlanDto> BuildOptimalSplitPlans(
        IReadOnlyList<BatchSearchItemRequest> requestedItems,
        IReadOnlyList<BatchPharmacyResultDto> candidatePharmacies,
        IReadOnlyList<BatchPharmacyResultDto> completePharmacies,
        string strategy)
    {
        if (requestedItems.Count < 2 || candidatePharmacies.Count < 2)
        {
            return [];
        }

        var baselineSinglePrice = completePharmacies.Count > 0
            ? completePharmacies.Min(p => p.TotalEstimatedPrice)
            : 0m;

        var candidatePairs = new List<SplitBasketPlanDto>();

        for (var i = 0; i < candidatePharmacies.Count; i++)
        {
            for (var j = i + 1; j < candidatePharmacies.Count; j++)
            {
                var p1 = candidatePharmacies[i];
                var p2 = candidatePharmacies[j];

                var p1Assigned = new List<BatchSearchMedicationItemDto>();
                var p2Assigned = new List<BatchSearchMedicationItemDto>();
                var coveredCount = 0;
                var p1Subtotal = 0m;
                var p2Subtotal = 0m;

                foreach (var req in requestedItems)
                {
                    var item1 = p1.Items.FirstOrDefault(x =>
                        x.InStock && x.Medication.Equals(req.Medication, StringComparison.OrdinalIgnoreCase));
                    var item2 = p2.Items.FirstOrDefault(x =>
                        x.InStock && x.Medication.Equals(req.Medication, StringComparison.OrdinalIgnoreCase));

                    if (item1 is null && item2 is null)
                    {
                        continue;
                    }

                    coveredCount++;

                    if (item1 is not null && item2 is null)
                    {
                        p1Assigned.Add(item1);
                        p1Subtotal += item1.Price * req.Quantity;
                    }
                    else if (item2 is not null && item1 is null)
                    {
                        p2Assigned.Add(item2);
                        p2Subtotal += item2.Price * req.Quantity;
                    }
                    else if (item1 is not null && item2 is not null)
                    {
                        // Both pharmacies stock this medication: assign to cheaper pharmacy (tie-break: closer pharmacy)
                        if (item1.Price < item2.Price ||
                            (item1.Price == item2.Price && p1.DistanceKm <= p2.DistanceKm))
                        {
                            p1Assigned.Add(item1);
                            p1Subtotal += item1.Price * req.Quantity;
                        }
                        else
                        {
                            p2Assigned.Add(item2);
                            p2Subtotal += item2.Price * req.Quantity;
                        }
                    }
                }

                // Only valid split if both pharmacies contribute at least 1 item and together cover more than either alone
                if (p1Assigned.Count == 0 || p2Assigned.Count == 0)
                {
                    continue;
                }

                var maxSingleCoverage = Math.Max(p1.MatchedCount, p2.MatchedCount);
                var combinedPrice = p1Subtotal + p2Subtotal;
                var improvesCoverage = coveredCount > maxSingleCoverage;
                var improvesPriceOnFullCoverage = coveredCount == requestedItems.Count &&
                                                  baselineSinglePrice > 0m &&
                                                  combinedPrice < baselineSinglePrice;

                if (!improvesCoverage && !improvesPriceOnFullCoverage)
                {
                    continue;
                }

                var interDistKm = ComputeHaversineKm(p1.Latitude, p1.Longitude, p2.Latitude, p2.Longitude);
                // Optimal 2-stop route starts at closer pharmacy from user, then travels to second pharmacy
                var firstLegKm = Math.Min(p1.DistanceKm, p2.DistanceKm);
                var totalRouteKm = Math.Round(firstLegKm + interDistKm, 2);
                var avgTrust = Math.Round((p1.TrustScore + p2.TrustScore) / 2m, 2);
                var savings = baselineSinglePrice > combinedPrice ? baselineSinglePrice - combinedPrice : 0m;

                var stops = new List<SplitBasketStopDto>
                {
                    new(
                        p1.PharmacyId,
                        p1.PharmacyName,
                        p1.AddressLine,
                        p1.Phone,
                        p1.TrustScore,
                        Math.Round(p1.DistanceKm, 2),
                        p1.Latitude,
                        p1.Longitude,
                        p1Subtotal,
                        p1Assigned),
                    new(
                        p2.PharmacyId,
                        p2.PharmacyName,
                        p2.AddressLine,
                        p2.Phone,
                        p2.TrustScore,
                        Math.Round(p2.DistanceKm, 2),
                        p2.Latitude,
                        p2.Longitude,
                        p2Subtotal,
                        p2Assigned)
                }
                .OrderBy(s => s.DistanceFromUserKm)
                .ToList();

                candidatePairs.Add(new SplitBasketPlanDto(
                    PlanType: "Candidate",
                    ArabicLabel: "تقسيم ذكي على صيدليتين",
                    CoveredItemsCount: coveredCount,
                    TotalRequestedItems: requestedItems.Count,
                    IsFullCoverage: coveredCount == requestedItems.Count,
                    CombinedTotalPrice: combinedPrice,
                    TotalRouteDistanceKm: totalRouteKm,
                    InterPharmacyDistanceKm: Math.Round(interDistKm, 2),
                    AverageTrustScore: avgTrust,
                    SavingsVsSinglePharmacyEgp: savings,
                    Stops: stops));
            }
        }

        if (candidatePairs.Count == 0)
        {
            return [];
        }

        var topCoverage = candidatePairs.Max(c => c.CoveredItemsCount);
        var bestCoveragePool = candidatePairs.Where(c => c.CoveredItemsCount == topCoverage).ToList();

        var selectedPlans = new List<SplitBasketPlanDto>();

        // 1. Shortest Route Plan (أقرب خط سير مزدوج)
        var shortestRoute = bestCoveragePool
            .OrderBy(c => c.TotalRouteDistanceKm)
            .ThenBy(c => c.CombinedTotalPrice)
            .First();

        selectedPlans.Add(shortestRoute with
        {
            PlanType = "ShortestRoute",
            ArabicLabel = "أقرب خط سير (أقل مشوار بين صيدليتين)"
        });

        // 2. Lowest Total Cost Plan (أقل تكلفة إجمالية للروشتة)
        var lowestCost = bestCoveragePool
            .OrderBy(c => c.CombinedTotalPrice)
            .ThenBy(c => c.TotalRouteDistanceKm)
            .First();

        if (!HasSamePharmacyPair(selectedPlans, lowestCost))
        {
            selectedPlans.Add(lowestCost with
            {
                PlanType = "LowestCost",
                ArabicLabel = "أوفر سعر إجمالي للروشتة"
            });
        }

        // 3. Highest Trust Plan (الأعلى تقييماً وموثوقية)
        var highestTrust = bestCoveragePool
            .OrderByDescending(c => c.AverageTrustScore)
            .ThenBy(c => c.TotalRouteDistanceKm)
            .First();

        if (!HasSamePharmacyPair(selectedPlans, highestTrust))
        {
            selectedPlans.Add(highestTrust with
            {
                PlanType = "HighestTrust",
                ArabicLabel = "الأعلى موثوقية وتقييماً"
            });
        }

        if (string.Equals(strategy, "LowestCost", StringComparison.OrdinalIgnoreCase))
        {
            return selectedPlans.OrderBy(p => p.CombinedTotalPrice).ToList();
        }

        if (string.Equals(strategy, "ShortestRoute", StringComparison.OrdinalIgnoreCase))
        {
            return selectedPlans.OrderBy(p => p.TotalRouteDistanceKm).ToList();
        }

        return selectedPlans;
    }

    private static bool HasSamePharmacyPair(IEnumerable<SplitBasketPlanDto> existing, SplitBasketPlanDto candidate)
    {
        var candidateIds = candidate.Stops.Select(s => s.PharmacyId).OrderBy(id => id).ToArray();
        return existing.Any(e =>
            e.Stops.Select(s => s.PharmacyId).OrderBy(id => id).SequenceEqual(candidateIds));
    }

    private static double ComputeHaversineKm(double lat1, double lon1, double lat2, double lon2)
    {
        if (lat1 == 0 && lon1 == 0 || lat2 == 0 && lon2 == 0)
            return 0.0;

        const double R = 6371.0;
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var rLat1 = lat1 * Math.PI / 180.0;
        var rLat2 = lat2 * Math.PI / 180.0;

        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(rLat1) * Math.Cos(rLat2) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return R * c;
    }
}

