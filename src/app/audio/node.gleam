// IMPORTS ---------------------------------------------------------------------

import gleam/option.{None, Option, Some}
import app/audio/param.{Param}

// TYPES -----------------------------------------------------------------------

pub type Node {
  Key(id: String, t: String, params: List(Param), connections: List(Node))
  Node(t: String, params: List(Param), connections: List(Node))
  Ref(id: String, param: Option(String))
}

// CONSTANTS -------------------------------------------------------------------

pub const dac = Node("AudioDestinationNode", [], [])

// CONSTRUCTORS ----------------------------------------------------------------

pub fn key(id: String, node: Node) -> Node {
  assert Node(t, params, connections) = node

  Key(id, t, params, connections)
}

pub fn node(t: String, params: List(Param), connections: List(Node)) -> Node {
  Node(t, params, connections)
}

pub fn ref(id: String) -> Node {
  Ref(id, None)
}

pub fn param(id: String, param: String) -> Node {
  Ref(id, Some(param))
}

//

pub fn osc(params: List(Param), connections: List(Node)) -> Node {
  Node("OscillatorNode", params, connections)
}

pub fn amp(params: List(Param), connections: List(Node)) -> Node {
  Node("GainNode", params, connections)
}

pub fn del(params: List(Param), connections: List(Node)) -> Node {
  Node("DelayNode", params, connections)
}

pub fn lpf(params: List(Param), connections: List(Node)) -> Node {
  Node("BiquadFilterNode", [param.filter("lowpass"), ..params], connections)
}
