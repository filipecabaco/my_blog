# Taming Flaky Tests
tags: backend

There's nothing quite like watching your CI go red, hitting rerun, and watching it go green. That specific combination of relief and dread is what got me to finally sit down and deal with flaky tests in a real-time system I work on. This post is about what I found and how we fixed it.

All the patterns here come from real work on [Supabase Realtime](https://github.com/supabase/realtime), an Elixir system that manages WebSocket connections to Postgres. The test suite runs against real Docker containers spinning up actual Postgres instances, which makes it powerful but also a minefield for flakiness.

## The Usual Suspects

Most of our flaky tests came from three places: timing assumptions, shared state, and resource contention. Let me show you the real examples.

### Timing Assumptions

This was the biggest offender. We had tests that used `Process.sleep/1` to wait for async operations:

```elixir
test "set_position updates the position of a registered tag" do
  start_tag(id, "my_post")
  Supervisor.set_position(id, 150)
  Process.sleep(10)
  assert Supervisor.get_state(id).position == 150
end
```

That `Process.sleep(10)` works fine on a beefy dev machine but on CI with limited resources? Coin flip. The cast might not have been processed in 10 milliseconds 😅

The fix is to either use `assert_receive` with a proper timeout when you can, or to build polling helpers for cases where you're waiting on process state:

```elixir
defp eventually(fun, opts \\ []) do
  timeout = Keyword.get(opts, :timeout, 1_000)
  interval = Keyword.get(opts, :interval, 50)
  deadline = System.monotonic_time(:millisecond) + timeout

  do_eventually(fun, interval, deadline)
end

defp do_eventually(fun, interval, deadline) do
  case fun.() do
    true -> :ok
    false ->
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(interval)
        do_eventually(fun, interval, deadline)
      else
        flunk("condition not met within timeout")
      end
  end
end
```

Now instead of hoping 10ms is enough, you poll until the condition is true or a real timeout expires.

### Shared State and Global Registration

We had tests that registered processes globally and then wondered why they clashed:

```elixir
test "start registers a read tag and get_state returns it" do
  id = "sup-start-#{System.unique_integer()}"
  start_tag(id, "my_post")
  state = Supervisor.get_state(id)
  assert state.title == "my_post"
  cleanup(id)
end
```

The `System.unique_integer()` helps avoid name collisions, but when tests run with `async: false` on the same named Registry, global registration can still race. We also had tests that relied on `Application.put_env` which is global state that any concurrent test can stomp on.

The solution is isolation. Each test gets its own world:

```elixir
setup do
  Blog.Posts.invalidate_cache()
  Application.put_env(:blog, :req_options, plug: {Req.Test, __MODULE__})

  on_exit(fn ->
    Application.delete_env(:blog, :req_options)
    Blog.Posts.invalidate_cache()
  end)
end
```

The `on_exit` callback is crucial. Without it, one test's state leaks into the next.

### Resource Contention in CI

This is the one that really bit us. Our test suite spins up Docker containers with real Postgres instances. On CI, pulling Docker images and starting containers takes time and resources. Tests would fail not because of bugs but because the database wasn't ready yet.

The fix had two parts. First, cache Docker images in CI so they don't need to be pulled every run:

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

Second, partition the tests so they don't fight over resources. Each partition gets its own database and port:

```elixir
partition = System.get_env("MIX_TEST_PARTITION")

config :realtime, repo,
  database: "realtime_test#{partition}",
  pool: Ecto.Adapters.SQL.Sandbox

http_port = if partition, do: 4002 + String.to_integer(partition), else: 4002

config :realtime, RealtimeWeb.Endpoint,
  http: [port: http_port],
  server: true
```

Even the RPC ports needed partitioning to avoid collisions:

```elixir
gen_rpc_offset = if partition, do: String.to_integer(partition) * 10, else: 0

config :gen_rpc,
  tcp_server_port: 5969 + gen_rpc_offset,
  tcp_client_port: 5970 + gen_rpc_offset
```

## The Compound Effect

Here's what people don't talk about enough. One flaky test in a suite of 500 is annoying. Ten flaky tests means your CI fails roughly 30% of the time from pure noise. People start hitting rerun reflexively. Real bugs slip through because "it's probably just the flaky test". The whole point of having tests collapses.

After partitioning our CI into 4 parallel jobs and fixing the timing issues, our false failure rate dropped dramatically. And the suite actually runs faster because the partitions execute in parallel 🧐

## Caveats

Some async operations are genuinely hard to test deterministically. External services, time-dependent logic, network calls. For those, mocking the boundary with something like `Req.Test` stubs is the right call. The point isn't "never mock" but "don't mock to hide flakiness in your own code".

Also, `async: false` is sometimes the honest answer. If your tests need a shared resource that can't be sandboxed, sequential execution is better than fragile parallelism.

## Conclusion

- Most flaky tests come from timing assumptions, shared state, or resource contention
- Replace `Process.sleep` with polling helpers or `assert_receive` with real timeouts
- Isolate test state with unique names and `on_exit` cleanup
- Partition CI runs so tests don't fight over databases and ports
- Cache Docker images in CI to avoid pull-time variance
- Fix flaky tests the moment you spot them - the compound effect is brutal
