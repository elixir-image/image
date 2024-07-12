defmodule Image.ColorTest do
  use ExUnit.Case, async: true

  test "Sort colors" do
    assert [[1, 5, 1], [1, 3, 2]] = Image.Color.sort([[1,5,1], [1,3,2]])

  end
end