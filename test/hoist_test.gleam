import gleeunit
import hoist

pub fn main() {
  gleeunit.main()
}

pub fn parses_empty_args_test() {
  let assert Ok(parsed) = hoist.parse([], [])
  assert parsed == hoist.Args(arguments: [], flags: [])
}

pub fn parses_only_positionals_test() {
  let assert Ok(parsed) = hoist.parse(["wibble", "wobble"], [])
  assert parsed == hoist.Args(arguments: ["wibble", "wobble"], flags: [])
}

pub fn parse_bare_single_tack_as_positional_test() {
  let assert Ok(parsed) = hoist.parse(["wibble", "-", "wobble"], [])
  assert parsed == hoist.Args(arguments: ["wibble", "-", "wobble"], flags: [])
}

pub fn parses_all_args_after_bare_double_tack_as_positional_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) =
    hoist.parse(["wibble", "--", "--name", "lucy", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wibble", "--name", "lucy", "wobble"], flags: [])
}

pub fn parses_long_alias_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_long_alias("surname")]
  let assert Ok(parsed) = hoist.parse(["--surname", "Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_alias_resolves_to_canonical_name_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_long_alias("surname")]
  let assert Ok(parsed) = hoist.parse(["--surname=Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_flag_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) = hoist.parse(["--name", "Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_flag_with_equals_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) = hoist.parse(["--name=Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_flag_value_containing_equals_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) = hoist.parse(["--name=a=b"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "a=b"),
    ])
}

pub fn fails_long_flag_with_no_argument_test() {
  let flags = [hoist.new_flag("name")]
  let assert Error(hoist.ValueNotProvided("name")) =
    hoist.parse(["--name"], flags)
}

pub fn fails_unknown_flag_test() {
  let assert Error(hoist.UnknownFlag("name")) = hoist.parse(["--name"], [])
}

pub fn parses_duplicate_value_flag_keeps_last_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) = hoist.parse(["--name", "A", "--name", "B"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "B"),
    ])
}

pub fn parses_mixed_long_flags_and_positionals() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(parsed) =
    hoist.parse(["wibble", "--name", "lucy", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_toggle_flags() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_toggle]
  let assert Ok(parsed) = hoist.parse(["--verbose"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_args_after_long_toggle_flag_as_positional_test() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_toggle]
  let assert Ok(parsed) = hoist.parse(["--verbose", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wobble"], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_duplicate_toggle_flag_deduplicates_test() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_toggle]
  let assert Ok(parsed) = hoist.parse(["--verbose", "--verbose"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn fails_long_toggle_flag_with_value() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_toggle]
  let assert Error(hoist.ValueNotSupported(flag: "verbose", given: "wobble")) =
    hoist.parse(["--verbose=wobble"], flags)
}

pub fn parses_mixed_long_toggle_flags_and_positionals() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_toggle]
  let assert Ok(parsed) = hoist.parse(["wibble", "--verbose", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_long_count_flags() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_count]
  let assert Ok(parsed) = hoist.parse(["--verbose"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_multiple_long_count_flags() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_count]
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "--verbose", "--verbose"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 3),
    ])
}

pub fn parses_args_after_long_count_flag_as_positional_test() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_count]
  let assert Ok(parsed) = hoist.parse(["--verbose", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wobble"], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn fails_long_count_flag_with_value() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_count]
  let assert Error(_) = hoist.parse(["--verbose=wobble"], flags)
}

pub fn parses_mixed_long_count_flags_and_positionals() {
  let flags = [hoist.new_flag("verbose") |> hoist.as_count]
  let assert Ok(parsed) = hoist.parse(["wibble", "--verbose", "wobble"], flags)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_short_flag_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_short_alias("n")]
  let assert Ok(parsed) = hoist.parse(["-n", "Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_short_flag_with_equals_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_short_alias("n")]
  let assert Ok(parsed) = hoist.parse(["-n=Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_short_flag_value_attached_no_space_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_short_alias("n")]
  let assert Ok(parsed) = hoist.parse(["-nLucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn fails_unknown_short_flag_test() {
  let assert Error(hoist.UnknownFlag("x")) = hoist.parse(["-x"], [])
}

pub fn fails_short_value_flag_with_no_argument_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_short_alias("n")]
  let assert Error(hoist.ValueNotProvided("n")) = hoist.parse(["-n"], flags)
}

pub fn parses_short_toggle_flag_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_toggle,
  ]
  let assert Ok(parsed) = hoist.parse(["-v"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_short_count_flag_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
  ]
  let assert Ok(parsed) = hoist.parse(["-v"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_combined_short_flags_test() {
  let flags = [
    hoist.new_flag("name") |> hoist.with_short_alias("n"),
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    hoist.new_flag("dry-run") |> hoist.with_short_alias("d") |> hoist.as_toggle,
  ]
  let assert Ok(parsed) = hoist.parse(["-vdn", "Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
      hoist.ToggleFlag("dry-run"),
      hoist.ValueFlag("name", "Lucy"),
    ])
}

pub fn parses_combined_short_count_flags_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
  ]
  let assert Ok(parsed) = hoist.parse(["-vvv"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 3),
    ])
}

pub fn parses_combined_short_toggle_flags_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_toggle,
    hoist.new_flag("dry-run") |> hoist.with_short_alias("d") |> hoist.as_toggle,
  ]
  let assert Ok(parsed) = hoist.parse(["-vd"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
      hoist.ToggleFlag(name: "dry-run"),
    ])
}

pub fn parses_combined_short_value_flag_consumes_rest_test() {
  let flags = [
    hoist.new_flag("name") |> hoist.with_short_alias("n"),
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_toggle,
  ]
  let assert Ok(parsed) = hoist.parse(["-nv"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "v"),
    ])
}

