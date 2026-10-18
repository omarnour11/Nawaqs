using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Nawakes.Domain.Entities;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Identity;
using Nawakes.Infrastructure.Persistence;
using Nawakes.Infrastructure.Persistence.Seed;
using NetTopologySuite.Geometries;

namespace Nawakes.API.Extensions;

public static class DatabaseSeeder
{
    public static async Task SeedDatabaseAsync(this WebApplication app)
    {
        using var scope = app.Services.CreateScope();
        var services = scope.ServiceProvider;

        try
        {
            var context = services.GetRequiredService<ApplicationDbContext>();
            var userManager = services.GetRequiredService<UserManager<ApplicationUser>>();
            var roleManager = services.GetRequiredService<RoleManager<ApplicationRole>>();

            // 1. Apply migrations automatically
            if (context.Database.IsSqlServer())
            {
                await context.Database.MigrateAsync();
            }

            // 2. Seed Roles
            var roles = new[] { UserRole.Patient.ToString(), UserRole.PharmacyOwner.ToString(), UserRole.Admin.ToString() };
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role))
                {
                    await roleManager.CreateAsync(new ApplicationRole { Name = role, NormalizedName = role.ToUpper() });
                }
            }

            // 3. Seed Users
            await CreateUserAsync(userManager, "patient@nawaqs.com", "Ahmed", "Hassan", UserRole.Patient.ToString());
            await CreateUserAsync(userManager, "pharmacy@nawaqs.com", "Omar", "Nour", UserRole.PharmacyOwner.ToString());
            await CreateUserAsync(userManager, "pharmacy2@nawaqs.com", "Laila", "Mansour", UserRole.PharmacyOwner.ToString());
            await CreateUserAsync(userManager, "pharmacy3@nawaqs.com", "Youssef", "Farid", UserRole.PharmacyOwner.ToString());
            await CreateUserAsync(userManager, "admin@nawaqs.com", "Admin", "User", UserRole.Admin.ToString());

            // 4. Seed Pharmacies + Inventory (idempotent — skips owners that already have a pharmacy)
            await SeedPharmacyAsync(context, userManager, "pharmacy@nawaqs.com",
                "Nawaqs Pharmacy — Downtown", "15 Talaat Harb St, Downtown", "Cairo", "01012345678",
                30.0476, 31.2365);
            await SeedPharmacyAsync(context, userManager, "pharmacy2@nawaqs.com",
                "El Nozha Pharmacy", "12 El Nozha St, Nasr City", "Cairo", "01123456789",
                30.0595, 31.3305);
            await SeedPharmacyAsync(context, userManager, "pharmacy3@nawaqs.com",
                "Zamalek Care Pharmacy", "8 Brasil St, Zamalek", "Cairo", "01234567890",
                30.0624, 31.2150);
            await SeedPharmacyAsync(context, userManager, "admin@nawaqs.com",
                "Nawaqs Central Pharmacy", "100 El Zamalek Corniche", "Cairo", "01555555555",
                30.0555, 31.2200, ownerIsAdmin: true);

            // 5. Seed the EDA master drug catalog (idempotent)
            var drugSeeder = services.GetRequiredService<EdaDrugSeeder>();
            await drugSeeder.SeedAsync();
        }
        catch (Exception ex)
        {
            var logger = services.GetRequiredService<ILogger<Program>>();
            logger.LogError(ex, "An error occurred while seeding the database.");
        }
    }

    private static async Task CreateUserAsync(UserManager<ApplicationUser> userManager, string email, string firstName, string lastName, string roleStr)
    {
        if (await userManager.FindByEmailAsync(email) == null)
        {
            var role = Enum.Parse<UserRole>(roleStr);
            var user = new ApplicationUser
            {
                UserName = email,
                Email = email,
                EmailConfirmed = true,
                FullName = $"{firstName} {lastName}",
                Role = role
            };

            var result = await userManager.CreateAsync(user, "P@ssword123");
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(user, roleStr);
            }
        }
    }

    private static async Task SeedPharmacyAsync(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        string ownerEmail,
        string name,
        string address,
        string city,
        string phone,
        double lat,
        double lng,
        bool ownerIsAdmin = false)
    {
        var user = await userManager.FindByEmailAsync(ownerEmail);
        if (user is null) return;

        var pharmacy = await context.Pharmacies.FirstOrDefaultAsync(p => p.OwnerId == user.Id);
        if (pharmacy is null)
        {
            pharmacy = new Pharmacy
            {
                OwnerId = user.Id,
                Name = name,
                AddressLine = address,
                City = city,
                Phone = phone,
                VerificationStatus = VerificationStatus.Approved,
                GeoPoint = new Point(lng, lat) { SRID = 4326 }
            };
            context.Pharmacies.Add(pharmacy);
            await context.SaveChangesAsync();
        }

        // Seed inventory only for the three pharmacy owners (the admin-owned one stays empty/demo)
        if (!ownerIsAdmin)
        {
            await SeedInventoryAsync(context, pharmacy.Id);
        }
    }

    /// <summary>Common Egyptian medications with realistic Cairo prices (EGP).</summary>
    private static readonly (string Name, decimal Price, InventoryStatus Status)[] SeedCatalog =
    [
        ("Panadol 500mg", 28.50m, InventoryStatus.InStock),
        ("Panadol Extra 24 tabs", 34.00m, InventoryStatus.InStock),
        ("Amoxicillin 500mg", 45.75m, InventoryStatus.InStock),
        ("Paracetamol 500mg", 12.00m, InventoryStatus.InStock),
        ("Diclofenac 50mg", 18.25m, InventoryStatus.InStock),
        ("Ibuprofen 200mg", 22.50m, InventoryStatus.InStock),
        ("Metformin 500mg", 31.00m, InventoryStatus.InStock),
        ("Insulin Regular 100IU", 85.00m, InventoryStatus.InStock),
        ("Amoxicillin 250mg", 38.00m, InventoryStatus.OutOfStock),
        ("Ciprofloxacin 250mg", 52.00m, InventoryStatus.InStock),
        ("Omeprazole 20mg", 40.50m, InventoryStatus.InStock),
        ("Ranitidine 150mg", 15.75m, InventoryStatus.OutOfStock),
        ("Dexamethasone 8mg", 21.00m, InventoryStatus.InStock),
        ("Salbutamol Inhaler", 120.00m, InventoryStatus.InStock),
        ("Hydrocortisone Cream 1%", 48.00m, InventoryStatus.InStock),
        ("Vitamin D3 5000IU", 62.00m, InventoryStatus.InStock),
        ("Iron Fumarate 200mg", 35.00m, InventoryStatus.InStock),
        ("Folic Acid 1mg", 14.50m, InventoryStatus.InStock),
        ("Cetirizine 10mg", 26.00m, InventoryStatus.InStock),
        ("Ranitidine 150mg", 15.75m, InventoryStatus.OutOfStock),
        ("Chlorpheniramine 4mg", 9.50m, InventoryStatus.InStock),
        ("Prednisolone 5mg", 17.00m, InventoryStatus.InStock),
        ("Aspirin 81mg", 11.25m, InventoryStatus.InStock),
        ("Vitamin C 1000mg", 28.00m, InventoryStatus.InStock)
    ];

    private static async Task SeedInventoryAsync(ApplicationDbContext context, Guid pharmacyId)
    {
        var existingCount = await context.InventoryItems
            .Where(i => i.PharmacyId == pharmacyId)
            .CountAsync();

        if (existingCount > 0) return;

        foreach (var (name, price, status) in SeedCatalog)
        {
            context.InventoryItems.Add(new InventoryItem
            {
                PharmacyId = pharmacyId,
                MedicationName = name,
                MedicationNameNormalized = name.Trim().ToUpperInvariant(),
                Price = price,
                Status = status
            });
        }
        await context.SaveChangesAsync();
    }
}
