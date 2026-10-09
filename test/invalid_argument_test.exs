defmodule Image.InvalidArgumentTest do
  @moduledoc """
  Every public `Image` function whose `@spec` promises
  `{:ok, term()} | {:error, Image.error()}` must return an error tuple for
  an invalid argument rather than raising `FunctionClauseError`, and its
  `!` variant must raise `Image.Error` rather than `FunctionClauseError`.

  Functions are called through `apply/3` so that passing a deliberately
  wrong type does not trip the compiler's type checker, which would
  otherwise be an error under `mix compile --warnings-as-errors`.

  """
  use ExUnit.Case, async: true

  setup do
    %{image: Image.new!(20, 20, color: :red)}
  end

  # {function, reason, args_for_bad_value, invalid_values}
  defp cases(image) do
    numbers = [nil, "x", :bad, [1], %{}, {1}]

    [
      {:multiply_alpha, :invalid_factor, &[image, &1], [1.5, -0.5 | numbers]},
      {:posterize, :invalid_levels, &[image, &1], [1, 257, 2.5 | numbers]},
      {:sepia, :invalid_strength, &[image, &1], [1.5, -0.1 | numbers]},
      {:gamma, :invalid_exponent, &[image, &1], [0.0, -1 | numbers]},
      {:set_orientation, :invalid_orientation, &[image, &1], [0, 9 | numbers]},
      {:resize, :invalid_scale, &[image, &1], [-1 | numbers]},
      {:brightness, :invalid_brightness, &[image, &1], [-1 | numbers]},
      {:saturation, :invalid_saturation, &[image, &1], [-1 | numbers]},
      {:vibrance, :invalid_vibrance, &[image, &1], [-1 | numbers]},
      {:dilate, :invalid_radius, &[image, &1], [1.5 | numbers]},
      {:erode, :invalid_radius, &[image, &1], [1.5 | numbers]},
      {:dhash, :invalid_hash_size, &[image, &1], [0, -1, 1.5 | numbers]},
      {:pixelate, :invalid_scale, &[image, &1], [0, -1 | numbers]},
      {:rotate, :invalid_angle, &[image, &1], numbers},
      {:shear, :invalid_shear, &[image, &1, 0.5], numbers},
      {:translate, :invalid_displacement, &[image, &1, 5], numbers},
      {:meme, :invalid_headline, &[image, &1], [nil, 123, :bad, [1], %{}]},
      {:from_binary, :invalid_binary, &[&1], [nil, 123, :bad, [1], %{}]},
      {:from_svg, :invalid_svg, &[&1], [nil, 123, :bad, [1], %{}]},
      {:join_bands, :invalid_bands, &[&1], [nil, [], [1], "x", %{}]}
    ]
  end

  describe "invalid arguments return an error tuple" do
    test "for every function whose spec promises one", %{image: image} do
      for {function, reason, args, values} <- cases(image), value <- values do
        result =
          try do
            apply(Image, function, args.(value))
          rescue
            exception -> {:raised, exception.__struct__}
          end

        assert {:error, %Image.Error{reason: ^reason, value: _}} = result,
               "Image.#{function} with #{inspect(value)} returned #{inspect(result)}, " <>
                 "expected reason #{inspect(reason)}"
      end
    end

    test "and the ! variant raises Image.Error, never FunctionClauseError", %{image: image} do
      for {function, _reason, args, [value | _]} <- cases(image) do
        bang = :"#{function}!"
        arguments = args.(value)

        if function_exported?(Image, bang, length(arguments)) do
          error =
            assert_raise Image.Error, fn ->
              apply(Image, bang, arguments)
            end

          assert Exception.message(error) =~ "Invalid"
        end
      end
    end
  end

  describe "the error itself" do
    test "names the offending value and what was expected", %{image: image} do
      assert {:error, error} = Image.posterize(image, 1)

      assert error.value == 1
      assert error.reason == :invalid_levels
      assert Exception.message(error) =~ "Invalid levels 1"
      assert Exception.message(error) =~ "2..256"
    end
  end
end
