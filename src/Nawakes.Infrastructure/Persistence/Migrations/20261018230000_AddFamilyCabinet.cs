using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(Nawakes.Infrastructure.Persistence.ApplicationDbContext))]
    [Migration("20261018230000_AddFamilyCabinet")]
    public partial class AddFamilyCabinet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FamilyProfiles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Nickname = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    HomeLatitude = table.Column<double>(type: "float", nullable: false),
                    HomeLongitude = table.Column<double>(type: "float", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FamilyProfiles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FamilyProfiles_AspNetUsers_OwnerUserId",
                        column: x => x.OwnerUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "FamilyMedications",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FamilyProfileId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    MedicationName = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    Strength = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    StripsCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    UnitsPerStrip = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    DailyDoseUnits = table.Column<decimal>(type: "decimal(9,2)", nullable: false),
                    LastRefillDate = table.Column<DateTime>(type: "datetime2(7)", nullable: true),
                    AlertThresholdDays = table.Column<int>(type: "int", nullable: false, defaultValue: 7),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FamilyMedications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FamilyMedications_FamilyProfiles_FamilyProfileId",
                        column: x => x.FamilyProfileId,
                        principalTable: "FamilyProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FamilyCaregiverLinks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FamilyProfileId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CaregiverUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    InvitedPhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    IsAccepted = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    DeletedAt = table.Column<DateTime>(type: "datetime2(7)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FamilyCaregiverLinks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FamilyCaregiverLinks_FamilyProfiles_FamilyProfileId",
                        column: x => x.FamilyProfileId,
                        principalTable: "FamilyProfiles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_FamilyCaregiverLinks_AspNetUsers_CaregiverUserId",
                        column: x => x.CaregiverUserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_FamilyProfiles_OwnerUserId",
                table: "FamilyProfiles",
                column: "OwnerUserId",
                filter: "[IsDeleted] = 0");

            migrationBuilder.CreateIndex(
                name: "IX_FamilyMedications_FamilyProfileId_IsActive",
                table: "FamilyMedications",
                columns: new[] { "FamilyProfileId", "IsActive" },
                filter: "[IsDeleted] = 0");

            migrationBuilder.CreateIndex(
                name: "IX_FamilyCaregiverLinks_FamilyProfileId_CaregiverUserId",
                table: "FamilyCaregiverLinks",
                columns: new[] { "FamilyProfileId", "CaregiverUserId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "FamilyCaregiverLinks");
            migrationBuilder.DropTable(name: "FamilyMedications");
            migrationBuilder.DropTable(name: "FamilyProfiles");
        }
    }
}
