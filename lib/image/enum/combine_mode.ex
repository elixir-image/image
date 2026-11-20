defmodule Image.CombineMode do
  @moduledoc """
  Functions to define and validate the combine
  modes that can be applied when composing images.

  """

  @type t :: :VIPS_COMBINE_MODE_SET | :VIPS_COMBINE_MODE_ADD | :VIPS_COMBINE_MODE_LAST

  @doc """
  Normalizes and validates a combine mode.

  ### Arguments

  * `mode` is `:set`, `:add` or `:last`, or the matching
    libvips value such as `:VIPS_COMBINE_MODE_SET`.

  ### Returns

  * `{:ok, combine_mode}` where `combine_mode` is a
    `t:Image.CombineMode.t/0`, or

  * `{:error, reason}`.

  ### Examples

      iex> Image.CombineMode.validate(:add)
      {:ok, :VIPS_COMBINE_MODE_ADD}

      iex> Image.CombineMode.validate(:VIPS_COMBINE_MODE_SET)
      {:ok, :VIPS_COMBINE_MODE_SET}

  """
  @spec validate(:set | :add | :last | t()) :: {:ok, t()} | {:error, Image.error()}
  def validate(mode)
      when mode in [:VIPS_COMBINE_MODE_SET, :VIPS_COMBINE_MODE_ADD, :VIPS_COMBINE_MODE_LAST] do
    {:ok, mode}
  end

  def validate(:set), do: {:ok, :VIPS_COMBINE_MODE_SET}
  def validate(:add), do: {:ok, :VIPS_COMBINE_MODE_ADD}
  def validate(:last), do: {:ok, :VIPS_COMBINE_MODE_LAST}

  def validate(other) do
    {:error,
     %Image.Error{
       message: "Invalid combine mode #{inspect(other)}. The valid modes are :set, :add or :last",
       reason: "Invalid combine mode #{inspect(other)}. The valid modes are :set, :add or :last"
     }}
  end
end
