# Accelerating CI: How We Reduced Build Times from 10 Minutes to 3
tags: backend, applications

Waiting for CI is the invisible tax on developer productivity. Ten minutes feels short until you multiply it by the dozens of PRs you push in a week. That's real context loss, delayed feedback, and frustration. We reduced our realtime test suite from ~10 minutes to ~3 by partitioning tests across parallel workers. It wasn't complicated, but it required thinking differently about how we organize and run tests.

## The Problem: Serialized Tests Don't Scale

Most CI setups run tests sequentially or across a fixed number of workers without considering test weight. A 30-second unit test gets the same worker slot as a 5-minute integration test. Fast tests wait behind slow ones. The bottleneck is the slowest test partition, not the sum of all tests.

We had 800+ tests across unit, integration, and distributed channels:
- Unit tests: ~2 minutes
- Integration tests: ~5 minutes
- Distributed channel tests: ~3 minutes

Running these sequentially on a single runner totaled ~10 minutes per CI run. But even on a 4-worker job, if tests weren't balanced, three workers would finish in 3 minutes while one chugged along for 8 minutes. We were paying for the 8-minute max, not the 3-minute median.

## The Solution: Intelligent Test Partitioning

Partition CI by distributing tests evenly across workers by execution time, not by count. Instead of running 200 tests on worker 1 and 100 on worker 2, run a mix of fast and slow tests on each so all workers finish around the same time.

Our approach:

**1. Measure test durations** — Run the full suite once with timing output. Elixir's `ExUnit` includes this:

```bash
MIX_ENV=test mix test --max-failures=100 2>&1 | grep -E "^\s+\d+\.\d+ [a-z_]+"
```

Most tests finish in milliseconds. The slow ones (integration tests, database operations, distributed node coordination) take 100ms–5000ms.

**2. Define partitions** — Split tests into N groups where each worker gets a balanced mix of slow + fast tests. We used 4 partitions:

```elixir
# config/test.exs
partition = System.get_env("MIX_TEST_PARTITION", "1") |> String.to_integer()
partitions = 4

# Calculate which tests this partition should run
# Distribute by test name hash so the split is deterministic
test_exclude_filters = []

if partition do
  test_exclude_filters = [
    {:exclude, {:partition, fn test_number ->
      rem(test_number, partitions) != partition - 1
    end}}
  ]
end

config :ex_unit,
  exclude: test_exclude_filters,
  formatters: [ExUnit.CLIFormatter, ExUnit.Sobertest.Formatter]
```

**3. Tag tests by partition** — Not all tests need partitioning. We tagged integration tests (the slow ones):

```elixir
defmodule RealtimeChannel.BroadcastTest do
  use ExUnit.Case, async: false

  @moduletag :partition

  test "broadcast delivers to subscribers" do
    # ...
  end
end
```

**4. Run partitions in parallel on CI** — Use your CI's matrix strategy:

```yaml
jobs:
  tests:
    name: Tests (Partition ${{ matrix.partition }})
    runs-on: ubuntu-latest
    strategy:
      matrix:
        partition: [1, 2, 3, 4]
    steps:
      - uses: actions/checkout@v6
      - uses: erlef/setup-beam@v1
      - name: Run tests
        run: MIX_TEST_PARTITION=${{ matrix.partition }} mix test --cover
```

Each partition runs independently, and CI only succeeds if all 4 pass. Parallel execution shrank our runtime from ~10 minutes (serial) to ~3 minutes (max partition time).

## The Details That Mattered

**Docker layer caching** — Pulling the Postgres image for every partition was wasteful. We cached it:

```yaml
- name: Cache Docker images
  uses: actions/cache@v5
  id: docker-cache
  with:
    path: /tmp/docker-images
    key: docker-images-zstd-${{ env.POSTGRES_IMAGE }}

- name: Load Docker images from cache
  if: steps.docker-cache.outputs.cache-hit == 'true'
  run: zstd -d --stdout /tmp/docker-images/postgres.tar.zst | docker image load
```

This saved ~60 seconds per partition startup.

**Dependency caching** — `mix deps.get` downloads and compiles dependencies. Cache it:

```yaml
- name: Cache Mix
  uses: actions/cache@v5
  with:
    path: |
      deps
      _build
    key: ${{ github.workflow }}-${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
```

Saves ~40 seconds per partition.

**Coverage merging** — Each partition uploads coverage data. We merge them after all partitions succeed:

```yaml
coverage:
  name: Merge Coverage
  needs: tests
  if: ${{ needs.tests.result == 'success' }}
  runs-on: ubuntu-latest
  steps:
    - uses: coverallsapp/github-action@v2
      with:
        parallel-finished: true
        carryforward: "partition-1,partition-2,partition-3,partition-4"
```

This gives accurate total coverage without double-counting.

## The Trade-offs We Accept

**Cost:** 4× the runner hours means higher CI costs. We weighed this against developer time (expensive) vs. machine time (cheap). The trade-off was obvious.

**Flakiness amplification:** Running tests in parallel can surface race conditions that don't appear serially. But that's a feature, not a bug—those races are real bugs you want to catch. We invested in making tests deterministic (removing hardcoded timeouts, using proper async waits) rather than hiding the problems.

**Setup/teardown overhead:** Each partition spins up its own Postgres container. For 4 partitions, that's 4× database startup overhead. Worth it when the slowest test suite takes 8 minutes, but at very large scales (50+ partitions), this gets expensive. Know your boundary.

## Results

- Serial tests: 10–12 minutes
- Partitioned across 4 workers: 3–4 minutes (usually bottlenecked by the slowest partition)
- **Time saved per developer per week:** ~2–3 hours (assuming 20 CI runs/week)
- **Developer morale:** Noticeably better. Faster feedback loops reduce context loss and frustration.

## What to Watch

**Uneven partition balance** — If one partition consistently runs longer than others, rebalance by moving tests. We check partition times on every run:

```bash
# In CI logs
partition-1: 3m 15s ✓
partition-2: 3m 42s ✓
partition-3: 3m 08s ✓
partition-4: 4m 01s ✗ (slowest)
```

If partition-4 regularly runs 1m longer, move a slow test to a faster partition and re-run.

**Flaky tests under parallelization** — Some tests only fail when run alongside others. We added logging and deterministic test ordering to surface these early.

**Don't partition everything** — Linting, type checking, and simple unit tests don't benefit from partitioning. Keep them on a single runner. Only partition suites where the total time is >5 minutes.

## Conclusion

Partitioning CI is a straightforward optimization with outsized returns: less time waiting, better test isolation, and catching real concurrency bugs. It costs more in machine resources but pays back in developer velocity.

The key is balancing test execution time so all workers finish around the same time. Measure once, partition intelligently, then iterate based on real run times. Your team will notice.
