defmodule Image.ICCProfile do
  @moduledoc """
  Helpers for the ICC color profiles known to libvips.

  ## What "built-in" means

  libvips ships with a small set of built-in colour profile *names*
  (`:srgb`, `:cmyk`, `:p3`). They are loaded by libvips itself on
  demand from its own profile collection — `:image` does *not* ship
  any `.icc` files. The four atoms are simply the names libvips
  recognises and resolves to its own internal profiles when you pass
  them to a vips operation that takes a profile.

  Anything else (the `t:Path.t/0` form) is treated as a path to an
  `.icc` file on disk. Absolute paths are used as-is. Relative paths
  are resolved against the libvips profile search path. The path is
  validated by attempting to load it with
  `Vix.Vips.Operation.profile_load/1`.

  ## API summary

  * `inbuilt/0` returns the four built-in atoms.
  * `is_inbuilt/1` is a `defguard` for the same set.
  * `known?/1` returns `true` for any built-in *or* any loadable file
    path. Use it to validate user-supplied profile arguments.

  ## Migration

  This module is the new home for the ICC-related helpers that used
  to live in `Image.Color`. The contracts are unchanged.

  """

  @inbuilt [:none, :srgb, :cmyk, :p3]

  @typedoc """
  An ICC profile reference.

  * `:none` means no profile.
  * `:srgb`, `:cmyk`, and `:p3` refer to the libvips built-in
    profiles.
  * A path is any file system path. Relative paths are resolved
    against the system profile directory.

  """
  @type t :: :none | :srgb | :cmyk | :p3 | Path.t()

  @doc """
  Guards whether a profile is one of the built-ins.

  """
  defguard is_inbuilt(profile) when profile in @inbuilt

  @doc """
  Returns the list of profiles built into libvips.

  ### Examples

      iex> Image.ICCProfile.inbuilt()
      [:none, :srgb, :cmyk, :p3]

  """
  @spec inbuilt() :: [t()]
  def inbuilt, do: @inbuilt

  @doc """
  Returns true if the given profile is known and usable.

  Built-in atoms (`:none`, `:srgb`, `:cmyk`, `:p3`) always return
  true. File paths are validated by trying to load them with
  `Vix.Vips.Operation.profile_load/1`.

  ### Examples

      iex> Image.ICCProfile.known?(:srgb)
      true

      iex> Image.ICCProfile.known?(:none)
      true

      iex> Image.ICCProfile.known?("/no/such/file.icc")
      false

  """
  @spec known?(t()) :: boolean()
  def known?(profile) when is_inbuilt(profile), do: true

  def known?(path) when is_binary(path) do
    case Vix.Vips.Operation.profile_load(path) do
      {:ok, _} -> true
      _other -> false
    end
  end

  def known?(_other), do: false
end
