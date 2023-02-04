if erlang {
  // IMPORTS ---------------------------------------------------------------------

  import gleam/bit_builder
  import gleam/erlang/file
  import gleam/erlang/process.{Subject}
  import gleam/http.{Get}
  import gleam/http/request
  import gleam/http/response.{Response}
  import gleam/io
  import gleam/json
  import gleam/list
  import gleam/map
  import gleam/option.{Some}
  import gleam/otp/actor.{Continue, StartError}
  import gleam/result
  import gleam/set.{Set}
  import gleam/string
  import glisten
  import glisten/handler.{HandlerMessage} as glisten_handler
  import mist
  import mist/handler.{HandlerResponse} as mist_handler
  import mist/http.{BitBuilderBody, HttpResponseBody} as mist_http
  import mist/websocket.{TextMessage, WebsocketHandler}
  import shared/state as shared
  import shared/to_backend.{
    Play, Stop, ToBackend, UpdateDelayTime, UpdateGain, UpdateStep,
    UpdateWaveform,
  }
  import shared/to_frontend.{
    SetDelayTime, SetGain, SetRows, SetState, SetStep, SetWaveform,
  }

  // TYPES ---------------------------------------------------------------------

  type Msg {
    OnConnect(client: Client)
    OnDisconnect(client: Client)
    OnMessage(self: App, client: Client, message: ToBackend)
    Tick(self: App)
  }

  type App =
    Subject(Msg)

  type Client =
    Subject(HandlerMessage)

  type State {
    State(clients: Set(Client), shared: shared.State, running: Bool)
  }

  // CONSTANTS -----------------------------------------------------------------

  const interval = 250

  // MAIN ----------------------------------------------------------------------

  pub fn main() {
    assert Ok(app) = start()
    assert Ok(_) = serve(app)

    // Serve starts a new process so we want to keep the main process alive.
    process.sleep_forever()
  }

  fn start() -> Result(App, StartError) {
    let init = State(set.new(), shared.init(), False)
    let broadcast = fn(clients, message) -> Nil {
      use _, client <- set.fold(clients, Nil)
      let json = to_frontend.encode(message)
      let text = TextMessage(json.to_string(json))
      websocket.send(client, text)
    }

    use event, state <- actor.start(init)
    let state = case event {
      OnConnect(client) -> {
        let message = SetState(state.shared)
        let json = to_frontend.encode(message)
        let text = TextMessage(json.to_string(json))

        websocket.send(client, text)
        State(..state, clients: set.insert(state.clients, client))
      }

      OnDisconnect(client) ->
        State(..state, clients: set.delete(state.clients, client))

      OnMessage(self, _, Play) -> {
        process.send_after(self, interval, Tick(self))
        State(..state, running: True)
      }

      OnMessage(_, _, Stop) -> State(..state, running: False)

      OnMessage(_, _, UpdateStep(#(name, idx, on))) -> {
        let step_count = state.shared.step_count
        let rows = {
          use row <- list.map(state.shared.rows)

          case row.name == name {
            True if idx < step_count ->
              shared.Row(..row, steps: map.insert(row.steps, idx, on))
            _ -> row
          }
        }
        let shared = shared.State(..state.shared, rows: rows)

        broadcast(state.clients, SetRows(rows))
        State(..state, shared: shared)
      }

      OnMessage(_, _, UpdateWaveform(waveform)) -> {
        let shared = shared.State(..state.shared, waveform: waveform)
        broadcast(state.clients, SetWaveform(waveform))

        State(..state, shared: shared)
      }

      OnMessage(_, _, UpdateDelayTime(delay_time)) -> {
        let shared = shared.State(..state.shared, delay_time: delay_time)
        broadcast(state.clients, SetDelayTime(delay_time))

        State(..state, shared: shared)
      }

      OnMessage(_, _, UpdateGain(gain)) -> {
        let shared = shared.State(..state.shared, gain: gain)
        broadcast(state.clients, SetGain(gain))

        State(..state, shared: shared)
      }

      Tick(self) ->
        case state.running {
          False -> state
          True -> {
            process.send_after(self, interval, Tick(self))

            let step = { state.shared.step + 1 } % state.shared.step_count
            let shared = shared.State(..state.shared, step: step)

            case step {
              0 -> broadcast(state.clients, SetState(shared))
              _ -> broadcast(state.clients, SetStep(step))
            }

            State(..state, shared: shared)
          }
        }
    }

    Continue(state)
  }

  // WEB SERVER ----------------------------------------------------------------

  fn serve(app: App) -> Result(Nil, glisten.StartError) {
    let port = 8080
    let handler = {
      use req <- mist_handler.with_func
      let path = request.path_segments(req)

      case req.method, path {
        // Attempt to upgrade the connection to a websocket.
        Get, ["ws"] -> upgrade_websocket(app)

        // Serve the `index.html` if someone just navigates to the root url.
        Get, [] -> {
          let res = serve_static_asset("index.html")
          mist_handler.Response(res)
        }

        // Attempt to serve a static asset resolve inside `build/app`.
        Get, _ -> {
          let res = serve_static_asset(req.path)
          mist_handler.Response(res)
        }
      }
    }

    // Serve the standard lustre web app here.
    mist.serve(port, handler)
  }

  fn serve_static_asset(path: String) -> Response(HttpResponseBody) {
    // This shouldn't really be a relative path like this. We're assuming way too
    // much about how and where things are executed, but yolo.
    let root = "./build/app"
    let path = string.concat([root, "/", string.replace(path, "..", "")])
    let file =
      path
      |> file.read_bits
      |> result.map(bit_builder.from_bit_string)

    let res = case file {
      Ok(bits) -> Response(200, [], BitBuilderBody(bits))
      Error(_) -> Response(404, [], BitBuilderBody(bit_builder.new()))
    }

    let is_js = string.ends_with(path, ".js")
    let is_css = string.ends_with(path, ".css")
    let is_html = string.ends_with(path, ".html")
    let is_svg = string.ends_with(path, ".svg")

    let set_content_type = fn(mime) {
      response.set_header(res, "content-type", mime)
    }

    case Nil {
      _ if is_js -> set_content_type("application/javascript")
      _ if is_css -> set_content_type("text/css")
      _ if is_html -> set_content_type("text/html")
      _ if is_svg -> set_content_type("image/svg+xml")
      _ -> set_content_type("text/plain")
    }
  }

  // WEB SOCKETS ---------------------------------------------------------------

  fn upgrade_websocket(app: App) -> HandlerResponse {
    let handler =
      WebsocketHandler(
        on_init: Some(on_ws_open(_, app)),
        on_close: Some(on_ws_close(_, app)),
        handler: fn(message, client) {
          case message {
            TextMessage(json) -> Ok(on_ws_message(client, json, app))
            _ -> Error(Nil)
          }
        },
      )

    mist_handler.Upgrade(handler)
  }

  fn on_ws_message(client: Client, json: String, app: App) -> Nil {
    case json.decode(json, to_backend.decoder) {
      Ok(message) -> actor.send(app, OnMessage(app, client, message))
      Error(error) -> {
        io.debug(error)
        Nil
      }
    }
  }

  fn on_ws_open(client: Client, app: App) -> Nil {
    actor.send(app, OnConnect(client))
  }

  fn on_ws_close(client: Client, app: App) -> Nil {
    actor.send(app, OnDisconnect(client))
  }
}
