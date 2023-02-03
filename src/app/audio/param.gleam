// IMPORTS ---------------------------------------------------------------------

import app/util/encode
import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/result

// TYPES -----------------------------------------------------------------------

pub type Param {
  ExponentialRamp(name: String, value: Float, time: Float)
  LinearRamp(name: String, value: Float, time: Float)
  Param(name: String, value: Float)
  Property(name: String, value: Dynamic)
  SetAt(name: String, value: Float, time: Float)
}

// CONSTANTS -------------------------------------------------------------------
// CONSTRUCTORS ----------------------------------------------------------------

pub fn prop(name: String, value: a) -> Param {
  Property(name, dynamic.from(value))
}

pub fn param(name: String, value: Float) -> Param {
  Param(name, value)
}

pub fn linear_ramp(param: Param, time: Float) -> Param {
  assert Param(name, value) = param

  LinearRamp(name, value, time)
}

pub fn exponential_ramp(param: Param, time: Float) -> Param {
  assert Param(name, value) = param

  ExponentialRamp(name, value, time)
}

pub fn set_at(param: Param, time: Float) -> Param {
  assert Param(name, value) = param

  SetAt(name, value, time)
}

//

pub fn freq(value: Float) -> Param {
  param("frequency", value)
}

pub fn waveform(value: String) -> Param {
  prop("type", value)
}

pub fn gain(value: Float) -> Param {
  param("gain", value)
}

pub fn filter(value: String) -> Param {
  prop("type", value)
}

pub fn delay_time(value: Float) -> Param {
  param("delayTime", value)
}

// JSON ------------------------------------------------------------------------

pub fn encode(param: Param) -> Json {
  case param {
    ExponentialRamp(name, value, time) ->
      json.object([
        #("$", json.string("ExponentialRamp")),
        #("name", json.string(name)),
        #("value", json.float(value)),
        #("time", json.float(time)),
      ])

    LinearRamp(name, value, time) ->
      json.object([
        #("$", json.string("LinearRamp")),
        #("name", json.string(name)),
        #("value", json.float(value)),
        #("time", json.float(time)),
      ])

    Param(name, value) ->
      json.object([
        #("$", json.string("Param")),
        #("name", json.string(name)),
        #("value", json.float(value)),
      ])

    Property(name, value) ->
      json.object([
        #("$", json.string("Property")),
        #("name", json.string(name)),
        #("value", encode.dynamic(value)),
      ])

    SetAt(name, value, time) ->
      json.object([
        #("$", json.string("SetAt")),
        #("name", json.string(name)),
        #("value", json.float(value)),
        #("time", json.float(time)),
      ])
  }
}

pub fn decoder(value: Dynamic) -> Result(Param, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(value))
  let decoder = case tag {
    "ExponentialRamp" ->
      dynamic.decode3(
        ExponentialRamp,
        dynamic.field("name", dynamic.string),
        dynamic.field("value", dynamic.float),
        dynamic.field("time", dynamic.float),
      )

    "LinearRamp" ->
      dynamic.decode3(
        LinearRamp,
        dynamic.field("name", dynamic.string),
        dynamic.field("value", dynamic.float),
        dynamic.field("time", dynamic.float),
      )

    "Param" ->
      dynamic.decode2(
        Param,
        dynamic.field("name", dynamic.string),
        dynamic.field("value", dynamic.float),
      )

    "Property" ->
      dynamic.decode2(
        Property,
        dynamic.field("name", dynamic.string),
        dynamic.field("value", dynamic.dynamic),
      )

    "SetAt" ->
      dynamic.decode3(
        SetAt,
        dynamic.field("name", dynamic.string),
        dynamic.field("value", dynamic.float),
        dynamic.field("time", dynamic.float),
      )

    found -> fn(_) {
      let expected = "Expected one of 'Key'|'Node'|'Ref'"
      let path = ["$"]

      Error([DecodeError(expected, found, path)])
    }
  }

  decoder(value)
}
