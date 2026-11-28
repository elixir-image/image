defmodule Image.SvgFreeMasksTest do
  use ExUnit.Case, async: true

  # libvips reads VIPS_BLOCK_UNTRUSTED only when it starts, and it blocks
  # the SVG loader, so these run in a separate BEAM with it set.
  @script """
  Application.ensure_all_started(:image)
  image = Image.new!(40, 30, color: :red)

  results = [
    from_svg: Image.from_svg("<svg width='3' height='3'><rect width='3' height='3'/></svg>"),
    circle: Image.circle(image),
    rounded: Image.rounded(image),
    squircle: Image.squircle(image),
    avatar: Image.avatar(image, size: 20),
    fade: Image.fade(image),
    text_background: Image.Text.text("Hi", background_fill_color: :blue),
    text_border:
      Image.Text.text("Hi",
        background_fill_color: :blue,
        background_stroke_color: :white,
        padding: 4
      )
  ]

  for {name, result} <- results do
    IO.puts("\#{name}=\#{elem(result, 0)}")
  end
  """

  test "masks, fades and text backgrounds work with the SVG loader blocked" do
    paths = Enum.flat_map(:code.get_path(), &["-pa", to_string(&1)])
    elixir = System.find_executable("elixir")

    {output, 0} =
      System.cmd(elixir, paths ++ ["-e", @script],
        env: [{"VIPS_BLOCK_UNTRUSTED", "1"}],
        stderr_to_stdout: true
      )

    results =
      ~r/^(\w+)=(ok|error)$/m
      |> Regex.scan(output, capture: :all_but_first)
      |> Map.new(fn [name, result] -> {name, result} end)

    # The control: SVG loading really is blocked.
    assert results["from_svg"] == "error"

    for name <- ~w(circle rounded squircle avatar fade text_background text_border) do
      assert results[name] == "ok", "#{name} failed with SVG loading blocked: #{output}"
    end
  end

  describe "an existing alpha band" do
    for shape <- [:circle, :rounded, :squircle] do
      test "is scaled by the #{shape} mask, keeping the antialiased edge" do
        apply_shape = Function.capture(Image, unquote(shape), 1)
        opaque = Image.new!(40, 30, color: [255, 0, 0, 255])
        translucent = Image.new!(40, 30, color: [255, 0, 0, 128])

        {:ok, mask} = apply_shape.(opaque)
        {:ok, masked} = apply_shape.(translucent)

        expected = Image.Math.multiply!(mask[3], 128 / 255)
        difference = Vix.Vips.Operation.abs!(Image.Math.subtract!(masked[3], expected))
        {max_difference, _} = Vix.Vips.Operation.max!(difference)

        assert max_difference <= 1.0
        assert Image.get_pixel!(masked, div(Image.width(masked), 2), 15) == [255, 0, 0, 128]
      end
    end
  end
end
