using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Nawakes.Domain.Common;
using Nawakes.Domain.Entities;
using Nawakes.Infrastructure.Persistence;

namespace Nawakes.Infrastructure.Persistence.Seed;

/// <summary>
/// Seeds the EDA master drug catalog. Supports an external CSV export
/// (tradeName,activeIngredient,strength,dosageForm,priceEGP,manufacturer,edaNumber,isChronic)
/// and otherwise seeds a curated built-in catalog of the most-demanded Egyptian medications.
/// Idempotent: existing normalized trade names are skipped.
/// </summary>
public sealed class EdaDrugSeeder(
    ApplicationDbContext context,
    ILogger<EdaDrugSeeder> logger)
{
    private const int BatchSize = 1000;

    public async Task<int> SeedAsync(string? csvPath = null, CancellationToken cancellationToken = default)
    {
        List<EgyptianDrugRegistry> records;

        if (!string.IsNullOrEmpty(csvPath) && File.Exists(csvPath))
        {
            records = LoadFromCsv(csvPath);
            logger.LogInformation("Loaded {Count} drug records from {Path}", records.Count, csvPath);
        }
        else
        {
            records = [.. BuiltInCatalog.Select(r => BuildRecord(
                r.TradeName, r.ActiveIngredient, r.Strength, r.DosageForm,
                r.PriceEGP, r.Manufacturer, r.IsChronic))];
        }

        var existing = (await context.EgyptianDrugRegistry
            .Select(d => d.TradeNameNormalized)
            .ToListAsync(cancellationToken))
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var toInsert = records
            .Where(r => !existing.Contains(r.TradeNameNormalized))
            .ToList();

        int inserted = 0;
        for (var i = 0; i < toInsert.Count; i += BatchSize)
        {
            var batch = toInsert.Skip(i).Take(BatchSize);
            context.EgyptianDrugRegistry.AddRange(batch);
            await context.SaveChangesAsync(cancellationToken);
            inserted += batch.Count();
        }

        logger.LogInformation("EDA catalog seeded: {Inserted} inserted, {Skipped} already present.",
            inserted, records.Count - inserted);
        return inserted;
    }

    private static List<EgyptianDrugRegistry> LoadFromCsv(string path)
    {
        var records = new List<EgyptianDrugRegistry>();
        foreach (var line in File.ReadLines(path))
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            var parts = line.Split(',');
            if (parts.Length < 4 || parts[0].StartsWith("tradeName", StringComparison.OrdinalIgnoreCase)) continue;

            records.Add(BuildRecord(
                parts[0].Trim(),
                parts.Length > 1 ? parts[1].Trim() : null,
                parts.Length > 2 ? parts[2].Trim() : null,
                parts.Length > 3 ? parts[3].Trim() : null,
                parts.Length > 4 ? DrugNameNormalizer.ParsePrice(parts[4]) : null,
                parts.Length > 5 ? parts[5].Trim() : null,
                parts.Length > 6 && bool.TryParse(parts[6].Trim(), out var chronic) && chronic));
        }
        return records;
    }

    private static EgyptianDrugRegistry BuildRecord(
        string tradeName, string? activeIngredient, string? strength,
        string? dosageForm, decimal? price, string? manufacturer, bool isChronic)
    {
        // Derive strength/form from the trade name when the columns are missing
        strength ??= DrugNameNormalizer.ExtractStrength(tradeName);
        dosageForm ??= DrugNameNormalizer.ExtractDosageForm(tradeName);

        return new EgyptianDrugRegistry
        {
            TradeName = tradeName,
            TradeNameNormalized = DrugNameNormalizer.NormalizeName(tradeName),
            ActiveIngredient = activeIngredient,
            ActiveIngredientNormalized = DrugNameNormalizer.NormalizeName(activeIngredient) is { Length: > 0 } ai ? ai : null,
            Strength = strength,
            DosageForm = dosageForm,
            OfficialPriceEGP = price,
            Manufacturer = manufacturer,
            EdaRegistrationNumber = null,
            IsChronic = isChronic
        };
    }

    private sealed record CatalogEntry(
        string TradeName, string? ActiveIngredient, string? Strength,
        string? DosageForm, decimal PriceEGP, string? Manufacturer, bool IsChronic);

    private static readonly CatalogEntry[] BuiltInCatalog =
    [
        // Cardiovascular
        new("Concor 5mg", "Bisoprolol Fumarate", "5mg", "Tablet", 42, "Merck", true),
        new("Concor 2.5mg", "Bisoprolol Fumarate", "2.5mg", "Tablet", 36, "Merck", true),
        new("Concor 10mg", "Bisoprolol Fumarate", "10mg", "Tablet", 55, "Merck", true),
        new("Bisor 5mg", "Bisoprolol Fumarate", "5mg", "Tablet", 28, "Borg", true),
        new("Concor 5mg (Arabic: كونكور)", null, null, null, 42, "Merck", true),
        new("Norvasc 5mg", "Amlodipine Besylate", "5mg", "Tablet", 45, "Pfizer", true),
        new("Amlodipine 5mg Sandoz", "Amlodipine Besylate", "5mg", "Tablet", 24, "Sandoz", true),
        new("Ateno 50mg", "Atenolol", "50mg", "Tablet", 18, "Amoun", true),
        new("Capoten 25mg", "Captopril", "25mg", "Tablet", 15, "Bristol", true),
        new("Zestril 10mg", "Lisinopril", "10mg", "Tablet", 40, "AstraZeneca", true),
        new("Lasix 40mg", "Furosemide", "40mg", "Tablet", 12, "Sanofi", true),

        // Diabetes
        new("Glucophage 1000mg", "Metformin Hydrochloride", "1000mg", "Tablet", 38, "Merck", true),
        new("Glucophage 500mg", "Metformin Hydrochloride", "500mg", "Tablet", 25, "Merck", true),
        new("Cidophage 1000mg", "Metformin Hydrochloride", "1000mg", "Tablet", 20, "CID", true),
        new("Cidophage 500mg", "Metformin Hydrochloride", "500mg", "Tablet", 14, "CID", true),
        new("Amaryl 3mg", "Glimepiride", "3mg", "Tablet", 52, "Sanofi", true),
        new("Amaryl 2mg", "Glimepiride", "2mg", "Tablet", 45, "Sanofi", true),
        new("Lantus SoloStar Pen 100IU/ml", "Insulin Glargine", "100IU/ml", "Pre-filled Pen", 320, "Sanofi", true),
        new("Mixtard 30 Pen 100IU/ml", "Insulin Human", "100IU/ml", "Pre-filled Pen", 190, "Novo Nordisk", true),
        new("NovoRapid Pen 100IU/ml", "Insulin Aspart", "100IU/ml", "Pre-filled Pen", 260, "Novo Nordisk", true),
        new("Januvia 100mg", "Sitagliptin", "100mg", "Tablet", 210, "Merck", true),
        new("Janumet 50/1000mg", "Sitagliptin + Metformin", "50/1000mg", "Tablet", 240, "Merck", true),

        // Anticoagulants
        new("Clexane 60mg Injection", "Enoxaparin Sodium", "60mg", "Injection", 480, "Sanofi", true),
        new("Clexane 40mg Injection", "Enoxaparin Sodium", "40mg", "Injection", 390, "Sanofi", true),
        new("Marevan 5mg", "Warfarin Sodium", "5mg", "Tablet", 30, "Amoun", true),
        new("Xarelto 20mg", "Rivaroxaban", "20mg", "Tablet", 550, "Bayer", true),
        new("Eliquis 5mg", "Apixaban", "5mg", "Tablet", 580, "BMS", true),

        // Antibiotics
        new("Augmentin 1gm", "Amoxicillin + Clavulanic Acid", "1000mg", "Tablet", 95, "GSK", false),
        new("Augmentin 625mg", "Amoxicillin + Clavulanic Acid", "625mg", "Tablet", 70, "GSK", false),
        new("Hibiotic 1gm", "Amoxicillin + Clavulanic Acid", "1000mg", "Tablet", 55, "Hikma", false),
        new("Zithromax 500mg", "Azithromycin", "500mg", "Tablet", 110, "Pfizer", false),
        new("Azrolid 500mg", "Azithromycin", "500mg", "Tablet", 45, "Borg", false),
        new("Klacid 500mg", "Clarithromycin", "500mg", "Tablet", 130, "Abbott", false),
        new("Ciprofar 500mg", "Ciprofloxacin", "500mg", "Tablet", 35, "Pharco", false),
        new("Velosef 500mg", "Cephradine", "500mg", "Capsule", 40, "Bristol", false),

        // Respiratory / Allergy
        new("Ventolin Inhaler 100mcg", "Salbutamol", "100mcg", "Spray", 65, "GSK", true),
        new("Flixotide Inhaler 125mcg", "Fluticasone", "125mcg", "Spray", 120, "GSK", true),
        new("Telfast 180mg", "Fexofenadine", "180mg", "Tablet", 60, "Sanofi", false),
        new("Rizolex 10mg", "Loratadine", "10mg", "Tablet", 20, "SigMA", false),
        new("Claritine 10mg", "Loratadine", "10mg", "Tablet", 42, "Bayer", false),

        // Analgesics / Anti-inflammatory
        new("Cataflam 50mg", "Diclofenac Potassium", "50mg", "Tablet", 35, "Novartis", false),
        new("Voltaren 75mg Ampoule", "Diclofenac Sodium", "75mg", "Injection", 28, "Novartis", false),
        new("Brufen 400mg", "Ibuprofen", "400mg", "Tablet", 22, "Abbott", false),
        new("Panadol Extra", "Paracetamol + Caffeine", "500mg", "Tablet", 25, "GSK", false),
        new("Adol 500mg", "Paracetamol", "500mg", "Tablet", 15, "Amoun", false),

        // Gastrointestinal
        new("Nexium 40mg", "Esomeprazole", "40mg", "Tablet", 140, "AstraZeneca", true),
        new("Nexium 20mg", "Esomeprazole", "20mg", "Tablet", 120, "AstraZeneca", true),
        new("Controloc 40mg", "Pantoprazole", "40mg", "Tablet", 100, "Takeda", true),
        new("Omez 20mg", "Omeprazole", "20mg", "Capsule", 25, "EIPICO", true),
        new("Buscopan 10mg", "Hyoscine Butylbromide", "10mg", "Tablet", 20, "Sanofi", false),
        new("Antinal", "Nifuroxazide", "200mg", "Capsule", 18, "Amoun", false),

        // Thyroid
        new("Eltroxin 100mcg", "Levothyroxine Sodium", "100mcg", "Tablet", 25, "GSK", true),
        new("Eltroxin 50mcg", "Levothyroxine Sodium", "50mcg", "Tablet", 20, "GSK", true),
        new("Thyrozole 5mg", "Thiamazole", "5mg", "Tablet", 22, "Amoun", true),

        // Vitamins / Supplements
        new("Centrum Adults", "Multivitamin", null, "Tablet", 180, "Pfizer", false),
        new("Vitamax Plus", "Multivitamin + Ginseng", null, "Capsule", 120, "SIGMA", false),
        new("Milga 800/200mg", "Vitamin B1 + B6 + B12", null, "Tablet", 45, "EVA Pharma", false),
        new("Ferrotron 200ml", "Iron + B-Complex", null, "Syrup", 55, "Borg", false),
        new("Cal-Mag 500mg", "Calcium Carbonate + Magnesium", "500mg", "Tablet", 40, "EVA Pharma", false),
        new("Osteocare 30Tab", "Calcium + Magnesium + Zinc + D3", null, "Tablet", 95, "Vitabiotics", false)
    ];
}
