---
paths: **/Migrations/*.cs,**/*DbContext.cs,**/*EntityTypeConfiguration.cs,**/Configurations/*.cs
description: Rules for creating Entity Framework Core database migrations
---

# EF Core Migrations

Guidelines for creating and reviewing Entity Framework Core migrations. Provider-agnostic rules come first; PostgreSQL-specific guidance is in a clearly marked optional section at the end.

## Implementation

1. Follow the project's migration workflow—check existing migrations before creating one:
   - **Generated** (default EF workflow): `dotnet ef migrations add <Name> --project <DataProject> --startup-project <HostProject>`. Always read the generated `Up`/`Down` code; never hand-edit `*.Designer.cs` or the `ModelSnapshot`—change the model and regenerate instead
   - **Hand-written**: some projects write migrations manually (no snapshot). Then name files with a 14-digit timestamp prefix `YYYYMMDDHHmmss_MigrationName.cs`, where `HHmm` is the actual current time (never `0000`), and add the `[DbContext(typeof(...))]` and `[Migration("...")]` attributes
2. Name migrations descriptively in PascalCase (e.g., `AddOrderShippingAddress`), without a `Migration` suffix; make migration classes `sealed` when hand-written
3. Never modify a migration that has been applied to any shared environment (CI, staging, production)—add a new migration instead
4. `Down` methods: follow the project's convention (some projects never write `Down`, relying on forward-only fixes). Don't mix styles
5. Column ordering in new tables:
   - Tenant/partition key (if the project is multi-tenant)
   - `id` (always required)
   - Foreign keys
   - `created_at` / `modified_at` (or the project's audit columns)
   - All other properties in the same order as they appear in the C# entity class
6. Naming: use the project's convention consistently for tables, columns, and constraints (EF default PascalCase, or snake_case via a naming-convention package/configuration). Constraint names follow a predictable pattern, e.g.:
   - Primary keys: `pk_table_name`
   - Foreign keys: `fk_child_table_parent_table_column_name`
   - Indexes: `ix_table_name_column_name`
7. Data types:
   - `DateTimeOffset` columns use a time-zone-aware type
   - `decimal` properties always get explicit precision (`HasPrecision(18, 2)` or the project's standard) in the EF configuration and migration
   - Enforce string length and format rules at the application level (validators) unless the project's convention is to constrain in the database
   - JSON columns: use the provider's native JSON type when the model uses `OwnsOne(..., b => b.ToJson())` or a JSON `HasConversion`
8. EF configuration (`IEntityTypeConfiguration<T>`): match the existing style. Configure what EF needs at runtime (conversions, owned/JSON types, keys, cascade behavior); avoid redundant configuration that only restates conventions
9. Data migrations:
   - Use `migrationBuilder.Sql("UPDATE ...;")` with care; end every SQL statement with `;`
   - Make data migrations safe to re-run (idempotent) where possible, and consider large-table performance and locking
   - Never reference application services or entity classes from a migration—migrations must keep working when the model evolves
10. Indexes on large tables: plan for lock duration; use the provider's online/concurrent index option where the deployment pipeline allows it
11. Verify before handing off:
    - `[BUILD]` and `[TEST]` pass (tests should run against the migrated schema)
    - For generated migrations: `dotnet ef migrations has-pending-model-changes` (EF Core 8+) reports no pending changes
    - Review the SQL with `dotnet ef migrations script <From> <To> --idempotent` for anything non-trivial

## Examples

### Example 1 - New table

```csharp
[DbContext(typeof(AppDbContext))]
[Migration("20250507141500_AddUserPreferences")] // ✅ DO: Use a real 14-digit timestamp (hand-written migrations)
public sealed class AddUserPreferences : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            "user_preferences", // ✅ DO: Follow the project's table naming convention consistently
            table => new
            {
                id = table.Column<Guid>(nullable: false), // ✅ DO: id first (after a tenant key, if any)
                user_id = table.Column<Guid>(nullable: false), // ✅ DO: Foreign keys before audit columns
                created_at = table.Column<DateTimeOffset>(nullable: false),
                modified_at = table.Column<DateTimeOffset>(nullable: true),
                language = table.Column<string>(nullable: false) // ✅ DO: Remaining columns in entity property order
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_user_preferences", x => x.id);
                table.ForeignKey("fk_user_preferences_users_user_id", x => x.user_id, "users", "id");
            }
        );

        migrationBuilder.CreateIndex("ix_user_preferences_user_id", "user_preferences", "user_id");
    }
}

// ❌ DON'T
[Migration("20250507000000_AddUserPrefs")] // ❌ HHmm is `0000`—use the actual current time
public class AddUserPrefsMigration : Migration // ❌ Not sealed, suffixed with Migration, missing [DbContext]
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            "UserPreference", // ❌ Inconsistent with the project's naming convention
            table => new
            {
                Language = table.Column<string>(nullable: false), // ❌ Properties before id, FKs, and audit columns
                Id = table.Column<Guid>(nullable: false),
                ModifiedAt = table.Column<DateTime>(nullable: true), // ❌ DateTime instead of DateTimeOffset
                UserId = table.Column<Guid>(nullable: false) // ❌ Foreign key after audit columns
            },
            constraints: table => table.PrimaryKey("PK_1", i => i.Id) // ❌ Meaningless constraint name
        );
    }
}
```

### Example 2 - Adding a column with a default and a data migration

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.AddColumn<string>("time_zone", "users", nullable: false, defaultValue: "UTC");

    // ✅ DO: End SQL with `;` and keep it idempotent
    migrationBuilder.Sql("UPDATE users SET time_zone = 'UTC' WHERE time_zone IS NULL OR time_zone = '';");
}
```

## Optional: PostgreSQL (Npgsql) conventions

Apply this section only if the project uses PostgreSQL; otherwise delete it.

- Use snake_case for tables (plural, e.g., `users`, `email_logins`), columns, and C# anonymous-type members in migrations (e.g., `tenant_id = table.Column<long>(...)`)
- Use `text` for all string columns—PostgreSQL stores `text`, `varchar`, and `varchar(N)` identically with no performance difference
- Use `timestamptz` for `DateTimeOffset` columns—never `timestamp`, `datetime`, or `datetimeoffset`
- Use `boolean` for `bool`, `integer` for `int`, `bigint` for `long`, `numeric(18,2)` for `decimal`
- Use `jsonb` for all JSON columns—both `OwnsOne(..., b => b.ToJson())` and manually serialized values via `HasConversion`. With `HasConversion`, also add `.HasColumnType("jsonb")` in the EF configuration so Npgsql sends the value as `jsonb` instead of `text`
- Filtered indexes use PostgreSQL `WHERE` syntax, never SQL Server brackets:
  ```csharp
  // ✅ DO
  migrationBuilder.CreateIndex("ix_users_email", "users", "email", unique: true, filter: "deleted_at IS NULL");
  // ❌ DON'T
  migrationBuilder.CreateIndex("IX_Users_Email", "Users", "Email", unique: true, filter: "[DeletedAt] IS NULL");
  ```
- For indexes on large tables, use `migrationBuilder.Sql("CREATE INDEX CONCURRENTLY IF NOT EXISTS ...;", suppressTransaction: true)` to avoid locking the table—only if your deployment applies migrations outside a single wrapping transaction
- If your deployment wraps migration SQL in `DO $$ ... END $$` blocks (as idempotent scripts do), a missing trailing `;` in `migrationBuilder.Sql` causes `syntax error at or near "END"`
