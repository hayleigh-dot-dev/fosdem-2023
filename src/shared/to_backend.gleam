// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result
import shared/state.{DelayTime, Waveform}

// TYPES -----------------------------------------------------------------------

///
///
pub type ToBackend {
  Play
  Stop
  UpdateDelayTime(DelayTime)
  UpdateGain(Float)
  UpdateStep(#(String, Int, Bool))
  UpdateWaveform(Waveform)
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
        #("waveform", state.encode_waveform(waveform)),
      ])

    UpdateDelayTime(delay_time) ->
      json.object([
        #("$", json.string("UpdateDelayTime")),
        #("delay_time", state.encode_delay_time(delay_time)),
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
      |> dynamic.field("waveform", state.waveform_decoder)
      |> result.map(UpdateWaveform)

    "UpdateDelayTime" ->
      dynamic
      |> dynamic.field("delay_time", state.delay_time_decoder)
      |> result.map(UpdateDelayTime)

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
