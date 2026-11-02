using System;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    [DbContext(typeof(ApplicationDbContext))]
    [Migration("20261102180000_AddClinicalProfileAndPharmacyDelivery")]
    public partial class AddClinicalProfileAndPharmacyDelivery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // AspNetUsers (ApplicationUser)
            migrationBuilder.AddColumn<string>(
                name: "Gender",
                table: "AspNetUsers",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Age",
                table: "AspNetUsers",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ChronicConditions",
                table: "AspNetUsers",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "KnownAllergies",
                table: "AspNetUsers",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            // Pharmacies
            migrationBuilder.AddColumn<bool>(
                name: "OffersDelivery",
                table: "Pharmacies",
                type: "bit",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<decimal>(
                name: "DeliveryFee",
                table: "Pharmacies",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryPhone",
                table: "Pharmacies",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            // Reservations
            migrationBuilder.AddColumn<byte>(
                name: "FulfillmentType",
                table: "Reservations",
                type: "tinyint",
                nullable: false,
                defaultValue: (byte)0);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryAddress",
                table: "Reservations",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "DeliveryLatitude",
                table: "Reservations",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "DeliveryLongitude",
                table: "Reservations",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryContactPhone",
                table: "Reservations",
                type: "nvarchar(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryNotes",
                table: "Reservations",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: true);

            migrationBuilder.AddColumn<byte>(
                name: "DeliveryStatus",
                table: "Reservations",
                type: "tinyint",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Reservations
            migrationBuilder.DropColumn(
                name: "FulfillmentType",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryAddress",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryLatitude",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryLongitude",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryContactPhone",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryNotes",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "DeliveryStatus",
                table: "Reservations");

            // Pharmacies
            migrationBuilder.DropColumn(
                name: "OffersDelivery",
                table: "Pharmacies");

            migrationBuilder.DropColumn(
                name: "DeliveryFee",
                table: "Pharmacies");

            migrationBuilder.DropColumn(
                name: "DeliveryPhone",
                table: "Pharmacies");

            // AspNetUsers
            migrationBuilder.DropColumn(
                name: "Gender",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "Age",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "ChronicConditions",
                table: "AspNetUsers");

            migrationBuilder.DropColumn(
                name: "KnownAllergies",
                table: "AspNetUsers");
        }
    }
}
