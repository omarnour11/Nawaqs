using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Nawakes.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSpatialIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // SQL Server spatial grid indexes for Egyptian coordinates
            // Using GEOGRAPHY_GRID with 4 levels of MEDIUM density and 16 cells per object
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pharmacies_GeoPoint' AND object_id = OBJECT_ID('Pharmacies'))
                BEGIN
                    CREATE SPATIAL INDEX IX_Pharmacies_GeoPoint
                    ON Pharmacies(GeoPoint)
                    USING GEOGRAPHY_GRID
                    WITH (
                        GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
                        CELLS_PER_OBJECT = 16
                    );
                END
            ");

            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Subscriptions_GeoPoint' AND object_id = OBJECT_ID('Subscriptions'))
                BEGIN
                    CREATE SPATIAL INDEX IX_Subscriptions_GeoPoint
                    ON Subscriptions(GeoPoint)
                    USING GEOGRAPHY_GRID
                    WITH (
                        GRIDS = (LEVEL_1 = MEDIUM, LEVEL_2 = MEDIUM, LEVEL_3 = MEDIUM, LEVEL_4 = MEDIUM),
                        CELLS_PER_OBJECT = 16
                    );
                END
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Pharmacies_GeoPoint' AND object_id = OBJECT_ID('Pharmacies'))
                BEGIN
                    DROP INDEX IX_Pharmacies_GeoPoint ON Pharmacies;
                END
            ");

            migrationBuilder.Sql(@"
                IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Subscriptions_GeoPoint' AND object_id = OBJECT_ID('Subscriptions'))
                BEGIN
                    DROP INDEX IX_Subscriptions_GeoPoint ON Subscriptions;
                END
            ");
        }
    }
}
