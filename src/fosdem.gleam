if erlang {
  // IMPORTS ---------------------------------------------------------------------

  import gleam/bit_builder
  import gleam/erlang/file
  import gleam/erlang/process.{Subject}
  import gleam/http.{Get}
  import gleam/http/request
  import gleam/http/response.{Response}
  import gleam/list
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

  // TYPES -----------------------------------------------------------------------

  type Msg {
    OnConnect(client: Client)
    OnDisconnect(client: Client)
    Tick(self: App)
  }

  type App =
    Subject(Msg)

  type Client =
    Subject(HandlerMessage)

  type State {
    State(clients: Set(Client))
  }

  //

  pub fn main() {
    assert Ok(app) = start()
    assert Ok(_) = serve(app)

    // Kick off the main regular update loop. This will broadcast the current
    // audio graph to all clients.
    process.send_after(app, 500, Tick(app))
    // Serve starts a new process so we want to keep the main process alive.
    process.sleep_forever()
  }

  //

  fn start() -> Result(App, StartError) {
    let init = State(set.new())

    use event, state <- actor.start(init)
    let state = case event {
      OnConnect(conn) -> on_connect(conn, state)
      OnDisconnect(conn) -> on_disconnect(conn, state)
      Tick(self) -> {
        list.each(
          set.to_list(state.clients),
          fn(client) { websocket.send(client, TextMessage("tick")) },
        )

        process.send_after(self, 500, Tick(self))
        state
      }
    }

    Continue(state)
  }

  fn on_connect(client: Client, state: State) -> State {
    State(set.insert(state.clients, client))
  }

  fn on_disconnect(client: Client, state: State) -> State {
    State(set.delete(state.clients, client))
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

    let set_content_type = fn(mime) {
      response.set_header(res, "content-type", mime)
    }

    case Nil {
      _ if is_js -> set_content_type("application/javascript")
      _ if is_css -> set_content_type("text/css")
      _ if is_html -> set_content_type("text/html")
      _ -> set_content_type("text/plain")
    }
  }

  //

  fn upgrade_websocket(app: App) -> HandlerResponse {
    let handler =
      WebsocketHandler(
        on_init: Some(on_ws_open(_, app)),
        on_close: Some(on_ws_close(_, app)),
        handler: fn(_, _) { Ok(Nil) },
      )

    mist_handler.Upgrade(handler)
  }

  fn on_ws_open(client: Client, app: App) -> Nil {
    actor.send(app, OnConnect(client))
  }

  fn on_ws_close(client: Client, app: App) -> Nil {
    actor.send(app, OnDisconnect(client))
  }
}
