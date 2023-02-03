// IMPORTS ---------------------------------------------------------------------

import gleam/map.{Map}
import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result
import gleam/list

// TYPES -----------------------------------------------------------------------

pub type State {
  State(
    rows: List(Row),
    step: Int,
    step_count: Int,
    waveform: String,
    delay_time: Float,
    delay_amount: Float,
    gain: Float,
  )
}

pub type Row {
  Row(name: String, note: Float, steps: Map(Int, Bool))
}

// CONSTANTS -------------------------------------------------------------------

const notes: List(#(String, Float)) = [
  #("C5", 523.25),
  #("B4", 493.88),
  #("A4", 440.00),
  #("G4", 392.00),
  #("F4", 349.23),
  #("E4", 329.63),
  #("D4", 293.66),
  #("C4", 261.63),
]

// CONSTRUCTORS ----------------------------------------------------------------

pub fn init() {
  let step_count = 8
  let rows = init_rows(step_count)

  State(rows, 0, step_count, "sine", 1.0, 0.2, 0.5)
}

fn init_rows(step_count: Int) -> List(Row) {
  let steps =
    list.range(0, step_count - 1)
    |> list.map(fn(i) { #(i, False) })
    |> map.from_list

  list.map(notes, fn(note) { Row(note.0, note.1, steps) })
}

// JSON ------------------------------------------------------------------------

pub fn encode(state: State) -> Json {
  json.object([
    #("$", json.string("State")),
    #("rows", json.array(state.rows, encode_row)),
    #("step", json.int(state.step)),
    #("step_count", json.int(state.step_count)),
    #("waveform", json.string(state.waveform)),
    #("delay_time", json.float(state.delay_time)),
    #("delay_amount", json.float(state.delay_amount)),
    #("gain", json.float(state.gain)),
  ])
}

pub fn encode_row(row: Row) -> Json {
  json.object([
    #("$", json.string("Row")),
    #("name", json.string(row.name)),
    #("note", json.float(row.note)),
    #("steps", encode_steps(row.steps)),
  ])
}

fn encode_steps(steps: Map(Int, Bool)) -> Json {
  use step <- json.array(map.to_list(steps))
  json.preprocessed_array([json.int(step.0), json.bool(step.1)])
}

pub fn decoder(dynamic: Dynamic) -> Result(State, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(dynamic))

  let decoder = case tag {
    "State" ->
      dynamic.decode7(
        State,
        dynamic.field("rows", dynamic.list(row_decoder)),
        dynamic.field("step", dynamic.int),
        dynamic.field("step_count", dynamic.int),
        dynamic.field("waveform", dynamic.string),
        dynamic.field("delay_time", dynamic.float),
        dynamic.field("delay_amount", dynamic.float),
        dynamic.field("gain", dynamic.float),
      )

    _ -> fn(_) { Error([DecodeError("State", tag, ["$"])]) }
  }

  decoder(dynamic)
}

pub fn row_decoder(dynamic: Dynamic) -> Result(Row, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(dynamic))
  let decoder = case tag {
    "Row" ->
      dynamic.decode3(
        Row,
        dynamic.field("name", dynamic.string),
        dynamic.field("note", dynamic.float),
        dynamic.field("steps", steps_decoder),
      )

    _ -> fn(_) { Error([DecodeError("Row", tag, ["$"])]) }
  }

  decoder(dynamic)
}

fn steps_decoder(dynamic: Dynamic) -> Result(Map(Int, Bool), List(DecodeError)) {
  use steps <- result.then(dynamic.list(step_decoder)(dynamic))
  Ok(map.from_list(steps))
}

fn step_decoder(dynamic: Dynamic) -> Result(#(Int, Bool), List(DecodeError)) {
  dynamic.decode2(
    fn(k, v) { #(k, v) },
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.bool),
  )(
    dynamic,
  )
}
