## Test Writing

### Test Behavior
Test what the code does rather than how it does it, so refactoring stays safe.

### Clear Names
Give tests descriptive names that say what is tested and what is expected (`shouldReturnErrorWhenUserNotFound`).

### Mock External Dependencies
Keep tests isolated by mocking databases, APIs, and external services.

### Fast Execution
Keep unit tests fast (milliseconds) so developers run them often.

### Risk-Based Testing
Set testing priorities by business criticality and the likelihood of bugs.

### Balance Coverage and Velocity
Tune test coverage to the project's needs and the team's workflow.

### Critical Path Focus
Make sure core user workflows and critical business logic have solid test coverage.

### Appropriate Depth
Scale edge case testing to the code's risk profile.
