# Accelerating CI: How We Reduced Build Times from 10 Minutes to 3
tags: backend, applications

Waiting for CI is the invisible tax on developer productivity. Ten minutes feels short until you multiply it by the dozens of PRs you push in a week. That's real context loss, delayed feedback, and frustration. We reduced our realtime test suite from ~10 minutes to ~3 by partitioning tests across parallel workers. It wasn't complicated, but it required thinking differently about how we organize and run tests.

## The Problem: Serialized Tests Don't Scale

Most CI setups run tests sequentially or across a fixed number of workers without considering test weight. A 30-second unit test gets the same worker slot as a 5-minute integration test. Fast tests wait behind slow ones. The bottleneck is the slowest test partition, not the sum of all tests.

We had ~1,259 test blocks distributed across 106 test files in unit, integration, and distributed channel categories. Running these sequentially on a single 4vCPU runner took ~10 minutes per CI run. But even with multiple workers, if tests weren't balanced, some workers would idle while others ran long. We were paying for the slowest partition's wall time, not benefiting from parallelism.

## The Solution: ExUnit's Built-in Partitioning

ExUnit has built-in test partitioning via `--partitions 4`. It automatically distributes tests evenly by name hash. We just needed three things:

**1. CI matrix strategy** — Run 4 parallel test jobs:

```yaml
strategy:
  matrix:
    partition: [1, 2, 3, 4]
run: MIX_TEST_PARTITION=${{ matrix.partition }} mix coveralls.lcov --partitions 4
```

**2. Partition-aware config** — Each partition gets unique databases and ports:

```elixir
partition = System.get_env("MIX_TEST_PARTITION")
database: "realtime_test#{partition}"       # test1, test2, test3, test4
http_port: if(partition, do: 4002 + String.to_integer(partition), else: 4002)
```

This allows all 4 partitions to run simultaneously without conflicts.

**3. Docker + dependency caching** — Cache the Postgres image and Mix dependencies:

```yaml
- Cache Docker image with key tied to version (auto-invalidates on upgrades)
- Use zstd compression (~40% smaller transfer)
- Cache Mix deps with hash of mix.lock
```

Result: ~1,259 tests distributed across 4 partitions. CI time: 10 minutes → 3 minutes.

## Key Wins

**Docker image caching** — Pulling Postgres took ~60-90s per partition. With `actions/cache` + zstd compression, first partition pulls (~60s), partitions 2-4 load from cache (~5s each). **Savings: ~180 seconds per CI run.**

**Mix dependency caching** — Cache keyed to `mix.lock` invalidates only when dependencies change. **Saves ~40 seconds per partition.**

**Partition isolation** — Each partition gets unique database name, HTTP port, and RPC ports. No coordination overhead—all 4 run independently in parallel.

**Coverage merging** — Each partition uploads its coverage, a separate job merges them with `carryforward`. Ensures accurate coverage across all 1,259 tests.

## The Trade-offs We Accept

**Cost:** 4× the runner hours means higher CI costs. We weighed this against developer time (expensive) vs. machine time (cheap). The trade-off was obvious.

**Flakiness amplification:** Running tests in parallel can surface race conditions that don't appear serially. But that's a feature, not a bug—those races are real bugs you want to catch. We invested in making tests deterministic (removing hardcoded timeouts, using proper async waits) rather than hiding the problems.

**Setup/teardown overhead:** Each partition spins up its own Postgres container. For 4 partitions, that's 4× database startup overhead. Worth it when the slowest test suite takes 8 minutes, but at very large scales (50+ partitions), this gets expensive. Know your boundary.

## Results

- **Before:** ~1,259 tests running serially: ~10 minutes per CI run
- **After:** Same tests partitioned across 4 workers: ~3 minutes per CI run (max partition time)
- **Speedup:** 3.3x faster
- **Per developer per week:** ~2.3 hours saved (assuming 20 CI runs/week at 7 minutes saved each)
- **Infrastructure:** 8vCPU runners × 4 partitions = more expensive per run, but outweighed by developer velocity gains
- **Feedback loop:** Context loss eliminated. PRs can be validated in 3 minutes instead of 10, keeping developers in flow.

## Caveats

**Uneven partition balance** — ExUnit distributes by name hash, which is usually balanced. If one partition runs significantly longer, you can adjust by reordering tests or splitting problematic test files.

**Flaky tests surface faster** — Parallelization reveals race conditions that hide in serial runs. If you see new flakiness after partitioning, that's actually a bug you want to catch. Fix the race condition, don't avoid parallelization.

**Infrastructure cost** — 4 parallel runners costs more than 1. But the math favors it: developer time saved (2–3 hours/dev/week) far exceeds the compute cost increase.

## Conclusion

Partitioning CI is a straightforward optimization with outsized returns: less time waiting, better test isolation, and catching real concurrency bugs. It costs more in machine resources but pays back in developer velocity.

The key is balancing test execution time so all workers finish around the same time. Measure once, partition intelligently, then iterate based on real run times. Your team will notice.
