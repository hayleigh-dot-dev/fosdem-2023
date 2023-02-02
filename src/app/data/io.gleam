if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import lustre/cmd.{Cmd}

  // TYPES -----------------------------------------------------------------------

  pub type IO(state, action) =
    #(state, Cmd(action))

  // CONSTANTS -------------------------------------------------------------------
  // CONSTRUCTORS ----------------------------------------------------------------

  pub fn pure(state: state) -> IO(state, action) {
    #(state, cmd.none())
  }

  // QUERIES ---------------------------------------------------------------------
  // MANIPULATIONS ---------------------------------------------------------------

  pub fn then(io: IO(a, action), f: fn(a) -> IO(b, action)) -> IO(b, action) {
    let #(state, cmd) = io
    let #(next_state, next_cmds) = f(state)

    #(next_state, cmd.batch([cmd, next_cmds]))
  }

  pub fn map(io: IO(a, action), f: fn(a) -> b) -> IO(b, action) {
    use state <- then(io)

    pure(f(state))
  }

  pub fn with(io: IO(state, action), cmd: Cmd(action)) -> IO(state, action) {
    let #(state, cmds) = io

    #(state, cmd.batch([cmd, cmds]))
  }
}
// CONVERSIONS -----------------------------------------------------------------
// UTILS -----------------------------------------------------------------------
