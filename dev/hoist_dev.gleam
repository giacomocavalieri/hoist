import argv
import gleam/int
import gleam/io
import gleam/list
import hoist

pub fn main() {
  let flag_specs = [
    hoist.new_flag("target")
      |> hoist.with_short_alias("t"),
    hoist.new_flag("cannons")
      |> hoist.with_short_alias("c"),
    hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_count,
    hoist.new_flag("dry-run")
      |> hoist.with_short_alias("d")
      |> hoist.as_toggle,
  ]

  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flag_specs)
  let assert Ok(args) = hoist.parse(argv.load().arguments, validated_flag_specs)

  // $ gleam dev attack --target "The Black Pearl" -vvd --cannons 12
  //
  // Args(
  //   arguments: ["attack"],
  //   flags: [
  //     ValueFlag("target", "The Black Pearl"),
  //     CountFlag("verbose", 2),
  //     ToggleFlag("dry-run"),
  //     ValueFlag("cannons", "12"),
  //   ],
  // )

  case args.arguments {
    ["attack"] -> {
      case args.flags {
        [] ->
          io.println(
            "You didn' give me no directions! Maybe I'll attack ye instead...",
          )
        _ ->
          list.each(args.flags, fn(flag) {
            case flag {
              hoist.ValueFlag("target", ship) ->
                io.println("Arr! Setting course for " <> ship <> "!")
              hoist.CountFlag("verbose", n) ->
                io.println(
                  "Verbosity: "
                  <> int.to_string(n)
                  <> " "
                  <> {
                    case n {
                      1 -> "parrot"
                      _ -> "parrots"
                    }
                  }
                  <> " squawking",
                )
              hoist.ToggleFlag("dry-run") ->
                io.println("Dry run — keeping the powder dry, cap'n")
              hoist.ValueFlag("cannons", n) ->
                io.println("Loading " <> n <> " cannons!")
              _ -> Nil
            }
          })
      }
    }
    _ ->
      io.println(
        "Arrrr, I don't recognise that command. Usage: gleam dev attack [OPTIONS]",
      )
  }
}
