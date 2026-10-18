using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Infrastructure;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(Nawakes.Infrastructure.Persistence.ApplicationDbContext))]
    [Migration("20261018100000_AddFairQueueFields")]
    public partial class AddFairQueueFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "QueuePosition",
                table: "Subscriptions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<byte>(
                name: "QueueStatus",
                table: "Subscriptions",
                type: "tinyint",
                nullable: false,
                defaultValue: (byte)0);

            migrationBuilder.AddColumn<DateTime>(
                name: "OfferedAt",
                table: "Subscriptions",
                type: "datetime2(7)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "OfferExpiresAt",
                table: "Subscriptions",
                type: "datetime2(7)",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "OfferedInventoryItemId",
                table: "Subscriptions",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OfferExpiryHangfireJobId",
                table: "Subscriptions",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Subscriptions_MedicationNameNormalized_QueueStatus",
                table: "Subscriptions",
                columns: new[] { "MedicationNameNormalized", "QueueStatus" },
                filter: "[IsDeleted] = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Subscriptions_MedicationNameNormalized_QueueStatus",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "OfferExpiryHangfireJobId",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "OfferedInventoryItemId",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "OfferExpiresAt",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "OfferedAt",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "QueueStatus",
                table: "Subscriptions");

            migrationBuilder.DropColumn(
                name: "QueuePosition",
                table: "Subscriptions");
        }
    }
}
