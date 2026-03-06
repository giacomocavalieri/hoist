import gleam/dict
import gleam/list
import gleam/result
import gleam/set
import gleam/string

pub type ParseError {
  UnknownFlag(String)
  ValueNotProvided(flag: String)
  ValueNotSupported(flag: String, given: String)
}

fn replace_error_flag_name(error: ParseError, flag_name: String) {
  case error {
    UnknownFlag(_) -> error
    ValueNotProvided(_) -> ValueNotProvided(flag_name)
    ValueNotSupported(given:, ..) -> ValueNotSupported(flag: flag_name, given:)
  }
}

/// Whether a flag takes a value or is a boolean toggle
type FlagKind {
  /// Flag takes a value (Int, Float, String, list variants)
  ValueKind
  /// Flag is a boolean toggle
  ToggleKind
  /// Flag is a count
  CountKind
}

pub opaque type FlagSpec {
  FlagSpec(
    name: String,
    aliases: set.Set(String),
    short: set.Set(String),
    kind: FlagKind,
  )
}

type FlagSpecs {
  FlagSpecs(
    long_flags: dict.Dict(String, FlagSpec),
    short_flags: dict.Dict(String, FlagSpec),
  )
}

pub fn new_flag(name: String) -> FlagSpec {
  FlagSpec(name:, aliases: set.new(), short: set.new(), kind: ValueKind)
}

pub fn with_long_alias(flag: FlagSpec, alias: String) -> FlagSpec {
  FlagSpec(..flag, aliases: set.insert(flag.aliases, alias))
}

pub fn with_short_alias(flag: FlagSpec, short: String) -> FlagSpec {
  FlagSpec(..flag, short: set.insert(flag.short, short))
}

pub fn as_toggle(flag: FlagSpec) -> FlagSpec {
  FlagSpec(..flag, kind: ToggleKind)
}

pub fn as_count(flag: FlagSpec) -> FlagSpec {
  FlagSpec(..flag, kind: CountKind)
}

fn build_flag_specs(flags: List(FlagSpec)) -> FlagSpecs {
  let #(long_flags, short_flags) =
    list.fold(flags, #(dict.new(), dict.new()), fn(dicts, flag) {
      let #(lf, stl) = dicts

      let lf = dict.insert(lf, flag.name, flag)
      let lf =
        set.fold(flag.aliases, lf, fn(curr, alias) {
          dict.insert(curr, alias, flag)
        })

      let stl =
        set.fold(flag.short, stl, fn(curr, short) {
          dict.insert(curr, short, flag)
        })

      #(lf, stl)
    })

  FlagSpecs(long_flags:, short_flags:)
}

pub type Flag {
  /// A flag with a value, e.g. from `--name=val` or `--name val` or `-n val`
  ValueFlag(name: String, value: String)
  /// A flag toggle (bool), e.g. from `--verbose` or `-v`
  ToggleFlag(name: String)
  /// A flag count, e.g. from `-vvv`
  CountFlag(name: String, count: Int)
}

/// Result of parsing raw args
pub type Args {
  Args(
    /// Positional arguments
    arguments: List(String),
    /// Flag inputs normalised to "name=value" or "name" (toggle) form, prefix stripped
    flags: List(Flag),
  )
}

/// Intermediate representation of ParsedArgs that has positional arguments reversed.
type ParseState {
  ParseState(
    /// Flag inputs normalised to "name=value" or "name" (toggle) form, prefix stripped
    flags: List(Flag),
    /// Positional arguments in reverse order
    arguments_reversed: List(String),
  )
}

/// Parse positional args and flags from a list of args.
///
/// Note: this function expects any whitespace-only args to have been filtered
/// already, and does not handle them.
pub fn parse(
  input: List(String),
  flags: List(FlagSpec),
) -> Result(Args, ParseError) {
  let state = ParseState(flags: [], arguments_reversed: [])
  do_parse(input, build_flag_specs(flags), Ok(state))
  |> result.map(fn(state) {
    Args(
      arguments: list.reverse(state.arguments_reversed),
      flags: list.reverse(state.flags),
    )
  })
}

fn do_parse(
  remaining_input: List(String),
  flag_specs: FlagSpecs,
  state: Result(ParseState, ParseError),
) -> Result(ParseState, ParseError) {
  // TODO: refactor to not use result.try as this prevents tail recursion.
  // Might not be necessary given the length of most commands, but definitely
  // something to take into consideration.
  use state <- result.try(state)

  case remaining_input {
    [] -> Ok(state)

    // Treat anything after bare `--` as positional args and end parsing here.
    ["--", ..rest] ->
      Ok(
        ParseState(
          ..state,
          arguments_reversed: list.append(
            list.reverse(rest),
            state.arguments_reversed,
          ),
        ),
      )
    // Treat `--` followed by a string as a flag. May have a value with
    // `=`, or may be a bare flag with the value in the next arg.
    ["--" <> flag_name, ..rest] ->
      handle_long_flag(flag_name, rest, flag_specs, state)

    // Treat bare `-` as positional.
    ["-" as arg, ..rest] ->
      do_parse(
        rest,
        flag_specs,
        Ok(
          ParseState(..state, arguments_reversed: [
            arg,
            ..state.arguments_reversed
          ]),
        ),
      )
    // `-` followed by a value is one or more short flags.
    ["-" <> flag_names, ..rest] ->
      handle_short_flag(flag_names, rest, flag_specs, state)

    // Anything else is positional
    [arg, ..rest] ->
      do_parse(
        rest,
        flag_specs,
        Ok(
          ParseState(..state, arguments_reversed: [
            arg,
            ..state.arguments_reversed
          ]),
        ),
      )
  }
}

