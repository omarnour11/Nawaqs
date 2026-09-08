using MediatR;
using Nawakes.Application.Auth.Commands.Register;

namespace Nawakes.Application.Auth.Commands.Login;

/// <summary>Login with email + password, returns JWT tokens.</summary>
public sealed record LoginCommand(string Email, string Password) : IRequest<AuthResult>;
