using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Application.FamilyCabinet;

// ── CreateFamilyProfile ────────────────────────────────────────────────
public sealed record CreateFamilyProfileCommand(string Nickname, double HomeLatitude, double HomeLongitude)
    : IRequest<Guid>;

public sealed class CreateFamilyProfileCommandValidator : AbstractValidator<CreateFamilyProfileCommand>
{
    public CreateFamilyProfileCommandValidator()
    {
        RuleFor(x => x.Nickname).NotEmpty().MaximumLength(100);
        RuleFor(x => x.HomeLatitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.HomeLongitude).InclusiveBetween(-180, 180);
    }
}

public sealed class CreateFamilyProfileCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<CreateFamilyProfileCommand, Guid>
{
    public async Task<Guid> Handle(CreateFamilyProfileCommand request, CancellationToken cancellationToken)
    {
        var profile = new Domain.Entities.FamilyProfile
        {
            OwnerUserId = currentUser.UserId,
            Nickname = request.Nickname.Trim(),
            HomeLatitude = request.HomeLatitude,
            HomeLongitude = request.HomeLongitude
        };
        context.FamilyProfiles.Add(profile);
        await context.SaveChangesAsync(cancellationToken);
        return profile.Id;
    }
}

// ── AddFamilyMedication ────────────────────────────────────────────────
public sealed record AddFamilyMedicationCommand(
    Guid FamilyProfileId,
    string MedicationName,
    string? Strength,
    int StripsCount,
    int UnitsPerStrip,
    decimal DailyDoseUnits,
    int AlertThresholdDays) : IRequest<Guid>;

public sealed class AddFamilyMedicationCommandValidator : AbstractValidator<AddFamilyMedicationCommand>
{
    public AddFamilyMedicationCommandValidator()
    {
        RuleFor(x => x.MedicationName).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Strength).MaximumLength(100);
        RuleFor(x => x.StripsCount).InclusiveBetween(0, 1000);
        RuleFor(x => x.UnitsPerStrip).InclusiveBetween(1, 500);
        RuleFor(x => x.DailyDoseUnits).GreaterThan(0);
        RuleFor(x => x.AlertThresholdDays).InclusiveBetween(1, 60);
    }
}

public sealed class AddFamilyMedicationCommandHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<AddFamilyMedicationCommand, Guid>
{
    public async Task<Guid> Handle(AddFamilyMedicationCommand request, CancellationToken cancellationToken)
    {
        await CabinetAccess.EnsureCabinetAccessAsync(context, currentUser.UserId, request.FamilyProfileId, cancellationToken);

        var med = new Domain.Entities.FamilyMedication
        {
            FamilyProfileId = request.FamilyProfileId,
            MedicationName = request.MedicationName.Trim(),
            Strength = request.Strength,
            StripsCount = request.StripsCount,
            UnitsPerStrip = request.UnitsPerStrip,
            DailyDoseUnits = request.DailyDoseUnits,
            AlertThresholdDays = request.AlertThresholdDays,
            LastRefillDate = request.StripsCount > 0 ? DateTime.UtcNow : null
        };
        context.FamilyMedications.Add(med);
        await context.SaveChangesAsync(cancellationToken);
        return med.Id;
    }
}

// ── RefillFamilyMedication ─────────────────────────────────────────────
public sealed record RefillFamilyMedicationCommand(Guid MedicationId, int StripsAdded) : IRequest<Guid>;

public sealed class RefillFamilyMedicationCommandValidator : AbstractValidator<RefillFamilyMedicationCommand>
{
    public RefillFamilyMedicationCommandValidator()
    {
        RuleFor(x => x.StripsAdded).InclusiveBetween(1, 100);
    }
}

public sealed class RefillFamilyMedicationCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<RefillFamilyMedicationCommand, Guid>
{
    public async Task<Guid> Handle(RefillFamilyMedicationCommand request, CancellationToken cancellationToken)
    {
        var med = await context.FamilyMedications
            .Include(m => m.FamilyProfile)
            .FirstOrDefaultAsync(m => m.Id == request.MedicationId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.FamilyMedication), request.MedicationId);

        await CabinetAccess.EnsureCabinetAccessAsync(context, currentUser.UserId, med.FamilyProfileId, cancellationToken);

        med.StripsCount += request.StripsAdded;
        med.LastRefillDate = DateTime.UtcNow;

        // Tell co-caregivers so nobody buys the same strip twice
        var others = await context.FamilyCaregiverLinks
            .Where(l => l.FamilyProfileId == med.FamilyProfileId &&
                        l.IsAccepted &&
                        l.CaregiverUserId != currentUser.UserId)
            .Select(l => l.CaregiverUserId)
            .ToListAsync(cancellationToken);

