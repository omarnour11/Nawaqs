using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentFieldsToReservation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── Reservation payment columns (genuinely new) ──────────────────
            migrationBuilder.AddColumn<decimal>(
                name: "PaymentAmountEgp",
                table: "Reservations",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentProvider",
                table: "Reservations",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentReference",
                table: "Reservations",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PaymentStatus",
                table: "Reservations",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "Unpaid");

            migrationBuilder.AddColumn<string>(
                name: "PaymobMerchantOrderId",
                table: "Reservations",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Reservations_PaymobMerchantOrderId",
                table: "Reservations",
                column: "PaymobMerchantOrderId",
                filter: "[PaymobMerchantOrderId] IS NOT NULL");

            // Note: InventoryItems.Barcode, ExternalPosSku, EgyptianDrugRegistry.CommercialNameAr,
            // CommercialNameArNormalized, GtinBarcode, and AspNetRoles columns are intentionally
            // excluded — they already exist in the database from prior migrations that were
            // applied outside the EF migration history (column drift). Applying them again
            // causes duplicate-column errors.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reservations_PaymobMerchantOrderId",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "PaymentAmountEgp",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "PaymentProvider",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "PaymentReference",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "PaymentStatus",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "PaymobMerchantOrderId",
                table: "Reservations");
        }
    }
}
