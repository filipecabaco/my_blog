# Coverage Without Confidence
tags: backend, web

There's something deeply unsatisfying about having 90% test coverage and still being afraid to deploy on a Friday. I recently went through the exercise of improving coverage on a large Elixir codebase and came out the other side with opinions about what coverage actually means and what it doesn't.

The work here comes from [Supabase Realtime](https://github.com/supabase/realtime) where we went from running tests in a single CI job to partitioned parallel runs with merged coverage reports. The coverage number went up but the interesting part was what we learned about the gap between "lines executed" and "behavior verified".

## The Number That Lies

When you run `mix coveralls.github` you get a percentage that tells you how many lines were executed during your test run. That's it. Not tested. Not verified. Just touched.

Here's a real example. Our `check_tenant_connection` function queries Postgres for available connections and migration counts:

```elixir
defp query_connection_info(conn) do
  Postgrex.transaction(conn, fn conn ->
    %{rows: [[available_connections]]} = Postgrex.query!(conn, @connections_query, [])
    %{rows: [[table_exists]]} = Postgrex.query!(conn, @migrations_table_exists_query, [])

    %{rows: [[migrations_ran]]} =
      if table_exists, do: Postgrex.query!(conn, @migrations_count_query, []), else: %{rows: [[0]]}

    [available_connections, migrations_ran]
  end)
rescue
  e ->
    GenServer.stop(conn)
    {:error, e}
end
```

A test that just calls this function and checks `{:ok, _conn, _count}` covers every line. But does it verify what happens when the `schema_migrations` table doesn't exist? When the connection count is at the limit? When the transaction fails mid-way? Coverage says green. Confidence says maybe.

## What Coverage Actually Misses

### Concurrent Behavior

Our system manages hundreds of tenant connections simultaneously. Coverage can tell you each code path ran once, but says nothing about what happens when two tenants connect at the same time. The `Piper` pipeline for tenant connection runs through multiple steps:

```elixir
pipes = [
  GetTenant,
  CheckConnection,
  ReconcileMigrations,
  RegisterProcess
]
```

Each pipe runs in sequence for one tenant. But what if `ReconcileMigrations` for tenant A updates the database while `CheckConnection` for tenant B reads stale data? Coverage doesn't catch that. Only integration tests with real concurrent load do.

### Mocked Boundaries

When we stub out external calls, coverage looks great but we're not testing the real thing. This applies whether you're stubbing a GitHub API call in a blog or a tenant database connection in a real-time system. The pattern is the same: the stub always returns well-formed data, so coverage includes lines that never face timeouts, rate limits, or malformed responses.

The right move is to be honest about what stubs cover. Use them for unit tests where you need determinism, but don't count that coverage as proof that the integration works.

### The Rescue Path Nobody Tests

Look at that `rescue` block in `query_connection_info`. Does any test actually trigger it? Probably not. The happy path covers the function. The rescue clause gets counted because Elixir compiles it but no test verifies the error handling behavior.

To actually test it, you need to force the failure. For a Postgrex connection, that means killing the connection mid-transaction or pointing the query at a database that rejects it:

```elixir
test "handles connection failure during query", %{tenant: tenant} do
  {:ok, conn} = Database.connect(tenant, "realtime_test", :stop)
  GenServer.stop(conn)

  assert {:error, _} = Database.check_tenant_connection(tenant, conn)
end
```

This kind of test rarely shows up in coverage reports because the happy path already "covers" the function. But it's the test that actually matters when things go wrong in production.

## What Actually Builds Confidence

### Test Behavior, Not Lines

Instead of chasing the percentage, ask: "if someone broke this feature, would a test catch it?"

```elixir
test "returns 0 migrations when realtime.schema_migrations does not exist", %{tenant: tenant} do
  assert {:ok, _conn, 0} = Database.check_tenant_connection(tenant)
end

test "returns migration count when realtime.schema_migrations exists", %{tenant: tenant} do
  {:ok, conn} = Database.connect(tenant, "realtime_test", :stop)
  Postgrex.query!(conn, "CREATE TABLE IF NOT EXISTS realtime.schema_migrations (version bigint PRIMARY KEY)", [])
  Postgrex.query!(conn, "INSERT INTO realtime.schema_migrations VALUES (1), (2), (3)", [])

  assert {:ok, check_conn, 3} = Database.check_tenant_connection(tenant)
  GenServer.stop(check_conn)
  GenServer.stop(conn)
end
```

These tests hit a real Postgres container. They create actual tables. They verify actual behavior. Worth more than ten unit tests with mocked queries.

### Partition and Merge Coverage

When your suite gets large enough, running it in a single job becomes painful. We partitioned our tests across 4 CI workers, each producing its own coverage data:

```yaml
- name: Run tests
  run: >
    MIX_TEST_PARTITION=${{ matrix.partition }}
    MAX_CASES=3
    mix coveralls.github
    --partitions 4
    --parallel
    --flagname partition-${{ matrix.partition }}
```

Then a separate job merges them:

```yaml
coverage:
  name: Merge Coverage
  needs: tests
  steps:
    - uses: coverallsapp/github-action@v2
      with:
        parallel-finished: true
        carryforward: "partition-1,partition-2,partition-3,partition-4"
```

The total coverage number stays the same but now you get it 4x faster and each partition can have its own isolated database, avoiding the flakiness that comes from shared state.

### Integration Tests Over Mocks

Our test setup spins up real Docker containers:

```elixir
setup do
  tenant = Containers.checkout_tenant(run_migrations: true)
  %{tenant: tenant}
end
```

`Containers.checkout_tenant` starts a real Postgres instance, runs actual migrations, and hands you a tenant connected to a real database. It's slower than mocks. It's also what catches the bugs that actually make it to production.

## The Coverage Sweet Spot

After going through the cycle of ignoring coverage, chasing percentages, and getting burned despite high numbers, here's what worked for us:

- 60-80% line coverage ended up being our practical range
- Focus effort on critical paths: tenant connections, migrations, authorization
- Use coverage to find blind spots, not as a quality metric
- Integration tests on core flows, stubs for external boundaries
- Partition your CI so the feedback loop stays fast

## Conclusion

- Coverage measures execution, not verification - a line can be "covered" without being tested
- Test behavior and outcomes against real infrastructure, not mocked interfaces
- Partition CI runs for faster feedback without losing coverage accuracy
- Integration tests that hit real databases catch the bugs that actually ship
- Use coverage as a smoke detector, not a quality certificate
