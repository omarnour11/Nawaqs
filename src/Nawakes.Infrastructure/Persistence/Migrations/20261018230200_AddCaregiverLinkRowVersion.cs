using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCaregiverLinkRowVersion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Only the new column belongs here: AddFamilyCabinet already creates
            // the table and the queue/family objects come from earlier migrations.
            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "FamilyCaregiverLinks",
                type: "rowversion",
                rowVersion: true,
                nullable: false,
                defaultValue: new byte[0]);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "RowVersion",
                table: "FamilyCaregiverLinks");
        }
    }
}
