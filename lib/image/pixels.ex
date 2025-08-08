defmodule Image.Pixels do
  @moduledoc false

  def pixels_from_binary(_binary, _type, bands) when bands not in 1..4 do
    {:error, "Only images with 1..4 bands are supported. Found #{inspect(bands)}"}
  end

  def pixels_from_binary(binary, {:u, 8}, bands) do
    case bands do
      1 ->
        for <<red::native-unsigned-8 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-unsigned-8, green::native-unsigned-8 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-unsigned-8, green::native-unsigned-8, blue::native-unsigned-8 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-unsigned-8, green::native-unsigned-8, blue::native-unsigned-8,
              alpha::native-unsigned-8 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:u, 16}, bands) do
    case bands do
      1 ->
        for <<red::native-unsigned-16 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-unsigned-16, green::native-unsigned-16 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-unsigned-16, green::native-unsigned-16,
              blue::native-unsigned-16 <- binary>>,
            do: [red, green, blue]

      4 ->
        for <<red::native-unsigned-16, green::native-unsigned-16, blue::native-unsigned-16,
              alpha::native-unsigned-16 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:u, 32}, bands) do
    case bands do
      1 ->
        for <<red::native-unsigned-32 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-unsigned-32, green::native-unsigned-32 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-unsigned-32, green::native-unsigned-32,
              blue::native-unsigned-32 <- binary>>,
            do: [red, green, blue]

      4 ->
        for <<red::native-unsigned-32, green::native-unsigned-32, blue::native-unsigned-32,
              alpha::native-unsigned-32 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:u, 64}, bands) do
    case bands do
      1 ->
        for <<red::native-unsigned-64 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-unsigned-64, green::native-unsigned-64 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-unsigned-64, green::native-unsigned-64,
              blue::native-unsigned-64 <- binary>>,
            do: [red, green, blue]

      4 ->
        for <<red::native-unsigned-64, green::native-unsigned-64, blue::native-unsigned-64,
              alpha::native-unsigned-64 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:s, 8}, bands) do
    case bands do
      1 ->
        for <<red::native-signed-8 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-signed-8, green::native-signed-8 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-signed-8, green::native-signed-8, blue::native-signed-8 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-signed-8, green::native-signed-8, blue::native-signed-8,
              alpha::native-signed-8 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:s, 16}, bands) do
    case bands do
      1 ->
        for <<red::native-signed-16 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-signed-16, green::native-signed-16 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-signed-16, green::native-signed-16, blue::native-signed-16 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-signed-16, green::native-signed-16, blue::native-signed-16,
              alpha::native-signed-16 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:s, 32}, bands) do
    case bands do
      1 ->
        for <<red::native-signed-32 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-signed-32, green::native-signed-32 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-signed-32, green::native-signed-32, blue::native-signed-32 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-signed-32, green::native-signed-32, blue::native-signed-32,
              alpha::native-signed-32 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:s, 64}, bands) do
    case bands do
      1 ->
        for <<red::native-signed-64 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-signed-64, green::native-signed-64 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-signed-64, green::native-signed-64, blue::native-signed-64 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-signed-64, green::native-signed-64, blue::native-signed-64,
              alpha::native-signed-64 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:f, 32}, bands) do
    case bands do
      1 ->
        for <<red::native-float-32 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-float-32, green::native-float-32 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-float-32, green::native-float-32, blue::native-float-32 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-float-32, green::native-float-32, blue::native-float-32,
              alpha::native-float-32 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(binary, {:f, 64}, bands) do
    case bands do
      1 ->
        for <<red::native-float-64 <- binary>>,
          do: [red]

      2 ->
        for <<red::native-float-64, green::native-float-64 <- binary>>,
          do: [red, green]

      3 ->
        for <<red::native-float-64, green::native-float-64, blue::native-float-64 <- binary>>,
          do: [red, green, blue]

      4 ->
        for <<red::native-float-64, green::native-float-64, blue::native-float-64,
              alpha::native-float-64 <- binary>>,
            do: [red, green, blue, alpha]
    end
    |> wrap(:ok)
  end

  def pixels_from_binary(_binary, type, _bands) do
    {:error, "Unsupported image type for pixels_from_binary/3. Found #{inspect(type)}"}
  end

  defp wrap(item, atom) do
    {atom, item}
  end
end
