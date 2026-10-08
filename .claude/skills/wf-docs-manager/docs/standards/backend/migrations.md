## Database Migrations

### Reversible
Always provide rollback methods so migrations can be reversed safely.

### Small and Focused
Limit each migration to one logical change.

### Zero-Downtime Awareness
For high-availability systems, take deployment order and backward compatibility into account.

### Separate Schema and Data
Keep data migrations apart from schema changes so rollbacks are safer.

### Careful Indexing
Be careful when creating indexes on large tables, and use concurrent options where available.

### Descriptive Names
Give migrations names that say what they do.

### Version Control
Commit migrations, and never alter existing ones once deployed.
