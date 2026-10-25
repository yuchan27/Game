# World v4 prop contact

`WorldProp.gd` can blend a thin strip of a wasteland prop into the shared earth
material. The binding is opt-in under the root of
`data/art/world_materials_v3.json`:

```json
"ground_contact": {
  "enabled": true,
  "band_pixels": 5.0,
  "strength": 0.40
}
```

When enabled, the prop shader reads `ground.earth` or the optional
`regions[route_id].earth` override, including its PNG path, source rectangle and
world size. A missing or unusable regional source falls back to base earth.
Settings are cached per route so props on different routes keep the correct
material. Sampling uses nearest filtering and the same world-pixel center,
repeat phase, earth contrast (`mix` from the shared dark umber base, default
`0.68`) and grain multiplier as `WorldBackdrop.gd`. A valid finite numeric
`regions[route_id].earth_contrast` from `0.0` to `1.0` overrides that default.
The route's default tint or a valid regional `tint: [r, g, b]` is applied to the
sampled earth before grain. The shader blends that color into only the 3–6
world-pixel band around each registered `foot`; the edge varies by at most half
a pixel from the world grain. Prop alpha is retained, and each entry's existing
`alpha_cutoff` continues to control source clipping.

The shader and loaded earth texture are shared. Contact-enabled props receive
their own `ShaderMaterial` so the registered foot can vary per instance. The
brown contact polygon and dark shadow quad are omitted while this binding is
active. If the setting, ground source or registered foot is unavailable, the
existing contact path remains in use. A direct prop entry with `route_ids` is
selected only on a listed route; missing or empty `route_ids` keeps it
universal. A route mismatch continues through the legacy prop-ID fallback.
The later hub checkpoint opts Village/Guild decor into this material adapter
while preserving their original decorative collision bounds. Registered station
sprites reuse `WorldProp.world_source_material`; source metadata defaults keep
other props unchanged. Unique-required legacy landmarks still bypass aliases.
See `hub_presentation.md` for the precise gate/building exceptions and evidence.

This note originally recorded source-only integration. Later ordinary rendered
checkpoints are linked in `README.md`; none constitutes gameplay QA.
