# Current v4 ordinary camera evidence

**Historical local checkpoint:** these images predate the contextual yards,
field mechanisms, title/prologue and field-objective UI continuation. See
`../chapter-sites/` for that later source identity and production review.
Keep this set for comparison; do not use it to claim current-source coverage.

Recorded 2026-10-23. **Art production review, not tests/QA or release acceptance.**

Twelve local cameras were rendered at 1280×720 in this directory and at
1024×768 under `1024x768/`. These are actual Wasteland scenes, R-17, props and
HUD through Godot 4.6.3, rather than generated gameplay mockups. Source PNGs are
unchanged. The isolated project's dedicated custom user directory is
`R17-Ordinary-Art-Preview-20261023`; the real player save was not used.

## Reproduction and identity

- Portable recipe: `../ArtPreview.gd.txt`; copy to an isolated project's
  `ArtPreviewV4.gd` and attach it to a Node scene. It requires an absolute
  `--art-output=...` argument and an isolated custom user directory.
- Use `--rendering-method gl_compatibility --audio-driver Dummy --resolution
  1280x720` or `1024x768`, the capture scene, then `-- --art-output=<absolute path>`.
  Optional `--art-view=crystal-spire-landmark` selects one of the recipe's views.
- Both final full render processes exited **0**. The two main logs have no
  observed script/engine errors. Backend: Compatibility/OpenGL 3.3, Intel Arc 140V.
  These exit codes describe ordinary rendering, not test-suite results.
- `source_snapshot.json` records 96 runtime code/scene/data and v4 PNG inputs,
  their matching isolated-copy hashes, and 24 output hashes/dimensions. This set
  includes inactive v4 candidates; it is not an assertion that every listed PNG
  is active. Other legacy PNGs are outside this identity record. Root/mirror
  project files differ intentionally for isolated user data.

## What changed after actual image review

1. Replaced oversized stones, high-noise dirt and a near-frontal depot with fine
   paving, quieter terrain and an oblique roof/side-wall structure.
2. Replaced inconsistent roadside props and bright bus presentation with rooted
   slate/oak/iron debris and a muted bus sibling. Source alpha clipping and a
   narrow world-space root band avoid bright halos and separate shadow plates.
3. Integrated ten architecture sources across twelve module entries in six
   routes, plus five story landmarks and two route-specific hazard sprites.
4. Assigned regional stone surfaces. Rejected the first actual-scale shale
   presentation as oversized/repetitive; reduced its tiling to 192 world pixels
   and earth contrast to 0.26. Road contrast follows earth +0.04. The road
   shoulder has broader irregular wear rather than a sharp texture boundary.
5. Replaced four water, two chasm, three furnace and three coolant rectangles
   with shared native polygon outlines for rendering and collision. The first
   factory review exposed a hard brown corner; the current corner follows a
   broken pit boundary. Existing rectangular fallback/save escape remain.
6. Kept HUD text at native size in the 1024-wide view. Offset the preview hero
   from five landmarks to expose their bases, then corrected the spire camera
   so its top fits. These preview positions do not change live spawn points.
7. Independent review found story E labels detached from their visual targets.
   The final correction anchors them above actual landmark bounds, while
   retaining the walk-up trigger, reach and event behavior. The parent inspected
   the affected final bus, pump and turbine frames after this correction.

An intermediate render failed to compile a new inferred Boolean in WorldProp.
It was explicitly typed and corrected before the successful renders. Failed
intermediate images are not evidence for this checkpoint; exit 0 alone would not
have made those error-filled frames acceptable.

## Review disposition and remaining work

The parent and a separate read-only reviewer inspected the local compositions.
Compared with the rejected v3 capture, the highway now has compatible apparent
pixel scale, oblique structure planes, muted materials and visibly rooted bases.
The reviewed views have no obvious bright alpha halos; hero/HUD remain legible
at both window sizes. The reviewer inspected all twelve narrow views and seven
relevant wide views before the final prompt-label correction.

This is a **local composition checkpoint awaiting player feedback**, not full
world acceptance. Highway paving still forms a broad corridor. Crystal's slate
road remains a deliberate cool surface transition. A small part of a furnace
pit enters the extreme wide-view factory corner; its complete rim/heat language
needs whole-route composition work. Full-route density, repeated prop placement,
environmental connections, traversal/collision, action animation, all menus,
save/load and performance remain open. Static captures prove none of those.

繁體中文：本批是實際遊戲鏡頭的場景修正紀錄，已處理尺度、透視、接地、區域
材質與互動文字位置；仍需要完整路線的構圖與玩法巡查。沒有執行測試，不代表
遊戲已達到發行或整張世界的驗收標準。
