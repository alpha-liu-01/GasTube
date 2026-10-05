#!/usr/bin/env python3
"""Enable partial repaint in a Flutter 3.47.1 engine tree.

The Linux GTK compositor does not render into the window surface. The
offscreen frame therefore never advertises partial repaint, the rasterizer
forces a full repaint because an external view embedder is set, and that
embedder clears the reused compositor FBO every frame. Together those three
choices discard the damage the rasterizer already knows how to compute.

This patch is applied only to the arm64 library built for Ubuntu Touch.
"""

import pathlib
import sys

IMPELLER_OLD = """  if (!render_to_surface_) {
    return std::make_unique<SurfaceFrame>(
        nullptr, SurfaceFrame::FramebufferInfo{.supports_readback = true},
        [](const SurfaceFrame& surface_frame, DlCanvas* canvas) {
          return true;
        },
        [](const SurfaceFrame& surface_frame) { return true; }, size);
  }
"""

IMPELLER_NEW = """  if (!render_to_surface_) {
    // The GTK compositor keeps one FBO and copies it to the window. An empty
    // existing-damage rect tells the rasterizer that this FBO still holds the
    // previous frame, so only the dirty display-list bounds need to be drawn.
    SurfaceFrame::FramebufferInfo info;
    info.supports_readback = true;
    info.supports_partial_repaint = true;
    info.horizontal_clip_alignment = 32;
    info.vertical_clip_alignment = 32;
    info.existing_damage = DlIRect::MakeLTRB(0, 0, 0, 0);
    return std::make_unique<SurfaceFrame>(
        nullptr, info,
        [](const SurfaceFrame& surface_frame, DlCanvas* canvas) {
          return true;
        },
        [](const SurfaceFrame& surface_frame) { return true; }, size);
  }
"""

RASTER_OLD = """      // Disable partial repaint if external_view_embedder_ SubmitFlutterView is
      // involved - ExternalViewEmbedder unconditionally clears the entire
      // surface and also partial repaint with platform view present is
      // something that still need to be figured out.
      bool force_full_repaint =
          external_view_embedder_ &&
          (!raster_thread_merger_ || raster_thread_merger_->IsMerged());
"""

RASTER_NEW = """      // Ubuntu Touch build: the compositor FBO is cleared only on the first
      // frame of a given size (see RenderFlutterContents*). Later frames keep
      // the previous pixels, so the external-view path can use the damage
      // rect. This library is not the desktop Flutter engine.
      bool force_full_repaint = false;
"""

CLEAR_OLD = """    bool clear_surface = true;
    for (auto c : flutter_contents_) {"""

CLEAR_NEW = """    static int64_t preserved_w = -1;
    static int64_t preserved_h = -1;
    const auto preserved_size = flutter_contents_.empty()
                                    ? DlISize()
                                    : flutter_contents_.front()->GetRenderSurfaceSize();
    const bool preserve = preserved_w == preserved_size.width &&
                          preserved_h == preserved_size.height;
    bool clear_surface = !preserve;
    if (!preserve && preserved_size.width > 0 && preserved_size.height > 0) {
      preserved_w = preserved_size.width;
      preserved_h = preserved_size.height;
    }
    for (auto c : flutter_contents_) {"""


LOAD_OLD = """    auto* impeller_target = render_target_->GetImpellerRenderTarget();
    auto aiks_context = render_target_->GetAiksContext();
    auto cull_rect =
        impeller::Rect::MakeSize(impeller_target->GetRenderTargetSize());
"""

LOAD_NEW = """    auto* impeller_target = render_target_->GetImpellerRenderTarget();
    auto aiks_context = render_target_->GetAiksContext();
    auto cull_rect =
        impeller::Rect::MakeSize(impeller_target->GetRenderTargetSize());
    if (preserve) {
      // Impeller clears the first color pass unless the attachment asks to
      // load. The previous frame is still in this FBO.
      auto color0 = impeller_target->GetColorAttachment(0);
      color0.load_action = impeller::LoadAction::kLoad;
      impeller_target->SetColorAttachment(color0, 0);
    }
"""

INLINE_OLD = """  if (pass_count_ > 0) {
    color0.load_action = is_msaa ? LoadAction::kClear : LoadAction::kLoad;
  } else {
    color0.load_action = LoadAction::kClear;
  }
"""

INLINE_NEW = """  // A reused compositor FBO asks for kLoad so pixels outside this frame's
  // dirty clip stay. Explicit MSAA resolves from a transient buffer, which
  // cannot be loaded. Implicit MSAA uses one texture and can.
  const bool inplace_msaa =
      is_msaa && color0.resolve_texture == color0.texture;
  const bool can_load = !is_msaa || inplace_msaa;
  if (pass_count_ > 0) {
    color0.load_action = can_load ? LoadAction::kLoad : LoadAction::kClear;
  } else if (color0.load_action != LoadAction::kLoad || !can_load) {
    color0.load_action = LoadAction::kClear;
  }
"""


def replace_once(path: pathlib.Path, old: str, new: str, expected: int) -> None:
    text = path.read_text()
    if old not in text and new in text:
        return
    found = text.count(old)
    if found != expected:
        raise SystemExit(f"{path}: expected {expected} occurrence(s), found {found}")
    path.write_text(text.replace(old, new))


def main() -> None:
    root = pathlib.Path(sys.argv[1]).resolve()
    replace_once(
        root / "shell/gpu/gpu_surface_gl_impeller.cc",
        IMPELLER_OLD,
        IMPELLER_NEW,
        1,
    )
    replace_once(
        root / "shell/common/rasterizer.cc",
        RASTER_OLD,
        RASTER_NEW,
        1,
    )
    replace_once(
        root / "shell/platform/embedder/embedder_external_view_embedder.cc",
        CLEAR_OLD,
        CLEAR_NEW,
        2,
    )
    replace_once(
        root / "shell/platform/embedder/embedder_external_view_embedder.cc",
        LOAD_OLD,
        LOAD_NEW,
        1,
    )
    replace_once(
        root / "impeller/entity/inline_pass_context.cc",
        INLINE_OLD,
        INLINE_NEW,
        1,
    )
    print(f"partial repaint patch applied in {root}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} /path/to/engine/src/flutter")
    main()
