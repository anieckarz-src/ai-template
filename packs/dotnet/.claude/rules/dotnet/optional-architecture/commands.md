---
paths: **/Commands/*.cs
description: Rules for implementing CQRS commands, validation, handlers, and structure (MediatR-style)
---

# CQRS Commands

> **Apply only if this project uses CQRS with MediatR (or an equivalent mediator); otherwise delete this file.**
> Type names below (`ICommand`, `Result`, `Result<T>`, telemetry collector, repository interfaces) stand for **the project's equivalent base types**. Use whatever the codebase already defines; don't introduce these types if they don't exist.

Guidelines for implementing CQRS commands, including structure, validation, handlers, and pipeline behaviors.

## Structure

Commands live in the feature's commands folder (e.g., `Features/[Feature]/Commands`)—match the existing layout.

## Implementation

1. Create one file per command containing `Command`, `Validator`, and `Handler`:
   - Name the file after the command without suffix (e.g., `CreateUser.cs`)
2. Command record:
   - Create a public sealed record (mark it `[PublicAPI]` if the project uses JetBrains annotations) implementing the project's command marker (e.g., `ICommand`) and `IRequest<Result>` / `IRequest<Result<T>>` (or the project's result type)
   - Name with `Command` suffix
   - Define properties in the primary constructor
   - Use property initializers for simple input sanitization (trimming, casing)
   - For route parameters, use `[JsonIgnore] // Removes from API contract` on real properties, not primary constructor parameters
3. Command validator (FluentValidation or the project's equivalent):
   - Only validate if the command has user input
   - Each property should have one shared validation message for all cases (required, max length, etc.)
   - Don't inject dependencies like repositories—use guards in the handler instead
   - Only validate user input, not route parameters, enum values, or IDs already validated by the model binder
4. Handler:
   - Create a public sealed class with `Handler` suffix
   - Implement `IRequestHandler<CommandType, Result>` or `IRequestHandler<CommandType, Result<T>>`
   - Commands can optionally return a newly created ID, but only if truly needed
   - Use guard statements with early returns like `Result.BadRequest(...)`, `Result.NotFound(...)`
     - Enclose dynamic values in single quotes and end messages with a period
   - Never throw exceptions for expected failures—return the project's failure result
   - If the project collects telemetry/audit events, collect one for each successful command (prefer one event per command; for bulk operations, track individual events if single-operation equivalents exist)
   - Persistence: use the project's repository/unit-of-work abstraction (`AddAsync()`, `Remove()`, `Update()`). If a pipeline behavior commits the unit of work, never call `SaveChangesAsync()` in handlers
   - Never do N+1 operations—load all entities and process them in memory
5. Command composition:
   - Chain commands through the mediator (`await mediator.Send(new CreateUserCommand(...))`) or raise domain events—never inject and call other handlers directly
   - Extract shared logic to the feature's shared folder

Note: know the project's pipeline behavior order (a common setup is Validation → Handler → PublishDomainEvents → UnitOfWork → PublishTelemetryEvents) and whether nested commands run inside the same transaction. Check whether EF change tracking is enabled before relying on it.

## Example

```csharp
// CreateUser.cs
[PublicAPI]
public sealed record CreateUserCommand(string Email, string Name)
    : ICommand, IRequest<Result>
{
    [JsonIgnore] // Removes from API contract // ✅ DO: Add JsonIgnore on a real property for route parameters
    public Guid OrganizationId { get; init; }

    // ✅ DO: Normalize input in property initializers
    public string Email { get; } = Email.Trim().ToLower();
}

public sealed class CreateUserValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserValidator()
    {
        // ✅ DO: Use the same message for better user experience and easier localization
        RuleFor(x => x.Name).Length(1, 50).WithMessage("Name must be between 1 and 50 characters.");
    }
}

public sealed class CreateUserHandler(IUserRepository userRepository, ITelemetryEventsCollector events)
    : IRequestHandler<CreateUserCommand, Result>
{
    public async Task<Result> Handle(CreateUserCommand command, CancellationToken cancellationToken)
    {
        // ✅ DO: Use guard statements with early returns
        if (!await userRepository.IsEmailFreeAsync(command.Email, cancellationToken))
        {
            return Result.BadRequest($"User with email '{command.Email}' already exists.");
        }

        var user = User.Create(command.OrganizationId, command.Email, command.Name);
        await userRepository.AddAsync(user, cancellationToken);

        events.CollectEvent(new UserCreated(user.Id)); // ✅ DO: Collect events if the project tracks them

        return Result.Success();
    }
}
```

```csharp
public sealed record CreateUserCommand([JsonIgnore] Guid OrganizationId, string Email) // ❌ DON'T: Add attributes on positional (primary constructor) parameters
    : ICommand, IRequest<Result>;

public sealed class CreateUserValidator : AbstractValidator<CreateUserCommand>
{
    public CreateUserValidator()
    {
        // ❌ DON'T: Use different validation messages for the same property and redundant validation rules
        RuleFor(x => x.Name)
            .NotEmpty().WithMessage("Name must not be empty.")
            .MaximumLength(50).WithMessage("Name must not be more than 50 characters.");
    }
}

public sealed class CreateUserHandler(
    ITelemetryEventsCollector events, // ❌ DON'T: Place generic dependencies before specific ones
    IUserRepository userRepository,
    SendEmailHandler sendEmailHandler // ❌ DON'T: Inject handlers directly
) : IRequestHandler<CreateUserCommand, Result>
{
    public async Task<Result> Handle(CreateUserCommand command, CancellationToken cancellationToken)
    {
        // ❌ DON'T: Perform validation in the handler that belongs in the validator
        if (!command.Email.Contains('@'))
        {
            // ❌ Missing single quotes around the dynamic value and trailing period
            throw new ArgumentException($"Email {command.Email} must be valid"); // ❌ DON'T: Throw exceptions
        }

        if (someCondition)
        {
            return Result.BadRequest( // ❌ DON'T: Split Result returns across multiple lines if it fits on one line
                $"User with email {command.Email} already exists" // ❌ Missing single quotes and trailing period
            );
        }

        // ❌ DON'T: Call handlers directly instead of using the mediator or domain events
        await sendEmailHandler.Handle(new SendEmailCommand(command.Email, "Welcome!"), cancellationToken);

        return Result.Success();
    }
}
```
