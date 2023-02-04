if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import app/data/ctx.{AudioContext}
  import app/data/io.{IO}
  import gleam/int
  import gleam/io as console
  import gleam/json
  import gleam/list
  import gleam/map.{Map}
  import gleam/option.{None, Option, Some}
  import lustre
  import lustre_websocket.{OnClose,
    OnMessage, OnOpen, WebSocket, WebSocketEvent} as ws
  import lustre/attribute.{Attribute}
  import lustre/cmd
  import lustre/element.{Element}
  import lustre/event.{dispatch}
  import app/audio
  import app/audio/node.{Node}
  import app/audio/param.{param, prop}
  import shared/state as shared
  import shared/to_backend.{
    AddStep, Play, RemoveStep, Stop, ToBackend, UpdateDelayAmount,
    UpdateDelayTime, UpdateGain, UpdateStep, UpdateStepCount, UpdateWaveform,
  }
  import shared/to_frontend.{
    SetDelayAmount, SetDelayTime, SetGain, SetRows, SetState, SetStep,
    SetStepCount, SetWaveform, ToFrontend,
  }

  // MAIN ------------------------------------------------------------------------

  pub fn main(ctx: AudioContext) {
    assert Ok(dispatch) =
      init(ctx)
      |> lustre.application(update, render)
      |> lustre.start("#app")

    dispatch
  }

  // STATE -----------------------------------------------------------------------

  type State {
    State(
      ws: Option(WebSocket),
      ctx: AudioContext,
      nodes: audio.Graph,
      gain: Float,
      // `shared` here refers to the fact that all this state is shared and syncd
      // up with the backend and all other connected clients.
      shared: shared.State,
    )
  }

  fn init(ctx: AudioContext) -> IO(State, Action) {
    let state = State(None, ctx, [], 0.0, shared.init())
    let cmd = cmd.batch([ws.init("/ws", WebSocket), ctx.update(ctx, [], [])])

    #(state, cmd)
  }

  // UPDATE ----------------------------------------------------------------------

  pub type Action {
    WebSocket(WebSocketEvent)
    Resume
    Suspend
    Send(ToBackend)
  }

  fn update(state: State, action: Action) -> IO(State, Action) {
    case action {
      WebSocket(OnOpen(conn)) -> io.pure(State(..state, ws: Some(conn)))
      WebSocket(OnClose(_)) -> io.pure(State(..state, ws: None))
      WebSocket(OnMessage(msg)) ->
        on_message(state, msg)
        |> update_audio

      Send(message) ->
        case state.ws {
          Some(ws) -> {
            let json = to_backend.encode(message)
            let text = json.to_string(json)

            #(state, ws.send(ws, text))
          }
          None -> io.pure(state)
        }

      Resume -> {
        ctx.resume(state.ctx)
        io.pure(State(..state, gain: 1.0))
      }

      Suspend -> io.pure(State(..state, gain: 0.0))
    }
  }

  fn update_audio(state: State) -> IO(State, Action) {
    let shared.State(rows, step, _, waveform, delay_time, delay_amount, _) =
      state.shared
    let prev = state.nodes
    let next =
      list.map(rows, voice(step, waveform))
      |> list.append(output(delay_time, delay_amount, state.gain))

    io.pure(State(..state, nodes: next))
    |> io.with(ctx.update(state.ctx, prev, next))
  }

  fn voice(step: Int, waveform: String) -> fn(shared.Row) -> Node {
    fn(row) {
      let shared.Row(_, note, steps) = row
      assert Ok(is_active) = map.get(steps, step)
      let gain = case is_active {
        True -> 0.2
        False -> 0.0
      }

      console.debug(gain)

      node.osc(
        [param.freq(note), param.waveform(waveform)],
        [node.amp([param.gain(gain)], [node.ref("delay"), node.ref("master")])],
      )
    }
  }

  fn output(delay_time: Float, delay_amount: Float, gain: Float) -> List(Node) {
    let out = node.key("master", node.amp([param.gain(gain)], [node.dac]))
    let del =
      node.key(
        "delay",
        node.del(
          [param.delay_time(delay_time)],
          [
            node.amp(
              [param.gain(delay_amount)],
              [
                node.lpf(
                  [param.freq(400.0)],
                  [node.ref("delay"), node.ref("master")],
                ),
              ],
            ),
          ],
        ),
      )

    [del, out]
  }

  fn on_message(state: State, message: String) -> State {
    let shared = state.shared

    case json.decode(message, to_frontend.decoder) {
      Ok(SetState(shared)) -> State(..state, shared: shared)
      Ok(SetRows(rows)) ->
        State(..state, shared: shared.State(..state.shared, rows: rows))
      Ok(SetStepCount(step_count)) ->
        State(
          ..state,
          shared: shared.State(..state.shared, step_count: step_count),
        )
      Ok(SetStep(step)) ->
        State(..state, shared: shared.State(..state.shared, step: step))
      Ok(SetWaveform(waveform)) ->
        State(..state, shared: shared.State(..state.shared, waveform: waveform))
      Ok(SetGain(gain)) ->
        State(..state, shared: shared.State(..state.shared, gain: gain))
      Ok(SetDelayTime(delay_time)) ->
        State(
          ..state,
          shared: shared.State(..state.shared, delay_time: delay_time),
        )
      Ok(SetDelayAmount(delay_amount)) ->
        State(
          ..state,
          shared: shared.State(..state.shared, delay_amount: delay_amount),
        )
      Ok(SetGain(gain)) ->
        State(..state, shared: shared.State(..state.shared, gain: gain))

      Error(_) -> state
    }
  }

  // RENDER ----------------------------------------------------------------------

  fn render(state: State) -> Element(Action) {
    element.main(
      [
        attribute.class(
          "flex flex-col font-mono mx-auto py-6 px-4 gap-6 w-screen",
        ),
      ],
      [
        //
        element.section(
          [],
          [
            element.h1(
              [attribute.class("text-2xl font-bold text-gleam-white")],
              [element.text("Hello, FOSDEM")],
            ),
          ],
        ),
        //
        element.section(
          [attribute.class("flex flex-row gap-6")],
          [
            element.div(
              [attribute.class("flex flex-row gap-1")],
              [
                render_button(
                  "play",
                  "w-24 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [event.on_click(dispatch(Send(Play)))],
                ),
                render_button(
                  "stop",
                  "w-24 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [event.on_click(dispatch(Send(Stop)))],
                ),
                case state.gain {
                  1.0 ->
                    render_button(
                      "mute",
                      "w-24 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                      [event.on_click(dispatch(Suspend))],
                    )
                  _ ->
                    render_button(
                      "unmute",
                      "w-24 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                      [event.on_click(dispatch(Resume))],
                    )
                },
              ],
            ),
            element.div(
              [attribute.class("flex flex-row gap-1")],
              [
                render_button(
                  "add step",
                  "bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [event.on_click(dispatch(Send(AddStep)))],
                ),
                render_button(
                  "remove step",
                  "bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [event.on_click(dispatch(Send(RemoveStep)))],
                ),
                render_button(
                  "reset steps",
                  "bg-orange-600 hover:bg-orange-800",
                  [],
                ),
              ],
            ),
          ],
        ),
        //
        element.section(
          [],
          [
            element.div(
              [attribute.class("text-gleam-white")],
              [element.text(int.to_string(state.shared.step))],
            ),
            render_sequencer(state.shared.rows, state.shared.step),
          ],
        ),
        //
        element.section(
          [],
          [
            element.h2(
              [attribute.class("text-lg font-bold text-gleam-white")],
              [element.text("Waveform:")],
            ),
            element.div(
              [attribute.class("flex flex-row gap-1")],
              [
                render_image_button(
                  "/assets/sine.svg",
                  "flex justify-center items-center w-20 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [],
                ),
                render_image_button(
                  "/assets/triangle.svg",
                  "flex justify-center items-center w-20 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [],
                ),
                render_image_button(
                  "/assets/square.svg",
                  "flex justify-center items-center w-20 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [],
                ),
                render_image_button(
                  "/assets/saw.svg",
                  "flex justify-center items-center w-20 bg-unnamed-blue-700 hover:bg-unnamed-blue-800",
                  [],
                ),
              ],
            ),
          ],
        ),
        //
        element.section(
          [],
          [
            element.h2(
              [attribute.class("text-lg font-bold text-gleam-white")],
              [element.text("Delay Time:")],
            ),
            element.div(
              [attribute.class("flex flex-row gap-1")],
              [
                render_button(
                  "short",
                  "bg-unnamed-blue-700 hover:bg-unnamed-blue-800 w-20",
                  [],
                ),
                render_button(
                  "long",
                  "bg-unnamed-blue-700 hover:bg-unnamed-blue-800 w-20",
                  [],
                ),
              ],
            ),
          ],
        ),
      ],
    )
  }

  fn render_button(label, bg, attrs) -> Element(Action) {
    element.button(
      [
        attribute.class(
          "text-white " <> bg <> " p-2 mr-4 my-2 rounded-md transition-color",
        ),
        ..attrs
      ],
      [element.text(label)],
    )
  }

  fn render_image_button(src, bg, attrs) -> Element(Action) {
    element.button(
      [
        attribute.class(
          "text-white " <> bg <> " p-2 mr-4 my-2 rounded-md transition-color",
        ),
        ..attrs
      ],
      [element.img([attribute.src(src), attribute.class("w-10")])],
    )
  }

  fn render_sequencer(rows, active_column) -> Element(Action) {
    element.div(
      [
        attribute.class(
          "overflow-x border-4 border-[#828282] rounded-md my-4 w-auto",
        ),
      ],
      list.map(rows, render_row(active_column)),
    )
  }

  fn render_row(active_column) -> fn(shared.Row) -> Element(Action) {
    fn(row) {
      let shared.Row(name, note, steps) = row
      element.div(
        [attribute.class("flex flex-row items-center")],
        [
          element.span(
            [attribute.class("pl-2 pr-6 font-bold text-gleam-white")],
            [element.text(name)],
          ),
          ..list.map(map.to_list(steps), render_step(name, active_column))
        ],
      )
    }
  }

  fn render_step(name, active_column) -> fn(#(Int, Bool)) -> Element(Action) {
    fn(step) {
      let #(idx, is_active) = step

      // let bg = case is_active {
      //   True -> "bg-faff-400"
      //   False -> "bg-[#595959]"
      // }
      // let col_bg = case idx == active_column {
      //   True -> "bg-faff-50"
      //   False -> "bg-transparent"
      // }
      let bg = case idx == active_column {
        True ->
          case is_active {
            True -> "bg-faff-200 animate-bloop"

            False -> "bg-charcoal-500 scale-[0.8]"
          }

        False ->
          case is_active {
            True -> "bg-faff-300"

            False -> "bg-charcoal-600 scale-[0.8]"
          }
      }

      element.div(
        [attribute.class("p-2 ")],
        [
          element.button(
            [
              event.on_click(dispatch(Send(UpdateStep(#(name, idx, !is_active))))),
              attribute.class(
                "text-white " <> bg <> " hover:bg-faff-100 px-6 py-6 rounded-lg shadow-sm transition-all",
              ),
            ],
            [],
          ),
        ],
      )
    }
  }
}
