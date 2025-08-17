defmodule MooreTracing do
  @moduledoc """
  Idiomatic Elixir implementation of the Moore Neighborhood Tracing Algorithm
  for contour following in binary images.

  The Moore neighborhood consists of 8 directions around each pixel:
      NW  N  NE
      W   •  E
      SW  S  SE

  This implementation demonstrates functional programming patterns:
  - Immutable data structures
  - Pattern matching
  - Recursive processing with tail call optimization
  - Stream-based lazy evaluation
  - Error handling with {:ok, result} | {:error, reason} tuples
  """

  # 8-connectivity directions in clockwise order starting from North
  @directions %{
    0 => {-1,  0},  # N  (North)
    1 => {-1,  1},  # NE (North-East)
    2 => { 0,  1},  # E  (East)
    3 => { 1,  1},  # SE (South-East)
    4 => { 1,  0},  # S  (South)
    5 => { 1, -1},  # SW (South-West)
    6 => { 0, -1},  # W  (West)
    7 => {-1, -1}   # NW (North-West)
  }

  @direction_names %{
    0 => :north, 1 => :northeast, 2 => :east, 3 => :southeast,
    4 => :south, 5 => :southwest, 6 => :west, 7 => :northwest
  }

  defstruct [:image_map, :height, :width, :boundary_pixels]

  @type position :: {row :: integer(), col :: integer()}
  @type direction_index :: 0..7
  @type pixel_value :: 0 | 1
  @type image_map :: %{position() => pixel_value()}
  @type trace_result :: {:ok, [position()]} | {:error, atom()}

  @doc """
  Traces the boundary of an object using Moore neighborhood algorithm.

  ## Parameters
  - `image`: 2D list representing binary image (0 = background, 1 = foreground)
  - `start_pos`: Starting position {row, col} on the object boundary
  - `opts`: Options keyword list
    - `:max_iterations` - Maximum steps to prevent infinite loops (default: 10000)
    - `:clockwise` - Direction of tracing, true for clockwise (default: true)
    - `:return_directions` - Include direction information (default: false)

  ## Returns
  - `{:ok, boundary_points}` - List of boundary positions in trace order
  - `{:error, reason}` - Error with reason atom

  ## Examples
      iex> image = [
      ...>   [0, 0, 0, 0, 0],
      ...>   [0, 1, 1, 1, 0],
      ...>   [0, 1, 1, 1, 0],
      ...>   [0, 1, 1, 1, 0],
      ...>   [0, 0, 0, 0, 0]
      ...> ]
      iex> {:ok, boundary} = MooreTracing.trace_boundary(image, {1, 1})
      iex> length(boundary)
      8
  """
  def trace_boundary(image, start_pos, opts \\ []) do
    with {:ok, image_map, height, width} <- validate_and_convert_image(image),
         {:ok, validated_start} <- validate_start_position(image_map, start_pos, height, width) do

      max_iterations = Keyword.get(opts, :max_iterations, 10_000)
      clockwise = Keyword.get(opts, :clockwise, true)
      return_directions = Keyword.get(opts, :return_directions, false)

      trace_state = %{
        image_map: image_map,
        height: height,
        width: width,
        clockwise: clockwise,
        return_directions: return_directions,
        max_iterations: max_iterations
      }

      perform_moore_trace(trace_state, validated_start)
    end
  end

  @doc """
  Finds all contours in a binary image using Moore tracing.

  ## Parameters
  - `image`: 2D binary image
  - `opts`: Options for tracing (same as trace_boundary/3)

  ## Returns
  - `{:ok, contours}` - List of contour boundary lists
  - `{:error, reason}` - Error information
  """
  def find_all_contours(image, opts \\ []) do
    with {:ok, image_map, height, width} <- validate_and_convert_image(image) do
      start_positions = find_boundary_start_positions(image_map, height, width)

      contours =
        start_positions
        |> Enum.map(&trace_boundary(image, &1, opts))
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, contour} -> contour end)
        |> Enum.uniq()

      {:ok, contours}
    end
  end

  @doc """
  Analyzes the traced boundary to extract geometric properties.

  ## Returns
  A map containing:
  - `:perimeter` - Number of boundary pixels
  - `:area` - Approximate area using shoelace formula
  - `:centroid` - Center of mass {row, col}
  - `:bounding_box` - {{min_row, min_col}, {max_row, max_col}}
  """
  def analyze_contour(boundary_points) when is_list(boundary_points) do
    if length(boundary_points) < 3 do
      {:error, :insufficient_points}
    else
      perimeter = length(boundary_points)
      area = calculate_area_shoelace(boundary_points)
      centroid = calculate_centroid(boundary_points)
      bounding_box = calculate_bounding_box(boundary_points)

      {:ok, %{
        perimeter: perimeter,
        area: abs(area),
        centroid: centroid,
        bounding_box: bounding_box,
        is_clockwise: area < 0
      }}
    end
  end

  @doc """
  Visualizes the boundary trace on the original image.

  Returns a 2D list where:
  - 0 = background
  - 1 = original foreground
  - 2 = boundary pixels
  - 3 = start position
  """
  def visualize_trace(image, boundary_points, start_pos \\ nil) do
    start_pos = start_pos || List.first(boundary_points)

    image
    |> Enum.with_index()
    |> Enum.map(fn {row, r} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {pixel, c} ->
        pos = {r, c}
        cond do
          pos == start_pos -> 3
          pos in boundary_points -> 2
          pixel == 1 -> 1
          true -> 0
        end
      end)
    end)
  end

  # Private Implementation Functions

  # Convert 2D list to map and validate
  defp validate_and_convert_image(image) when is_list(image) do
    if Enum.empty?(image) or Enum.empty?(hd(image)) do
      {:error, :empty_image}
    else
      height = length(image)
      width = image |> hd() |> length()

      # Validate all rows have same width
      if Enum.all?(image, &(length(&1) == width)) do
        image_map =
          image
          |> Enum.with_index()
          |> Enum.flat_map(fn {row, r} ->
            row
            |> Enum.with_index()
            |> Enum.map(fn {pixel, c} -> {{r, c}, pixel} end)
          end)
          |> Map.new()

        {:ok, image_map, height, width}
      else
        {:error, :inconsistent_row_widths}
      end
    end
  end

  defp validate_start_position(image_map, {row, col} = pos, height, width)
       when is_integer(row) and is_integer(col) do
    cond do
      row < 0 or row >= height or col < 0 or col >= width ->
        {:error, :position_out_of_bounds}

      Map.get(image_map, pos, 0) == 0 ->
        {:error, :start_position_not_foreground}

      true ->
        {:ok, pos}
    end
  end

  defp validate_start_position(_, _, _, _), do: {:error, :invalid_position_format}

  # Core Moore tracing algorithm
  defp perform_moore_trace(state, start_pos) do
    # Find the backtrack position (first background pixel when searching clockwise from West)
    backtrack_pos = find_backtrack_position(state.image_map, start_pos)

    case backtrack_pos do
      nil -> {:error, :no_backtrack_position}
      backtrack ->
        trace_result = moore_trace_recursive(
          state,
          start_pos,
          start_pos,
          backtrack,
          [start_pos],
          0
        )

        case trace_result do
          {:ok, points} when state.return_directions ->
            directions = extract_directions(points)
            {:ok, %{points: points, directions: directions}}
          result -> result
        end
    end
  end

  # Recursive Moore tracing with tail call optimization
  defp moore_trace_recursive(state, current_pos, start_pos, backtrack_pos, trace, iteration) do
    if iteration >= state.max_iterations do
      {:error, :max_iterations_exceeded}
    else
      case find_next_boundary_pixel(state, current_pos, backtrack_pos) do
        {:ok, {next_pos, next_backtrack}} ->
          cond do
            # Completed the loop
            next_pos == start_pos and length(trace) > 2 ->
              {:ok, Enum.reverse(trace)}

            # Continue tracing
            next_pos not in trace ->
              moore_trace_recursive(
                state,
                next_pos,
                start_pos,
                next_backtrack,
                [next_pos | trace],
                iteration + 1
              )

            # Avoid infinite loop on single pixel
            true ->
              {:ok, Enum.reverse(trace)}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Find the backtrack position (first background pixel in Moore neighborhood)
  defp find_backtrack_position(image_map, pos) do
    # Start from West (direction 6) and search clockwise
    6..13
    |> Stream.map(&rem(&1, 8))
    |> Stream.map(&{&1, add_direction(pos, @directions[&1])})
    |> Stream.filter(fn {_dir, neighbor} -> get_pixel(image_map, neighbor) == 0 end)
    |> Stream.map(fn {_dir, neighbor} -> neighbor end)
    |> Enum.take(1)
    |> List.first()
  end

  # Find next boundary pixel using Moore neighborhood
  defp find_next_boundary_pixel(state, current_pos, backtrack_pos) do
    # Find the direction from current to backtrack
    backtrack_dir = find_direction_to_neighbor(current_pos, backtrack_pos)

    case backtrack_dir do
      nil -> {:error, :invalid_backtrack}
      start_dir ->
        # Search clockwise from backtrack direction
        search_range = if state.clockwise, do: 0..7, else: 7..0

        result =
          search_range
          |> Stream.map(&rem(start_dir + &1, 8))
          |> Stream.map(&{&1, add_direction(current_pos, @directions[&1])})
          |> Stream.filter(fn {_dir, neighbor} -> get_pixel(state.image_map, neighbor) == 1 end)
          |> Enum.take(1)

        case result do
          [{found_dir, next_pos}] ->
            # New backtrack is the pixel before the found direction
            new_backtrack_dir = rem(found_dir - 1 + 8, 8)
            new_backtrack = add_direction(current_pos, @directions[new_backtrack_dir])
            {:ok, {next_pos, new_backtrack}}

          [] ->
            {:error, :no_next_pixel}
        end
    end
  end

  # Utility functions for geometric calculations
  defp calculate_area_shoelace(points) do
    points
    |> Stream.chunk_every(2, 1, points)
    |> Stream.map(fn
      [{r1, c1}, {r2, c2}] -> (r1 * c2) - (r2 * c1)
      [point] -> calculate_shoelace_term(point, hd(points))
    end)
    |> Enum.sum()
    |> Kernel./(2.0)
  end

  defp calculate_shoelace_term({r1, c1}, {r2, c2}), do: (r1 * c2) - (r2 * c1)

  defp calculate_centroid(points) do
    {sum_r, sum_c} =
      points
      |> Enum.reduce({0, 0}, fn {r, c}, {acc_r, acc_c} ->
        {acc_r + r, acc_c + c}
      end)

    n = length(points)
    {sum_r / n, sum_c / n}
  end

  defp calculate_bounding_box(points) do
    {min_r, max_r, min_c, max_c} =
      points
      |> Enum.reduce({nil, nil, nil, nil}, fn {r, c}, {min_r, max_r, min_c, max_c} ->
        {
          if(min_r == nil, do: r, else: min(min_r, r)),
          if(max_r == nil, do: r, else: max(max_r, r)),
          if(min_c == nil, do: c, else: min(min_c, c)),
          if(max_c == nil, do: c, else: max(max_c, c))
        }
      end)

    {{min_r, min_c}, {max_r, max_c}}
  end

  # Helper functions
  defp get_pixel(image_map, pos), do: Map.get(image_map, pos, 0)

  defp add_direction({row, col}, {dr, dc}), do: {row + dr, col + dc}

  defp find_direction_to_neighbor(from_pos, to_pos) do
    target_direction = {elem(to_pos, 0) - elem(from_pos, 0), elem(to_pos, 1) - elem(from_pos, 1)}

    @directions
    |> Enum.find_value(fn {dir_idx, direction} ->
      if direction == target_direction, do: dir_idx
    end)
  end

  defp find_boundary_start_positions(image_map, height, width) do
    for r <- 0..(height-1),
        c <- 0..(width-1),
        get_pixel(image_map, {r, c}) == 1,
        get_pixel(image_map, {r, c-1}) == 0,
        do: {r, c}
  end

  defp extract_directions(points) do
    points
    |> Stream.chunk_every(2, 1, :discard)
    |> Stream.map(fn [{r1, c1}, {r2, c2}] ->
      direction = {r2 - r1, c2 - c1}
      @directions
      |> Enum.find_value(fn {idx, dir} -> if dir == direction, do: @direction_names[idx] end)
    end)
    |> Enum.to_list()
  end

  # Pretty printing functions
  def print_trace_visualization(image, boundary, opts \\ []) do
    start_pos = Keyword.get(opts, :start_pos)
    legend = Keyword.get(opts, :legend, true)

    visualization = visualize_trace(image, boundary, start_pos)

    if legend do
      IO.puts("Legend: 0=background, 1=foreground, 2=boundary, 3=start")
    end

    visualization
    |> Enum.each(fn row ->
      row
      |> Enum.map(&to_string/1)
      |> Enum.join(" ")
      |> IO.puts()
    end)
  end

  def print_analysis(boundary_points) do
    case analyze_contour(boundary_points) do
      {:ok, analysis} ->
        IO.puts("=== Contour Analysis ===")
        IO.puts("Perimeter: #{analysis.perimeter} pixels")
        IO.puts("Area: #{Float.round(analysis.area, 2)} square units")
        {cent_r, cent_c} = analysis.centroid
        IO.puts("Centroid: (#{Float.round(cent_r, 2)}, #{Float.round(cent_c, 2)})")
        {{min_r, min_c}, {max_r, max_c}} = analysis.bounding_box
        IO.puts("Bounding Box: (#{min_r},#{min_c}) to (#{max_r},#{max_c})")
        IO.puts("Orientation: #{if analysis.is_clockwise, do: "Clockwise", else: "Counter-clockwise"}")

      {:error, reason} ->
        IO.puts("Analysis failed: #{reason}")
    end
  end
