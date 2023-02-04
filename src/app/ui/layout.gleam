if javascript {
  // IMPORTS -------------------------------------------------------------------
  import lustre/element.{Element}
  import lustre/attribute.{class}

  // RENDER --------------------------------------------------------------------

  ///
  ///
  pub fn row(children) -> Element(msg) {
    element.div([class("flex flex-row gap-1")], children)
  }

  ///
  ///
  pub fn styled_row(classes, children) -> Element(msg) {
    element.div([class("flex flex-row gap-1 " <> classes)], children)
  }

  ///
  ///
  pub fn stack(children) -> Element(msg) {
    element.div([class("flex flex-col gap-1")], children)
  }

  ///
  ///
  pub fn styled_stack(classes, children) -> Element(msg) {
    element.div([class("flex flex-col gap-1 " <> classes)], children)
  }
}
