using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(Nawakes.Infrastructure.Persistence.ApplicationDbContext))]
    [Migration("20261018000000_AddEgyptianDrugRegistry")]
    public partial class AddEgyptianDrugRegistry : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "EgyptianDrugRegistry",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TradeName = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    TradeNameNormalized = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    ActiveIngredient = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ActiveIngredientNormalized = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    Strength = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    DosageForm = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    OfficialPriceEGP = table.Column<decimal>(type: "decimal(18,2)", nullable: true),
                    Manufacturer = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    EdaRegistrationNumber = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    IsChronic = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EgyptianDrugRegistry", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_EgyptianDrugRegistry_TradeNameNormalized",
                table: "EgyptianDrugRegistry",
                column: "TradeNameNormalized");

            migrationBuilder.CreateIndex(
                name: "IX_EgyptianDrugRegistry_ActiveIngredientNormalized_Strength_DosageForm",
                table: "EgyptianDrugRegistry",
                columns: new[] { "ActiveIngredientNormalized", "Strength", "DosageForm" },
                filter: "[ActiveIngredientNormalized] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "EgyptianDrugRegistry");
        }
    }
}