end

# Example usage and demonstrations
defmodule MooreTracingExamples do
  @moduledoc """
  Example usage of the Moore Neighborhood Tracing algorithm.
  """

  def run_all_examples do
    IO.puts("Moore Neighborhood Tracing - Elixir Examples")
    IO.puts("===========================================\n")

    simple_rectangle()
    complex_shape()
    multiple_contours()
    performance_demo()
  end

  def simple_rectangle do
    IO.puts("=== Example 1: Simple Rectangle ===")

    image = [
      [0, 0, 0, 0, 0, 0],
      [0, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 1, 0],
      [0, 1, 1, 1, 1, 0],
      [0, 0, 0, 0, 0, 0]
    ]

    case MooreTracing.trace_boundary(image, {1, 1}) do
      {:ok, boundary} ->
        IO.puts("Boundary traced: #{length(boundary)} pixels")
        MooreTracing.print_analysis(boundary)
        IO.puts("\nVisualization:")
        MooreTracing.print_trace_visualization(image, boundary, start_pos: {1, 1})

      {:error, reason} ->
        IO.puts("Error: #{reason}")
    end

    IO.puts("")
  end

  def complex_shape do
    IO.puts("=== Example 2: L-shaped Object ===")

    image = [
      [0, 0, 0, 0, 0, 0, 0],
      [0, 1, 1, 1, 0, 0, 0],
      [0, 1, 0, 1, 0, 0, 0],
      [0, 1, 0, 1, 1, 1, 0],
      [0, 1, 0, 0, 0, 1, 0],
      [0, 1, 1, 1, 1, 1, 0],
      [0, 0, 0, 0, 0, 0, 0]
    ]

    with {:ok, boundary} <- MooreTracing.trace_boundary(image, {1, 1}, return_directions: true) do
      IO.puts("Complex boundary traced: #{length(boundary.points)} pixels")
      IO.puts("First 5 directions: #{boundary.directions |> Enum.take(5) |> inspect}")
      MooreTracing.print_analysis(boundary.points)
      IO.puts("\nVisualization:")
      MooreTracing.print_trace_visualization(image, boundary.points, start_pos: {1, 1})
    end

    IO.puts("")
  end

  def multiple_contours do
    IO.puts("=== Example 3: Multiple Objects ===")

    image = [
      [0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 1, 0, 0, 1, 1, 0],
      [0, 1, 1, 0, 0, 1, 1, 0],
      [0, 0, 0, 0, 0, 0, 0, 0],
      [0, 1, 1, 1, 1, 0, 0, 0],
      [0, 1, 0, 0, 1, 0, 0, 0],
      [0, 1, 1, 1, 1, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0]
    ]

    case MooreTracing.find_all_contours(image) do
      {:ok, contours} ->
        IO.puts("Found #{length(contours)} contours")

        contours
        |> Enum.with_index()
        |> Enum.each(fn {contour, idx} ->
          IO.puts("Contour #{idx + 1}: #{length(contour)} pixels")
          MooreTracing.print_analysis(contour)
        end)

      {:error, reason} ->
        IO.puts("Error finding contours: #{reason}")
    end

    IO.puts("")
  end

  def performance_demo do
    IO.puts("=== Example 4: Performance Demonstration ===")

    # Create a larger test image
    size = 20
    image =
      0..(size-1)
      |> Enum.map(fn r ->
        0..(size-1)
        |> Enum.map(fn c ->
          # Create a circle pattern
          center = div(size, 2)
          radius = div(size, 3)
          distance = :math.sqrt((r - center) * (r - center) + (c - center) * (c - center))
          if distance <= radius, do: 1, else: 0
        end)
      end)

    {time, result} = :timer.tc(fn -> MooreTracing.trace_boundary(image, {5, 10}) end)

    case result do
      {:ok, boundary} ->
        IO.puts("Large circle traced in #{time / 1000} ms")
        IO.puts("Boundary length: #{length(boundary)} pixels")
        MooreTracing.print_analysis(boundary)

      {:error, reason} ->
        IO.puts("Performance test failed: #{reason}")
    end
  end
end