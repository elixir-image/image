defmodule Image.SmartCell.Operations do
  @moduledoc false

  # The catalogue of operations the Livebook smart cell offers.
  #
  # Each entry describes one operation well enough for a form to be
  # rendered for it and for a line of an `Image` pipeline to be generated
  # from the values that form collects. The client knows nothing about any
  # particular operation: it is handed this catalogue and renders whatever
  # it is given, so adding an operation here needs no change to the
  # JavaScript.
  #
  # `:call` says how the collected parameters become a call. Its first
  # element lists the parameters passed positionally, in order, and its
  # second lists those passed as options. The image itself is never in
  # either, because the generated call is always piped into.
  #
  # Ranges match each function's own domain, so a form cannot produce a
  # call the function rejects. `Image.brightness/2` accepts any number at
  # or above zero, for instance, so its range starts at zero rather than
  # at a negative number.

  @crop_focus [:none, :center, :entropy, :attention, :low, :high]
  @interpretations [:srgb, :bw, :lab, :lch, :cmyk, :scrgb, :rgb16, :grey16, :hsv]

  @operation_specs [
    %{
      name: :thumbnail,
      label: "Thumbnail",
      doc: "Fit or fill a bounding box, using shrink-on-load where the loader allows it.",
      call: {[:length], [:crop, :fit]},
      params: [
        %{key: :length, label: "Length", type: :number, min: 16, max: 4000, step: 1, default: 400},
        %{key: :crop, label: "Crop", type: :select, options: @crop_focus, default: :none},
        %{
          key: :fit,
          label: "Fit",
          type: :select,
          options: [:contain, :cover, :fill],
          default: :contain
        }
      ]
    },
    %{
      name: :resize,
      label: "Resize",
      doc: "Scale by a factor. Below 1.0 shrinks, above 1.0 enlarges.",
      call: {[:scale], []},
      params: [
        %{key: :scale, label: "Scale", type: :range, min: 0.05, max: 4.0, step: 0.05, default: 1.0}
      ]
    },
    %{
      name: :crop,
      label: "Crop",
      doc: "Take a rectangle. A negative left or top is measured from the right or bottom.",
      call: {[:left, :top, :width, :height], []},
      params: [
        %{key: :left, label: "Left", type: :number, min: -4000, max: 4000, step: 1, default: 0},
        %{key: :top, label: "Top", type: :number, min: -4000, max: 4000, step: 1, default: 0},
        %{key: :width, label: "Width", type: :number, min: 1, max: 4000, step: 1, default: 100},
        %{key: :height, label: "Height", type: :number, min: 1, max: 4000, step: 1, default: 100}
      ]
    },
    %{
      name: :rotate,
      label: "Rotate",
      doc: "Rotate by an arbitrary angle, growing the canvas to fit.",
      call: {[:angle], []},
      params: [
        %{
          key: :angle,
          label: "Angle",
          type: :range,
          min: -180.0,
          max: 180.0,
          step: 1.0,
          default: 0.0
        }
      ]
    },
    %{
      name: :flip,
      label: "Flip",
      doc: "Mirror horizontally or vertically.",
      call: {[:direction], []},
      params: [
        %{
          key: :direction,
          label: "Direction",
          type: :select,
          options: [:horizontal, :vertical],
          default: :horizontal
        }
      ]
    },
    %{
      name: :blur,
      label: "Blur",
      doc: "Gaussian blur.",
      call: {[], [:sigma]},
      params: [
        %{key: :sigma, label: "Sigma", type: :range, min: 0.1, max: 20.0, step: 0.1, default: 1.5}
      ]
    },
    %{
      name: :sharpen,
      label: "Sharpen",
      doc: "Unsharp mask.",
      call: {[], [:sigma]},
      params: [
        %{key: :sigma, label: "Sigma", type: :range, min: 0.1, max: 10.0, step: 0.1, default: 1.0}
      ]
    },
    %{
      name: :brightness,
      label: "Brightness",
      doc: "Multiply lightness. 1.0 is unchanged.",
      call: {[:brightness], []},
      params: [
        %{
          key: :brightness,
          label: "Brightness",
          type: :range,
          min: 0.0,
          max: 3.0,
          step: 0.05,
          default: 1.0
        }
      ]
    },
    %{
      name: :saturation,
      label: "Saturation",
      doc: "Multiply chroma. 1.0 is unchanged, 0.0 is greyscale.",
      call: {[:saturation], []},
      params: [
        %{
          key: :saturation,
          label: "Saturation",
          type: :range,
          min: 0.0,
          max: 3.0,
          step: 0.05,
          default: 1.0
        }
      ]
    },
    %{
      name: :gamma,
      label: "Gamma",
      doc: "Apply a gamma adjustment. Below 1.0 darkens, above 1.0 brightens.",
      call: {[:exponent], []},
      params: [
        %{
          key: :exponent,
          label: "Exponent",
          type: :range,
          min: 0.1,
          max: 5.0,
          step: 0.05,
          default: 1.0
        }
      ]
    },
    %{
      name: :sepia,
      label: "Sepia",
      doc: "Blend towards a sepia tone. 0.0 is the identity.",
      call: {[:strength], []},
      params: [
        %{
          key: :strength,
          label: "Strength",
          type: :range,
          min: 0.0,
          max: 1.0,
          step: 0.05,
          default: 1.0
        }
      ]
    },
    %{
      name: :to_colorspace,
      label: "Colourspace",
      doc: "Convert to another interpretation. Changes the band count.",
      call: {[:interpretation], []},
      params: [
        %{
          key: :interpretation,
          label: "Interpretation",
          type: :select,
          options: @interpretations,
          default: :srgb
        }
      ]
    },
    %{
      name: :rounded,
      label: "Rounded corners",
      doc: "Round the corners, adding an alpha band.",
      call: {[], [:radius]},
      params: [
        %{key: :radius, label: "Radius", type: :number, min: 1, max: 500, step: 1, default: 50}
      ]
    },
    %{
      name: :squircle,
      label: "Squircle",
      doc: "Mask to a squircle, adding an alpha band.",
      call: {[], [:radius]},
      params: [
        %{key: :radius, label: "Radius", type: :number, min: 1, max: 500, step: 1, default: 20}
      ]
    },
    %{
      name: :avatar,
      label: "Avatar",
      doc: "Crop and mask to a square avatar.",
      call: {[], [:size, :shape]},
      params: [
        %{key: :size, label: "Size", type: :number, min: 16, max: 1000, step: 1, default: 180},
        %{
          key: :shape,
          label: "Shape",
          type: :select,
          options: [:circle, :square, :squircle],
          default: :circle
        }
      ]
    },
    %{
      name: :drop_shadow,
      label: "Drop shadow",
      doc: "Composite a soft shadow beneath the image.",
      call: {[], [:sigma, :opacity, :color]},
      params: [
        %{key: :sigma, label: "Sigma", type: :range, min: 0.5, max: 30.0, step: 0.5, default: 5.0},
        %{
          key: :opacity,
          label: "Opacity",
          type: :range,
          min: 0.0,
          max: 1.0,
          step: 0.05,
          default: 0.5
        },
        %{key: :color, label: "Colour", type: :colour, default: "#000000"}
      ]
    }
  ]

  # The bang function each operation calls, resolved at compile time so no
  # atom is created from a notebook's data at runtime.
  @operations for operation <- @operation_specs,
                  do: Map.put(operation, :function, :"#{operation.name}!")

  @doc false
  def all, do: @operations

  @doc false
  def names, do: Enum.map(@operations, & &1.name)

  @doc false
  def fetch(name) when is_atom(name) do
    case Enum.find(@operations, &(&1.name == name)) do
      nil -> :error
      operation -> {:ok, operation}
    end
  end

  @doc false
  def defaults(name) when is_atom(name) do
    case fetch(name) do
      {:ok, operation} -> Map.new(operation.params, &{&1.key, &1.default})
      :error -> %{}
    end
  end

  # Coerces the values a client sends, which arrive as strings, into the
  # terms the corresponding function expects. An unparseable value falls
  # back to the parameter's default rather than failing, so a half-typed
  # number does not break the preview.
  @doc false
  def cast(name, params) when is_atom(name) and is_map(params) do
    case fetch(name) do
      :error ->
        %{}

      {:ok, operation} ->
        Map.new(operation.params, fn param ->
          {param.key,
           cast_param(param, Map.get(params, param.key, Map.get(params, to_string(param.key))))}
        end)
    end
  end

  defp cast_param(param, nil), do: param.default

  defp cast_param(%{type: :select, options: options} = param, value) do
    string = to_string(value)
    Enum.find(options, param.default, &(to_string(&1) == string))
  end

  defp cast_param(%{type: :colour} = param, value) when is_binary(value) do
    if Regex.match?(~r/^#[0-9a-fA-F]{6}$/, value), do: value, else: param.default
  end

  defp cast_param(%{type: :colour} = param, _value), do: param.default

  defp cast_param(%{type: :number} = param, value), do: cast_number(param, value, :integer)
  defp cast_param(%{type: :range} = param, value), do: cast_number(param, value, :float)

  defp cast_number(param, value, kind) when is_number(value) do
    clamp(param, if(kind == :integer, do: round(value), else: value * 1.0))
  end

  defp cast_number(param, value, kind) when is_binary(value) do
    parsed =
      case kind do
        :integer -> Integer.parse(value)
        :float -> Float.parse(value)
      end

    case parsed do
      {number, _rest} -> clamp(param, number)
      :error -> param.default
    end
  end

  defp cast_number(param, _value, _kind), do: param.default

  defp clamp(%{min: min, max: max}, number), do: number |> max(min) |> min(max)
  defp clamp(_param, number), do: number

  # The call an operation becomes, with its first argument left out so
  # that it can be piped into. `Image.blur!(sigma: 1.5)` piped from an
  # image is `Image.blur!(image, sigma: 1.5)`.
  @doc false
  def quoted_call(name, params) when is_atom(name) and is_map(params) do
    with {:ok, operation} <- fetch(name) do
      {positional_keys, option_keys} = operation.call
      values = cast(name, params)

      positional = Enum.map(positional_keys, &Macro.escape(Map.fetch!(values, &1)))
      options = Enum.map(option_keys, &{&1, Map.fetch!(values, &1)})

      arguments =
        case options do
          [] -> positional
          options -> positional ++ [Macro.escape(options)]
        end

      {:ok,
       {{:., [], [{:__aliases__, [alias: false], [:Image]}, operation.function]}, [], arguments}}
    end
  end
end
