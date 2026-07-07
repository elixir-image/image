# Credo configuration for the image library.
#
# The default strict suite runs with two policy adjustments:
#
# * Design.AliasUsage is disabled: the codebase intentionally uses
#   fully-qualified module names for one-off references rather than
#   aliasing every nested module at the top of each file.
#
# * Readability.AliasOrder is disabled: alias groups are ordered for
#   readability (primary collaborator first) rather than alphabetically.
#
# * Refactor.Nesting is disabled: the with/case/cond combinations
#   used for option validation and NIF-boundary error handling
#   commonly nest three to four levels and read clearly.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/"],
        excluded: ["deps/", "_build/"]
      },
      checks: [
        {Credo.Check.Design.AliasUsage, false},
        {Credo.Check.Readability.AliasOrder, false},
        {Credo.Check.Refactor.Nesting, false}
      ]
    }
  ]
}
