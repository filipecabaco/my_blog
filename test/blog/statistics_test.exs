defmodule Blog.StatisticsTest do
  use ExUnit.Case, async: false

  alias Blog.Statistics

  test "fetch returns 0 for unknown title" do
    assert Statistics.fetch("nonexistent_post_#{System.unique_integer()}") == 0
  end

  test "telemetry event increments an existing counter" do
    title = "test_telemetry_#{System.unique_integer()}"

    # Seed the dets entry so update_counter works
    :dets.insert(:statistics, {to_charlist(title), 0})

    assert Statistics.fetch(title) == 0

    :telemetry.execute([:blog, :visit], %{}, %{title: title})
    assert Statistics.fetch(title) == 1

    :telemetry.execute([:blog, :visit], %{}, %{title: title})
    assert Statistics.fetch(title) == 2
  end

  test "fetch works for a manually inserted counter" do
    title = "manual_#{System.unique_integer()}"

    :dets.insert(:statistics, {to_charlist(title), 42})
    assert Statistics.fetch(title) == 42
  end
end
