if javascript {
  // IMPORTS -------------------------------------------------------------------
  import lustre/element.{Element}
  import lustre/attribute.{class, src}
  import lustre/event.{on_click}

  // RENDER --------------------------------------------------------------------

  ///
  ///
  pub fn text(label, colour, msg) -> Element(msg) {
    let classes = "text-gleam-black p-2 mr-4 my-2 rounded-md transition-color"

    element.button(
      [
        class(classes <> " " <> colour),
        on_click(fn(dispatch) { dispatch(msg) }),
      ],
      [element.text(label)],
    )
  }

  ///
  ///
  pub fn img(url, colour, msg) -> Element(msg) {
    let classes = "text-white p-2 mr-4 my-2 rounded-md transition-color"

    element.button(
      [
        class(classes <> " " <> colour),
        on_click(fn(dispatch) { dispatch(msg) }),
      ],
      [element.img([src(url), class("h-6 w-6")])],
    )
  }

  ///
  ///
  pub fn box(colour, msg) -> Element(msg) {
    let classes = "p-6 rounded-lg shadow-sm transition-all"

    element.button(
      [
        class(classes <> " " <> colour),
        on_click(fn(dispatch) { dispatch(msg) }),
      ],
      [],
    )
  }
}
