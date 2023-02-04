if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import app/audio/node.{Key, Node, Ref}
  import app/audio/param.{Param, Property}
  import gleam/dynamic.{Dynamic}
  import gleam/int
  import gleam/list
  import gleam/map.{Map}
  import gleam/option.{None, Option}
  import gleam/order.{Gt, Lt}
  import gleam/string
  import lustre/cmd.{Cmd}

  // TYPES -----------------------------------------------------------------------

  pub external type AudioContext

  pub type Graph =
    List(Node)

  pub type Patches {
    Patches(created: List(CreatedPatch), deleted: List(DeletedPatch))
  }

  pub type CreatedPatch {
    CreatedNode(key: String, t: String, params: List(Param))
    CreatedParam(key: String, name: String, value: Float)
    CreatedProperty(key: String, name: String, value: Dynamic)
    Connect(from: String, to: String, param: Option(String))
  }

  pub type DeletedPatch {
    DeletedNode(key: String)
    DeletedParam(key: String, name: String)
    DeletedProperty(key: String, name: String)
    Disconnect(from: String, to: String, param: Option(String))
  }

  // EXTERNALS -------------------------------------------------------------------

  external fn create_from_patch(ctx: AudioContext, patch: CreatedPatch) -> Nil =
    "../../app.ffi.mjs" "create_from_patch"

  external fn delete_from_patch(ctx: AudioContext, patch: DeletedPatch) -> Nil =
    "../../app.ffi.mjs" "delete_from_patch"

  pub external fn resume(ctx: AudioContext) -> Nil =
    "../../app.ffi.mjs" "resume"

  pub external fn suspend(ctx: AudioContext) -> Nil =
    "../../app.ffi.mjs" "suspend"

  // MANIPULATIONS ---------------------------------------------------------------

  pub fn update(
    ctx: AudioContext,
    prev: List(Node),
    next: List(Node),
  ) -> Cmd(msg) {
    let prev = to_graph(prev)
    let next = to_graph(next)
    let patches = diff(prev, next)

    apply_patches(ctx, patches)
  }

  pub fn apply_patches(ctx: AudioContext, patches: Patches) -> Cmd(msg) {
    cmd.from(fn(_) {
      apply_deleted_patches(ctx, patches.deleted)
      apply_created_patches(ctx, patches.created)
    })
  }

  fn apply_created_patches(
    ctx: AudioContext,
    patches: List(CreatedPatch),
  ) -> Nil {
    use _, patch <- list.fold(patches, Nil)
    create_from_patch(ctx, patch)
  }

  fn apply_deleted_patches(
    ctx: AudioContext,
    patches: List(DeletedPatch),
  ) -> Nil {
    use _, patch <- list.fold(patches, Nil)
    delete_from_patch(ctx, patch)
  }

  // CONVERSIONS -----------------------------------------------------------------
  // UTILS -----------------------------------------------------------------------

  pub fn to_graph(nodes: List(Node)) -> Map(String, Node) {
    nodes
    |> list.index_fold(map.new(), flatten(""))
  }

  ///
  fn flatten(
    base: String,
  ) -> fn(Map(String, Node), Node, Int) -> Map(String, Node) {
    fn(acc, node, i) {
      case node {
        Ref(_, _) -> acc

        Key(key, t, params, connections) ->
          do_flatten(acc, key, t, params, connections)

        Node(t, params, connections) -> {
          let key = base <> "-" <> int.to_string(i)
          do_flatten(acc, key, t, params, connections)
        }
      }
    }
  }

  fn do_flatten(
    acc: Map(String, Node),
    key: String,
    t: String,
    params: List(Param),
    connections: List(Node),
  ) -> Map(String, Node) {
    let to_ref = fn(i, connection) {
      case connection {
        Ref(key, param) -> Ref(key, param)
        Key(key, _, _, _) -> Ref(key, None)
        Node(_, _, _) -> Ref(key <> "-" <> int.to_string(i), None)
      }
    }
    let node = Node(t, params, list.index_map(connections, to_ref))
    let acc = map.insert(acc, key, node)

    list.index_fold(connections, acc, flatten(key))
  }

  ///
  pub fn diff(prev: Map(String, Node), curr: Map(String, Node)) -> Patches {
    Patches(created: [], deleted: [])
    |> diff_created(curr, prev)
    |> diff_deleted(prev, curr)
    |> sort_patches
  }

  fn diff_created(
    patches: Patches,
    curr: Map(String, Node),
    prev: Map(String, Node),
  ) -> Patches {
    use patches, key, curr_node <- map.fold(curr, patches)
    // We should've run `flatten` before we start diffing things, and at that
    // point all nodes in the graph are converted to `Node` variants so this is
    // safe to assert.
    assert Node(curr_t, curr_params, curr_connections) = curr_node
    case map.get(prev, key) {
      Ok(Node(prev_t, _, _) as prev_node) if curr_t == prev_t ->
        diff_node(patches, key, prev_node, curr_node)

      Ok(_) -> {
        let new_node = CreatedNode(key, curr_t, curr_params)
        let connections =
          list.map(
            curr_connections,
            fn(connection) {
              assert Ref(to, param) = connection
              Connect(key, to, param)
            },
          )
        let created = list.append([new_node, ..connections], patches.created)
        let deleted = [DeletedNode(key), ..patches.deleted]

        Patches(created, deleted)
      }

      Error(_) -> {
        let new_node = CreatedNode(key, curr_t, curr_params)
        let connections =
          list.map(
            curr_connections,
            fn(connection) {
              assert Ref(to, param) = connection
              Connect(key, to, param)
            },
          )
        let created = list.append([new_node, ..connections], patches.created)

        Patches(..patches, created: created)
      }
    }
  }

  fn diff_node(
    patches: Patches,
    key: String,
    prev_node: Node,
    curr_node: Node,
  ) -> Patches {
    assert Node(_, prev_params, prev_connections) = prev_node
    assert Node(_, curr_params, curr_connections) = curr_node

    patches
    |> diff_params(key, prev_params, curr_params)
    |> diff_connections(key, prev_connections, curr_connections)
  }

  fn diff_params(
    patches: Patches,
    key: String,
    prev_params: List(Param),
    curr_params: List(Param),
  ) -> Patches {
    let #(prev_params, prev_props) = {
      use acc, param <- list.fold(prev_params, #(map.new(), map.new()))
      case param {
        Param(name, value) -> #(map.insert(acc.0, name, value), acc.1)
        Property(name, value) -> #(acc.0, map.insert(acc.1, name, value))
        _ -> acc
      }
    }
    let #(curr_params, curr_props) = {
      use acc, param <- list.fold(curr_params, #(map.new(), map.new()))
      case param {
        Param(name, value) -> #(map.insert(acc.0, name, value), acc.1)
        Property(name, value) -> #(acc.0, map.insert(acc.1, name, value))
        _ -> acc
      }
    }

    patches
    |> fn(patches) {
      use patches, name, curr_value <- map.fold(curr_params, patches)
      case map.get(prev_params, name) {
        Ok(prev_value) if curr_value == prev_value -> patches
        _ ->
          Patches(
            ..patches,
            created: [CreatedParam(key, name, curr_value), ..patches.created],
          )
      }
    }
    |> fn(patches) {
      use patches, name, _ <- map.fold(prev_params, patches)
      case map.has_key(curr_params, name) {
        True -> patches
        False ->
          Patches(
            ..patches,
            deleted: [DeletedParam(key, name), ..patches.deleted],
          )
      }
    }
    |> fn(patches) {
      use patches, name, curr_value <- map.fold(curr_props, patches)
      case map.get(prev_props, name) {
        Ok(prev_value) if curr_value == prev_value -> patches
        _ ->
          Patches(
            ..patches,
            created: [CreatedProperty(key, name, curr_value), ..patches.created],
          )
      }
    }
    |> fn(patches) {
      use patches, name, _ <- map.fold(prev_props, patches)
      case map.has_key(curr_props, name) {
        True -> patches
        False ->
          Patches(
            ..patches,
            deleted: [DeletedProperty(key, name), ..patches.deleted],
          )
      }
    }
  }

  fn diff_connections(
    patches: Patches,
    key: String,
    prev_connections: List(Node),
    curr_connections: List(Node),
  ) -> Patches {
    patches
    |> fn(patches) {
      use patches, connection <- list.fold(prev_connections, patches)
      case list.contains(curr_connections, connection) {
        True -> patches
        False -> {
          assert Ref(to, param) = connection
          Patches(
            ..patches,
            deleted: [Disconnect(key, to, param), ..patches.deleted],
          )
        }
      }
    }
    |> fn(patches) {
      use patches, connection <- list.fold(curr_connections, patches)
      case list.contains(prev_connections, connection) {
        True -> patches
        False -> {
          assert Ref(to, param) = connection
          Patches(
            ..patches,
            created: [Connect(key, to, param), ..patches.created],
          )
        }
      }
    }
  }

  fn diff_deleted(
    patches: Patches,
    prev: Map(String, Node),
    curr: Map(String, Node),
  ) -> Patches {
    use patches, key, _ <- map.fold(prev, patches)
    case map.has_key(curr, key) {
      True -> patches
      False ->
        Patches(..patches, deleted: [DeletedNode(key), ..patches.deleted])
    }
  }

  fn sort_patches(patches: Patches) -> Patches {
    let created =
      list.sort(
        patches.created,
        fn(a, b) {
          case a, b {
            CreatedNode(a, _, _), CreatedNode(b, _, _) -> string.compare(a, b)
            CreatedNode(_, _, _), CreatedParam(_, _, _) -> Lt
            CreatedNode(_, _, _), CreatedProperty(_, _, _) -> Lt
            CreatedNode(_, _, _), Connect(_, _, _) -> Lt

            CreatedParam(_, _, _), CreatedNode(_, _, _) -> Gt
            CreatedParam(a, _, _), CreatedParam(b, _, _) -> string.compare(a, b)
            CreatedParam(a, _, _), CreatedProperty(b, _, _) ->
              string.compare(a, b)
            CreatedParam(_, _, _), Connect(_, _, _) -> Lt

            CreatedProperty(_, _, _), CreatedNode(_, _, _) -> Gt
            CreatedProperty(a, _, _), CreatedParam(b, _, _) ->
              string.compare(a, b)
            CreatedProperty(a, _, _), CreatedProperty(b, _, _) ->
              string.compare(a, b)
            CreatedProperty(_, _, _), Connect(_, _, _) -> Lt

            Connect(_, _, _), CreatedNode(_, _, _) -> Gt
            Connect(_, _, _), CreatedParam(_, _, _) -> Gt
            Connect(_, _, _), CreatedProperty(_, _, _) -> Gt
            Connect(a, _, _), Connect(b, _, _) -> string.compare(a, b)
          }
        },
      )

    Patches(..patches, created: created)
  }
}
