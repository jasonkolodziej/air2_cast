defmodule ElixerTemplateTest do
  use ExUnit.Case
  doctest ElixerTemplate

  test "greets the world" do
    assert ElixerTemplate.hello() == :world
  end
end
