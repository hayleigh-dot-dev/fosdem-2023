// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result

// TYPES -----------------------------------------------------------------------

///
///
pub type ToBackend {
  Play
  Stop
  UpdateDelayAmount(Float)
  UpdateDelayTime(Float)
  UpdateGain(Float)
  UpdateStep(#(String, Int, Bool))
  UpdateWaveform(String)
}

// JSON ------------------------------------------------------------------------

///
///
pub fn encode(msg: ToBackend) -> Json {
  case msg {
    Play -> json.object([#("$", json.string("Play"))])
    Stop -> json.object([#("$", json.string("Stop"))])
    UpdateStep(step) ->
      json.object([
        #("$", json.string("UpdateStep")),
        #("step", encode_step(step)),
      ])

    UpdateWaveform(waveform) ->
      json.object([
        #("$", json.string("UpdateWaveform")),
        #("waveform", json.string(waveform)),
      ])

    UpdateDelayTime(delay_time) ->
      json.object([
        #("$", json.string("UpdateDelayTime")),
        #("delay_time", json.float(delay_time)),
      ])

    UpdateDelayAmount(delay_amount) ->
      json.object([
        #("$", json.string("UpdateDelayAmount")),
        #("delay_amount", json.float(delay_amount)),
      ])

    UpdateGain(gain) ->
      json.object([
        #("$", json.string("UpdateGain")),
        #("gain", json.float(gain)),
      ])
  }
}

fn encode_step(step: #(String, Int, Bool)) -> Json {
  json.object([
    #("$", json.string("Step")),
    #("note", json.string(step.0)),
    #("idx", json.int(step.1)),
    #("on", json.bool(step.2)),
  ])
}

///
///
pub fn decoder(dynamic: Dynamic) -> Result(ToBackend, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(dynamic))

  case tag {
    "Play" -> Ok(Play)
    "Stop" -> Ok(Stop)
    "UpdateStep" ->
      dynamic
      |> dynamic.field("step", step_decoder)
      |> result.map(UpdateStep)

    "UpdateWaveform" ->
      dynamic
      |> dynamic.field("waveform", dynamic.string)
      |> result.map(UpdateWaveform)

    "UpdateDelayTime" ->
      dynamic
      |> dynamic.field("delay_time", dynamic.float)
      |> result.map(UpdateDelayTime)

    "UpdateDelayAmount" ->
      dynamic
      |> dynamic.field("delay_amount", dynamic.float)
      |> result.map(UpdateDelayAmount)

    "UpdateGain" ->
      dynamic
      |> dynamic.field("gain", dynamic.float)
      |> result.map(UpdateGain)

    _ -> Error([DecodeError("", tag, ["$"])])
  }
}

fn step_decoder(
  dynamic: Dynamic,
) -> Result(#(String, Int, Bool), List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(dynamic))

  case tag {
    "Step" ->
      dynamic
      |> dynamic.decode3(
        fn(note, idx, on) { #(note, idx, on) },
        dynamic.field("note", dynamic.string),
        dynamic.field("idx", dynamic.int),
        dynamic.field("on", dynamic.bool),
      )
    _ -> Error([DecodeError("", tag, ["$"])])
  }
}
