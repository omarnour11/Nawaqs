using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Nawakes.Domain.Enums;
using Nawakes.Infrastructure.Identity;
using Nawakes.Infrastructure.Persistence;

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
            await CreateUserAsync(userManager, "patient@nawaqs.com", "Patient", "Test", UserRole.Patient.ToString());
            await CreateUserAsync(userManager, "pharmacy@nawaqs.com", "Pharmacy", "Owner", UserRole.PharmacyOwner.ToString());
            await CreateUserAsync(userManager, "admin@nawaqs.com", "Admin", "User", UserRole.Admin.ToString());

            // 4. Seed Pharmacy
            await CreatePharmacyAsync(context, userManager, "pharmacy@nawaqs.com");
        }
        catch (Exception ex)
        {
            var logger = services.GetRequiredService<ILogger<Program>>();
            logger.LogError(ex, "An error occurred while seeding the database.");
        }
    }

    private static async Task CreateUserAsync(UserManager<ApplicationUser> userManager, string email, string dummyFirstName, string dummyLastName, string roleStr)
    {
        if (await userManager.FindByEmailAsync(email) == null)
        {
            var role = Enum.Parse<UserRole>(roleStr);
            var user = new ApplicationUser
            {
                UserName = email,
                Email = email,
                EmailConfirmed = true,
                Role = role
            };
            
            var result = await userManager.CreateAsync(user, "P@ssword123");
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(user, roleStr);
            }
        }
    }

    private static async Task CreatePharmacyAsync(ApplicationDbContext context, UserManager<ApplicationUser> userManager, string email)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user != null && !await context.Pharmacies.AnyAsync(p => p.OwnerId == user.Id))
        {
            context.Pharmacies.Add(new Nawakes.Domain.Entities.Pharmacy
            {
                OwnerId = user.Id,
                Name = "Nawaqs Main Pharmacy",
                AddressLine = "123 Main Street",
                City = "Cairo",
                Phone = "01000000000",
                VerificationStatus = VerificationStatus.Approved,
                GeoPoint = new NetTopologySuite.Geometries.Point(31.2357, 30.0444) { SRID = 4326 }
            });
            await context.SaveChangesAsync();
        }
    }
}
