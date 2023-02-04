// CONSTRUCTORS ----------------------------------------------------------------

pub fn with(a: a, b: b) -> #(a, b) {
  #(a, b)
}

// QUERIES ---------------------------------------------------------------------

pub fn fst(pair: #(a, b)) -> a {
  pair.0
}

pub fn snd(pair: #(a, b)) -> b {
  pair.1
}

// MANIPULATIONS ---------------------------------------------------------------

pub fn map_fst(pair: #(a, b), f: fn(a) -> c) -> #(c, b) {
  #(f(pair.0), pair.1)
}

pub fn map_snd(pair: #(a, b), f: fn(b) -> c) -> #(a, c) {
  #(pair.0, f(pair.1))
}
