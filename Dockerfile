# syntax=docker/dockerfile:1
# ── Build Stage ──────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /source

# Install culture invariants / globalization dependencies for NetTopologySuite & ICU if needed
RUN apk add --no-cache icu-libs

# Copy solution and project files for layer caching
COPY Nawakes.sln ./
COPY src/Nawakes.Domain/Nawakes.Domain.csproj ./src/Nawakes.Domain/
COPY src/Nawakes.Application/Nawakes.Application.csproj ./src/Nawakes.Application/
COPY src/Nawakes.Infrastructure/Nawakes.Infrastructure.csproj ./src/Nawakes.Infrastructure/
COPY src/Nawakes.API/Nawakes.API.csproj ./src/Nawakes.API/
COPY tests/Nawakes.Application.Tests/Nawakes.Application.Tests.csproj ./tests/Nawakes.Application.Tests/

# Restore packages
RUN dotnet restore Nawakes.sln

# Copy source code and build
COPY src/ ./src/
COPY tests/ ./tests/

WORKDIR /source/src/Nawakes.API
RUN dotnet publish Nawakes.API.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

# ── Runtime Stage ─────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Enable globalization support (needed for Arabic formatting and invariant culture)
RUN apk add --no-cache icu-libs
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish .

# Run with non-root security context
USER app

EXPOSE 8080
ENTRYPOINT ["dotnet", "Nawakes.API.dll"]
