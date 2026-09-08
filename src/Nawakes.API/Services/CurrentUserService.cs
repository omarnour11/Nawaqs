using System.Security.Claims;
using Nawakes.Application.Common.Interfaces;

namespace Nawakes.API.Services;

/// <summary>
/// Resolves the authenticated user's identity from the JWT claims principal.
/// Registered as Scoped — one instance per HTTP request.
/// </summary>
public sealed class CurrentUserService(IHttpContextAccessor httpContextAccessor) : ICurrentUserService
{
    private readonly ClaimsPrincipal? _user = httpContextAccessor.HttpContext?.User;

    public Guid UserId =>
        Guid.TryParse(_user?.FindFirstValue(ClaimTypes.NameIdentifier), out var id)
            ? id
            : Guid.Empty;

    public string? Role => _user?.FindFirstValue(ClaimTypes.Role);

    public bool IsAuthenticated => _user?.Identity?.IsAuthenticated == true;
}
