using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSupportAttachmentAndClinicalFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AttachmentUrl",
                table: "SupportTickets",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ClinicalContraindicationReason",
                table: "Reservations",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RecommendedAlternativeItemId",
                table: "Reservations",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RecommendedAlternativeMedication",
                table: "Reservations",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "AllowPharmacistViewActiveMedications",
                table: "AspNetUsers",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AttachmentUrl",
                table: "SupportTickets");

            migrationBuilder.DropColumn(
                name: "ClinicalContraindicationReason",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "RecommendedAlternativeItemId",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "RecommendedAlternativeMedication",
                table: "Reservations");

            migrationBuilder.DropColumn(
                name: "AllowPharmacistViewActiveMedications",
                table: "AspNetUsers");
        }
    }
}
