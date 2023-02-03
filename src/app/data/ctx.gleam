if javascript {
  // IMPORTS ---------------------------------------------------------------------

  import gleam/io
  import gleam/list
  import lustre/cmd.{Cmd}
  import shared/audio/node.{Node}
  import shared/audio/param.{Param}
  import shared/audio.{CreatedPatch, DeletedPatch, Patches}

  // TYPES -----------------------------------------------------------------------

  pub external type AudioContext

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
    let prev = audio.to_graph(prev)
    let next = audio.to_graph(next)
    let patches = audio.diff(prev, next)

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
}
// CONVERSIONS -----------------------------------------------------------------
// UTILS -----------------------------------------------------------------------
