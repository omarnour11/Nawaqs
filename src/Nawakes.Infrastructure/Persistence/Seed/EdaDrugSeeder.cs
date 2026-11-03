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
        new("Osteocare 30Tab", "Calcium + Magnesium + Zinc + D3", null, "Tablet", 95, "Vitabiotics", false),

        // ── Extended Egyptian market catalog (2025-2026 common EDA-priced items) ──
        // Analgesics / Antipyretics
        new("Panadol 500mg", "Paracetamol", "500mg", "Tablet", 18, "GSK", false),
        new("Panadol Advance 500mg", "Paracetamol", "500mg", "Tablet", 24, "GSK", false),
        new("Panadol Night", "Paracetamol + Diphenhydramine", "500mg", "Tablet", 30, "GSK", false),
        new("Adol Extra", "Paracetamol + Caffeine", "500mg", "Tablet", 22, "Amoun", false),
        new("Cetal 500mg", "Paracetamol", "500mg", "Tablet", 12, "Pharco", false),
        new("Paramol 500mg", "Paracetamol", "500mg", "Tablet", 10, "Medical Union", false),
        new("Rivo 500mg", "Paracetamol", "500mg", "Tablet", 10, "Riva", false),
        new("Perfalgan 1g IV", "Paracetamol", "1000mg", "Infusion", 60, "Bristol", false),
        new("Brufen 600mg", "Ibuprofen", "600mg", "Tablet", 30, "Abbott", false),
        new("Brufen 200mg", "Ibuprofen", "200mg", "Tablet", 15, "Abbott", false),
        new("Ibucap 400mg", "Ibuprofen + Paracetamol", "400mg", "Tablet", 24, "Amoun", false),
        new("Cataflam 25mg", "Diclofenac Potassium", "25mg", "Tablet", 20, "Novartis", false),
        new("Voltaren 50mg", "Diclofenac Sodium", "50mg", "Tablet", 26, "Novartis", false),
        new("Voltaren Gel 1%", "Diclofenac Diethylamine", "1%", "Gel", 55, "Novartis", false),
        new("Olfen 50mg", "Diclofenac Sodium", "50mg", "Tablet", 18, "SIGMA", false),
        new("Ketolac 10mg", "Ketorolac", "10mg", "Tablet", 20, "Amriya", false),
        new("Novalgin 500mg", "Metamizole Sodium", "500mg", "Tablet", 24, "Sanofi", false),
        new("Aspocid 75mg", "Acetylsalicylic Acid", "75mg", "Tablet", 8, "Chemipharm", true),
        new("Rivo Aspirin 81mg", "Acetylsalicylic Acid", "81mg", "Tablet", 10, "Riva", true),
        new("Solpadeine", "Paracetamol + Codeine + Caffeine", "500mg", "Tablet", 40, "GSK", false),
        new("Mobic 15mg", "Meloxicam", "15mg", "Tablet", 55, "Boehringer", false),
        new("Celebrex 200mg", "Celecoxib", "200mg", "Capsule", 85, "Pfizer", false),
        new("Arcoxia 90mg", "Etoricoxib", "90mg", "Tablet", 110, "Merck", false),
        new("Zerotol 90mg", "Etoricoxib", "90mg", "Tablet", 70, "Marcyrl", false),

        // Antibiotics (more)
        new("Hibiotic 625mg", "Amoxicillin + Clavulanic Acid", "625mg", "Tablet", 45, "Hikma", false),
        new("Curam 1gm", "Amoxicillin + Clavulanic Acid", "1000mg", "Tablet", 75, "Hikma", false),
        new("Megaclav 625mg", "Amoxicillin + Clavulanic Acid", "625mg", "Tablet", 48, "MUP", false),
        new("Amoxil 500mg", "Amoxicillin", "500mg", "Capsule", 25, "GSK", false),
        new("Flumox 500mg", "Flucloxacillin + Amoxicillin", "500mg", "Capsule", 30, "EIPICO", false),
        new("Klavox 1gm", "Amoxicillin + Clavulanic Acid", "1000mg", "Tablet", 60, "EVA Pharma", false),
        new("Zinadol 250mg", "Roxithromycin", "250mg", "Tablet", 60, "Eva", false),
        new("Vibramycin 100mg", "Doxycycline", "100mg", "Capsule", 35, "Pfizer", false),
        new("Doxy 100mg", "Doxycycline", "100mg", "Capsule", 20, "Pharco", false),
        new("Unictam 375mg", "Sultamicillin", "375mg", "Tablet", 55, "Pfizer", false),
        new("Ospexin 500mg", "Cefalexin", "500mg", "Capsule", 28, "Bristol", false),
        new("Ceporex 500mg", "Cefalexin", "500mg", "Capsule", 30, "GSK", false),
        new("Duricef 500mg", "Cefadroxil", "500mg", "Capsule", 40, "Bristol", false),
        new("Suprax 400mg", "Cefixime", "400mg", "Capsule", 95, "Sanofi", false),
        new("Cefix 400mg", "Cefixime", "400mg", "Tablet", 70, "Hikma", false),
        new("Cefotax 1gm", "Cefotaxime", "1000mg", "Injection", 30, "Hikma", false),
        new("Cefaxone 1gm", "Ceftriaxone", "1000mg", "Injection", 40, "EIPICO", false),
        new("Epicephin 1gm", "Ceftriaxone", "1000mg", "Injection", 35, "EIPICO", false),
        new("Tavanic 500mg", "Levofloxacin", "500mg", "Tablet", 120, "Sanofi", false),
        new("Levaquin 500mg", "Levofloxacin", "500mg", "Tablet", 130, "J&J", false),
        new("Ciprodar 500mg", "Ciprofloxacin", "500mg", "Tablet", 28, "Dar El Dawa", false),
        new("Fucidin 500mg", "Fusidic Acid", "500mg", "Tablet", 65, "Leo", false),
        new("Fucidin Cream 2%", "Fusidic Acid", "2%", "Cream", 45, "Leo", false),
        new("Flagyl 500mg", "Metronidazole", "500mg", "Tablet", 22, "Sanofi", false),
        new("Amrizole 500mg", "Metronidazole", "500mg", "Tablet", 15, "Amriya", false),
        new("Klont 500mg", "Clindamycin", "500mg", "Capsule", 80, "Hikma", false),
        new("Dalacin C 300mg", "Clindamycin", "300mg", "Capsule", 95, "Pfizer", false),

        // Respiratory / Cough & Cold
        new("Ventolin Syrup", "Salbutamol", "2mg/5ml", "Syrup", 20, "GSK", false),
        new("Farcolin Syrup", "Salbutamol", "2mg/5ml", "Syrup", 15, "Pharco", false),
        new("Aerolin Spray", "Salbutamol", "100mcg", "Spray", 55, "GSK", true),
        new("Sultolin Spray", "Salbutamol", "100mcg", "Spray", 40, "SULTAN", true),
        new("Serevent Inhaler", "Salmeterol", "25mcg", "Spray", 95, "GSK", true),
        new("Seretide Inhaler 250", "Salmeterol + Fluticasone", "250mcg", "Spray", 210, "GSK", true),
        new("Symbicort Inhaler 160/4.5", "Budesonide + Formoterol", "160/4.5mcg", "Spray", 240, "AstraZeneca", true),
        new("Singulair 10mg", "Montelukast", "10mg", "Tablet", 180, "Merck", true),
        new("Kastair 10mg", "Montelukast", "10mg", "Tablet", 80, "Amoun", true),
        new("Montika 10mg", "Montelukast", "10mg", "Tablet", 65, "Hikma", true),
        new("Rhinopront", "Carbinoxamine", null, "Capsule", 25, "Amoun", false),
        new("Sinupret", "Herbal Sinus Formula", null, "Tablet", 70, "Bionorica", false),
        new("Comtrex", "Paracetamol + Pseudoephedrine", null, "Tablet", 30, "GSK", false),
        new("Flustat", "Paracetamol + Pseudoephedrine", null, "Capsule", 25, "Amoun", false),
        new("Panadol Cold & Flu", "Paracetamol + Phenylephrine", "500mg", "Tablet", 32, "GSK", false),
        new("Bronchicum Syrup", "Thyme Herbal Extract", null, "Syrup", 45, "Sanofi", false),
        new("Balsam Syrup", "Herbal Expectorant", null, "Syrup", 22, "MUP", false),
        new("Selgon", "Pipazethate", "20mg", "Tablet", 24, "Amoun", false),
        new("Toplexil Syrup", "Oxomemazine + Guaifenesin", null, "Syrup", 28, "Sanofi", false),
        new("Notussil Syrup", "Butamirate", null, "Syrup", 40, "EVA Pharma", false),
        new("Mucophylline Syrup", "Bromhexine + Theophylline", null, "Syrup", 20, "MUP", false),
        new("Mucosol 30mg", "Carbocisteine", "30mg", "Syrup", 25, "EIPICO", false),
        new("Bisolvon 8mg", "Bromhexine", "8mg", "Tablet", 20, "Boehringer", false),

        // Antihistamines
        new("Zyrtec 10mg", "Cetirizine", "10mg", "Tablet", 45, "UCB", false),
        new("Cetrizet 10mg", "Cetirizine", "10mg", "Tablet", 18, "Dr. Reddy's", false),
        new("Xyzal 5mg", "Levocetirizine", "5mg", "Tablet", 60, "UCB", false),
        new("Claritine Syrup", "Loratadine", "5mg/5ml", "Syrup", 48, "Bayer", false),
        new("Telfast Syrup", "Fexofenadine", "30mg/5ml", "Syrup", 55, "Sanofi", false),
        new("Anallerge", "Chlorpheniramine", null, "Tablet", 8, "Amoun", false),
        new("Toplexil expectorant", "Oxomemazine", null, "Syrup", 28, "Sanofi", false),

        // Cardiovascular (more)
        new("Concor Plus", "Bisoprolol + Hydrochlorothiazide", "5/6.25mg", "Tablet", 55, "Merck", true),
        new("Lopressor 100mg", "Metoprolol Tartrate", "100mg", "Tablet", 30, "Novartis", true),
        new("Betaloc 100mg", "Metoprolol", "100mg", "Tablet", 32, "AstraZeneca", true),
        new("Dilatrend 25mg", "Carvedilol", "25mg", "Tablet", 60, "Roche", true),
        new("Cortone 25mg", "Carvedilol", "25mg", "Tablet", 35, "Amoun", true),
        new("Tritace 5mg", "Ramipril", "5mg", "Tablet", 65, "Sanofi", true),
        new("Ramistar 5mg", "Ramipril", "5mg", "Tablet", 30, "Marcyrl", true),
        new("Tritace 10mg", "Ramipril", "10mg", "Tablet", 90, "Sanofi", true),
        new("Enalapril 10mg", "Enalapril Maleate", "10mg", "Tablet", 15, "Amoun", true),
        new("Norton 10mg", "Enalapril", "10mg", "Tablet", 14, "Nile", true),
        new("Cozaar 50mg", "Losartan Potassium", "50mg", "Tablet", 90, "Merck", true),
        new("Angisartan 50mg", "Losartan", "50mg", "Tablet", 45, "Amoun", true),
        new("Diovan 160mg", "Valsartan", "160mg", "Tablet", 140, "Novartis", true),
        new("Valsacor 160mg", "Valsartan", "160mg", "Tablet", 60, "Borg", true),
        new("Exforge 5/160mg", "Amlodipine + Valsartan", "5/160mg", "Tablet", 185, "Novartis", true),
        new("Micardis 40mg", "Telmisartan", "40mg", "Tablet", 120, "Boehringer", true),
        new("Micardis Plus 80/12.5", "Telmisartan + HCT", "80/12.5mg", "Tablet", 160, "Boehringer", true),
        new("Atacand 8mg", "Candesartan", "8mg", "Tablet", 100, "AstraZeneca", true),
        new("Nifedicron 10mg", "Nifedipine Retard", "10mg", "Tablet", 20, "Amoun", true),
        new("Adalat Oros 30mg", "Nifedipine", "30mg", "Tablet", 75, "Bayer", true),
        new("Isoptin Retard 240mg", "Verapamil", "240mg", "Tablet", 45, "Abbott", true),
        new("Cardiolite retard 240", "Verapamil", "240mg", "Tablet", 30, "EIPICO", true),
        new("Tarka 2/180mg", "Trandolapril + Verapamil", "2/180mg", "Tablet", 130, "Abbott", true),
        new("Mexitil 50mg", "Mexiletine", "50mg", "Capsule", 60, "Boehringer", false),
        new("Atenolol 50mg", "Atenolol", "50mg", "Tablet", 12, "Amoun", true),
        new("Tenormin 50mg", "Atenolol", "50mg", "Tablet", 20, "AstraZeneca", true),
        new("Lasix 20mg", "Furosemide", "20mg", "Tablet", 8, "Sanofi", true),
        new("Aldactone 25mg", "Spironolactone", "25mg", "Tablet", 30, "Pfizer", true),
        new("Dytor 10mg", "Torasemide", "10mg", "Tablet", 40, "Amoun", true),
        new("Aquarese 10mg", "Torasemide", "10mg", "Tablet", 28, "Marcyrl", true),
        new("Zestril 5mg", "Lisinopril", "5mg", "Tablet", 30, "AstraZeneca", true),
        new("Capoten 50mg", "Captopril", "50mg", "Tablet", 18, "Bristol", true),
        new("Digoxin 0.25mg", "Digoxin", "0.25mg", "Tablet", 12, "Amoun", true),
        new("Nitromak Retard 2.5", "Nitroglycerin", "2.5mg", "Capsule", 25, "Hikma", true),
        new("Nitrocontin 2.6", "Nitroglycerin", "2.6mg", "Tablet", 30, "Modipharm", true),
        new("Isordil 5mg", "Isosorbide Dinitrate", "5mg", "Sublingual Tablet", 20, "Amoun", true),
        new("Monis 40mg", "Isosorbide Mononitrate", "40mg", "Tablet", 40, "EVA Pharma", true),
        new("Atupros 10mg", "Bisoprolol", "10mg", "Tablet", 40, "Atos", true),

        // Lipids
        new("Lipitor 20mg", "Atorvastatin", "20mg", "Tablet", 95, "Pfizer", true),
        new("Ator 40mg", "Atorvastatin", "40mg", "Tablet", 45, "EIPICO", true),
        new("Lipiget 20mg", "Atorvastatin", "20mg", "Tablet", 35, "Hikma", true),
        new("Lescol 80mg", "Fluvastatin", "80mg", "Capsule", 110, "Novartis", true),
        new("Crestor 10mg", "Rosuvastatin", "10mg", "Tablet", 120, "AstraZeneca", true),
        new("Rovar 10mg", "Rosuvastatin", "10mg", "Tablet", 50, "Marcyrl", true),
        new("Vastarel MR 35mg", "Trimetazidine", "35mg", "Tablet", 55, "Servier", true),
        new("Preductal MR 35mg", "Trimetazidine", "35mg", "Tablet", 60, "Servier", true),
        new("Gemfibrozil 450mg", "Gemfibrozil", "450mg", "Tablet", 45, "Pfizer", true),

        // Diabetes (more)
        new("Glucophage XR 750mg", "Metformin ER", "750mg", "Tablet", 45, "Merck", true),
        new("Siofor 1000mg", "Metformin", "1000mg", "Tablet", 40, "Berlin-Chemie", true),
        new("Diamicron MR 60mg", "Gliclazide", "60mg", "Tablet", 70, "Servier", true),
        new("Reclide MR 60mg", "Gliclazide", "60mg", "Tablet", 40, "Amoun", true),
        new("Novonorm 2mg", "Repaglinide", "2mg", "Tablet", 80, "Novo Nordisk", true),
        new("Starlix 120mg", "Nateglinide", "120mg", "Tablet", 95, "Novartis", true),
        new("Avandia 4mg", "Rosiglitazone", "4mg", "Tablet", 110, "GSK", true),
        new("Actos 30mg", "Pioglitazone", "30mg", "Tablet", 120, "Takeda", true),
        new("Galvus 50mg", "Vildagliptin", "50mg", "Tablet", 180, "Novartis", true),
        new("Jalra 50mg", "Vildagliptin", "50mg", "Tablet", 120, "USV", true),
        new("Galvumet 50/1000", "Vildagliptin + Metformin", "50/1000mg", "Tablet", 200, "Novartis", true),
        new("Forxiga 10mg", "Dapagliflozin", "10mg", "Tablet", 260, "AstraZeneca", true),
        new("Jardiance 25mg", "Empagliflozin", "25mg", "Tablet", 290, "Boehringer", true),
        new("Ozempic 1mg Pen", "Semaglutide", "1mg", "Pre-filled Pen", 1800, "Novo Nordisk", true),
        new("Rybelsus 14mg", "Semaglutide", "14mg", "Tablet", 1600, "Novo Nordisk", true),
        new("Saxenda Pen 3ml", "Liraglutide", "3mg", "Pre-filled Pen", 2600, "Novo Nordisk", false),
        new("Victoza Pen", "Liraglutide", "1.8mg", "Pre-filled Pen", 1400, "Novo Nordisk", true),
        new("Toujeo SoloStar", "Insulin Glargine U300", "300IU/ml", "Pen", 450, "Sanofi", true),
        new("Levemir Pen", "Insulin Detemir", "100IU/ml", "Pen", 380, "Novo Nordisk", true),
        new("Humalog Pen", "Insulin Lispro", "100IU/ml", "Pen", 300, "Lilly", true),
        new("Apidra Pen", "Insulin Glulisine", "100IU/ml", "Pen", 310, "Sanofi", true),

        // GI (more)
        new("Nexium Control 20mg", "Esomeprazole", "20mg", "Tablet", 90, "Pfizer", false),
        new("Emanera 40mg", "Esomeprazole", "40mg", "Tablet", 85, "Hikma", true),
        new("Losec 20mg", "Omeprazole", "20mg", "Capsule", 55, "AstraZeneca", true),
        new("Omezolan 20mg", "Omeprazole", "20mg", "Capsule", 22, "Pharco", true),
        new("Risek 20mg", "Omeprazole", "20mg", "Capsule", 45, "Getz", true),
        new("Pantoloc 40mg", "Pantoprazole", "40mg", "Tablet", 90, "Takeda", true),
        new("Pan 40mg", "Pantoprazole", "40mg", "Tablet", 40, "Alcobra", true),
        new("Pantoloc Control 20", "Pantoprazole", "20mg", "Tablet", 60, "Takeda", false),
        new("Rani 300mg", "Ranitidine", "300mg", "Tablet", 15, "Amoun", false),
        new("Zantac 300mg", "Ranitidine", "300mg", "Tablet", 20, "GSK", false),
        new("Gaviscon Advance", "Sodium Alginate", null, "Suspension", 85, "Reckitt", false),
        new("Gaviscon 200ml", "Alginate/Antacid", null, "Suspension", 60, "Reckitt", false),
        new("Maalox Plus", "Aluminium + Magnesium + Simethicone", null, "Suspension", 35, "Sanofi", false),
        new("Epicogel suspension", "Antacid + Simethicone", null, "Suspension", 25, "EIPICO", false),
        new("Motilium 10mg", "Domperidone", "10mg", "Tablet", 28, "J&J", false),
        new("Gastreg 10mg", "Domperidone", "10mg", "Tablet", 15, "Amoun", false),
        new("Dyssecan", "Alizapride", null, "Tablet", 22, "Amoun", false),
        new("Navoban 5mg", "Tropisetron", "5mg", "Capsule", 70, "Novartis", false),
        new("Buscopan Plus", "Hyoscine + Paracetamol", "10/500mg", "Tablet", 30, "Sanofi", false),
        new("Coloverin 200mg", "Mebeverine", "200mg", "Tablet", 35, "Amoun", false),
        new("Duspatalin Retard 200", "Mebeverine", "200mg", "Capsule", 48, "Abbott", false),
        new("Colona 100mg", "Pinaverium", "100mg", "Tablet", 40, "Eva", false),
        new("Antinal suspension", "Nifuroxazide", "220mg/5ml", "Suspension", 20, "Amoun", false),
        new("Streptoquin", "Antidiarrheal Combination", null, "Tablet", 12, "Amoun", false),
        new("Enterogermina 2B", "Bacillus Clausii", "2Billion", "Oral Vial", 60, "Sanofi", false),
        new("Lacteol Forte", "Lactobacillus", "340mg", "Capsule", 45, "Hikma", false),
        new("Duphalac 300ml", "Lactulose", null, "Syrup", 55, "Abbott", false),
        new("Duphalac Sachets", "Lactulose", "10g", "Sachet", 50, "Abbott", false),
        new("Dulcolax 5mg", "Bisacodyl", "5mg", "Tablet", 30, "Boehringer", false),
        new("Agiolax Granules", "Plantago + Senna", null, "Granules", 40, "Sanofi", false),
        new("Fleet Phospho Soda", "Sodium Phosphate", null, "Oral Solution", 45, "C.B. Fleet", false),

        // Urinary / Renal
        new("Vesicare 5mg", "Solifenacin", "5mg", "Tablet", 160, "Astellas", true),
        new("Detrusiol 2mg", "Tolterodine", "2mg", "Tablet", 80, "Pfizer", true),
        new("Urispas 200mg", "Flavoxate", "200mg", "Tablet", 40, "Amoun", false),
        new("Monurol 3g", "Fosfomycin", "3g", "Sachet", 95, "Zambon", false),
        new("Cran-Max", "Cranberry Extract", null, "Capsule", 90, "SIGMA", false),
        new("Uribel", "Urinary Antiseptic Combo", null, "Tablet", 35, "MUP", false),
        new("Pramipex 0.5mg", "Pramipexole", "0.5mg", "Tablet", 90, "Boehringer", true),
        new("Ketosteril", "Ketoanalogues", null, "Tablet", 320, "Fresenius", true),

        // Neuro / Psych
        new("Cipralex 10mg", "Escitalopram", "10mg", "Tablet", 170, "Lundbeck", true),
        new("Cipralex 5mg", "Escitalopram", "5mg", "Tablet", 140, "Lundbeck", true),
        new("Seroquel 25mg", "Quetiapine", "25mg", "Tablet", 110, "AstraZeneca", true),
        new("Zoloft 50mg", "Sertraline", "50mg", "Tablet", 130, "Pfizer", true),
        new("Prozac 20mg", "Fluoxetine", "20mg", "Capsule", 90, "Lilly", true),
        new("Depalex 500mg", "Divalproex Sodium", "500mg", "Tablet", 110, "Sanofi", true),
        new("Tegretol 200mg", "Carbamazepine", "200mg", "Tablet", 45, "Novartis", true),
        new("Tegretol CR 400", "Carbamazepine", "400mg", "Tablet", 70, "Novartis", true),
        new("Lamictal 50mg", "Lamotrigine", "50mg", "Tablet", 130, "GSK", true),
        new("Keppra 500mg", "Levetiracetam", "500mg", "Tablet", 220, "UCB", true),
        new("Keppra Syrup", "Levetiracetam", "100mg/ml", "Syrup", 280, "UCB", true),
        new("Topamax 25mg", "Topiramate", "25mg", "Tablet", 120, "J&J", true),
        new("Neurontin 300mg", "Gabapentin", "300mg", "Capsule", 95, "Pfizer", false),
        new("Gabapin 300mg", "Gabapentin", "300mg", "Capsule", 40, "Intas", false),
        new("Lyrica 75mg", "Pregabalin", "75mg", "Capsule", 160, "Pfizer", false),
        new("Valium 5mg", "Diazepam", "5mg", "Tablet", 20, "Roche", false),
        new("Xanax 0.5mg", "Alprazolam", "0.5mg", "Tablet", 30, "Pfizer", false),
        new("Atarax 25mg", "Hydroxyzine", "25mg", "Tablet", 25, "Pfizer", false),
        new("Rivotril 2mg", "Clonazepam", "2mg", "Tablet", 35, "Roche", false),
        new("Zolam 0.5mg", "Alprazolam", "0.5mg", "Tablet", 20, "Amoun", false),
        new("Zopiclone 7.5mg", "Zopiclone", "7.5mg", "Tablet", 55, "Amoun", false),
        new("Imigran 50mg", "Sumatriptan", "50mg", "Tablet", 180, "GSK", false),
        new("Zomig 2.5mg", "Zolmitriptan", "2.5mg", "Tablet", 190, "AstraZeneca", false),
        new("Panlor", "Acetaminophen Combo", null, "Tablet", 35, "Amoun", false),
        new("Migrastat", "Herbal Migraine Formula", null, "Tablet", 60, "MUP", false),
        new("Bilival 40mg", "Bilastine", "40mg", "Tablet", 70, "Menarini", false),

        // Ophthalmic / ENT (drops — matching the new decoder support)
        new("Tobrex Eye Drops", "Tobramycin", "0.3%", "Eye Drops", 35, "Alcon", false),
        new("Tobradex Eye Drops", "Tobramycin + Dexamethasone", "0.3/0.1%", "Eye Drops", 55, "Alcon", false),
        new("Vigamox Eye Drops", "Moxifloxacin", "0.5%", "Eye Drops", 75, "Novartis", false),
        new("Optive Eye Drops", "Carboxymethylcellulose", "0.5%", "Eye Drops", 90, "Allergan", false),
        new("Systane Ultra Drops", "Polyethylene Glycol", null, "Eye Drops", 110, "Alcon", false),
        new("Refresh Tears Drops", "Carboxymethylcellulose", "0.5%", "Eye Drops", 60, "Allergan", false),
        new("Timoptic 0.5%", "Timolol Maleate", "0.5%", "Eye Drops", 45, "Merck", true),
        new("Trusopt Drops", "Dorzolamide", "2%", "Eye Drops", 95, "Merck", true),
        new("Xalatan Eye Drops", "Latanoprost", "0.005%", "Eye Drops", 220, "Pfizer", true),
        new("Oftan Tiloc Drops", "Tilidazole Combo", null, "Eye Drops", 40, "Santen", false),
        new("Otal Ear Drops", "Lidocaine + Phenazone", null, "Ear Drops", 30, "EIPICO", false),
        new("Epifenac Drops", "Diclofenac Sodium", "0.1%", "Eye Drops", 28, "EIPICO", false),

        // Dermatological
        new("Betnovate Cream", "Betamethasone", "0.1%", "Cream", 25, "GSK", false),
        new("Dermovate Cream", "Clobetasol", "0.05%", "Cream", 40, "GSK", false),
        new("Elocon Cream", "Mometasone", "0.1%", "Cream", 45, "Merck", false),
        new("Quadriderm Cream", "Betamethasone + Gentamicin + Clotrimazole", null, "Cream", 35, "Merck", false),
        new("Canesten Cream 1%", "Clotrimazole", "1%", "Cream", 30, "Bayer", false),
        new("Daktarin Cream 2%", "Miconazole", "2%", "Cream", 28, "J&J", false),
        new("Daktacort Cream", "Miconazole + Hydrocortisone", null, "Cream", 38, "J&J", false),
        new("Fucidin H Cream", "Fusidic Acid + Hydrocortisone", null, "Cream", 50, "Leo", false),
        new("Bactroban Cream 2%", "Mupirocin", "2%", "Cream", 70, "GSK", false),
        new("Clotrimazole Vaginal Tablets", "Clotrimazole", "500mg", "Vaginal Tablet", 25, "Bayer", false),
        new("Povidone Iodine 10%", "Povidone-Iodine", "10%", "Solution", 22, "MUP", false),
        new("Curacne 20mg", "Isotretinoin", "20mg", "Capsule", 85, "Hikma", false),
        new("Roaccutane 20mg", "Isotretinoin", "20mg", "Capsule", 180, "Roche", false),
        new("Skinoren Cream 20%", "Azelaic Acid", "20%", "Cream", 95, "Bayer", false),
        new("Acretin Cream 0.025%", "Tretinoin", "0.025%", "Cream", 40, "EIPICO", false),
        new("Differin Gel 0.1%", "Adapalene", "0.1%", "Gel", 110, "Galderma", false),

        // Hormones / Endocrine
        new("Prednisolone 5mg", "Prednisolone", "5mg", "Tablet", 10, "Amoun", false),
        new("Betasonide 0.5mg", "Betamethasone", "0.5mg", "Tablet", 15, "Schering", false),
        new("Decadron 4mg", "Dexamethasone", "4mg", "Tablet", 18, "Merck", false),
        new("Medrol 16mg", "Methylprednisolone", "16mg", "Tablet", 65, "Pfizer", false),
        new("Solu-Medrol 500mg", "Methylprednisolone", "500mg", "Injection", 180, "Pfizer", false),
        new("Cortisone 25mg", "Cortisone Acetate", "25mg", "Tablet", 12, "Amoun", true),
        new("Ovestin Cream", "Estriol", "0.1%", "Vaginal Cream", 95, "Organon", false),
        new("Cyclo-Progynova", "Estradiol + Norgestrel", null, "Tablet", 60, "Bayer", false),
        new("Prontogest 200 Amp", "Progesterone", "200mg", "Injection", 45, "AMSAT", false),
        new("Duphaston 10mg", "Dydrogesterone", "10mg", "Tablet", 85, "Abbott", false),
        new("Crinone Gel", "Progesterone", "8%", "Vaginal Gel", 180, "Merck", false),
        new("Clomid 50mg", "Clomiphene", "50mg", "Tablet", 45, "Sanofi", false),
        new("Cidolut Nor 5mg", "Norethisterone", "5mg", "Tablet", 25, "CID", false),
        new("Primolut Nor 5mg", "Norethisterone", "5mg", "Tablet", 35, "Bayer", false),
        new("L thyroxin 100mcg", "Levothyroxine", "100mcg", "Tablet", 30, "Berlin-Chemie", true),
        new("Thyrox 100mcg", "Levothyroxine", "100mcg", "Tablet", 20, "Amoun", true),
        new("Neomercazole 5mg", "Carbimazole", "5mg", "Tablet", 20, "Nicholas", true),
        new("Zollinger 20mcg", "Cinacalcet", "30mg", "Tablet", 350, "Amoun", true),

        // Musculoskeletal
        new("Myonal 50mg", "Eperisone", "50mg", "Tablet", 45, "Eisai", false),
        new("Mydocalm 50mg", "Tolperisone", "50mg", "Tablet", 40, "Gedeon", false),
        new("Collagenase / Chymoral", "Trypsin + Chymotrypsin", null, "Tablet", 60, "Amoun", false),
        new("Calcium Sandoz Forte", "Calcium Carbonate", "600mg", "Tablet", 60, "Sandoz", false),
        new("Osteocare Plus", "Calcium + Omega-3", null, "Tablet", 140, "Vitabiotics", false),
        new("Depophos 50mg", "Methylprednisolone Acetate", "50mg", "Injection", 55, "Pfizer", false),
        new("Diclomax retard 100", "Diclofenac", "100mg", "Capsule", 30, "Hikma", false),
        new("Rheumafen 100mg", "Diclofenac", "100mg", "Suppository", 15, "Amoun", false),
        new("VOLTAREN suppository 100", "Diclofenac", "100mg", "Suppository", 26, "Novartis", false),

        // Hematology
        new("Feroglobin Capsules", "Iron + B12 + Zinc", null, "Capsule", 70, "Vitabiotics", false),
        new("Ferrofol 100mg", "Ferrous Fumarate", "100mg", "Tablet", 18, "Amoun", false),
        new("Ferrograd F", "Iron + Folic Acid", null, "Tablet", 40, "Abbott", false),
        new("Fefol", "Iron + Folic Acid", null, "Capsule", 42, "GSK", false),
        new("Duru Iron Syrup", "Iron", null, "Syrup", 25, "Sato", false),
        new("Concor Folic 5", "Bisoprolol + Folic Acid", null, "Tablet", 50, "Merck", true),
        new("Folicap 500mcg", "Folic Acid", "500mcg", "Tablet", 10, "EIPICO", false),
        new("Cys-Control", "Cranberry Extract", null, "Sachet", 130, "Bioserena", false),

        // Urology / BPH
        new("Avodart 0.5mg", "Dutasteride", "0.5mg", "Capsule", 210, "GSK", true),
        new("Proscar 5mg", "Finasteride", "5mg", "Tablet", 160, "Merck", true),
        new("Finasteride 5mg Sandoz", "Finasteride", "5mg", "Tablet", 60, "Sandoz", true),
        new("Tamsulosin 0.4mg", "Tamsulosin", "0.4mg", "Capsule", 80, "Boehringer", true),
        new("Pradif T 0.4", "Tamsulosin", "0.4mg", "Capsule", 70, "Amoun", true),
        new("Cardura 4mg", "Doxazosin", "4mg", "Tablet", 75, "Pfizer", true),

        // More vitamins / common supplements
        new("Vitamin D3 50000 IU", "Cholecalciferol", "50000IU", "Capsule", 30, "MUP", false),
        new("Devarol-S 200K", "Cholecalciferol", "200000IU", "Oral Vial", 15, "Amoun", false),
        new("Vidrop", "Cholecalciferol", "2800IU/ml", "Oral Drops", 12, "Medical Union", false),
        new("Osteo D3 Sachets", "Calcium + D3", null, "Sachet", 80, "Hikma", false),
        new("Ferrose F Syrup", "Iron + Folic Acid", null, "Syrup", 20, "Eva", false),
        new("Neurobion Amp", "Vitamins B1+B6+B12", null, "Injection", 20, "Merck", false),
        new("Depovit B12", "Hydroxocobalamin", "1000mcg", "Injection", 15, "EVA Pharma", false),
        new("Thiotacid 600", "Thioctic Acid", "600mg", "Tablet", 120, "Eva", true),
        new("Alpha Lipoic 600", "Thioctic Acid", "600mg", "Capsule", 60, "MUP", true),
        new("Vitamax Immune", "Multivitamin + Zinc", null, "Effervescent", 90, "SIGMA", false),
        new("Redoxon Effervescent", "Vitamin C", "1000mg", "Effervescent", 60, "Bayer", false),
        new("C-Retard 500", "Vitamin C", "500mg", "Capsule", 30, "EIPICO", false),
        new("Centrum Women", "Multivitamin Women", null, "Tablet", 220, "Pfizer", false),
        new("Pregnacare", "Prenatal Multivitamin", null, "Tablet", 165, "Vitabiotics", false),
        new("Ferrotron Drops", "Iron Pediatric", null, "Oral Drops", 22, "Borg", false),
        new("Zinctron", "Zinc + Vitamins", null, "Capsule", 45, "Borg", false),
        new("Sangobion", "Iron + Vitamins", null, "Capsule", 55, "Merck", false),

        // Liquids & pediatric (verify decoder drops/suspension paths)
        new("Augmentin ES Suspension", "Amoxicillin + Clavulanic Acid", "600mg/5ml", "Suspension", 120, "GSK", false),
        new("Zithromax Suspension", "Azithromycin", "200mg/5ml", "Suspension", 90, "Pfizer", false),
        new("Betadine Gargle", "Povidone-Iodine", "1%", "Gargle Solution", 25, "Mundipharma", false),
        new("Otrivin Nasal Spray", "Xylometazoline", "0.1%", "Nasal Spray", 30, "Novartis", false),
        new("Sinupret Drops", "Herbal Sinus Formula", null, "Oral Drops", 75, "Bionorica", false),
        new("Salin Nasal Spray", "Sodium Chloride", "0.65%", "Nasal Spray", 25, "Sigma", false),
        new("Flixonase Nasal Spray", "Fluticasone", "50mcg", "Nasal Spray", 95, "GSK", false),
        new("Nasonex Nasal Spray", "Mometasone", "50mcg", "Nasal Spray", 110, "Merck", false),
        new("Ventolin Nebulising Solution", "Salbutamol", "5mg/ml", "Nebuliser Solution", 35, "GSK", true),
        new("Bricanyl 5mg", "Terbutaline", "5mg", "Tablet", 30, "AstraZeneca", true),
        new("Insulin Syringes 1ml", "Single-Use Syringe", "1ml", "Device", 15, "Various", false),
        new("Accu-Chek Strips 50", "Glucose Test Strips", "50", "Device", 260, "Roche", false),
        new("Contour Plus Strips 50", "Glucose Test Strips", "50", "Device", 220, "Ascensia", false)
    ];
}
