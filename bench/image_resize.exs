image_path = Path.expand("test/support/images/Kamchatka-2019-8754.jpg")
{:ok, image} = Image.open(image_path, access: :random)

Benchee.run(
  %{
    "Using Operation.text" => fn ->
      Image.Text.plain(image)
    end,
    "Using SVG render" => fn ->
      Image.Text.text2(image)
    end
    },
  time: 20,
  memory_time: 2
)