## Database Queries

### Parameterized Queries
Always rely on parameterized queries or ORM methods; never interpolate user input into SQL.

### Avoid N+1
Fetch related data in a single query using eager loading or joins.

### Select Only Needed Columns
Ask only for the columns you need instead of SELECT *.

### Index Strategic Columns
Add indexes to columns that appear in WHERE, JOIN, and ORDER BY clauses.

### Transactions
Group related operations in transactions to keep data consistent.

### Query Timeouts
Configure timeouts so runaway queries can't degrade performance.

### Cache Expensive Queries
Where appropriate, cache the results of complex or frequently run queries.
