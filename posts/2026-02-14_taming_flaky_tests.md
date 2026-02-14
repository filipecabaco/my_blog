# Taming Flaky Tests
tags: backend

If you've ever stared at a CI pipeline going red for no apparent reason, only to hit "rerun" and watch it go green, you know the pain. Flaky tests are one of those problems that seem minor until they erode all trust in your test suite. In this post I'll share some patterns I've found useful for making async and concurrent tests actually reliable.

## The Anatomy of a Flaky Test

Most flaky tests come from one of three places: timing assumptions, shared state, or ordering dependencies. Let's break them down.

### Timing Assumptions

This is the biggest offender in async code. You write something like this:

```elixir
test "process sends message after initialization" do
  start_supervised!(MyWorker)
  assert_received :ready
end
```

The problem? `start_supervised!/1` returns as soon as the process starts, but `:ready` might be sent in `handle_continue/2` which runs asynchronously. On your machine it's fast enough. On CI with limited resources, it's a coin flip 😅

The fix is straightforward - use `assert_receive/2` with an explicit timeout instead of `assert_received/1`:

```elixir
test "process sends message after initialization" do
  start_supervised!(MyWorker)
  assert_receive :ready, 1_000
end
```

`assert_receive` will wait up to the timeout for the message to arrive. `assert_received` only checks the mailbox at that exact instant.

### Shared State

Async test suites are great for speed but brutal when tests share state. ETS tables, named processes, application env - anything global becomes a potential race condition.

```elixir
# This test will randomly fail when run with async: true
test "configuration changes take effect" do
  Application.put_env(:my_app, :feature_flag, true)
  assert MyApp.feature_enabled?()
  Application.put_env(:my_app, :feature_flag, false)
end
```

Two instances of this test running simultaneously will stomp on each other. The solution: isolate state per test. Pass configuration explicitly instead of relying on global state:

```elixir
test "configuration changes take effect" do
  assert MyApp.feature_enabled?(feature_flag: true)
  refute MyApp.feature_enabled?(feature_flag: false)
end
```

If you absolutely need global state, drop `async: true` for that module. It's better to have a slower test that's reliable than a fast one that's a liar.

### Ordering Dependencies

This one is sneaky. Test A creates some data, test B happens to run after A and implicitly depends on that data. Works fine until ExUnit shuffles the order.

```elixir
# test A
test "creates a user" do
  {:ok, _user} = Accounts.create_user(%{name: "test"})
  assert Accounts.count_users() == 1
end

# test B - implicitly depends on A having run first
test "lists all users" do
  users = Accounts.list_users()
  assert length(users) == 1
end
```

Each test should set up its own world. If test B needs a user, it should create one. The `setup` block is your friend here.

## Strategies That Actually Work

### Make Async Boundaries Explicit

Whenever a function kicks off an async operation, give callers a way to know when it's done. This is one of the best investments you can make for testability:

```elixir
defmodule MyWorker do
  use GenServer

  def start_link(opts) do
    caller = Keyword.get(opts, :caller)
    GenServer.start_link(__MODULE__, %{caller: caller})
  end

  def init(state) do
    {:ok, state, {:continue, :setup}}
  end

  def handle_continue(:setup, %{caller: caller} = state) do
    # do the actual work...
    if caller, do: send(caller, :ready)
    {:noreply, state}
  end
end
```

Now your tests can reliably wait:

```elixir
test "worker initializes properly" do
  start_supervised!({MyWorker, caller: self()})
  assert_receive :ready, 5_000
end
```

### Use Sandbox Patterns

If you're using Ecto, you already know `Ecto.Adapters.SQL.Sandbox`. The same pattern works for other shared resources. Wrap them so each test gets its own isolated instance:

```elixir
setup do
  cache = start_supervised!({MyCache, name: :"cache_#{System.unique_integer()}"})
  %{cache: cache}
end

test "caching works", %{cache: cache} do
  MyCache.put(cache, :key, "value")
  assert MyCache.get(cache, :key) == "value"
end
```

The trick is using unique names per test. No shared state, no races.

### Don't Retry, Fix

This is the hardest one to follow through on 🧐 When a test flakes, the temptation is to add a retry mechanism or increase timeouts. Resist. Every retry is a lie you're telling yourself about the reliability of your code.

Instead, when a test flakes:

1. Reproduce it locally (run the test in a loop: `for i in {1..100}; do mix test test/my_test.exs; done`)
2. Identify the category (timing, state, ordering)
3. Apply the appropriate isolation pattern
4. Verify by running in a loop again

If you can't reproduce it locally, it's almost certainly a resource contention issue. CI runners have less CPU, less memory, and more noisy neighbors. Your test is probably making a timing assumption that only holds with fast hardware.

## The Compound Effect

Here's the thing about flaky tests that people don't talk about enough - the damage is exponential. One flaky test in a suite of 500? Annoying but manageable. Ten flaky tests? Now your CI pipeline fails ~30% of the time purely from test noise. People start ignoring failures. Real bugs slip through because "it's probably just the flaky test". The whole point of having tests collapses.

Fix flaky tests the moment you spot them. It's never "just" a flaky test.

## Caveats

I should be honest here - some async operations are genuinely hard to test deterministically. External services, time-dependent logic, network calls. For those, mocking the boundary is the right call. The point isn't "never mock" but "don't mock to hide flakiness in your own code".

Also, there are legitimate cases where `async: false` is the right answer. If your tests need to share a resource that can't be sandboxed, sequential execution is better than fragile parallelism ❤️

## Conclusion

- Flaky tests almost always come from timing, shared state, or ordering assumptions
- Use `assert_receive` with explicit timeouts instead of `assert_received` for async code
- Isolate state per test using unique names and explicit dependencies
- Give async operations an explicit "I'm done" signal for testability
- Fix flaky tests immediately - the compound effect of ignoring them destroys trust in your suite
- Retries are band-aids, not solutions
