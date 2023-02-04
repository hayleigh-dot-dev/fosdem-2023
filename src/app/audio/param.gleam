// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{Dynamic}

// TYPES -----------------------------------------------------------------------

pub type Param {
  Param(name: String, value: Float)
  Property(name: String, value: Dynamic)
  Scheduled(name: String, value: Float, time: Float, method: String)
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
  Scheduled(name, value, time, "linearRampToValueAtTime")
}

pub fn exponential_ramp(param: Param, time: Float) -> Param {
  assert Param(name, value) = param
  Scheduled(name, value, time, "exponentialRampToValueAtTime")
}

pub fn set_at(param: Param, time: Float) -> Param {
  assert Param(name, value) = param
  Scheduled(name, value, time, "setValueAtTime")
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
