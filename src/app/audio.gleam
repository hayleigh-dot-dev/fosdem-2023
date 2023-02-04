if javascript {
  // IMPORTS -------------------------------------------------------------------

  import lustre/cmd.{Cmd}
  import app/audio/context.{AudioContext}
  import app/util/bool.{when}
  import gleam/list
  import gleam/map
  import app/audio/node.{Node, amp, dac, del, key, lpf, osc, ref}
  import app/audio/param.{delay_time, freq, gain, waveform}
  import shared/state.{
    DelayTime, Long, Row, Sawtooth, Short, Sine, Square, State, Triangle,
    Waveform,
  }

  ///
  ///
  pub fn render(
    ctx: AudioContext,
    state: State,
    gain: Float,
    prev: List(Node),
  ) -> #(List(Node), Cmd(action)) {
    let nodes = list.map(state.rows, render_voice(state.step, state.waveform))
    let master = render_master(state.delay_time, gain)
    let next = list.append(nodes, master)

    #(next, context.update(ctx, prev, next))
  }

  fn render_voice(step: Int, wave: Waveform) -> fn(Row) -> Node {
    let wave = case wave {
      Sine -> "sine"
      Triangle -> "triangle"
      Sawtooth -> "sawtooth"
      Square -> "square"
    }

    fn(row: Row) {
      assert Ok(is_active) = map.get(row.steps, step)
      let vol = when(is_active, then: 0.2, else: 0.0)

      osc(
        [freq(row.note), waveform(wave)],
        [amp([gain(vol)], [ref("delay"), ref("master")])],
      )
    }
  }

  fn render_master(delay: DelayTime, vol: Float) -> List(Node) {
    let #(time, amount) = case delay {
      Short -> #(0.2, 0.3)
      Long -> #(0.75, 0.5)
    }

    let out = amp([gain(vol)], [dac])
    let del =
      del(
        [delay_time(time)],
        [
          amp(
            [gain(amount)],
            [lpf([freq(400.0)], [ref("delay"), ref("master")])],
          ),
        ],
      )

    [key("master", out), key("delay", del)]
  }
}
