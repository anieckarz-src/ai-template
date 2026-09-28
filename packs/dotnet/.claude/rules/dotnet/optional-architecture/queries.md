---
paths: **/Queries/*.cs
description: Rules for CQRS queries, including structure, validation, response types, and mapping (MediatR-style)
---

# CQRS Queries

> **Apply only if this project uses CQRS with MediatR (or an equivalent mediator); otherwise delete this file.**
> Type names below (`Result<T>`, repository interfaces, strongly typed IDs) stand for **the project's equivalent base types**. Use whatever the codebase already defines; don't introduce these types if they don't exist.

Guidelines for implementing CQRS queries, including structure, validation, response types, and pipeline behaviors.

## Implementation

1. Create queries in the feature's queries folder (e.g., `Features/[Feature]/Queries`)—match the existing layout
2. Create one file per query containing Query, Response, Validator (optional), and Handler:
   - Name the file after the query without suffix (e.g., `GetUsers.cs`)
3. Query record:
   - Create a public sealed record (mark it `[PublicAPI]` if the project uses JetBrains annotations) implementing `IRequest<Result<TResponse>>` (or the project's result type)
   - Name with `Query` suffix (e.g., `GetUsersQuery`)
   - Define properties in the primary constructor
   - Use property initializers for input normalization: `public string? Email { get; } = Email?.Trim().ToLower();`
   - For route parameters, use `[JsonIgnore] // Removes from API contract` on properties
   - Use default values for optional parameters (e.g., `int PageSize = 25`)
   - Use nullable types for optional parameters (e.g., `UserRole? UserRole = null`)
   - Queries never mutate state
4. Response record:
   - Create a public sealed record
   - Name with `Response` suffix (e.g., `UsersResponse`); never `Dto`
   - Include all necessary data for the client
   - Use the project's ID types (strongly typed IDs if used—see `strongly-typed-ids.md`) and enums
   - Take special care not to include sensitive data
5. Validator (optional):
   - Focus on preventing malicious or abusive input like `PageSize=1_000_000_000`
   - Create a public sealed class with `Validator` suffix (e.g., `GetUsersQueryValidator`)
   - Each property should have one shared error message
   - Only validate query properties (format, length)—use guards in the handler for complex checks
6. Handler:
   - Create a public sealed class with `Handler` suffix (e.g., `GetUsersHandler`)
   - Implement `IRequestHandler<QueryType, Result<ResponseType>>`
   - Use guard statements with early returns instead of throwing exceptions
   - Enclose dynamic values in single quotes: `$"User with ID '{userId}' not found."`
   - Retrieve data through the project's data-access abstraction (repositories or read models)—don't bypass it with ad-hoc `DbContext` access unless that is the project's convention for queries
   - Use the project's mapping approach (Mapster, AutoMapper, or manual mapping) consistently
   - Never do N+1 operations—load all entities and process in memory
   - Queries should rarely track telemetry events
7. After changing the API, rebuild every consumer of the contract in the repository (OpenAPI document, generated clients) as part of `[BUILD]`

Note: a common pipeline order for queries is Validation → Handler → PublishTelemetryEvents. Know the project's actual order.

## Examples

```csharp
[PublicAPI] // ✅ DO: Suffix with Query
public sealed record GetUsersQuery(string? Search = null, UserRole? UserRole = null, int PageOffset = 0, int PageSize = 25)
    : IRequest<Result<UsersResponse>>
{
    public string? Search { get; } = Search?.Trim().ToLower(); // ✅ DO: Sanitize input
}

[PublicAPI] // ✅ DO: Suffix with Response
public sealed record UsersResponse(int TotalCount, int PageSize, UserDetails[] Users);

[PublicAPI]
public sealed record UserDetails(UserId Id, string Email, UserRole Role);

public sealed class GetUsersQueryValidator : AbstractValidator<GetUsersQuery>
{
    public GetUsersQueryValidator()
    {
        // ✅ DO: Validate input
        RuleFor(x => x.Search).MaximumLength(100).WithMessage("The search term must be at most 100 characters.");
        RuleFor(x => x.PageSize).InclusiveBetween(1, 100).WithMessage("The page size must be between 1 and 100.");
    }
}

public sealed class GetUsersHandler(IUserRepository userRepository)
    : IRequestHandler<GetUsersQuery, Result<UsersResponse>>
{
    public async Task<Result<UsersResponse>> Handle(GetUsersQuery query, CancellationToken cancellationToken)
    {
        var (users, count) = await userRepository.Search(query.Search, query.UserRole, query.PageOffset, query.PageSize, cancellationToken);

        var totalPages = (count + query.PageSize - 1) / query.PageSize;
        if (query.PageOffset > 0 && query.PageOffset >= totalPages)
        {
            // ✅ DO: Return a failure result instead of throwing, and enclose values in single quotes
            return Result<UsersResponse>.BadRequest($"The page offset '{query.PageOffset}' is greater than the total number of pages.");
        }

        var userResponses = users.Adapt<UserDetails[]>(); // ✅ DO: Use the project's mapper for simple cases
        return new UsersResponse(count, query.PageSize, userResponses);
    }
}
```

```csharp
[PublicAPI] // ❌ No Query suffix, using class instead of record
public sealed class BadUsers : IRequest<Result<BadUsersDto>>
{
    public bool UpdateLastAccessed { get; init; } = true; // ❌ Queries must not mutate state
}

public sealed record BadUsersDto(UserId Id, string Email, UserRole Role); // ❌ Dto suffix

public sealed class BadUsersHandler(IUserRepository userRepository)
    : IRequestHandler<BadUsers, Result<BadUsersDto>>
{
    public async Task<Result<BadUsersDto>> Handle(BadUsers query, CancellationToken cancellationToken)
    {
        var user = await userRepository.GetByIdAsync(query.UserId, cancellationToken);
        if (user == null) // ❌ Use `is null`
        {
            throw new NotFoundException($"User with ID {query.UserId} not found"); // ❌ Throws exception, wrong message format
        }

        return new BadUsersDto(user.Id, user.Email, user.Role); // ❌ Manual mapping where the project's mapper fits
    }
}
```
