namespace Nawakes.Application.Common.Interfaces;

public interface ITrustScoreJobScheduler
{
    void ScheduleTrustScoreRecalculation(Guid pharmacyId);
}
