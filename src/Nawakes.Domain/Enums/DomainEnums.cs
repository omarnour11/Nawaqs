namespace Nawakes.Domain.Enums;

public enum InventoryStatus : byte
{
    InStock = 0,
    OutOfStock = 1,
    Reserved = 2
}

public enum ReservationStatus : byte
{
    Active = 0,
    Completed = 1,
    Expired = 2,
    Cancelled = 3
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
