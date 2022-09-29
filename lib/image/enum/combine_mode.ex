defmodule Image.CombineMode do
  @type t :: :VIPS_COMBINE_MODE_SET | :VIPS_COMBINE_MODE_ADD | :VIPS_COMBINE_MODE_LAST

  def validate(mode) when mode in [:VIPS_COMBINE_MODE_SET, :VIPS_COMBINE_MODE_ADD, :VIPS_COMBINE_MODE_LAST] do
    {:ok, mode}
  end

  def validate(:set), do: {:ok, VIPS_COMBINE_MODE_SET}
  def validate(:add), do: {:ok, VIPS_COMBINE_MODE_ADD}
  def validate(:last), do: {:ok, VIPS_COMBINE_MODE_LAST}

  def validate(other) do
    {:error, "Invalid combine mode #{inspect other}. The valid modes are :set, :add or :last"}
  end
end