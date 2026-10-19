using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSubscriptionRowVersion : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Only the new column belongs here: AddFairQueueFields and
            // AddFamilyCabinet already create the other queue/family objects.
            migrationBuilder.AddColumn<byte[]>(
                name: "RowVersion",
                table: "Subscriptions",
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
                table: "Subscriptions");
        }
    }
}
