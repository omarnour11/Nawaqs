using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.Infrastructure.Security;

/// <summary>
/// AES-256-CBC encryption service for health questionnaire data at rest.
/// Key and IV are derived from configuration. Key must be exactly 32 bytes (256-bit).
///
/// Production note: replace with Azure Key Vault or AWS KMS managed key in Phase 2.
/// </summary>
public sealed class AesEncryptionService : IEncryptionService
{
    // Key: 32 bytes (256-bit), IV: 16 bytes (128-bit)
    private readonly byte[] _key;

    public AesEncryptionService(IConfiguration configuration)
    {
        var rawKey = configuration["Encryption:Key"]
            ?? throw new InvalidOperationException("Encryption:Key is not configured.");

        // Derive a 32-byte key via SHA-256 so any string config value works
        _key = SHA256.HashData(Encoding.UTF8.GetBytes(rawKey));
    }

    public string Encrypt(string plaintext)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.GenerateIV(); // Fresh random IV per encryption — critical for security

        using var encryptor = aes.CreateEncryptor();
        var plaintextBytes = Encoding.UTF8.GetBytes(plaintext);
        var cipherBytes = encryptor.TransformFinalBlock(plaintextBytes, 0, plaintextBytes.Length);

        // Prepend IV to ciphertext: [16 bytes IV][N bytes cipher]
        var result = new byte[aes.IV.Length + cipherBytes.Length];
        aes.IV.CopyTo(result, 0);
        cipherBytes.CopyTo(result, aes.IV.Length);

        return Convert.ToBase64String(result);
    }

    public string Decrypt(string ciphertext)
    {
        var fullBytes = Convert.FromBase64String(ciphertext);

        using var aes = Aes.Create();
        aes.Key = _key;

        // Extract IV from the first 16 bytes
        var iv = fullBytes[..16];
        var cipher = fullBytes[16..];

        aes.IV = iv;
        using var decryptor = aes.CreateDecryptor();
        var plaintextBytes = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);

        return Encoding.UTF8.GetString(plaintextBytes);
    }
}