fn handle_long_flag(
  flag_name: String,
  remaining_input: List(String),
  flag_specs: FlagSpecs,
  state: ParseState,
) -> Result(ParseState, ParseError) {
  // If the flag contains a `=` character, treat that as the value
  // and prepend it to the rest of the args to make processing easier
  // later (i.e. so we only have to process the case where the flag
  // value is the first item in the list).
  let #(parsed_flag_name, has_equals_value, remaining_input) = case
    string.split_once(flag_name, "=")
  {
    Ok(#(name, value)) -> #(name, True, [value, ..remaining_input])
    Error(_) -> #(flag_name, False, remaining_input)
  }

  case dict.get(flag_specs.long_flags, parsed_flag_name) {
    Error(_) -> Error(UnknownFlag(parsed_flag_name))
    Ok(flag_spec) -> {
      case flag_spec.kind, has_equals_value {
        ValueKind, _ ->
          case remaining_input {
            [value, ..rest] ->
              do_parse(
                rest,
                flag_specs,
                Ok(
                  ParseState(
                    ..state,
                    flags: upsert_flag(
                      ValueFlag(flag_spec.name, value),
                      state.flags,
                    ),
                  ),
                ),
              )
            [] -> Error(ValueNotProvided(parsed_flag_name))
          }

        // If we had a value after `=` but this is not a value-kind
        // flag, then error.
        // TODO: decide if count-kind and toggle-kind flags can contain values
        ToggleKind, True ->
          Error(ValueNotSupported(
            parsed_flag_name,
            // This zero value will never be reached - we've already validated
            // that there's another value in the list.
            result.unwrap(list.first(remaining_input), ""),
          ))
        CountKind, True ->
          Error(ValueNotSupported(
            parsed_flag_name,
            result.unwrap(list.first(remaining_input), ""),
          ))

        ToggleKind, False ->
          do_parse(
            remaining_input,
            flag_specs,
            Ok(
              ParseState(
                ..state,
                flags: upsert_flag(
                  ToggleFlag(name: flag_spec.name),
                  state.flags,
                ),
              ),
            ),
          )

        CountKind, False ->
          do_parse(
            remaining_input,
            flag_specs,
            Ok(
              ParseState(
                ..state,
                flags: upsert_count_flag(flag_spec, state.flags),
              ),
            ),
          )
      }
    }
  }
}

fn handle_short_flag(
  flag_names: String,
  remaining_input: List(String),
  flag_specs: FlagSpecs,
  state: ParseState,
) -> Result(ParseState, ParseError) {
  let graphemes = string.to_graphemes(flag_names)

  case graphemes {
    [] -> do_parse(remaining_input, flag_specs, Ok(state))

    [short_flag, ..rest_flags] ->
      case dict.get(flag_specs.short_flags, short_flag) {
        Error(_) -> Error(UnknownFlag(short_flag))
        Ok(flag) -> {
          case rest_flags {
            // For a length 1 list (e.g. `-x`), we can just look up the corresponding
            // long flag name and parse that.
            [] ->
              handle_long_flag(flag.name, remaining_input, flag_specs, state)
              |> result.map_error(replace_error_flag_name(_, short_flag))

            // If the rest of the graphemes follow `=`, we assume the current flag is
            // the last one and any remaining graphemes make up the value passed
            // to the flag.
            ["=", ..value_graphemes] -> {
              let value = string.concat(value_graphemes)

              case flag.kind {
                ToggleKind | CountKind ->
                  Error(ValueNotSupported(flag: short_flag, given: value))
                // Continue with regular parsing loop
                ValueKind ->
                  do_parse(
                    remaining_input,
                    flag_specs,
                    Ok(
                      ParseState(
                        ..state,
                        flags: upsert_flag(
                          ValueFlag(name: flag.name, value:),
                          state.flags,
                        ),
                      ),
                    ),
                  )
              }
            }

            rest_flags ->
              case flag.kind {
                // For a value flag we consume any remaining input as the value for
                // that flag, then continue with the parse loop.
                ValueKind ->
                  do_parse(
                    remaining_input,
                    flag_specs,
                    Ok(
                      ParseState(
                        ..state,
                        flags: upsert_flag(
                          ValueFlag(
                            name: flag.name,
                            value: string.concat(rest_flags),
                          ),
                          state.flags,
                        ),
                      ),
                    ),
                  )
                ToggleKind ->
                  handle_short_flag(
                    string.concat(rest_flags),
                    remaining_input,
                    flag_specs,
                    ParseState(
                      ..state,
                      flags: upsert_flag(
                        ToggleFlag(name: flag.name),
                        state.flags,
                      ),
                    ),
                  )
                CountKind ->
                  handle_short_flag(
                    string.concat(rest_flags),
                    remaining_input,
                    flag_specs,
                    ParseState(
                      ..state,
                      flags: upsert_count_flag(flag, state.flags),
                    ),
                  )
              }
          }
        }
      }
  }
}

fn upsert_flag(new_flag: Flag, flags: List(Flag)) -> List(Flag) {
  [new_flag, ..list.filter(flags, fn(input) { input.name != new_flag.name })]
}

fn upsert_count_flag(flag_spec: FlagSpec, flags: List(Flag)) -> List(Flag) {
  let existing_flag_count_result =
    list.find_map(flags, fn(input) {
      case input {
        CountFlag(name: n, count:) if n == flag_spec.name -> Ok(count)
        _ -> Error(Nil)
      }
    })

  let count = case existing_flag_count_result {
    Ok(count) -> count + 1
    Error(_) -> 1
  }

  // Replace the existing input if it exists
  upsert_flag(CountFlag(name: flag_spec.name, count:), flags)
}