        foreach (var userId in others.Append(med.FamilyProfile.OwnerUserId)
                     .Where(id => id != currentUser.UserId).Distinct())
        {
            context.Notifications.Add(new Nawakes.Domain.Entities.UserNotification
            {
                UserId = userId,
                Type = Nawakes.Domain.Enums.NotificationType.FamilyMedicationRefilled,
                Title = "شراء جديد لدواء العيلة",
                Body = $"تم شراء {request.StripsAdded} شريط جديد لدواء {med.MedicationName} ({med.FamilyProfile.Nickname}).",
                RelatedEntityId = med.Id
            });
        }

        await context.SaveChangesAsync(cancellationToken);
        return med.Id;
    }
}

// ── InviteCaregiver ────────────────────────────────────────────────────
public sealed record InviteCaregiverCommand(Guid FamilyProfileId, string InvitedPhoneNumber) : IRequest<Guid>;

public sealed class InviteCaregiverCommandValidator : AbstractValidator<InviteCaregiverCommand>
{
    public InviteCaregiverCommandValidator()
    {
        RuleFor(x => x.InvitedPhoneNumber).NotEmpty().MaximumLength(20);
    }
}

public sealed class InviteCaregiverCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser,
    IUserDirectory users)
    : IRequestHandler<InviteCaregiverCommand, Guid>
{
    public async Task<Guid> Handle(InviteCaregiverCommand request, CancellationToken cancellationToken)
    {
        // Only the owner may invite caregivers; an accepted caregiver cannot
        // widen access to someone else's cabinet.
        var profile = await context.FamilyProfiles
            .FirstOrDefaultAsync(p => p.Id == request.FamilyProfileId &&
                                      p.OwnerUserId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.FamilyProfile), request.FamilyProfileId);

        var phone = request.InvitedPhoneNumber.Trim();

        // The invite must target a real account: the link is only useful once
        // there is a user who can accept it.
        var inviteeId = await users.FindUserIdByPhoneAsync(phone, cancellationToken)
            ?? throw new NotFoundException("User", phone);

        if (inviteeId == profile.OwnerUserId)
            throw new ConflictException("You cannot invite yourself as a caregiver.");

        var existing = await context.FamilyCaregiverLinks
            .FirstOrDefaultAsync(l => l.FamilyProfileId == profile.Id &&
                                      l.CaregiverUserId == inviteeId, cancellationToken);

        if (existing is not null)
        {
            if (existing.IsAccepted)
                throw new ConflictException("This caregiver is already linked to the cabinet.");

            // Pending invite: re-sending only refreshes the phone number.
            existing.InvitedPhoneNumber = phone;
            await context.SaveChangesAsync(cancellationToken);
            return existing.Id;
        }

        var link = new Domain.Entities.FamilyCaregiverLink
        {
            FamilyProfileId = profile.Id,
            CaregiverUserId = inviteeId,
            InvitedPhoneNumber = phone,
            IsAccepted = false
        };
        context.FamilyCaregiverLinks.Add(link);

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = inviteeId,
            Type = Domain.Enums.NotificationType.CaregiverInviteReceived,
            Title = "دعوة لمتابعة دولاب دوا العيلة",
            Body = $"تمت دعوتك لمتابعة دولاب دوا {profile.Nickname}. افتح التطبيق لقبول الدعوة.",
            RelatedEntityId = profile.Id
        });

        await context.SaveChangesAsync(cancellationToken);
        return link.Id;
    }
}

// ── AcceptCaregiverInvite ──────────────────────────────────────────────
public sealed record AcceptCaregiverInviteCommand(Guid LinkId) : IRequest<Guid>;

public sealed class AcceptCaregiverInviteCommandHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<AcceptCaregiverInviteCommand, Guid>
{
    public async Task<Guid> Handle(AcceptCaregiverInviteCommand request, CancellationToken cancellationToken)
    {
        // The invited user is the only one who can accept their own link.
        var link = await context.FamilyCaregiverLinks
            .FirstOrDefaultAsync(l => l.Id == request.LinkId &&
                                      l.CaregiverUserId == currentUser.UserId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.FamilyCaregiverLink), request.LinkId);

        if (link.IsAccepted)
            throw new ConflictException("This invitation was already accepted.");

        var profile = await context.FamilyProfiles
            .FirstOrDefaultAsync(p => p.Id == link.FamilyProfileId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.FamilyProfile), link.FamilyProfileId);

        link.IsAccepted = true;

        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = profile.OwnerUserId,
            Type = Domain.Enums.NotificationType.CaregiverInviteAccepted,
            Title = "تم قبول دعوة الرعاية",
            Body = $"شخص جديد انضم لمتابعة دولاب دوا {profile.Nickname}.",
            RelatedEntityId = profile.Id
        });

        try
        {
            await context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // A concurrent accept won the race. FamilyCaregiverLink.RowVersion
            // rejects the stale write so the owner is notified only once.
            throw new ConflictException("This invitation was already accepted.");
        }

        return profile.Id;
    }
}

