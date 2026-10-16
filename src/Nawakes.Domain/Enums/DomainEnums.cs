namespace Nawakes.Domain.Enums;

public enum InventoryStatus : byte
{
    InStock = 0,
    OutOfStock = 1,
    Reserved = 2,
    Unconfirmed = 3
}

public enum ReservationStatus : byte
{
    Active = 0,
    Ready = 3,
    Completed = 1,
    Expired = 2,
    Cancelled = 4
}

public enum VerificationStatus : byte
{
    Pending = 0,
    Approved = 1,
    Rejected = 2
}

public enum ReportType : byte
{
    Inaccurate = 0,
    Found = 1
}

public enum ReportStatus : byte
{
    Pending = 0,
    Confirmed = 1,
    Rejected = 2
}

public enum UserRole
{
    Patient,
    PharmacyOwner,
    Admin
}

public enum NotificationType : byte
{
    ReservationCreated = 0,
    ReservationCompleted = 1,
    ReservationExpired = 2,
    ReservationCancelled = 3,
    MedicationAvailable = 4,
    PharmacyApproved = 5,
    PharmacyRejected = 6,
    System = 7
}

public enum TicketStatus : byte
{
    Open = 0,
    InProgress = 1,
    Resolved = 2,
    Closed = 3
}

public enum ShortageRequestStatus : byte
{
    Open = 0,
    Claimed = 1,
    Fulfilled = 2,
    Expired = 3,
    Cancelled = 4
}

public enum TicketCategory : byte
{
    ReservationIssue = 0,
    InaccurateStock = 1,
    PharmacyConduct = 2,
    AccountIssue = 3,
    Other = 4
}
