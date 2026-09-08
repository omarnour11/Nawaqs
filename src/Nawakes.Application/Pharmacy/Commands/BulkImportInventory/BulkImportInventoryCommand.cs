using MediatR;

namespace Nawakes.Application.Pharmacy.Commands.BulkImportInventory;

public sealed record BulkImportInventoryCommand(byte[] FileContent) : IRequest<BulkImportResultDto>;

public sealed record BulkImportResultDto(int ImportedCount, int SkippedCount, string[] Errors);
