## Error Handling

### Clear User Messages
Display helpful, actionable messages that don't expose internal details or security-sensitive information.

### Fail Fast
Check preconditions and validate inputs early; reject invalid data before it can cause deeper problems.

### Typed Exceptions
Prefer specific exception types over generic ones so errors can be handled precisely.

### Centralized Handling
Catch and process errors at the appropriate boundaries (controllers, API layers) instead of scattering try-catch everywhere.

### Graceful Degradation
If non-critical services fail, keep running with reduced functionality instead of crashing entirely.

### Retry with Backoff
When calling external services, apply exponential backoff to transient failures.

### Resource Cleanup
Always free resources (file handles, connections) in finally blocks or an equivalent cleanup mechanism.
