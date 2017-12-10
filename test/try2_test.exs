defmodule Try2Test do
  use ExUnit.Case
  doctest Try2

  test "greets the world" do
    assert Try2.hello() == :world
  end
end
