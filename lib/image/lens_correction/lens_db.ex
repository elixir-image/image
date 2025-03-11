defmodule Image.LensDB do
  def parse_xml(path \\ "/Users/kip/Development/lensfun/data/db/slr-canon.xml") do
    import SweetXml

    path
    |> File.read!
    |> xpath(
      ~x"//lens"l,
      maker:  ~x"./maker/text()"s,
      crop_factor: ~x"./cropfactor/text()"s,
      lens: ~x"./model[not(@lang)]/text()"s,
      distortion: [
        ~x"./calibration/distortion"l,
        focal_length: ~x"@focal"s,
        a: ~x"@a"s,
        b: ~x"@a"s,
        c: ~x"@a"s,
      ]
    )
    |> Enum.group_by(&(&1.maker))
    |> Enum.map(fn {maker, lens} ->
      lens =
        Enum.map(lens, fn %{lens: lens} = lens_data ->
          {lens, Map.take(lens_data, [:crop_factor, :distortion])}
        end)
        |> Map.new()
      {maker, lens}
    end)
    |> Map.new()
  end
end

# Nest

# Maker
#   Crop Factor
#     Lens
#       Distortion