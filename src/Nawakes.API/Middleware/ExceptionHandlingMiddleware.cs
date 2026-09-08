using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Nawakes.Application.Common.Exceptions;
using System.Text.Json;

namespace Nawakes.API.Middleware;

/// <summary>
/// Global exception handler that maps domain exceptions to structured RFC 7807 ProblemDetails responses.
/// Sensitive data (email, health data) must never appear in logged messages.
/// </summary>
public sealed class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (ValidationException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status422UnprocessableEntity,
                "Validation Failed", FormatValidationErrors(ex), logLevel: LogLevel.Warning);
        }
        catch (NotFoundException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status404NotFound,
                "Not Found", ex.Message, logLevel: LogLevel.Warning);
        }
        catch (ConflictException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status409Conflict,
                "Conflict", ex.Message, logLevel: LogLevel.Warning);
        }
        catch (ForbiddenException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status403Forbidden,
                "Forbidden", ex.Message, logLevel: LogLevel.Warning);
        }
        catch (UnauthorizedAccessException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status401Unauthorized,
                "Unauthorized", ex.Message, logLevel: LogLevel.Warning);
        }
        catch (InvalidOperationException ex)
        {
            await WriteProblemAsync(context, StatusCodes.Status400BadRequest,
                "Bad Request", ex.Message, logLevel: LogLevel.Warning);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Unhandled exception on {Method} {Path}",
                context.Request.Method, context.Request.Path);

            await WriteProblemAsync(context, StatusCodes.Status500InternalServerError,
                "Internal Server Error", "An unexpected error occurred. Please try again later.",
                logLevel: LogLevel.None); // Already logged above
        }
    }

    private static async Task WriteProblemAsync(
        HttpContext context,
        int statusCode,
        string title,
        object detail,
        LogLevel logLevel)
    {
        context.Response.ContentType = "application/problem+json";
        context.Response.StatusCode = statusCode;

        var problem = new
        {
            type = $"https://httpstatuses.io/{statusCode}",
            title,
            status = statusCode,
            detail,
            traceId = context.TraceIdentifier
        };

        await context.Response.WriteAsync(JsonSerializer.Serialize(problem));
    }

    private static object FormatValidationErrors(ValidationException ex) =>
        ex.Errors
            .GroupBy(e => e.PropertyName)
            .ToDictionary(
                g => g.Key,
                g => g.Select(e => e.ErrorMessage).ToArray());
}
