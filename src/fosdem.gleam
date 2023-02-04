if erlang {
  // IMPORTS ---------------------------------------------------------------------

  import gleam/bit_builder
  import gleam/dynamic
  import gleam/erlang/file
  import gleam/erlang/process.{Subject}
  import gleam/http.{Get}
  import gleam/http/request
  import gleam/http/response.{Response}
  import gleam/int
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
    AddStep, Play, RemoveStep, Stop, ToBackend, UpdateDelayAmount,
    UpdateDelayTime, UpdateGain, UpdateStep, UpdateStepCount, UpdateWaveform,
  }
  import shared/to_frontend.{
    SetDelayAmount, SetDelayTime, SetGain, SetRows, SetState, SetStep,
    SetStepCount, SetWaveform, ToFrontend,
  }

  // TYPES -----------------------------------------------------------------------

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

  //

  pub fn main() {
    assert Ok(app) = start()
    assert Ok(_) = serve(app)

    // Serve starts a new process so we want to keep the main process alive.
    process.sleep_forever()
  }

  //

  fn start() -> Result(App, StartError) {
    let init = State(set.new(), shared.init(), False)

    use event, state <- actor.start(init)
    let state = case event {
      OnConnect(client) -> on_connect(client, state)
      OnDisconnect(client) -> on_disconnect(client, state)
      OnMessage(self, _, Play) -> on_play(self, state)
      OnMessage(_, _, Stop) -> on_stop(state)
      OnMessage(_, _, UpdateStep(#(name, idx, on))) ->
        on_update_step(state, name, idx, on)
      OnMessage(_, _, UpdateStepCount(step_count)) ->
        on_update_step_count(state, step_count)
      OnMessage(_, _, AddStep) -> on_add_step(state)
      OnMessage(_, _, RemoveStep) -> on_remove_step(state)

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

      OnMessage(_, _, UpdateDelayAmount(delay_amount)) -> {
        let shared = shared.State(..state.shared, delay_amount: delay_amount)
        broadcast(state.clients, SetDelayAmount(delay_amount))

        State(..state, shared: shared)
      }

      OnMessage(_, _, UpdateGain(gain)) -> {
        let shared = shared.State(..state.shared, gain: gain)
        broadcast(state.clients, SetGain(gain))

        State(..state, shared: shared)
      }

      Tick(self) -> {
        case state.running {
          True -> process.send_after(self, 400, Tick(self))
          False -> dynamic.unsafe_coerce(dynamic.from(Nil))
        }

        let step = { state.shared.step + 1 } % state.shared.step_count
        let shared = shared.State(..state.shared, step: step)

        case step {
          0 -> broadcast(state.clients, SetState(shared))
          _ -> broadcast(state.clients, SetStep(step))
        }

        State(..state, shared: shared)
      }
    }

    Continue(state)
  }

  fn on_play(self: App, state: State) -> State {
    process.send_after(self, 400, Tick(self))
    State(..state, running: True)
  }

  fn on_stop(state: State) -> State {
    State(..state, running: False)
  }

  fn on_update_step(state: State, name: String, idx: Int, on: Bool) -> State {
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

  fn on_update_step_count(state: State, step_count: Int) -> State {
    let shared = shared.State(..state.shared, step_count: step_count)
    broadcast(state.clients, SetStepCount(step_count))

    State(..state, shared: shared)
  }

  fn on_add_step(state: State) -> State {
    let step_count = state.shared.step_count + 1
    let rows =
      list.map(
        state.shared.rows,
        fn(row) {
          shared.Row(..row, steps: map.insert(row.steps, step_count - 1, False))
        },
      )
    let shared =
      shared.State(..state.shared, step_count: step_count, rows: rows)
    broadcast(state.clients, SetStepCount(step_count))

    State(..state, shared: shared)
  }

  fn on_remove_step(state: State) -> State {
    let step_count = int.max(state.shared.step_count - 1, 1)
    let rows =
      list.map(
        state.shared.rows,
        fn(row) {
          case step_count {
            1 -> row
            _ ->
              shared.Row(
                ..row,
                steps: map.insert(row.steps, step_count - 1, False),
              )
          }
        },
      )

    let shared =
      shared.State(..state.shared, step_count: step_count, rows: rows)
    broadcast(state.clients, SetStepCount(step_count))

    State(..state, shared: shared)
  }

  // Broadcast a message to all connected clients.
  fn broadcast(clients: Set(Client), message: ToFrontend) -> Nil {
    use _, client <- set.fold(clients, Nil)
    let json = to_frontend.encode(message)
    let text = TextMessage(json.to_string(json))
    websocket.send(client, text)
  }

  fn on_connect(client: Client, state: State) -> State {
    let message = SetState(state.shared)
    let json = to_frontend.encode(message)
    let text = TextMessage(json.to_string(json))

    websocket.send(client, text)
    State(..state, clients: set.insert(state.clients, client))
  }

  fn on_disconnect(client: Client, state: State) -> State {
    State(..state, clients: set.delete(state.clients, client))
  }

  //

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

  //

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
