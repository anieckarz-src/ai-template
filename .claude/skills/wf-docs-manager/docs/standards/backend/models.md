## Models

### Clear Naming
Name models in the singular and tables in the plural (or follow the framework's conventions).

### Timestamps
Add created and updated timestamps to support auditing and debugging.

### Database Constraints
Enforce data rules in the database itself (NOT NULL, UNIQUE, foreign keys).

### Appropriate Types
Pick data types that fit the purpose and size requirements.

### Index Foreign Keys
Add indexes to foreign key columns and to frequently queried fields.

### Multi-Layer Validation
For defense in depth, validate at both the model and the database level.

### Clear Relationships
Define relationships with suitable naming and cascade behaviors.

### Practical Normalization
Weigh normalization against the needs of query performance.
