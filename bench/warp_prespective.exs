image_path = Path.expand("test/support/images/warp_perspective.jpg")
{:ok, image} = Image.open(image_path, access: :random)

warp_from = [
  {139, 125},
  {826, 74},
  {796, 559},
  {155, 483}
]

warp_to = [
  {139, 125},
  {815, 125},
  {815, 528},
  {139, 528}
]

Benchee.run(
  %{
    "Image.warp_perspective/4" => fn ->
      Image.warp_perspective(image, warp_from, warp_to)
    end
    },
  time: 30,
  memory_time: 2
)