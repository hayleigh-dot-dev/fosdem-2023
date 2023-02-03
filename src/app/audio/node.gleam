// IMPORTS ---------------------------------------------------------------------

import gleam/dynamic.{DecodeError, Dynamic}
import gleam/json.{Json}
import gleam/option.{None, Option, Some}
import gleam/result
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

// JSON ------------------------------------------------------------------------

pub fn encode(node: Node) -> Json {
  case node {
    Key(id, t, params, connections) ->
      json.object([
        #("$", json.string("Key")),
        #("id", json.string(id)),
        #("type", json.string(t)),
        #("params", json.array(params, param.encode)),
        #("connections", json.array(connections, encode)),
      ])

    Node(t, params, connections) ->
      json.object([
        #("$", json.string("Node")),
        #("type", json.string(t)),
        #("params", json.array(params, param.encode)),
        #("connections", json.array(connections, encode)),
      ])

    Ref(id, param) ->
      json.object([
        #("$", json.string("Ref")),
        #("id", json.string(id)),
        #("param", json.nullable(param, json.string)),
      ])
  }
}

pub fn decoder(value: Dynamic) -> Result(Node, List(DecodeError)) {
  use tag <- result.then(dynamic.field("$", dynamic.string)(value))
  let decoder = case tag {
    "Key" ->
      dynamic.decode4(
        Key,
        dynamic.field("id", dynamic.string),
        dynamic.field("type", dynamic.string),
        dynamic.field("params", dynamic.list(param.decoder)),
        dynamic.field("connections", dynamic.list(decoder)),
      )

    "Node" ->
      dynamic.decode3(
        Node,
        dynamic.field("type", dynamic.string),
        dynamic.field("params", dynamic.list(param.decoder)),
        dynamic.field("connections", dynamic.list(decoder)),
      )

    "Ref" ->
      dynamic.decode2(
        Ref,
        dynamic.field("id", dynamic.string),
        dynamic.field("param", dynamic.optional(dynamic.string)),
      )

    found -> fn(_) {
      let expected = "Expected one of 'Key'|'Node'|'Ref'"
      let path = ["$"]

      Error([DecodeError(expected, found, path)])
    }
  }

  decoder(value)
}
