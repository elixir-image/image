defmodule Image.EnumDoctestTest do
  use ExUnit.Case, async: true

  # These modules' doctests document the error shapes returned by the
  # validate_* functions. They were previously not run by any test module,
  # which allowed the documented shapes to drift from the implementation.

  doctest Image.BandFormat
  doctest Image.BlendMode
  doctest Image.CombineMode
  doctest Image.ExtendMode
  doctest Image.Interpretation
  doctest Image.Kernel
end
