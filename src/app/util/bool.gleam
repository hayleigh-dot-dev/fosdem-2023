pub fn when(cond: Bool, then a: a, else b: a) -> a {
  case cond {
    True -> a
    False -> b
  }
}
