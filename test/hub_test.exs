defmodule HubTest do
  use ExUnit.Case
  doctest Hub

  test "greets the world" do
    assert Hub.hello() == :world
  end
end
