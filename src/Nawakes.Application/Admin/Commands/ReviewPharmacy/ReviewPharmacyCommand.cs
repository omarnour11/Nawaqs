using MediatR;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Nawakes.Application.Common.Exceptions;
using Nawakes.Application.Common.Interfaces;
using Nawakes.Domain.Enums;

namespace Nawakes.Application.Admin.Commands.ReviewPharmacy;

public sealed record ReviewPharmacyCommand(
    Guid PharmacyId,
    bool Approve,
    string? RejectionReason)
    : IRequest;

public sealed class ReviewPharmacyCommandValidator : AbstractValidator<ReviewPharmacyCommand>
{
    public ReviewPharmacyCommandValidator()
    {
        RuleFor(x => x.PharmacyId).NotEmpty();
        RuleFor(x => x)
            .Must(x => x.Approve || !string.IsNullOrWhiteSpace(x.RejectionReason))
            .WithMessage("A rejection reason is required when rejecting a pharmacy.");
        RuleFor(x => x.RejectionReason).MaximumLength(500);
    }
}

public sealed class ReviewPharmacyCommandHandler(IApplicationDbContext context)
    : IRequestHandler<ReviewPharmacyCommand>
{
    public async Task Handle(ReviewPharmacyCommand request, CancellationToken cancellationToken)
    {
        var pharmacy = await context.Pharmacies
            .FirstOrDefaultAsync(p => p.Id == request.PharmacyId, cancellationToken)
            ?? throw new NotFoundException(nameof(Domain.Entities.Pharmacy), request.PharmacyId);

        if (pharmacy.VerificationStatus != VerificationStatus.Pending)
            throw new ConflictException(
                $"Pharmacy has already been {pharmacy.VerificationStatus.ToString()?.ToLowerInvariant()}.");

        pharmacy.VerificationStatus = request.Approve
            ? VerificationStatus.Approved
            : VerificationStatus.Rejected;
        pharmacy.RejectionReason = request.Approve ? null : request.RejectionReason?.Trim();

        // Notify the owner via in-app notification center
        context.Notifications.Add(new Domain.Entities.UserNotification
        {
            UserId = pharmacy.OwnerId,
            Type = request.Approve ? NotificationType.PharmacyApproved : NotificationType.PharmacyRejected,
            Title = request.Approve ? "تم اعتماد الصيدلية بنجاح ✓" : "تم رفض توثيق الصيدلية",
            Body = request.Approve
                ? $"تهانينا! تمت الموافقة على صيدلية {pharmacy.Name}. يمكنك الآن إدارة المخزون واستقبال حجوزات المرضى."
                : $"تم رفض توثيق صيدلية \"{pharmacy.Name}\". السبب: {pharmacy.RejectionReason}",
            RelatedEntityId = pharmacy.Id
        });

        await context.SaveChangesAsync(cancellationToken);
    }
}
