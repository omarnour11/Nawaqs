using FluentValidation;
using MediatR;
using Nawakes.Application.Search.Queries.SearchMedication;

namespace Nawakes.Application.Search.Queries.SearchMedication;

/// <summary>
/// MediatR query for the geospatial medication search.
/// SortBy: "Distance" | "Price" | "Rating"
/// </summary>
public sealed record SearchMedicationQuery(
    string Medication,
    double Lat,
    double Lng,
    decimal RadiusKm,
    string SortBy = "Distance"
) : IRequest<SearchMedicationResponse>;

public sealed class SearchMedicationQueryValidator : AbstractValidator<SearchMedicationQuery>
{
    private static readonly decimal[] AllowedRadii = [5m, 10m, 20m];
    private static readonly string[] AllowedSortBys = ["Distance", "Price", "Rating"];

    public SearchMedicationQueryValidator()
    {
        RuleFor(x => x.Medication)
            .NotEmpty()
            .MinimumLength(2)
            .MaximumLength(300);

        RuleFor(x => x.Lat)
            .InclusiveBetween(-90, 90);

        RuleFor(x => x.Lng)
            .InclusiveBetween(-180, 180);

        RuleFor(x => x.RadiusKm)
            .InclusiveBetween(1, 1000)
            .WithMessage("Radius must be between 1 and 1000 km.");

        RuleFor(x => x.SortBy)
            .Must(s => AllowedSortBys.Contains(s))
            .WithMessage("SortBy must be Distance, Price, or Rating.");
    }
}
