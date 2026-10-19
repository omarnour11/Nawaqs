using Hangfire;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.BackgroundJobs;

/// <summary>
/// Family cabinet depletion engine (Phase 5, Slice 5.2): runs daily at 8 AM
/// Cairo time (06:00 UTC), computes days-remaining per tracked medication,
/// and notifies the owner plus accepted caregivers 7 days before a supply
/// runs out, with the nearest in-stock pharmacy attached.
/// </summary>
public sealed class CheckCabinetDepletionJob(
    IServiceProvider serviceProvider,
    ILogger<CheckCabinetDepletionJob> logger)
{
    [AutomaticRetry(Attempts = 3, DelaysInSeconds = [10, 60, 300])]
    public async Task RunAsync(CancellationToken cancellationToken)
    {
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var searchRepository = scope.ServiceProvider.GetRequiredService<IPharmacySearchRepository>();
        var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

        var candidates = await context.FamilyMedications
            .Include(m => m.FamilyProfile)
            .Where(m => m.IsActive &&
                        m.DailyDoseUnits > 0 &&
                        m.StripsCount * m.UnitsPerStrip /
                            m.DailyDoseUnits <= m.AlertThresholdDays)
            .ToListAsync(cancellationToken);

        var audienceIds = new List<Guid>();
        foreach (var med in candidates)
        {
            var daysRemaining = (int)Math.Floor(
                med.StripsCount * (decimal)med.UnitsPerStrip / med.DailyDoseUnits);

            string? nearestPharmacy = null;
            try
            {
                var results = await searchRepository.SearchAsync(
                    med.MedicationName.Trim().ToUpperInvariant(),
                    med.FamilyProfile.HomeLatitude,
                    med.FamilyProfile.HomeLongitude,
                    radiusKm: 5);
                nearestPharmacy = results.Count > 0 ? results[0].PharmacyName : null;
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Pharmacy search failed for medication {MedId}", med.Id);
            }

            var audience = await context.FamilyCaregiverLinks
                .Where(l => l.FamilyProfileId == med.FamilyProfileId && l.IsAccepted)
                .Select(l => l.CaregiverUserId)
                .Append(med.FamilyProfile.OwnerUserId)
                .Distinct()
                .ToListAsync(cancellationToken);

            audienceIds.AddRange(audience);

            foreach (var userId in audience)
            {
                context.Notifications.Add(new Nawakes.Domain.Entities.UserNotification
                {
                    UserId = userId,
                    Type = Nawakes.Domain.Enums.NotificationType.FamilyMedicationLow,
                    Title = "دواء العيلة قرب يخلص",
                    Body = nearestPharmacy is null
                        ? $"دواء {med.FamilyProfile.Nickname} ({med.MedicationName}) هيكفي {daysRemaining} أيام بس."
                        : $"دواء {med.FamilyProfile.Nickname} ({med.MedicationName}) هيكفي {daysRemaining} أيام بس! متوفر حالياً في صيدلية {nearestPharmacy}. اضغط هنا لحجزه مسبقاً.",
                    RelatedEntityId = med.Id
                });
            }
        }

        await context.SaveChangesAsync(CancellationToken.None);

        // High-priority FCM push once Firebase keys are configured
        var audienceUserIds = audienceIds.ToHashSet();
        var users = await context.Users
            .Where(u => u.FcmToken != null && audienceUserIds.Contains(u.Id))
            .Select(u => new { u.Id, u.FcmToken })
            .ToListAsync(CancellationToken.None);

        foreach (var u in users)
        {
            try
            {
                await notificationService.SendAsync(
                    u.FcmToken!,
                    "دواء العيلة قرب يخلص",
                    "افتح تطبيق نواقص لحجز الدواء قبل ما يخلص.",
                    cancellationToken: CancellationToken.None);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Depletion FCM push failed for user {UserId}", u.Id);
            }
        }

        logger.LogInformation("Cabinet depletion check complete: {Count} medications flagged.", candidates.Count);
    }
}
