namespace Nawakes.Application.Common.Exceptions;

public sealed class NotFoundException(string name, object key)
    : Exception($"Entity '{name}' with key '{key}' was not found.");

public sealed class ConflictException(string message) : Exception(message);

public sealed class ForbiddenException(string message) : Exception(message);
