defmodule Image.SmartCell.OperationsTest do
  @moduledoc """
  Tests the Livebook smart cell's operation catalogue against the real API.

  The catalogue describes operations well enough to generate a call for
  each. A wrong option name, a wrong arity or a default outside a
  function's domain is only a data error until the call is made, so these
  tests build every call from its own defaults and run it.

  See https://github.com/elixir-image/image/issues/31.

  """
  use ExUnit.Case, async: true

  alias Image.SmartCell.Operations

  setup do
    %{image: Image.open!("./test/support/images/Kip_small.png")}
  end

  describe "the catalogue" do
    test "describes every operation completely" do
      for operation <- Operations.all() do
        assert is_atom(operation.name)
        assert is_binary(operation.label)
        assert is_binary(operation.doc)
        assert {positional, options} = operation.call
        assert is_list(positional) and is_list(options)

        described = Enum.map(operation.params, & &1.key)

        # Every parameter the call needs must be described, and every
        # parameter described must be used by the call.
        assert Enum.sort(described) == Enum.sort(positional ++ options),
               "#{operation.name}: params #{inspect(described)} do not match " <>
                 "call #{inspect(operation.call)}"

        for param <- operation.params do
          assert is_atom(param.key)
          assert is_binary(param.label)
          assert param.type in [:number, :range, :select, :colour, :text, :boolean]
          assert Map.has_key?(param, :default)

          if param.type == :select do
            assert param.default in param.options
          end

          if param.type in [:number, :range] do
            assert param.default >= param.min and param.default <= param.max
          end
        end
      end
    end

    test "names a function that exists" do
      for operation <- Operations.all() do
        bang = :"#{operation.name}!"
        {positional, options} = operation.call
        arity = 1 + length(positional) + if(options == [], do: 0, else: 1)

        assert function_exported?(Image, bang, arity),
               "Image.#{bang}/#{arity} does not exist for #{operation.name}"
      end
    end
  end

  describe "quoted_call/2" do
    test "every operation's defaults produce a working pipeline", %{image: image} do
      for operation <- Operations.all() do
        defaults = Operations.defaults(operation.name)
        assert {:ok, call} = Operations.quoted_call(operation.name, defaults)

        piped = {:|>, [], [Macro.var(:image, nil), call]}

        {result, _binding} = Code.eval_quoted(piped, image: image)

        assert %Vix.Vips.Image{} = result,
               "#{operation.name} with defaults did not return an image"
      end
    end

    test "generates readable source" do
      assert {:ok, call} = Operations.quoted_call(:blur, %{sigma: 2.5})
      assert Macro.to_string(call) == "Image.blur!(sigma: 2.5)"

      assert {:ok, call} = Operations.quoted_call(:brightness, %{brightness: 1.2})
      assert Macro.to_string(call) == "Image.brightness!(1.2)"

      assert {:ok, call} = Operations.quoted_call(:crop, %{left: 1, top: 2, width: 3, height: 4})
      assert Macro.to_string(call) == "Image.crop!(1, 2, 3, 4)"

      assert {:ok, call} =
               Operations.quoted_call(:thumbnail, %{length: 400, crop: :attention, fit: :cover})

      assert Macro.to_string(call) == "Image.thumbnail!(400, crop: :attention, fit: :cover)"
    end

    test "is an error for an unknown operation" do
      assert :error = Operations.quoted_call(:no_such_operation, %{})
    end
  end

  describe "cast/2" do
    test "parses the strings a client sends" do
      assert %{sigma: 2.5} = Operations.cast(:blur, %{"sigma" => "2.5"})
      assert %{length: 400} = Operations.cast(:thumbnail, %{"length" => "400"})
      assert %{crop: :attention} = Operations.cast(:thumbnail, %{"crop" => "attention"})
    end

    test "clamps a value to the parameter's range" do
      # Image.brightness/2 rejects a negative, so the form cannot produce one.
      assert %{brightness: +0.0} = Operations.cast(:brightness, %{"brightness" => "-5"})
      assert %{brightness: 3.0} = Operations.cast(:brightness, %{"brightness" => "99"})
    end

    test "falls back to the default rather than failing" do
      assert %{sigma: 1.5} = Operations.cast(:blur, %{"sigma" => "not a number"})
      assert %{sigma: 1.5} = Operations.cast(:blur, %{})
      assert %{crop: :none} = Operations.cast(:thumbnail, %{"crop" => "bogus"})
      assert %{color: "#000000"} = Operations.cast(:drop_shadow, %{"color" => "red"})
    end

    test "accepts a well formed colour" do
      assert %{color: "#ff8800"} = Operations.cast(:drop_shadow, %{"color" => "#ff8800"})
    end
  end
end
