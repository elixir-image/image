defmodule Image.ErrorCoverageTest do
  use ExUnit.Case, async: true

  alias Image.Error

  describe "exception/1 with a keyword list" do
    test "explicit message is preserved" do
      error = Error.exception(message: "boom", reason: :some_reason)
      assert %Error{message: "boom", reason: :some_reason} = error
    end

    # When no :message is given the message is derived from the
    # reason plus operation/path context.
    test "binary reason without an explicit message derives the message" do
      error = Error.exception(reason: "libvips said no", operation: :open, path: "/tmp/a.jpg")
      assert error.reason == "libvips said no"
      assert error.operation == :open
      assert error.path == "/tmp/a.jpg"
      assert error.message == "open /tmp/a.jpg: libvips said no"
    end

    test ":enoent reason with a path derives the message" do
      error = Error.exception(reason: :enoent, path: "/tmp/missing.jpg")
      assert error.reason == :enoent
      assert error.path == "/tmp/missing.jpg"

      assert error.message ==
               "The image file \"/tmp/missing.jpg\" was not found or could not be opened"
    end

    test "tuple reason is captured" do
      error = Error.exception(reason: {:invalid_option, :crop})
      assert error.reason == {:invalid_option, :crop}
    end

    test "value field is captured" do
      error = Error.exception(reason: :invalid_option, value: 42)
      assert error.value == 42
    end

    test "unknown keys are ignored" do
      error = Error.exception(reason: :invalid_option, unrelated: :thing)
      assert error.reason == :invalid_option
    end
  end

  describe "exception/1 with other shapes" do
    test "binary message" do
      error = Error.exception("free form message")
      assert error.message == "free form message"
      assert error.reason == "free form message"
    end

    test "an existing %Image.Error{} is returned unchanged" do
      original = %Error{message: "original", reason: :original}
      assert Error.exception(original) == original
    end

    test "a bare atom" do
      error = Error.exception(:unsupported_format)
      assert error.reason == :unsupported_format
      assert error.message == "unsupported_format"
    end

    test "an unknown term is wrapped rather than returned raw" do
      error = Error.exception(%{some: :map})
      assert %Error{} = error
      assert error.reason == %{some: :map}
      assert error.message == "Image error: %{some: :map}"
    end
  end

  describe "raising Image.Error" do
    test "raise with a keyword list" do
      error =
        assert_raise Error, fn ->
          raise Error, reason: :enoent, path: "/tmp/x.jpg"
        end

      assert error.reason == :enoent
      assert error.path == "/tmp/x.jpg"
    end

    test "raise with a binary" do
      assert_raise Error, "free form", fn ->
        raise Error, "free form"
      end
    end

    test "raise with an unknown shape does not crash with BadStructError" do
      assert_raise Error, "Image error: %{}", fn ->
        raise Error, %{}
      end
    end
  end

  describe "wrap/2 with an %Image.Error{}" do
    test "merges context fields into the struct" do
      error = %Error{message: "boom", reason: "boom"}
      wrapped = Error.wrap(error, operation: :open, path: "/tmp/a.jpg", value: 1)
      assert wrapped.operation == :open
      assert wrapped.path == "/tmp/a.jpg"
      assert wrapped.value == 1
      assert wrapped.message == "boom"
    end

    test "nil context values are ignored" do
      error = %Error{message: "boom", reason: "boom", operation: :existing}
      wrapped = Error.wrap(error, operation: nil, path: nil)
      assert wrapped.operation == :existing
      assert wrapped.path == nil
    end

    test "unknown context keys are ignored" do
      error = %Error{message: "boom", reason: "boom"}
      wrapped = Error.wrap(error, unrelated: :thing)
      assert wrapped == error
    end
  end

  describe "wrap/2 message derivation" do
    test "agrees with the keyword form" do
      assert Error.wrap({:invalid_option, :crop}, operation: :thumbnail) ==
               Error.exception(reason: {:invalid_option, :crop}, operation: :thumbnail)
    end

    test "a :reason in the context overrides the raw value" do
      wrapped = Error.wrap(:enoent, reason: :custom, path: "/tmp/x.jpg")
      assert wrapped.reason == :custom
      assert wrapped.path == "/tmp/x.jpg"
      assert wrapped.message == "custom"
    end

    test "binary with operation only" do
      wrapped = Error.wrap("bad seek", operation: :open)
      assert wrapped.message == "open: bad seek"
    end

    test "binary with path only" do
      wrapped = Error.wrap("bad seek", path: "/tmp/x.jpg")
      assert wrapped.message == "/tmp/x.jpg: bad seek"
    end

    test "binary with no context" do
      wrapped = Error.wrap("bad seek")
      assert wrapped.message == "bad seek"
    end

    test "an atom other than :enoent" do
      wrapped = Error.wrap(:eacces, operation: :write, path: "/tmp/x.jpg")
      assert wrapped.reason == :eacces
      assert wrapped.operation == :write
      assert wrapped.path == "/tmp/x.jpg"
      assert wrapped.message == "eacces"
    end

    test "a {atom, value} tuple" do
      wrapped = Error.wrap({:invalid_option, :crop}, operation: :thumbnail)
      assert wrapped.reason == {:invalid_option, :crop}
      assert wrapped.operation == :thumbnail
      assert wrapped.message == "Image error: {:invalid_option, :crop}"
    end

    test "any other term" do
      wrapped = Error.wrap(%{oops: true}, operation: :open, path: "/p", value: 9)
      assert wrapped.reason == %{oops: true}
      assert wrapped.operation == :open
      assert wrapped.path == "/p"
      assert wrapped.value == 9
      assert wrapped.message == "Image error: %{oops: true}"
    end
  end
end
