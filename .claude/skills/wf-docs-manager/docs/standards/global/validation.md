## Validation

### Server-Side Always
Validate on the server; for security and data integrity, client-side validation by itself is not enough.

### Client-Side for Feedback
Client-side validation is for immediate user feedback, but repeat the checks on the server.

### Validate Early
Check inputs as early as you can and reject invalid data before it is processed.

### Specific Errors
Give clear, field-specific messages that help users fix their input.

### Allowlists Over Blocklists
Define what is allowed instead of trying to block everything else.

### Type and Format Checks
Systematically validate data types, formats, ranges, and required fields.

### Input Sanitization
Sanitize user input to guard against injection attacks (SQL, XSS, command injection).

### Business Rules
Validate business logic (sufficient balance, valid dates) in the appropriate layer.

### Consistent Enforcement
Apply validation the same way at every entry point (forms, APIs, background jobs).
