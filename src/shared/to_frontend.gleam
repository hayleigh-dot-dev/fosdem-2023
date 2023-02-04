// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result
import shared/state.{Row, State}

// TYPES -----------------------------------------------------------------------

///
///
pub type ToFrontend {
  SetState(State)
  SetRows(List(Row))
  SetStep(Int)
  SetStepCount(Int)
  SetWaveform(String)
  SetDelayTime(Float)
  SetDelayAmount(Float)
  SetGain(Float)
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
        #("waveform", json.string(waveform)),
      ])

    SetDelayTime(delay_time) ->
      json.object([
        #("$", json.string("SetDelayTime")),
        #("delay_time", json.float(delay_time)),
      ])

    SetDelayAmount(delay_amount) ->
      json.object([
        #("$", json.string("SetDelayAmount")),
        #("delay_amount", json.float(delay_amount)),
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
      |> dynamic.field("waveform", dynamic.string)
      |> result.map(SetWaveform)

    "SetDelayTime" ->
      dynamic
      |> dynamic.field("delay_time", dynamic.float)
      |> result.map(SetDelayTime)

    "SetDelayAmount" ->
      dynamic
      |> dynamic.field("delay_amount", dynamic.float)
      |> result.map(SetDelayAmount)

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
