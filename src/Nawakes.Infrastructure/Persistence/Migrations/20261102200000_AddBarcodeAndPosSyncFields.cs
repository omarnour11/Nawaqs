using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(ApplicationDbContext))]
    [Migration("20261102200000_AddBarcodeAndPosSyncFields")]
    public partial class AddBarcodeAndPosSyncFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GtinBarcode",
                table: "EgyptianDrugRegistry",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_EgyptianDrugRegistry_GtinBarcode",
                table: "EgyptianDrugRegistry",
                column: "GtinBarcode");

            migrationBuilder.AddColumn<string>(
                name: "Barcode",
                table: "InventoryItems",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BatchNumber",
                table: "InventoryItems",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ExpiryDate",
                table: "InventoryItems",
                type: "datetime2",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_InventoryItems_Pharmacy_Barcode",
                table: "InventoryItems",
                columns: new[] { "PharmacyId", "Barcode" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_InventoryItems_Pharmacy_Barcode",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "Barcode",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "BatchNumber",
                table: "InventoryItems");

            migrationBuilder.DropColumn(
                name: "ExpiryDate",
                table: "InventoryItems");

            migrationBuilder.DropIndex(
                name: "IX_EgyptianDrugRegistry_GtinBarcode",
                table: "EgyptianDrugRegistry");

            migrationBuilder.DropColumn(
                name: "GtinBarcode",
                table: "EgyptianDrugRegistry");
        }
    }
}
