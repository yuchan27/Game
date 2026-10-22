# Route prop expansion — 2026-10-21

Requested outcome: lower object similarity while retaining the existing R-17
identity and post-apocalyptic world. Four new assets were generated with the
built-in image_gen tool, not an API/CLI fallback. Existing artwork was preserved.

| Asset | Saved production PNG | World canvas | Ground footprint (normalized full source PNG) |
| --- | --- | --- | --- |
| Highway bus wreck | `assets/sprites/props/expanded/highway_bus.png` | 208×139 | [0.05, 0.62, 0.91, 0.28] |
| Marsh drainage pump | `assets/sprites/props/expanded/marsh_pump.png` | 160×146 | [0.12, 0.70, 0.82, 0.16] |
| Crystal fissure spire | `assets/sprites/props/expanded/crystal_spire.png` | 214×193 | [0.26, 0.77, 0.54, 0.18] |
| Factory turbine | `assets/sprites/props/expanded/factory_turbine.png` | 168×151 | [0.08, 0.66, 0.87, 0.20] |

The source PNGs retain generated RGBA pixels and transparent padding. Manifest
source dimensions and SHA-256 identify exact inputs. Godot import and nearest
texture filtering handle production display; explicit world sizes preserve aspect
and distinct silhouettes. Footprints describe ground contact, not the full visual
height; transparent margins do not become solid walls. Each route uses its own
new prop in its mixture and as a navigation landmark. New images do not replace
approved R-17, NPC or existing prop art.

## Generation prompts

All four calls used `transparent_background=true` and the following shared prompt
with the subject below substituted after `Subject:`:

> Use case: stylized-concept. Asset type: one production-ready transparent PNG
> world prop sprite for Wasteland Recycler, a Godot pixel-art pseudo-3D top-down
> 2D roguelike. Subject: [subject below] Style: carefully hand-placed crisp pixel
> clusters, detailed 16-bit postapocalyptic game sprite, 3/4 overhead camera about
> 40 degrees looking down, same grounded perspective as a top-down recycler robot
> game. Muted rust, dark steel, earth palette plus the subject accent. Upper-left
> lighting, distinct readable silhouette, strong value separation. Composition:
> isolated SINGLE complete object centered with ample transparent padding, bottom
> center is ground contact, no cropping, subtle compact semitransparent contact
> shadow only. Apparent sprite resolution approximately 160x144 pixels enlarged
> with nearest-neighbor crisp edges. Genuine transparent alpha background. Avoid
> photorealism, blur, soft painterly edges, white background, checkerboard drawn
> into the image, labels, text, grid, multiple objects/variants, duplicate
> silhouettes. This is a new asset; preserve existing game identity.

- Highway bus: A single collapsed rust-red transit minibus wreck for the scrap
  highway, front three-quarter view, long low wide silhouette, missing wheels,
  exposed blue engine block, yellow broken headlights, stacked bent metal panels.
  Clearly a vehicle, no pole or sign.
- Marsh pump: A single abandoned toxic drainage pump for the marsh route, low
  circular green oxidized tank with two thick bent pipes and a grated sump, moss,
  subtle luminous lime contaminated liquid inside one opening, asymmetrical
  outline. Clearly plumbing machinery, no tower or vehicle.
- Crystal spire: A single fractured purple crystal outcrop for the crystal fissure
  route, three dramatically different height angular amethyst spires on dark
  slate, luminous lavender inner cracks, small metallic debris fused into base,
  tall narrow jagged silhouette. Clearly mineral crystals, no machine or tree.
- Factory turbine: A single derelict industrial turbine-generator for the old
  factory route, chunky square blue-grey housing with large copper coil, huge
  round cooling fan on front, torn yellow-black hazard plates, coiled cables
  lying at base, compact broad rectangular silhouette. Clearly a power machine,
  no tower, pipes or car.

## Validation and limitations

Read-only asset validation checks file decode, nonempty alpha, source hashes,
references and footprint ranges. Real physics and rendered route inspection must
also pass; a transparent PNG alone does not prove good collisions. Existing reused
weapon/tool art and duplicate player frames remain explicit warnings. This prop
expansion does not claim all existing animation artwork is unique.
