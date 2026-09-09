using Nawakes.Domain.Common;

namespace Nawakes.Domain.Entities;

/// <summary>
/// A message inside a support ticket thread — patient/pharmacy writes,
/// admin replies. Turns tickets from open/close into a real conversation.
/// </summary>
public sealed class TicketMessage : BaseEntity
{
    public Guid TicketId { get; set; }
    public Guid SenderId { get; set; }

    /// <summary>Sender role snapshot (Patient / PharmacyOwner / Admin).</summary>
    public string SenderRole { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;
}
