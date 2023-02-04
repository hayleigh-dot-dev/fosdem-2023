// IMPORTS ---------------------------------------------------------------------

import gleam/map.{Map}
import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result
import gleam/list

// TYPES -----------------------------------------------------------------------

/// This `State` is shared by the backend and all connected clients. Clients then
/// use this state to render their own UI and play their own audio. Each client
/// can send updates to the backend to alter the state, and changes are broadcast
/// to everyone, so everyone is playing together!
///
pub type State {
  State(
    /// The represents each horizontal row of the sequencer. Each row is a differnt
    /// note, but every row is the same length.
    rows: List(Row),
    /// This is the current step that we're on in the sequence.
    step: Int,
    /// This is the total number of steps in the sequence. We keep this around so
    /// it's easy to wrap the `step` around once we get to the end.
    step_count: Int,
    /// The waveform to use for the oscillator.
    waveform: String,
    /// We have two delays, either a 
    delay_time: Float,
    delay_amount: Float,
    /// The master gain for the entire sequence. Each client will have their own
    /// volume toggle, but the master gain is used for global stop/start muting.
    gain: Float,
  )
}

/// Gleam doesn't have an `Array` type in the standard library, but we can make
/// do with a `Map` with `Int` keys. 
///
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
  #("B3", 246.94),
  #("A3", 220.00),
  #("G3", 196.00),
  #("F3", 174.61),
  #("E3", 164.81),
  #("D3", 146.83),
  #("C3", 130.81),
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

/// Gleam's JSON library gives us a handful of functions to turn everyday Gleam
/// values into JSON. By combining them together and building them up, we can 
/// encode our `State` type however we want.
///
/// As a convention I like to use the `$` field to encode the tag of the custom
/// type we're encoding: this makes it a lot easier to decode later on because
/// we can choose the correct decoder based on the tag.
///
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

/// `encode_row` is public because the backend sometimes wants to broadcast 
/// updates to the rows of the sequencer to all clients without broadcasting the
/// entire application state.
///
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

/// Where the JSON library let us turn Gleam values into JSON, the `dynamic`
/// module can help us turn unknown runtime values into well-typed Gleam ones.
///
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
  let decoder =
    dynamic.decode2(
      fn(k, v) { #(k, v) },
      dynamic.element(0, dynamic.int),
      dynamic.element(1, dynamic.bool),
    )

  decoder(dynamic)
}
