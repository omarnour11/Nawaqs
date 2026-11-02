namespace Nawakes.Application.Common.Interfaces;

/// <summary>
/// Result of prescription image sanitization and PII stripping for Law No. 151 compliance.
/// </summary>
public sealed record PrescriptionSanitizationResult(
    byte[] SanitizedImageBytes,
    string ContentType,
    int OriginalWidth,
    int OriginalHeight,
    int CropX,
    int CropY,
    int CropWidth,
    int CropHeight,
    bool IsCompliantWithLaw151,
    string? RedactedOcrText = null);

/// <summary>
/// Egyptian Personal Data Protection Law No. 151 of 2020 Compliance Service:
/// Crops out the doctor/clinic header (top ~20%) and patient footer (bottom ~18%),
/// suppressing all identifiable patient and physician data before forwarding
/// prescription images to fulfilling pharmacies.
/// </summary>
public interface IPrescriptionSanitizationService
{
    /// <summary>
    /// Computes and executes the medication-body crop window, stripping clinic headers and patient footers.
    /// </summary>
    PrescriptionSanitizationResult SanitizePrescription(
        byte[] imageBytes,
        string contentType = "image/jpeg",
        double headerRatio = 0.20,
        double footerRatio = 0.18);

    /// <summary>
    /// Determines whether the given text contains Egyptian PII / PHI (doctor names, clinics, syndicate numbers, patient info, Egyptian addresses).
    /// </summary>
    bool ContainsPii(string text);

    /// <summary>
    /// Redacts all PII / PHI lines from raw OCR strings, strictly preserving only medication orders.
    /// </summary>
    string RedactPii(string text);
}
