if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import app/data/io.{IO}
  import gleam/int
  import gleam/list
  import gleam/map.{Map}
  import lustre
  import lustre/cmd
  import lustre/element.{button, div, p, span, text}
  import lustre/event.{dispatch, on_click}
  import lustre_websocket.{OnClose, OnMessage, OnOpen, WebSocketEvent} as ws

  // MAIN ------------------------------------------------------------------------

  pub fn main() {
    init()
    |> lustre.application(io, render)
    |> lustre.start("#app")
  }

  // STATE -----------------------------------------------------------------------

  type State =
    Int

  fn init() -> IO(State, Action) {
    let state = 0
    let cmd = ws.init("/ws", WebSocket)

    #(state, cmd)
  }

  // UPDATE ----------------------------------------------------------------------

  pub type Action {
    WebSocket(WebSocketEvent)
  }

  fn io(state: State, action: Action) -> IO(State, Action) {
    case action {
      WebSocket(OnOpen(conn)) -> io.pure(state)
      WebSocket(OnClose(conn)) -> io.pure(state)
      WebSocket(OnMessage(msg)) ->
        case msg {
          "tick" -> io.pure(state + 1)
          _ -> io.pure(state)
        }
    }
  }

  // RENDER ----------------------------------------------------------------------

  fn render(state) {
    let count = int.to_string(state)

    p([], [text(count)])
  }
}
