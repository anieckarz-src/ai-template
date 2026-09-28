---
paths: **/Domain/*.cs
description: Rules for creating strongly typed IDs for DDD aggregates and entities
---

# Strongly Typed IDs

> **Apply only if this project uses strongly typed IDs; otherwise delete this file.**
> Base types below (`StronglyTypedUlid<T>`, `StronglyTypedLongId<T>`, `[IdPrefix]`, `StronglyTypedIdJsonConverter`, `MapStronglyTyped*` helpers) stand for **the project's equivalent base types** (hand-rolled or from a library such as StronglyTypedId or Vogen). Use whatever the codebase already defines; don't introduce a new ID library as part of an unrelated phase.

Guidelines for implementing strongly typed IDs, covering type safety, naming, serialization, and EF Core mapping.

## Implementation

1. Use strongly typed IDs to provide type safety and prevent mixing different ID types, improving readability and maintainability
2. Use the project's default ID base type. A ULID-based ID with a short prefix (e.g., `usr_01JMVAW4T4320KJ3A7EJMCG8R0`) gives chronological ordering and easy recognition; GUID-based IDs are also common
3. If the project uses prefixes, keep them short (e.g., max 5 characters) and unique across the codebase
4. Follow the naming convention `[Entity]Id`
5. Include the JSON converter (attribute or global registration) so IDs serialize as plain values in API contracts
6. Override `ToString()` in the concrete record when the base type requires it—record types don't inherit an overridden `ToString()` from the base record
7. Place the ID type in the same file as its corresponding aggregate or entity
8. Use strongly typed IDs everywhere: endpoints, request/response types, commands, and queries (and generated API clients, if any)
9. In rare cases other ID types are fine for performance (e.g., a `long`-based tenant ID used in almost every table)
10. IDs shared across modules live in the project's shared module
11. Map strongly typed IDs in EF Core configurations with the project's mapping helpers or a single value converter per ID type—never repeat ad-hoc conversions inconsistently

## Examples

### Example 1 - ULID-based ID with prefix

```csharp
// ✅ DO: Use the project's ID base type with prefix and serialization
[PublicAPI]
[IdPrefix("usr")]
[JsonConverter(typeof(StronglyTypedIdJsonConverter<string, UserId>))]
public sealed record UserId(string Value) : StronglyTypedUlid<UserId>(Value)
{
    public override string ToString()
    {
        return Value;
    }
}

// ❌ DON'T: Forget to override ToString or use incorrect naming
public sealed record BadUserIdentifier(string Value) : StronglyTypedUlid<BadUserIdentifier>(Value)
{
    // Missing ToString override
    // Incorrect naming - should be UserId, not UserIdentifier
}
```

### Example 2 - long-based ID for performance

```csharp
// ✅ DO: Use a long-based ID for performance-critical IDs
[PublicAPI]
[JsonConverter(typeof(StronglyTypedIdJsonConverter<long, TenantId>))]
public sealed record TenantId(long Value) : StronglyTypedLongId<TenantId>(Value)
{
    public override string ToString()
    {
        return Value.ToString();
    }
}

// ❌ DON'T: Use primitive types directly
public class BadUser
{
    public string Id { get; set; } // Should be UserId
    public long TenantId { get; set; } // Should be TenantId
}
```

### Example 3 - Entity Framework Core mapping

```csharp
// ✅ DO: Map strongly typed IDs with the project's helpers (or one shared value converter per ID type)
public sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.MapStronglyTypedUuid<User, UserId>(u => u.Id);
        builder.MapStronglyTypedLongId<User, TenantId>(u => u.TenantId);
    }
}

// ❌ DON'T: Hand-roll a different conversion in each configuration when a shared helper exists
public sealed class BadUserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.Property(u => u.Id).HasConversion(id => id.Value, value => new UserId(value));
    }
}
```
