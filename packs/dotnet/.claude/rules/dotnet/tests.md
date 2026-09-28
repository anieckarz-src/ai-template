---
paths: **/*Tests*/**/*.cs,**/*Tests.cs,**/tests/**/*.cs
description: Rules for writing .NET backend tests (xUnit, API-first)
---

# Writing Tests

Guidelines for writing backend tests. By default, tests should exercise API endpoints to verify behavior over implementation. Only in rare cases (pure algorithms, complex domain logic that is hard to reach through the API) should unit tests be used.

## Implementation

1. Follow these naming conventions:
   - Test projects: `[Project].Tests` (match the project's existing convention)
   - Test files: `[Feature]/[Operation]Tests.cs` (e.g., `Users/CreateUserTests.cs`)
   - Test classes: `[Operation]Tests` and `sealed`
   - Test methods: `[Method]_[Condition]_[ExpectedResult]` (e.g., `CreateUser_WhenEmailIsTaken_ShouldReturnBadRequest`)
2. Organize tests by feature area in directories mirroring the production code structure
3. Prefer API tests to verify behavior over implementation:
   - Use `WebApplicationFactory<TProgram>` (directly or through the project's test base class) to host the app in-process
   - Use separate clients for authenticated and anonymous requests, and one per role when authorization differs
4. Use xUnit with `[Fact]`, or `[Theory]` with `[InlineData]`/`[MemberData]` if multiple cases share the same shape
5. Use the assertion library the project already uses (FluentAssertions, Shouldly, or equivalent) for clear assertions—don't mix styles within a project
6. Use Bogus (`Faker`) to generate random test data instead of hardcoded values, unless a specific value is part of the behavior under test
7. Use NSubstitute for mocking external dependencies (HTTP integrations, email, clock, message bus)—never mock the persistence layer the tests are meant to exercise (repositories, `DbContext`)
8. Inject a controllable clock (`FakeTimeProvider` or the project's equivalent) when behavior depends on time
9. Follow the Arrange-Act-Assert pattern with clear comments:
   - Only use these three comment sections: `// Arrange`, `// Act`, and `// Assert`
   - Only include `// Arrange` when there is actually setup code
   - Do not add additional comments for subsections (e.g., no `// Setup database` or `// Verify events`)
10. Test both happy path and error cases (validation failures, not found, forbidden, conflicts)
11. Avoid sharing fields between tests—prefer local constants or variables within each test method
12. Each test is independent: it creates its own data and does not depend on execution order or data left by other tests
13. Verify side effects such as database changes and published events/messages, not just the HTTP status
14. If you capture side-effect events (telemetry, domain events, outbox messages) and used API calls in Arrange, reset the collector as the last Arrange statement so only events from the Act phase are verified
15. Create test data with helper methods called from `// Arrange`, never in constructors or shared fixtures that hide what a test depends on
16. Use the project's test database approach consistently (in-memory SQLite, Testcontainers, a dedicated test database)—don't introduce a second one

Ensure consistent ordering, naming, spacing, and line breaks. When inserting raw SQL test data, keep columns in the exact same order as in the database. Write similar elements consistently across tests.

### Example pattern: a shared test base class

If your project has a test base class (e.g., `EndpointBaseTest<TContext>`), inherit from it instead of wiring `WebApplicationFactory` in every test. A typical base class provides:
- Pre-configured authenticated and anonymous `HttpClient` instances
- An isolated database per test (or per class) and a helper connection for inserting and verifying data
- Registration points for NSubstitute replacements of external services
- A spy/collector for side-effect events
- Cleanup through `IDisposable` / `IAsyncLifetime`

If no such class exists, don't invent one as part of an unrelated phase; follow the pattern used by existing tests.

## Examples

```csharp
// ✅ DO: Use Arrange-Act-Assert, proper naming, fluent assertions, and verify side effects
[Fact]
public async Task CompleteLogin_WhenValid_ShouldCompleteLoginAndCreateTokens()
{
    // Arrange
    var loginId = await StartLogin(SeededUsers.Owner.Email); // ✅ DO: Use test helpers for setup
    var command = new CompleteLoginCommand(CorrectOneTimePassword);
    EventCollector.Reset(); // ✅ DO: Reset captured events if the API was called in Arrange

    // Act
    var response = await AnonymousHttpClient.PostAsJsonAsync($"/api/authentication/login/{loginId}/complete", command);

    // Assert
    response.StatusCode.Should().Be(HttpStatusCode.OK);
    (await CountRows("email_logins", "id = @id AND completed = 1", new { id = loginId })).Should().Be(1); // ✅ DO: Verify DB side effects
    EventCollector.CollectedEvents.Select(e => e.GetType().Name).Should().Equal("LoginCompleted"); // ✅ DO: Verify the correct events
}

// ❌ DON'T: Mix Arrange-Act-Assert, use unclear naming, or skip side effects
[Fact]
public async Task BadTest()
{
    var response = await AuthenticatedMemberHttpClient.GetAsync("/api/users?search=willgate"); // ❌ Unclear test name, no Arrange/Act/Assert
    Assert.Equal(HttpStatusCode.OK, response.StatusCode); // ❌ DON'T: Mix basic asserts with the project's fluent assertion library
    // ❌ DON'T: Skip verifying DB or event side effects
}

// ✅ DO: Create helper methods for test data, call them in // Arrange
private async Task<Guid> InsertTestUser(string? email = null)
{
    var userId = Guid.NewGuid();
    await InsertRow("users", [
        ("id", userId),
        ("created_at", TimeProvider.System.GetUtcNow().AddMinutes(-10)),
        ("modified_at", null),
        ("email", email ?? Faker.Internet.Email()) // ✅ DO: Use Bogus for data that isn't part of the behavior
    ]);
    return userId;
}

[Fact]
public async Task GetUser_WhenUserExists_ShouldReturnUser()
{
    // Arrange
    var userId = await InsertTestUser(); // ✅ DO: Call helper in Arrange - keeps the test standalone

    // Act
    var response = await AuthenticatedOwnerHttpClient.GetAsync($"/api/users/{userId}");

    // Assert
    response.StatusCode.Should().Be(HttpStatusCode.OK);
}

// ❌ DON'T: Create test data in constructors
public sealed class BadTestSetup
{
    public BadTestSetup()
    {
        // ❌ DON'T: Add setup logic to the constructor - tests become implicit and harder to understand
        // Insert user // ❌ DON'T: Add subsection comments
        InsertRow("users", [("id", Guid.NewGuid()), ("email", "test@example.com")]).GetAwaiter().GetResult(); // ❌ DON'T: Block on async code
    }
}
```

`InsertRow`, `CountRows`, `EventCollector`, and the HTTP clients above stand for the project's own test helpers; use whatever the existing tests use.