pub fn parses_combined_short_flags_value_attached_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    hoist.new_flag("dry-run") |> hoist.with_short_alias("d") |> hoist.as_toggle,
    hoist.new_flag("name") |> hoist.with_short_alias("n"),
  ]
  let assert Ok(parsed) = hoist.parse(["-vdnLucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag("verbose", 1),
      hoist.ToggleFlag("dry-run"),
      hoist.ValueFlag("name", "Lucy"),
    ])
}

pub fn fails_short_toggle_with_equals_value_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_toggle,
  ]
  let assert Error(hoist.ValueNotSupported(flag: "v", given: "foo")) =
    hoist.parse(["-v=foo"], flags)
}

pub fn fails_short_count_with_equals_value_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
  ]
  let assert Error(hoist.ValueNotSupported(flag: "v", given: "foo")) =
    hoist.parse(["-v=foo"], flags)
}

pub fn parses_mixed_short_and_long_flags_test() {
  let flags = [
    hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_toggle,
    hoist.new_flag("name"),
  ]
  let assert Ok(parsed) = hoist.parse(["-v", "--name", "Lucy"], flags)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn everything_test() {
  let flags = [
    hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_count,
    hoist.new_flag("foo")
      |> hoist.with_short_alias("f"),
    hoist.new_flag("bar") |> hoist.with_short_alias("b"),
    hoist.new_flag("wibble")
      |> hoist.with_long_alias("wib"),
    hoist.new_flag("dry-run")
      |> hoist.with_short_alias("d")
      |> hoist.as_toggle,
  ]
  let assert Ok(parsed) =
    hoist.parse(
      [
        "thing",
        "-vv",
        "args",
        "in",
        "the",
        "-",
        "-fbar",
        "-db",
        "baz",
        "middle",
        "--wib=wobble",
        "-dv",
        "more",
        "--",
        "--verbose",
        "here",
      ],
      flags,
    )

  assert parsed
    == hoist.Args(
      arguments: [
        "thing",
        "args",
        "in",
        "the",
        "-",
        "middle",
        "more",
        "--verbose",
        "here",
      ],
      flags: [
        hoist.ValueFlag("foo", "bar"),
        hoist.ValueFlag("bar", "baz"),
        hoist.ValueFlag("wibble", "wobble"),
        hoist.ToggleFlag("dry-run"),
        hoist.CountFlag("verbose", 3),
      ],
    )
}
