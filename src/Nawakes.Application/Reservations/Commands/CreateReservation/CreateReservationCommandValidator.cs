using FluentValidation;

namespace Nawakes.Application.Reservations.Commands.CreateReservation;

public sealed class CreateReservationCommandValidator : AbstractValidator<CreateReservationCommand>
{
    public CreateReservationCommandValidator()
    {
        RuleFor(x => x.InventoryItemId).NotEmpty();
    }
}