// ── GetPendingCaregiverInvites ─────────────────────────────────────────
public sealed record GetPendingCaregiverInvitesQuery : IRequest<IReadOnlyList<PendingCaregiverInviteDto>>;

public sealed record PendingCaregiverInviteDto(
    Guid LinkId,
    Guid FamilyProfileId,
    string FamilyProfileNickname,
    DateTime InvitedAt);

public sealed class GetPendingCaregiverInvitesQueryHandler(
    IApplicationDbContext context,
    ICurrentUserService currentUser)
    : IRequestHandler<GetPendingCaregiverInvitesQuery, IReadOnlyList<PendingCaregiverInviteDto>>
{
    public async Task<IReadOnlyList<PendingCaregiverInviteDto>> Handle(
        GetPendingCaregiverInvitesQuery request, CancellationToken cancellationToken)
        => await context.FamilyCaregiverLinks
            .Where(l => l.CaregiverUserId == currentUser.UserId && !l.IsAccepted)
            .Join(
                context.FamilyProfiles.Where(p => p.IsActive),
                l => l.FamilyProfileId,
                p => p.Id,
                (l, p) => new PendingCaregiverInviteDto(
                    l.Id,
                    l.FamilyProfileId,
                    p.Nickname,
                    l.CreatedAt))
            .OrderByDescending(i => i.InvitedAt)
            .ToListAsync(cancellationToken);
}

// ── GetFamilyCabinet ───────────────────────────────────────────────────
public sealed record GetFamilyCabinetQuery : IRequest<FamilyCabinetResponse>;

public sealed record FamilyCabinetResponse(IReadOnlyList<FamilyCabinetProfileDto> Profiles);

public sealed record FamilyCabinetProfileDto(
    Guid Id,
    string Nickname,
    double HomeLatitude,
    double HomeLongitude,
    IReadOnlyList<FamilyMedicationDto> Medications);

public sealed record FamilyMedicationDto(
    Guid Id,
    string MedicationName,
    string? Strength,
    int StripsCount,
    int UnitsPerStrip,
    decimal DailyDoseUnits,
    int DaysRemaining,
    int AlertThresholdDays,
    DateTime? LastRefillDate);

public sealed class GetFamilyCabinetQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    : IRequestHandler<GetFamilyCabinetQuery, FamilyCabinetResponse>
{
    public async Task<FamilyCabinetResponse> Handle(GetFamilyCabinetQuery request, CancellationToken cancellationToken)
    {
        var profiles = await context.FamilyProfiles
            .Include(p => p.FamilyMedications.Where(m => m.IsActive))
            .Where(p => p.IsActive &&
                        (p.OwnerUserId == currentUser.UserId ||
                         p.FamilyCaregiverLinks.Any(l => l.CaregiverUserId == currentUser.UserId && l.IsAccepted)))
            .OrderBy(p => p.CreatedAt)
            .ToListAsync(cancellationToken);

        return new FamilyCabinetResponse(profiles.Select(p => new FamilyCabinetProfileDto(
            p.Id,
            p.Nickname,
            p.HomeLatitude,
            p.HomeLongitude,
            p.FamilyMedications.Select(m => new FamilyMedicationDto(
                m.Id,
                m.MedicationName,
                m.Strength,
                m.StripsCount,
                m.UnitsPerStrip,
                m.DailyDoseUnits,
                ComputeDaysRemaining(m),
                m.AlertThresholdDays,
                m.LastRefillDate)).ToList())).ToList());
    }

    internal static int ComputeDaysRemaining(Domain.Entities.FamilyMedication m) =>
        m.DailyDoseUnits > 0
            ? (int)Math.Floor(m.StripsCount * (decimal)m.UnitsPerStrip / m.DailyDoseUnits)
            : int.MaxValue;
}

internal static class CabinetAccess
{
    public static async Task EnsureCabinetAccessAsync(
        IApplicationDbContext context,
        Guid userId,
        Guid profileId,
        CancellationToken ct)
    {
        var allowed = await context.FamilyProfiles
            .Where(p => p.Id == profileId &&
                        (p.OwnerUserId == userId ||
                         p.FamilyCaregiverLinks.Any(l => l.CaregiverUserId == userId && l.IsAccepted)))
            .AnyAsync(ct);

        if (!allowed)
            throw new NotFoundException(nameof(Domain.Entities.FamilyProfile), profileId);
    }
}
