# Coverage Without Confidence
tags: backend

There's something deeply unsatisfying about having 90% test coverage and still being afraid to deploy on a Friday. If you've ever felt that disconnect between what your coverage report tells you and how safe you actually feel pushing code, this post is for you.

## The Number That Lies

Let's start with what coverage actually measures. When you run `mix test --cover` or use a tool like ExCoveralls, you get a percentage that tells you how many lines of your code were executed during your test run. That's it. Not tested. Not verified. Just... touched.

```elixir
def transfer(from, to, amount) do
  balance = get_balance(from)

  if balance >= amount do
    debit(from, amount)
    credit(to, amount)
    {:ok, amount}
  else
    {:error, :insufficient_funds}
  end
end
```

Here's a test that gives you 100% coverage on this function:

```elixir
test "transfer with sufficient funds" do
  setup_account("alice", 100)
  setup_account("bob", 0)
  assert {:ok, 50} = Accounts.transfer("alice", "bob", 50)
end

test "transfer with insufficient funds" do
  setup_account("alice", 10)
  setup_account("bob", 0)
  assert {:error, :insufficient_funds} = Accounts.transfer("alice", "bob", 50)
end
```

Every line executed. Coverage report is green. Ship it 🚀

Except... what happens when two transfers run concurrently? What if `get_balance` returns stale data? What if `debit` succeeds but `credit` fails? The coverage report doesn't care about any of that.

## What Coverage Actually Misses

### Concurrency

Coverage is inherently single-path. It tells you each line ran at least once, but says nothing about what happens when multiple paths run simultaneously. Race conditions, deadlocks, lost updates - all invisible to coverage metrics.

### Edge Cases Within Covered Lines

A line can be "covered" without testing its interesting behavior:

```elixir
def parse_age(input) do
  String.to_integer(input)
end
```

One test with `"25"` gives you 100% coverage. But what about `"0"`, `"-1"`, `"99999999999999"`, `"not_a_number"`, or `""`? The line is covered. The behavior is not.

### Integration Boundaries

Unit tests with mocks can get you high coverage while completely missing the actual integration:

```elixir
test "sends notification" do
  expect(MockNotifier, :send, fn _user, _msg -> :ok end)
  assert :ok = Accounts.notify_user(user, "hello")
end
```

100% coverage on `notify_user`. But does the real notifier work? Does the message format match what the external service expects? Coverage can't tell you.

### Error Recovery Paths

You might cover the `{:error, _}` branch but not test what happens to system state after an error. Does the system recover? Are resources cleaned up? Partial failures are where the real bugs live.

## What Actually Builds Confidence

Here's the thing - I'm not saying coverage is useless. It's a decent smoke detector. Low coverage definitely means you're missing things. But high coverage doesn't mean you're catching things. The relationship is asymmetric.

What actually builds deployment confidence:

### Test Behavior, Not Lines

Instead of chasing coverage percentages, ask: "if someone broke this feature, would a test catch it?"

```elixir
# Low-value: tests that a function exists and returns something
test "get_user returns a user" do
  user = insert(:user)
  assert %User{} = Accounts.get_user(user.id)
end

# High-value: tests that the behavior works correctly
test "deactivated users cannot log in" do
  user = insert(:user, status: :deactivated)
  assert {:error, :account_deactivated} = Auth.login(user.email, "password123")
end
```

The second test catches real bugs. The first one mostly catches typos 🧐

### Property-Based Tests for Edge Cases

Instead of manually thinking of edge cases, let the computer explore:

```elixir
property "parsing and formatting are inverse operations" do
  check all amount <- positive_integer() do
    formatted = Money.format(amount)
    assert {:ok, ^amount} = Money.parse(formatted)
  end
end
```

This single property test exercises more edge cases than a hundred hand-written examples. And it finds the weird ones you'd never think of.

### Integration Tests at Real Boundaries

Mock less. Test the actual integration where it matters:

```elixir
test "full transfer flow with database" do
  alice = insert(:account, balance: 100)
  bob = insert(:account, balance: 0)

  assert {:ok, _} = Accounts.transfer(alice.id, bob.id, 50)

  assert Accounts.get_balance(alice.id) == 50
  assert Accounts.get_balance(bob.id) == 50
end
```

This test hits the database, exercises the transaction, and verifies the actual state. Worth more than ten unit tests with mocks.

### Mutation Testing

This is the real confidence builder. Mutation testing modifies your source code (introduces bugs on purpose) and checks whether your tests catch them. If you have 90% coverage but mutations survive, your tests are watching the code run without actually verifying anything.

Tools like `muzak` for Elixir can tell you the difference between "this line was executed" and "this line is actually tested".

## The Coverage Sweet Spot

After going through the cycle of ignoring coverage, chasing 100%, and then getting burned despite high numbers, here's where I've landed:

- **60-80% line coverage** is usually the sweet spot for most projects
- Focus effort on **critical paths**: money, auth, data integrity
- Use coverage to **find blind spots**, not as a quality metric
- **Mutation testing** on core business logic when you need real confidence
- **Integration tests** for anything that crosses a boundary

## Caveats

Coverage thresholds in CI are still useful as a floor. Setting a minimum (say 60%) catches the case where someone adds a large module with zero tests. That's different from treating it as a quality bar.

And there are codebases where high coverage genuinely correlates with quality - typically ones where the team writes tests first and coverage is a side effect, not a goal ❤️

## Conclusion

- Coverage measures execution, not verification - a line can be "covered" without being tested
- High coverage doesn't guarantee confidence; low coverage does guarantee risk
- Test behavior and outcomes, not implementation details
- Property-based tests find edge cases you'd never imagine
- Integration tests at real boundaries are worth more than mocked unit tests
- Use coverage as a smoke detector, not a quality certificate
