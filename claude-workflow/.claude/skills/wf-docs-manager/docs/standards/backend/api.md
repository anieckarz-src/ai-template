## API Design

### RESTful Principles
Build resource-based URLs and pair them with the appropriate HTTP methods (GET, POST, PUT, PATCH, DELETE).

### Consistent Naming
Apply lowercase, hyphenated or underscored names consistently across all endpoints.

### Versioning
Version the API (via URL path or headers) so breaking changes can be managed.

### Plural Nouns
Name resources with plural nouns (`/users`, `/products`).

### Limited Nesting
For readability, limit URL nesting to 2-3 levels at most.

### Query Parameters
Handle filtering, sorting, and pagination through query parameters.

### Proper Status Codes
Respond with the appropriate HTTP status codes (200, 201, 400, 404, 500).

### Rate Limit Headers
Expose rate limit information in the response headers.
