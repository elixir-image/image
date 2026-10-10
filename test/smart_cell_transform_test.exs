defmodule Image.SmartCell.TransformTest do
  @moduledoc """
  Tests the Livebook smart cell's generated source.

  The source the cell writes into a notebook is its real contract: the user
  can convert the cell to a plain Elixir cell and keep whatever it wrote.
  These tests assert that text exactly, and that it evaluates.

  Attributes come from a notebook's markdown and can be edited by hand, so
  the tampered cases are as important as the well formed ones.

  See https://github.com/elixir-image/image/issues/31.

  """
  use ExUnit.Case, async: true

  alias Image.SmartCell.Transform

  @image_path "./test/support/images/Kip_small.png"

  defp attrs(overrides) do
    Map.merge(
      %{
        "source_type" => "path",
        "source_path" => @image_path,
        "source_variable" => "",
        "to_variable" => "transformed",
        "operations" => []
      },
      overrides
    )
  end

  describe "to_source/1" do
    test "a source with no operations opens and shows it" do
      source = Transform.to_source(attrs(%{"source_path" => "photo.jpg"}))

      assert source == """
             transformed = Image.open!("photo.jpg")
             Image.Kino.show(transformed)\
             """
    end

    test "builds a pipeline in the order the operations are listed" do
      source =
        Transform.to_source(
          attrs(%{
            "to_variable" => "thumb",
            "source_path" => "photo.jpg",
            "operations" => [
              %{
                "name" => "thumbnail",
                "params" => %{"length" => "400", "crop" => "attention", "fit" => "contain"}
              },
              %{"name" => "blur", "params" => %{"sigma" => "2.5"}}
            ]
          })
        )

      assert source == """
             thumb =
               Image.open!("photo.jpg")
               |> Image.thumbnail!(400, crop: :attention, fit: :contain)
               |> Image.blur!(sigma: 2.5)

             Image.Kino.show(thumb)\
             """
    end

    test "takes a variable as the source when asked" do
      source =
        Transform.to_source(
          attrs(%{
            "source_type" => "variable",
            "source_variable" => "original",
            "to_variable" => "out",
            "operations" => [%{"name" => "rounded", "params" => %{"radius" => "30"}}]
          })
        )

      assert source == """
             out = original |> Image.rounded!(radius: 30)
             Image.Kino.show(out)\
             """
    end
  end

  describe "to_source/1 with attributes edited by hand" do
    test "skips an operation that is not in the catalogue" do
      source =
        Transform.to_source(
          attrs(%{
            "source_path" => "a.png",
            "operations" => [
              %{"name" => "definitely_not_an_operation", "params" => %{}},
              %{"name" => "sepia", "params" => %{"strength" => "0.6"}}
            ]
          })
        )

      assert source =~ "Image.sepia!(0.6)"
      refute source =~ "definitely_not_an_operation"
    end

    test "falls back when the target variable is not a valid name" do
      for name <- ["9bad", "Bad", "has space", "", nil] do
        source = Transform.to_source(attrs(%{"to_variable" => name}))
        assert source =~ "transformed ="
      end
    end

    test "falls back when a parameter is not parseable" do
      source =
        Transform.to_source(
          attrs(%{"operations" => [%{"name" => "blur", "params" => %{"sigma" => "wat"}}]})
        )

      # 1.5 is the catalogue default for blur.
      assert source =~ "Image.blur!(sigma: 1.5)"
    end

    test "clamps a parameter outside the function's domain" do
      source =
        Transform.to_source(
          attrs(%{
            "operations" => [%{"name" => "brightness", "params" => %{"brightness" => "-10"}}]
          })
        )

      # Image.brightness/2 rejects a negative, so the cell cannot emit one.
      assert source =~ "Image.brightness!(0.0)"
    end
  end

  describe "the generated pipeline" do
    test "evaluates to an image" do
      source_attrs =
        attrs(%{
          "operations" => [
            %{
              "name" => "thumbnail",
              "params" => %{"length" => "120", "crop" => "center", "fit" => "contain"}
            },
            %{"name" => "blur", "params" => %{"sigma" => "1.0"}},
            %{"name" => "rounded", "params" => %{"radius" => "12"}}
          ]
        })

      # The second statement renders through Kino, which needs a running
      # Livebook, so only the assignment is evaluated here.
      {:__block__, _meta, [assignment, _show]} = Transform.quoted_source(source_attrs)

      {result, binding} = Code.eval_quoted(assignment)

      assert %Vix.Vips.Image{} = result
      assert %Vix.Vips.Image{} = binding[:transformed]
      assert Image.width(result) <= 120
    end
  end

  describe "the cell" do
    test "implements the smart cell callbacks" do
      for {function, arity} <- [
            {:init, 2},
            {:handle_connect, 1},
            {:handle_event, 3},
            {:to_attrs, 1},
            {:to_source, 1},
            {:scan_binding, 3}
          ] do
        assert function_exported?(Transform, function, arity),
               "Image.SmartCell.Transform.#{function}/#{arity} is not exported"
      end
    end

    test "round trips its attributes" do
      given = attrs(%{"operations" => [%{"name" => "sepia", "params" => %{"strength" => "0.5"}}]})

      {:ok, ctx} = Transform.init(given, Kino.JS.Live.Context.new())

      assert Transform.to_attrs(ctx) == given
    end
  end
end
