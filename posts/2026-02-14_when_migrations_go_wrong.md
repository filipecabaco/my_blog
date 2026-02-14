# When Migrations Go Wrong
tags: backend, data

That moment when you realize your migration count in the application doesn't match what's actually in the database. It happened to us on a real-time system managing thousands of tenant databases and the fix turned out to be more interesting than the bug. This post is about migrations going sideways and what to do about it.

The code here comes from [Supabase Realtime](https://github.com/supabase/realtime), where each tenant gets their own Postgres schema with migrations managed by the application itself. When you're running migrations across thousands of databases, the things that can go wrong multiply fast.

## The Problem

Our system tracks how many migrations have been applied to each tenant database. When a tenant connects, we check if new migrations need to run by comparing a cached counter against the total migrations available:

```elixir
defstruct tenant_id: nil,
          db_conn_pid: nil,
          db_conn_reference: nil,
          tenant: nil,
          replication_connection_attempts: 0,
          check_connected_user_interval: nil,
          connected_users_bucket: [1],
          check_connect_region_interval: nil,
          migrations_ran_on_database: 0
```

Simple enough. Except... what happens when a tenant restores their database from a backup? The database rolls back to an earlier state but our cached `migrations_ran` counter still says the latest value. Now we think all migrations have been applied when half of them are actually missing 😅

## The Fix: Migration Reconciliation

Instead of trusting the cached count, we now query the actual database during every tenant connection to verify:

```elixir
@migrations_table_exists_query """
SELECT to_regclass('realtime.schema_migrations') IS NOT NULL
"""

@migrations_count_query """
SELECT count(*)::int FROM realtime.schema_migrations
"""

defp query_connection_info(conn) do
  Postgrex.transaction(conn, fn conn ->
    %{rows: [[available_connections]]} = Postgrex.query!(conn, @connections_query, [])
    %{rows: [[table_exists]]} = Postgrex.query!(conn, @migrations_table_exists_query, [])

    %{rows: [[migrations_ran]]} =
      if table_exists, do: Postgrex.query!(conn, @migrations_count_query, []), else: %{rows: [[0]]}

    [available_connections, migrations_ran]
  end)
end
```

First we check if the `schema_migrations` table even exists (a fresh database won't have one), then count the actual rows. This gives us the real number to compare against.

Then we added a reconciliation step to the tenant connection pipeline:

```elixir
defmodule Realtime.Tenants.Connect.ReconcileMigrations do
  use Realtime.Logs
  alias Realtime.Api

  @behaviour Realtime.Tenants.Connect.Piper

  @impl true
  def run(%{tenant: tenant, migrations_ran_on_database: migrations_ran_on_database} = acc) do
    if tenant.migrations_ran != migrations_ran_on_database do
      log_warning(
        "MigrationCountMismatch",
        "cached=#{tenant.migrations_ran} database=#{migrations_ran_on_database}"
      )

      case Api.update_migrations_ran(tenant.external_id, migrations_ran_on_database) do
        {:ok, updated_tenant} -> {:ok, %{acc | tenant: updated_tenant}}
        {:error, error} -> {:error, error}
      end
    else
      {:ok, acc}
    end
  end
end
```

This slots into the existing connection pipeline as a new pipe:

```elixir
pipes = [
  GetTenant,
  CheckConnection,
  ReconcileMigrations,
  RegisterProcess
]
```

If there's a mismatch, we log a warning and update the cached count to match reality. The next time migrations run, they'll apply the ones that are actually missing instead of skipping them.

## Squashing Old Migrations

Once you've accumulated dozens of migrations over years, something else becomes painful. New tenant databases still have to run through every single migration from the beginning. Thirty migrations that create, alter, and re-alter the same tables. Each one was necessary at the time but the intermediate states are history now.

The approach we took was replacing old migration bodies with no-ops and adding a single "squash" migration that creates the final schema from scratch:

```elixir
# Old migration - now a no-op
defmodule Realtime.Tenants.Migrations.CreateRealtimeSubscriptionTable do
  @moduledoc false
  use Ecto.Migration
  def change, do: nil
end
```

The squash migration checks if it's a fresh database (no existing tables) and applies the entire schema in one go. If the tables already exist, it's a no-op. This way, existing databases keep their migration history intact while new databases get set up in a single step instead of replaying years of schema evolution.

The key detail: the old migrations stay in the list with their original version numbers so that `schema_migrations` stays consistent:

```elixir
@migrations [
  {20_211_116_024_918, CreateRealtimeSubscriptionTable},
  {20_211_116_045_059, CreateRealtimeCheckFiltersTrigger},
  # ... 30+ more no-ops ...
  {20_260_211_000_000, SquashMigrations}
]
```

## Testing Migration Reconciliation

The tests for this had to be thorough because getting migration counting wrong means silently losing schema changes:

```elixir
test "does nothing when migrations_ran matches database count", %{tenant: tenant} do
  acc = %{tenant: tenant, migrations_ran_on_database: tenant.migrations_ran}
  assert {:ok, %{tenant: returned_tenant}} = ReconcileMigrations.run(acc)
  assert returned_tenant.migrations_ran == tenant.migrations_ran
end

test "updates tenant when database has fewer migrations than cached count", %{tenant: tenant} do
  stale_count = tenant.migrations_ran - 5
  acc = %{tenant: tenant, migrations_ran_on_database: stale_count}
  assert {:ok, %{tenant: updated_tenant}} = ReconcileMigrations.run(acc)
  assert updated_tenant.migrations_ran == stale_count
end
```

The second test simulates exactly the database restore scenario. The cached count says we've run all migrations, but the database only has some of them. After reconciliation, the counter is corrected and the missing migrations will be applied on the next run 🧐

## Caveats

This approach works because our migrations are designed to be idempotent where possible. If a migration runs against a database that already has the table, it uses `IF NOT EXISTS`. If your migrations aren't idempotent, reconciling counts could cause failures when re-running "already applied" migrations.

Also, the squash migration strategy only works cleanly if you control all the databases. If third parties have databases at various migration versions, you need to be careful that the squash doesn't skip migrations they actually need.

## Conclusion

- Never trust a cached migration counter - verify against the actual database
- Database restores can silently revert schema while your application thinks everything is current
- Add reconciliation as a pipeline step during connection, not as an afterthought
- Squash old migrations into no-ops to speed up new database setup
- Keep original version numbers in the migration list so `schema_migrations` stays consistent
- Test both the match and mismatch cases - silent miscounts are the worst bugs to debug
