import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/list
import gleam/result

pub fn dynamic(value: Dynamic) -> Json {
  assert Ok(json) =
    list.find_map(
      [
        encode_dynamic_int,
        encode_dynamic_float,
        encode_dynamic_string,
        encode_dynamic_bool,
        encode_dynamic_option(_, dynamic.int, json.int),
        encode_dynamic_option(_, dynamic.float, json.float),
        encode_dynamic_option(_, dynamic.string, json.string),
        encode_dynamic_option(_, dynamic.bool, json.bool),
        encode_dynamic_list(_, dynamic.int, json.int),
        encode_dynamic_list(_, dynamic.float, json.float),
        encode_dynamic_list(_, dynamic.string, json.string),
        encode_dynamic_list(_, dynamic.bool, json.bool),
      ],
      fn(f) { f(value) },
    )

  json
}

fn encode_dynamic_int(value: Dynamic) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.int(value), json.int)
}

fn encode_dynamic_float(value: Dynamic) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.float(value), json.float)
}

fn encode_dynamic_string(value: Dynamic) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.string(value), json.string)
}

fn encode_dynamic_bool(value: Dynamic) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.bool(value), json.bool)
}

fn encode_dynamic_option(
  value: Dynamic,
  f: fn(Dynamic) -> Result(a, List(DecodeError)),
  e: fn(a) -> Json,
) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.optional(f)(value), json.nullable(_, e))
}

fn encode_dynamic_list(
  value: Dynamic,
  f: fn(Dynamic) -> Result(a, List(DecodeError)),
  e: fn(a) -> Json,
) -> Result(Json, List(DecodeError)) {
  result.map(dynamic.list(f)(value), json.array(_, e))
}
