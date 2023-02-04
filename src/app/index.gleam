if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import app/audio
  import app/audio/context.{AudioContext}
  import app/audio/node.{Node}
  import app/ui/button
  import app/ui/layout
  import app/util/bool.{when}
  import app/util/pair
  import gleam/io
  import gleam/json
  import gleam/list
  import gleam/map
  import gleam/option.{None, Option, Some}
  import lustre
  import lustre_websocket.{OnClose,
    OnMessage, OnOpen, WebSocket, WebSocketEvent} as ws
  import lustre/attribute
  import lustre/cmd.{Cmd}
  import lustre/element.{Element}
  import shared/state.{
    DelayTime, Long, Sawtooth, Short, Sine, Square, Triangle, Waveform,
  } as shared
  import shared/to_backend.{
    Play, Stop, ToBackend, UpdateDelayTime, UpdateStep, UpdateWaveform,
  }
  import shared/to_frontend.{
    SetDelayTime, SetGain, SetRows, SetState, SetStep, SetStepCount, SetWaveform,
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
      nodes: List(Node),
      gain: Float,
      // `shared` here refers to the fact that all this state is shared and syncd
      // up with the backend and all other connected clients.
      shared: shared.State,
    )
  }

  fn init(ctx: AudioContext) -> #(State, Cmd(Msg)) {
    let state = State(None, ctx, [], 0.0, shared.init())
    let cmd =
      cmd.batch([ws.init("/ws", WebSocket), context.update(ctx, [], [])])

    #(state, cmd)
  }

  // UPDATE ----------------------------------------------------------------------

  pub type Msg {
    WebSocket(WebSocketEvent)
    Resume
    Suspend
    Send(ToBackend)
  }

  fn update(state: State, msg: Msg) -> #(State, Cmd(Msg)) {
    let pure = pair.with(_, cmd.none())

    io.debug(state)
    case io.debug(msg) {
      WebSocket(OnOpen(conn)) -> pure(State(..state, ws: Some(conn)))
      WebSocket(OnClose(_)) -> pure(State(..state, ws: None))
      WebSocket(OnMessage(msg)) -> {
        let state = on_message(state, msg)

        audio.render(state.ctx, state.shared, state.gain, state.nodes)
        |> pair.map_fst(fn(nodes) { State(..state, nodes: nodes) })
      }

      Send(message) ->
        case state.ws {
          Some(ws) -> {
            let json = to_backend.encode(message)
            let text = json.to_string(json)

            io.debug(text)

            state
            |> pair.with(ws.send(ws, text))
          }

          None -> pure(state)
        }

      Resume -> {
        context.resume(state.ctx)
        pure(State(..state, gain: 1.0))
      }

      Suspend -> pure(State(..state, gain: 0.0))
    }
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
      Ok(SetGain(gain)) ->
        State(..state, shared: shared.State(..state.shared, gain: gain))

      Error(_) -> state
    }
  }

  // RENDER ----------------------------------------------------------------------

  fn render(state: State) -> Element(Msg) {
    let classes = "flex flex-col font-mono mx-auto py-6 px-4 gap-6 max-w-4xl"
    let sections = [
      render_greeting(),
      render_controls(state.gain),
      render_sequencer(state.shared.rows, state.shared.step),
      render_sound_controls(state.shared.waveform, state.shared.delay_time),
    ]

    element.main([attribute.class(classes)], sections)
  }

  // RENDER: GREETING ----------------------------------------------------------

  fn render_greeting() -> Element(Msg) {
    element.section(
      [],
      [
        element.h1(
          [attribute.class("text-2xl font-bold")],
          [element.text("Hello, FOSDEM")],
        ),
      ],
    )
  }

  // RENDER: SEQUENCE CONTROLS -------------------------------------------------

  fn render_controls(gain: Float) -> Element(Msg) {
    let play =
      button.text(
        "play",
        "bg-unnamed-blue-200 hover:bg-unnamed-blue-400",
        Send(Play),
      )

    let stop =
      button.text(
        "stop",
        "bg-unnamed-blue-200 hover:bg-unnamed-blue-400",
        Send(Stop),
      )

    let mute =
      button.text(
        when(gain == 1.0, "mute", "unmute"),
        "bg-unnamed-blue-200 hover:bg-unnamed-blue-400",
        when(gain == 1.0, Suspend, Resume),
      )

    element.section([], [layout.row([play, stop, mute])])
  }

  // RENDER: SEQUENCER ---------------------------------------------------------

  fn render_sequencer(rows, active_column) -> Element(Msg) {
    element.section(
      [
        attribute.class(
          "overflow-x-scroll border-4 border-[#828282] rounded-md my-4",
        ),
      ],
      list.map(rows, render_row(active_column)),
    )
  }

  fn render_row(active_column) -> fn(shared.Row) -> Element(Msg) {
    fn(row) {
      element.div(
        [attribute.class("flex flex-row items-center")],
        [
          element.span(
            [attribute.class("pl-2 pr-6 font-bold")],
            [element.text(name)],
          ),
          ..list.map(
            map.to_list(row.steps),
            render_step(row.name, active_column),
          )
        ],
      )
    }
  }

  fn render_step(name, active_column) -> fn(#(Int, Bool)) -> Element(Msg) {
    fn(step) {
      let #(idx, is_active) = step
      let msg = Send(UpdateStep(#(name, idx, !is_active)))
      let bg = case idx == active_column, is_active {
        True, True -> "bg-faff-200 animate-bloop"
        True, False -> "bg-charcoal-200 scale-[0.8]"
        False, True -> "bg-faff-300"
        False, False -> "bg-charcoal-700 scale-[0.8]"
      }

      element.div(
        [attribute.class("p-2")],
        [button.box(bg <> " hover:bg-faff-100", msg)],
      )
    }
  }

  // RENDER: SOUND CONTROLS ----------------------------------------------------

  fn render_sound_controls(wave: Waveform, delay: DelayTime) -> Element(Msg) {
    element.section(
      [attribute.class("flex flex-row justify-between")],
      [render_waveform_controls(wave), render_delay_controls(delay)],
    )
  }

  fn render_waveform_controls(selected: Waveform) -> Element(Msg) {
    layout.stack([
      element.h2(
        [attribute.class("text-lg font-bold")],
        [element.text("Waveform:")],
      ),
      layout.row([
        button.img(
          "/assets/sine.svg",
          when(selected == Sine, "bg-blue-600", "bg-blue-200") <> " flex justify-center items-center w-20 hover:bg-blue-400",
          Send(UpdateWaveform(Sine)),
        ),
        button.img(
          "/assets/triangle.svg",
          when(selected == Triangle, "bg-green-600", "bg-green-200") <> " flex justify-center items-center w-20 hover:bg-green-400",
          Send(UpdateWaveform(Triangle)),
        ),
        button.img(
          "/assets/saw.svg",
          when(selected == Sawtooth, "bg-pink-600", "bg-pink-200") <> " flex justify-center items-center w-20 hover:bg-pink-400",
          Send(UpdateWaveform(Sawtooth)),
        ),
        button.img(
          "/assets/square.svg",
          when(selected == Square, "bg-yellow-600", "bg-yellow-200") <> " flex justify-center items-center w-20 hover:bg-yellow-400",
          Send(UpdateWaveform(Square)),
        ),
      ]),
    ])
  }

  fn render_delay_controls(selected: DelayTime) -> Element(Msg) {
    layout.stack([
      element.h2(
        [attribute.class("text-lg font-bold")],
        [element.text("Delay Time:")],
      ),
      layout.row([
        button.text(
          "short",
          when(selected == Short, "bg-purple-600", "bg-purple-200") <> " hover:bg-purple-400",
          Send(UpdateDelayTime(Short)),
        ),
        button.text(
          "long",
          when(selected == Long, "bg-purple-600", "bg-purple-200") <> " hover:bg-purple-400",
          Send(UpdateDelayTime(Long)),
        ),
      ]),
    ])
  }
}
