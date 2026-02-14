# When Migrations Go Wrong
tags: backend, data

That moment when you deploy to production and your migration fails halfway through. The table is partially altered, the old code expects the old schema, the new code expects the new one, and you're stuck somewhere in between wondering how this worked perfectly in staging. Let's talk about database migrations going sideways and what to do about it.

## The Simple Case That Isn't

Most migration tutorials show you something like this:

```elixir
defmodule MyApp.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "active"
    end
  end
end
```

Clean. Reversible. What could go wrong?

Plenty, actually. What if the `users` table has 50 million rows? That `ALTER TABLE` with a default value will lock the table while it rewrites every row. Your application is now serving 500 errors for as long as that takes 😅

## The Ways It Goes Wrong

### Lock Contention

The most common production migration failure. Long-running migrations hold locks that block queries, which pile up, which exhaust your connection pool, which takes down your app. The migration might succeed eventually, but your users already left.

```elixir
# This locks the table for the duration
alter table(:orders) do
  add :tracking_number, :string
end

create index(:orders, [:tracking_number])
```

The fix is to be explicit about concurrency:

```elixir
# This doesn't lock
alter table(:orders) do
  add :tracking_number, :string
end

# Create index without blocking writes
create index(:orders, [:tracking_number], concurrently: true)
```

In Ecto, `concurrently: true` translates to `CREATE INDEX CONCURRENTLY` which doesn't lock the table. You'll need to disable the migration transaction wrapper though:

```elixir
@disable_ddl_transaction true
@disable_migration_lock true
```

### Partial Failures

This is the scary one. Your migration runs three operations. The first two succeed. The third fails. Now your database is in a state that neither the old code nor the new code expects.

```elixir
def change do
  alter table(:products) do
    add :category_id, references(:categories)  # succeeds
  end

  execute "UPDATE products SET category_id = ..."  # succeeds

  alter table(:products) do
    remove :category_name  # fails - column still referenced somewhere
  end
end
```

If the migration runs inside a transaction (Ecto's default), the whole thing rolls back. Safe. But if you needed `@disable_ddl_transaction true` for concurrent indexing? Now you've got a partially applied migration that Ecto thinks succeeded based on the schema_migrations table.

### Schema Drift

Over time, the state of your database can drift from what your migrations describe. Someone runs a manual `ALTER TABLE` in production. A migration gets edited after being applied to some environments. A failed migration leaves artifacts. Now your migration history doesn't match reality.

The symptom is usually a migration that works in a fresh database but fails in production with "column already exists" or "relation does not exist".

## Strategies for the Real World

### Split Destructive Migrations

Never add and remove in the same migration. Split them across deploys:

**Deploy 1**: Add the new column, start writing to it

```elixir
def change do
  alter table(:products) do
    add :category_id, references(:categories)
  end
end
```

**Deploy 2**: Backfill data, stop reading the old column

```elixir
def up do
  execute "UPDATE products SET category_id = categories.id FROM categories WHERE categories.name = products.category_name"
end
```

**Deploy 3**: Remove the old column (once you're sure nothing reads it)

```elixir
def change do
  alter table(:products) do
    remove :category_name, :string
  end
end
```

Three deploys instead of one. More work? Yes. But each step is independently safe and reversible.

### Migration Reconciliation

When your database drifts from your migration history, you need to reconcile. The approach depends on how far things have drifted:

**Minor drift** - A column was added manually. Write a migration that's idempotent:

```elixir
def up do
  unless column_exists?(:users, :avatar_url) do
    alter table(:users) do
      add :avatar_url, :string
    end
  end
end

defp column_exists?(table, column) do
  query = """
  SELECT 1 FROM information_schema.columns
  WHERE table_name = '#{table}' AND column_name = '#{column}'
  """
  case repo().query(query) do
    {:ok, %{num_rows: n}} when n > 0 -> true
    _ -> false
  end
end
```

**Major drift** - Multiple manual changes, lost migration history. At this point, generate a "baseline" migration from the current schema and squash everything before it:

```bash
# Dump current schema
pg_dump --schema-only myapp_prod > baseline.sql

# Create a new migration that applies this baseline
# Mark all previous migrations as "applied" in schema_migrations
```

This is the nuclear option but sometimes the honest thing to do.

### Rollback Plans

Every migration should have an answer to "what if we need to roll back?" before it runs.

For `change` migrations, Ecto handles rollback automatically. For `up/down` migrations, write the `down` explicitly and test it:

```elixir
def up do
  execute """
  CREATE TYPE order_status AS ENUM ('pending', 'confirmed', 'shipped', 'delivered')
  """

  alter table(:orders) do
    add :status, :order_status, default: "pending"
  end
end

def down do
  alter table(:orders) do
    remove :status
  end

  execute "DROP TYPE order_status"
end
```

And here's a tip that's saved me more than once: test your rollbacks in a staging environment before deploying. Run up, run down, run up again. If the round-trip works, you have an escape hatch 🧐

### Monitor During Migration

Don't just fire and forget. Watch your database during migrations:

```sql
-- Check for lock contention
SELECT blocked_locks.pid AS blocked_pid,
       blocking_locks.pid AS blocking_pid,
       blocked_activity.query AS blocked_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_locks blocking_locks
  ON blocking_locks.locktype = blocked_locks.locktype
WHERE NOT blocked_locks.granted;
```

If you see locks piling up, you still have time to cancel the migration before it causes an outage.

## Caveats

I've been talking about Ecto and Postgres here because that's what I know, but these patterns apply to any database migration tool. The underlying problems - lock contention, partial failures, schema drift - are universal.

Also, for small tables (under a million rows), most of this is overkill. A simple `change` migration in a transaction will finish in milliseconds. The complexity is worth it when you're dealing with large tables in production with active traffic ❤️

## Conclusion

- Never combine additive and destructive changes in the same migration
- Use `concurrently: true` for indexes on large tables and disable the transaction wrapper
- Split risky migrations across multiple deploys
- Write idempotent migrations when reconciling schema drift
- Test rollbacks before deploying - run up, down, up in staging
- Monitor lock contention during migration execution
- The boring, multi-step approach is almost always the right one
