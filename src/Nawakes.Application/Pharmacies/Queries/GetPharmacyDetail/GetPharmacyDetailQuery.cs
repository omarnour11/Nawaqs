using MediatR;
using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Pharmacies.Queries.GetPharmacyDetail;

/// <summary>Query for GET /api/v1/pharmacies/{id}</summary>
public sealed record GetPharmacyDetailQuery(Guid PharmacyId) : IRequest<PharmacyDetailDto>;
