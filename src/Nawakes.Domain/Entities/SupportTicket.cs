using Nawakes.Domain.Common;
using Nawakes.Domain.Enums;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A support ticket raised by a patient or pharmacy owner, handled by Admin/Operations.
/// </summary>
public sealed class SupportTicket : BaseEntity
{
    public Guid UserId { get; set; }

    /// <summary>Reservation the dispute is about, if any.</summary>
    public Guid? ReservationId { get; set; }
    public Guid? PharmacyId { get; set; }

    public string Subject { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public TicketCategory Category { get; set; } = TicketCategory.Other;
    public TicketStatus Status { get; set; } = TicketStatus.Open;

    public Guid? AssignedAdminId { get; set; }
    public string? Resolution { get; set; }
    public DateTime? ResolvedAt { get; set; }
}
