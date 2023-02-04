// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result
import shared/state.{DelayTime, Row, State, Waveform}

// TYPES -----------------------------------------------------------------------

///
///
pub type ToFrontend {
  SetDelayTime(DelayTime)
  SetGain(Float)
  SetRows(List(Row))
  SetState(State)
  SetStep(Int)
  SetStepCount(Int)
  SetWaveform(Waveform)
}

// JSON ------------------------------------------------------------------------

///
///
pub fn encode(msg: ToFrontend) -> Json {
  case msg {
    SetState(state) ->
      json.object([
        #("$", json.string("SetState")),
        #("state", state.encode(state)),
      ])

    SetRows(rows) ->
      json.object([
        #("$", json.string("SetRows")),
        #("rows", json.array(rows, state.encode_row)),
      ])

    SetStep(step) ->
      json.object([#("$", json.string("SetStep")), #("step", json.int(step))])

    SetStepCount(step_count) ->
      json.object([
        #("$", json.string("SetStepCount")),
        #("step_count", json.int(step_count)),
      ])

    SetWaveform(waveform) ->
      json.object([
        #("$", json.string("SetWaveform")),
        #("waveform", state.encode_waveform(waveform)),
      ])

    SetDelayTime(delay_time) ->
      json.object([
        #("$", json.string("SetDelayTime")),
        #("delay_time", state.encode_delay_time(delay_time)),
      ])

    SetGain(gain) ->
      json.object([#("$", json.string("SetGain")), #("gain", json.float(gain))])
  }
}

///
///
pub fn decoder(dynamic: Dynamic) -> Result(ToFrontend, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(dynamic))

  case tag {
    "SetState" ->
      dynamic
      |> dynamic.field("state", state.decoder)
      |> result.map(SetState)

    "SetRows" ->
      dynamic
      |> dynamic.field("rows", dynamic.list(state.row_decoder))
      |> result.map(SetRows)

    "SetStep" ->
      dynamic
      |> dynamic.field("step", dynamic.int)
      |> result.map(SetStep)

    "SetStepCount" ->
      dynamic
      |> dynamic.field("step_count", dynamic.int)
      |> result.map(SetStepCount)

    "SetWaveform" ->
      dynamic
      |> dynamic.field("waveform", state.waveform_decoder)
      |> result.map(SetWaveform)

    "SetDelayTime" ->
      dynamic
      |> dynamic.field("delay_time", state.delay_time_decoder)
      |> result.map(SetDelayTime)

    "SetGain" ->
      dynamic
      |> dynamic.field("gain", dynamic.float)
      |> result.map(SetGain)

    _ ->
      Error([
        DecodeError(
          "one of 'SetState'|'SetRows'|'SetStep'|'SetStepCount'|'SetDelayTime'|'SetDelayAmount'|'SetGain'",
          tag,
          ["$"],
        ),
      ])
  }
}
