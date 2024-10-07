defmodule WsChatTest do
  use ExUnit.Case
  doctest WsChat

  test "greets the world" do
    assert WsChat.hello() == :world
  end
end
