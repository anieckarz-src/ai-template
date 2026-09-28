---
paths: **/*.cs,**/*.csproj,**/*.props,**/*.targets,**/*.sln,**/*.slnx,.editorconfig
description: Core rules for C# development and tooling
---

# C# Style

Guidelines for C# development, including code style, naming, exceptions, logging, and the build/test/format workflow.

## Code Style

- Be consistent—if you do something a certain way, do all similar things the same way
- Always use these C# features:
  - File-scoped (top-level) namespaces
  - Primary constructors
  - Collection expressions / array initializers
  - Pattern matching with `is null` and `is not null` instead of `== null` and `!= null`
- Records for immutable types
- Mark all C# types as sealed unless they are designed for inheritance
- Use `var` when possible
- Use simple collection types like `UserId[]` instead of `List<UserId>` whenever possible
- Line breaking: prefer long lines over splitting to maximize visible code (adjust the limit to the project's `.editorconfig`):
  - Wrap lines only when new language constructs start after 120 characters (content after 120 chars is acceptable if the construct starts before)
  - `CancellationToken cancellationToken` is not considered important and should never trigger a line break
  - Only wrap when truly necessary
  - Examples:
    ```csharp
    // ✅ DO: Keep on one line even if longer than 120 chars (the 'c' in 'command' is before 120 chars)
    public async Task<Result<CompleteEmailConfirmationResponse>> Handle(CompleteEmailConfirmationCommand command, CancellationToken cancellationToken)

    // ✅ DO: Keep constructor parameters on one line when they fit
    public sealed class GetPaymentHistoryHandler(IPaymentRepository paymentRepository, TimeProvider timeProvider)
        : IRequestHandler<GetPaymentHistoryQuery, PaymentHistoryResponse>

    // ✅ DO: Wrap to 2 lines when needed, but never 3, 4, or 5 lines
    var updatedLocale = await connection.ExecuteScalarAsync<string>(
        "SELECT locale FROM users WHERE id = @id", new { id = userId.ToString() }
    );

    // ❌ DON'T: Split method parameters across multiple lines when they fit before 120 chars
    public async Task<Result> Handle(
        UpgradeSubscriptionCommand command,
        CancellationToken cancellationToken
    )

    // ❌ DON'T: Split constructor parameters across multiple lines when they fit before 120 chars
    public sealed class GetPaymentHistoryHandler(
        IPaymentRepository paymentRepository,
        TimeProvider timeProvider
    ) : IRequestHandler<GetPaymentHistoryQuery, PaymentHistoryResponse>
    ```
- Avoid using exceptions for control flow:
  - When throwing exceptions, use meaningful exceptions following .NET conventions
  - Use `UnreachableException` to signal unreachable code that cannot be reached by tests
  - Exception messages should include a period
- Log only meaningful events at appropriate severity levels:
  - Logging messages should not include a period
  - Use structured logging (message templates with named placeholders, never string interpolation)
- Never introduce new NuGet dependencies without explicit agreement (record it in `divergence.md`)
- Never use `#pragma warning disable CS####`—fix the warning instead
- Don't do defensive coding (e.g., don't add exception handling for situations we don't know will happen)
- Use `user?.IsActive == true` over `user != null && user.IsActive == true`
- Avoid try-catch unless we cannot fix the root cause—global exception handling covers unknown exceptions
- Environment checks: use the project's single configuration/environment abstraction (e.g., `IHostEnvironment`), never ad-hoc environment variable reads scattered in code
- Inject `TimeProvider` into services and handlers, use `timeProvider.GetUtcNow()` instead of `DateTimeOffset.UtcNow`
- Pass `DateTimeOffset` values (not `TimeProvider`) to domain methods and entities to maintain clean boundaries (e.g., `entity.HasExpired(timeProvider.GetUtcNow())`)
- Accept a `CancellationToken` in async methods and pass it through; never block on async code (`.Result`, `.Wait()`)
- Naming rules:
  - Never use acronyms or abbreviations (e.g., use `SharedAccessSignature` not `Sas`, `Context` not `Ctx`)
  - Prefer long variable names for readability (e.g., `gravatarHttpClient` not `httpClient`)
  - Choose descriptive and unambiguous names
  - Make meaningful distinctions
  - Use pronounceable names
  - Use searchable names
  - Replace magic numbers with named constants
  - Avoid encodings—don't append prefixes or type information
- Comments rules:
  - Don't explain what you changed (that belongs in commit messages)—code should reflect the current state only
  - Always try to explain yourself in code
  - Don't be redundant
  - Don't add obvious noise
  - Don't use closing brace comments
  - Don't comment out code—just remove it
  - Use comments for explanation of intent, clarification, or warning of consequences
- Source code structure:
  - Separate concepts vertically
  - Related code should appear vertically dense
  - Declare variables close to their usage
  - Dependent functions should be close
  - Similar functions should be close
  - Place functions in the downward direction
  - Order: public functions above internal, internal above private
  - Don't use horizontal alignment
  - Use white space to associate related things and disassociate weakly related
  - Avoid nesting—prefer early return or break/continue statements, keeping the happy path at the end
- Functions rules:
  - Keep them small
  - Do one thing
  - Use descriptive names
  - Prefer fewer arguments
  - Have no side effects
  - Don't use flag arguments—split into independent methods instead
- For enum comparisons:
  - When comparing enums to enums, use direct comparison: `order.State == OrderState.Paid`
  - When comparing string properties to enums (e.g., JWT claims), use `nameof`: `user.Role == nameof(UserRole.Owner)`
  - Avoid unnecessary `Enum.TryParse` when the comparison context is clear

## Implementation

Follow these steps when implementing changes:

1. Always start new changes by writing new test cases (or changing existing tests)—consult [Tests](/.claude/rules/dotnet/tests.md) for details
2. Build and test your changes:
   - Run `[BUILD]`
   - Run `[TEST]` to run all tests
   - If you change API contracts (endpoints, DTOs), also rebuild every consumer of the contract in the repository (generated clients, OpenAPI documents) to ensure it still compiles
3. Format and lint your code:
   - When all tests pass and the feature is complete, run `[FORMAT]`, then `[LINT]`
   - Format automatically fixes code style issues according to the project's `.editorconfig`
   - **ALL lint findings are blocking**—CI fails on any finding
   - Severity level (note/warning/error) is irrelevant—fix all findings before proceeding

When you see paths like `[Feature]` in rules, replace them with the feature name (e.g., `Users`, `Orders`). Adjust example folder layouts to the project's actual structure.
