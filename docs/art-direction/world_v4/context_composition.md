# World v4 contextual prop composition

Historical contextual-yard assignment table. Later local court changes are in
[regional_courtyards.md](regional_courtyards.md) and
[late_story_courts.md](late_story_courts.md) and
[city_street_block.md](city_street_block.md). The City civilian row replaces
unpaired #1; it does not change the contextual-yard pairings below.
The later three story relocations
use unpaired Factory #4, City #3 and Facility #3; every pairing below remains.
Crystal #3 retains the listed
East survey-spur pairing; unpaired #10 moved to the story bay instead. The current
batch adds separate nonblocking approach/scatter entries after these ranges.

Parent render correction: the first native rubble-apron fill still read as a
detached rectangular paving mat. `WorldBackdrop` now renders dry rubble as
broken, low-coverage stone through the same regional earth, with no solid basin
rim. Water, chasm, furnace and coolant rendering/collision keep their existing
rules. Final local evidence is recorded separately under `captures/chapter-sites/`;
the placement table below does not imply whole-route traversal acceptance.

Revised 2026-10-23 after inspecting the actual wide frames under `C:/Users/wuwu6/AppData/Local/Temp/first-game-art-preview/chapter-composition-captures/`. Those images showed disconnected props, missing architecture in the same frame, an overly loose three-wagon layout, and no contextual ground aprons. The placements below directly attach each existing grouped decoration range to one named architecture placement.

The contextual placement pass uses `data/art/world_v2.json`. A later convoy-variety pass registers two distinct wagon crops in the existing material/visual manifests; it changes the first two convoy prop IDs, retaining their anchors and blocker footprints. The existing `Wasteland._spawn_authored_cover` adapter still consumes `prop`, normalized `position`, `size`, and `blocking`; no runtime code or schema was added. All 89 authored additions remain nonblocking and keep their original contiguous decoration indices and exact prop/size/blocking contracts. Existing architecture placements, registered physical feet, and prior ground-area outlines are unchanged.

Each site now has one irregular 12-point `ground_areas` apron within a 360×240 world-pixel rect. The entries use the existing `kind: "rubble"` native ground sampling in `WorldBackdrop` and set `blocking: false`; the Wasteland ground-collision builder therefore does not add collision for these visual patches. Each added decoration also remains nonblocking. The old highway and marsh blockers keep their original blocking states. New apron rectangles were checked against the existing blocking basin/rubble rectangles and kept on land.

A site’s `group_center` is the shared center for its compact props and apron. `camera_anchor` is halfway between that center and the referenced architecture placement foot so the parent preview can frame both parts of the site; the preview hero still needs its separate safe staging offset. The previous highway convoy sat 419px below its depot and could not frame the building and yard together. It now sits in a compact east-depot workyard; the six repair props moved to the upper west median shoulder, clear of the y=0.30 road. The marsh north-bank shelf remains 235px below its pumphouse so its 360×240 apron clears the y=0.23 approach and the neighboring blocking water outline.

| Route | Site | Group center `[x, y]` | Connected architecture placement and offset `[dx, dy]` px | Exact prop counts | Decoration range / apron index |
| --- | --- | --- | --- | --- | --- |
| `scrap_highway` | East-depot convoy workyard | `0.90243, 0.45939` | `highway_depot#12` `[340, 115]` | covered_wagon ×1, overturned_wagon ×1, wagon ×1, supply ×2, wall_stub ×2, waypost ×1 | `0–8` / `0` |
| `scrap_highway` | Upper west median repair pull-off | `0.33757, 0.21139` | `highway_median#15` `[-340, 115]` | rubble_a ×1, rubble_b ×1, supply ×1, dry_grass ×1, thorn ×1, waypost ×1 | `8–14` / `1` |
| `scrap_highway` | East median milepost | `0.64657, 0.45739` | `highway_median#13` `[-340, 115]` | wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, thorn ×1, waypost ×1 | `14–20` / `2` |
| `toxic_marsh` | South pumphouse service yard | `0.34892, 0.86717` | `marsh_pumphouse#0` `[-340, 160]` | wall_stub ×1, supply ×1, dry_grass ×2, rubble_a ×1, rubble_b ×1, thorn ×1, waypost ×1 | `0–8` / `4` |
| `toxic_marsh` | West pumphouse forecourt | `0.33695, 0.66953` | `marsh_pumphouse#2` `[-220, 115]` | waypost ×1, supply ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, thorn ×1 | `8–14` / `5` |
| `toxic_marsh` | North basin east-bank service shelf | `0.43108, 0.28991` | `marsh_pumphouse#6` `[340, 235]` | toxic_pool ×1, wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, thorn ×1 | `14–20` / `6` |
| `crystal_scar` | West fractured-stele scree | `0.10081, 0.53953` | `crystal_buttress#4` `[-340, 115]` | crystal_node ×1, rubble_a ×1, rubble_b ×1, thorn ×1, dry_grass ×1 | `0–5` / `2` |
| `crystal_scar` | Upper eastern spoil shelf | `0.88919, 0.32953` | `crystal_buttress#7` `[340, 115]` | crystal_node ×1, wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1 | `5–10` / `3` |
| `crystal_scar` | East crossing survey spur | `0.65183, 0.60189` | `crystal_buttress#3` `[220, 70]` | rubble_a ×1, rubble_b ×1, wall_stub ×1, dry_grass ×1, waypost ×1 | `10–15` / `4` |
| `old_factory` | West furnace workyard | `0.37257, 0.88042` | `factory_furnace#0` `[-340, 115]` | waypost ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, supply ×1 | `0–5` / `3` |
| `old_factory` | West slag-pit tool lip | `0.13257, 0.62243` | `factory_furnace#2` `[-340, 70]` | supply ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, thorn ×1 | `5–10` / `4` |
| `old_factory` | East iron-coffin transfer apron | `0.89743, 0.51243` | `factory_furnace#6` `[340, 70]` | wall_stub ×1, wagon ×1, supply ×1, rubble_a ×1, waypost ×1 | `10–15` / `5` |
| `ruined_metropolis` | South fallen-bell courtyard | `0.36420, 0.87872` | `metropolis_bell#0` `[-340, 115]` | wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, waypost ×1 | `0–5` / `3` |
| `ruined_metropolis` | East clinic loading apron | `0.89580, 0.39139` | `metropolis_bell#6` `[340, 70]` | wagon ×1, supply ×1, rubble_a ×1, thorn ×1, waypost ×1 | `5–10` / `4` |
| `ruined_metropolis` | West arcade ash edge | `0.38420, 0.45139` | `metropolis_bell#4` `[-340, 70]` | rubble_a ×1, rubble_b ×1, dry_grass ×1, thorn ×1, supply ×1 | `10–15` / `5` |
| `underground_facility` | West cistern maintenance yard | `0.36892, 0.41139` | `facility_lab#4` `[-340, 70]` | wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, waypost ×1 | `0–5` / `3` |
| `underground_facility` | East filter-valve service bay | `0.90108, 0.46872` | `facility_lab#6` `[340, 115]` | supply ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, waypost ×1 | `5–10` / `4` |
| `underground_facility` | Upper intake service spur | `0.63305, 0.39139` | `facility_lab#5` `[220, 70]` | wall_stub ×1, rubble_a ×1, rubble_b ×1, dry_grass ×1, waypost ×1 | `10–15` / `5` |

The parent preview recipe can consume the following exact normalized anchors, contiguous ranges, architecture references, prop lists and appended ground-area indexes. Indices are zero-based, and each decoration range is half-open.

```json
{
  "coordinate_space": "normalized route positions; world-pixel offsets use route size_tiles × 32",
  "index_convention": "zero-based decoration range [start, end_exclusive)",
  "camera_anchor_convention": "midpoint between the attached architecture placement foot and the group center; use group_center as the prop/apron center",
  "apron_contract": "one 360x240-world-pixel kind=rubble, blocking=false, 12-point native ground outline per site",
  "whole_map_review_status": "pending parent preview render and visual review",
  "sites": [
    {
      "route": "scrap_highway",
      "site_id": "east-depot-convoy-workyard",
      "capture_key": "highway-convoy-yard",
      "title": "East-depot convoy workyard",
      "purpose": "One abandoned convoy and its supplies sit together right-front of the east depot placement, forming a compact workyard outside the through road and return lane.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 8
      },
      "group_center": [
        0.90243304,
        0.45939137
      ],
      "camera_anchor": [
        0.87871652,
        0.44869568
      ],
      "architecture": {
        "module": "highway_depot",
        "placement_index": 12,
        "foot": [
          0.855,
          0.438
        ],
        "offset_world_px": [
          340,
          115
        ]
      },
      "ground_area_index": 0,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "covered_wagon",
        "overturned_wagon",
        "wagon",
        "supply",
        "wall_stub",
        "waypost",
        "supply",
        "wall_stub"
      ],
      "prop_counts": {
        "covered_wagon": 1,
        "overturned_wagon": 1,
        "wagon": 1,
        "supply": 2,
        "wall_stub": 2,
        "waypost": 1
      }
    },
    {
      "route": "scrap_highway",
      "site_id": "upper-west-median-repair-pull-off",
      "capture_key": "highway-repair-pull-off",
      "title": "Upper west median repair pull-off",
      "purpose": "A compact six-prop repair cache sits left-front of the upper west median wall, on the shoulder above the y=0.30 road and outside its through path.",
      "decoration_indices": {
        "start": 8,
        "end_exclusive": 14
      },
      "group_center": [
        0.33756696,
        0.21139137
      ],
      "camera_anchor": [
        0.36128348,
        0.20069568
      ],
      "architecture": {
        "module": "highway_median",
        "placement_index": 15,
        "foot": [
          0.385,
          0.19
        ],
        "offset_world_px": [
          -340,
          115
        ]
      },
      "ground_area_index": 1,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "rubble_a",
        "rubble_b",
        "supply",
        "dry_grass",
        "thorn",
        "waypost"
      ],
      "prop_counts": {
        "rubble_a": 1,
        "rubble_b": 1,
        "supply": 1,
        "dry_grass": 1,
        "thorn": 1,
        "waypost": 1
      }
    },
    {
      "route": "scrap_highway",
      "site_id": "east-median-milepost",
      "capture_key": "highway-milepost",
      "title": "East median milepost",
      "purpose": "Low roadside fragments and a waypost lean against the east median wall without occupying the crossing.",
      "decoration_indices": {
        "start": 14,
        "end_exclusive": 20
      },
      "group_center": [
        0.64656696,
        0.45739137
      ],
      "camera_anchor": [
        0.67028348,
        0.44669568
      ],
      "architecture": {
        "module": "highway_median",
        "placement_index": 13,
        "foot": [
          0.694,
          0.436
        ],
        "offset_world_px": [
          -340,
          115
        ]
      },
      "ground_area_index": 2,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "thorn",
        "waypost"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "thorn": 1,
        "waypost": 1
      }
    },
    {
      "route": "toxic_marsh",
      "site_id": "south-pumphouse-service-yard",
      "capture_key": "marsh-pump-yard",
      "title": "South pumphouse service yard",
      "purpose": "The inherited blocked wall and supply stack remain intact as a single southwest service cluster at the south pumphouse; small dry debris fills its irregular apron.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 8
      },
      "group_center": [
        0.34891827,
        0.86717391
      ],
      "camera_anchor": [
        0.37445913,
        0.85358696
      ],
      "architecture": {
        "module": "marsh_pumphouse",
        "placement_index": 0,
        "foot": [
          0.4,
          0.84
        ],
        "offset_world_px": [
          -340,
          160
        ]
      },
      "ground_area_index": 4,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "supply",
        "dry_grass",
        "rubble_a",
        "rubble_b",
        "thorn",
        "waypost",
        "dry_grass"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "supply": 1,
        "dry_grass": 2,
        "rubble_a": 1,
        "rubble_b": 1,
        "thorn": 1,
        "waypost": 1
      }
    },
    {
      "route": "toxic_marsh",
      "site_id": "pumphouse-west-forecourt",
      "capture_key": "marsh-salvage-shelf",
      "title": "West pumphouse forecourt",
      "purpose": "A small marker and salvage group sits left-front of the pumphouse at [0.37,0.65]; the moving field objective at [0.415,0.675] remains in the open right-front approach.",
      "decoration_indices": {
        "start": 8,
        "end_exclusive": 14
      },
      "group_center": [
        0.33694712,
        0.66953125
      ],
      "camera_anchor": [
        0.35347356,
        0.65976563
      ],
      "architecture": {
        "module": "marsh_pumphouse",
        "placement_index": 2,
        "foot": [
          0.37,
          0.65
        ],
        "offset_world_px": [
          -220,
          115
        ]
      },
      "ground_area_index": 5,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "waypost",
        "supply",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "thorn"
      ],
      "prop_counts": {
        "waypost": 1,
        "supply": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "thorn": 1
      }
    },
    {
      "route": "toxic_marsh",
      "site_id": "north-basin-east-bank-service-shelf",
      "capture_key": "marsh-spillway",
      "title": "North basin east-bank service shelf",
      "purpose": "A small treatment cache sits on dry ground east of the northern marsh basin and below the adjacent pumphouse; the pool sprite remains outside the water outline.",
      "decoration_indices": {
        "start": 14,
        "end_exclusive": 20
      },
      "group_center": [
        0.43108173,
        0.28991168
      ],
      "camera_anchor": [
        0.40554087,
        0.26995584
      ],
      "architecture": {
        "module": "marsh_pumphouse",
        "placement_index": 6,
        "foot": [
          0.38,
          0.25
        ],
        "offset_world_px": [
          340,
          235
        ]
      },
      "ground_area_index": 6,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "toxic_pool",
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "thorn"
      ],
      "prop_counts": {
        "toxic_pool": 1,
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "thorn": 1
      }
    },
    {
      "route": "crystal_scar",
      "site_id": "west-fractured-stele-scree",
      "capture_key": "crystal-stele-scree",
      "title": "West fractured-stele scree",
      "purpose": "The crystal node and two fragments gather beside the west buttress on solid ground, away from the supply-cache route.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 5
      },
      "group_center": [
        0.10081019,
        0.53953125
      ],
      "camera_anchor": [
        0.12540509,
        0.52976563
      ],
      "architecture": {
        "module": "crystal_buttress",
        "placement_index": 4,
        "foot": [
          0.15,
          0.52
        ],
        "offset_world_px": [
          -340,
          115
        ]
      },
      "ground_area_index": 2,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "crystal_node",
        "rubble_a",
        "rubble_b",
        "thorn",
        "dry_grass"
      ],
      "prop_counts": {
        "crystal_node": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "thorn": 1,
        "dry_grass": 1
      }
    },
    {
      "route": "crystal_scar",
      "site_id": "upper-eastern-spoil-shelf",
      "capture_key": "crystal-spoil-shelf",
      "title": "Upper eastern spoil shelf",
      "purpose": "A crystal and its masonry spoil sit east of the upper buttress, clear of the broken-robot approach and both chasms.",
      "decoration_indices": {
        "start": 5,
        "end_exclusive": 10
      },
      "group_center": [
        0.88918981,
        0.32953125
      ],
      "camera_anchor": [
        0.86459491,
        0.31976562
      ],
      "architecture": {
        "module": "crystal_buttress",
        "placement_index": 7,
        "foot": [
          0.84,
          0.31
        ],
        "offset_world_px": [
          340,
          115
        ]
      },
      "ground_area_index": 3,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "crystal_node",
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass"
      ],
      "prop_counts": {
        "crystal_node": 1,
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1
      }
    },
    {
      "route": "crystal_scar",
      "site_id": "east-crossing-survey-spur",
      "capture_key": "crystal-survey-spur",
      "title": "East crossing survey spur",
      "purpose": "A survey marker and compact fragments attach to the crossing-side buttress, with the marked route kept clear.",
      "decoration_indices": {
        "start": 10,
        "end_exclusive": 15
      },
      "group_center": [
        0.6518287,
        0.60188859
      ],
      "camera_anchor": [
        0.63591435,
        0.59594429
      ],
      "architecture": {
        "module": "crystal_buttress",
        "placement_index": 3,
        "foot": [
          0.62,
          0.59
        ],
        "offset_world_px": [
          220,
          70
        ]
      },
      "ground_area_index": 4,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "rubble_a",
        "rubble_b",
        "wall_stub",
        "dry_grass",
        "waypost"
      ],
      "prop_counts": {
        "rubble_a": 1,
        "rubble_b": 1,
        "wall_stub": 1,
        "dry_grass": 1,
        "waypost": 1
      }
    },
    {
      "route": "old_factory",
      "site_id": "west-furnace-workyard",
      "capture_key": "factory-furnace-yard",
      "title": "West furnace workyard",
      "purpose": "A compact tool and supply yard roots beside the west furnace module, outside the active factory objective and the service routes.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 5
      },
      "group_center": [
        0.37256696,
        0.88041903
      ],
      "camera_anchor": [
        0.39628348,
        0.87020952
      ],
      "architecture": {
        "module": "factory_furnace",
        "placement_index": 0,
        "foot": [
          0.42,
          0.86
        ],
        "offset_world_px": [
          -340,
          115
        ]
      },
      "ground_area_index": 3,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "waypost",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "supply"
      ],
      "prop_counts": {
        "waypost": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "supply": 1
      }
    },
    {
      "route": "old_factory",
      "site_id": "west-slag-pit-tool-lip",
      "capture_key": "factory-slag-lip",
      "title": "West slag-pit tool lip",
      "purpose": "Tools and low debris sit beside the west furnace on dry ground, outside the furnace outlines and the supply-cache approach.",
      "decoration_indices": {
        "start": 5,
        "end_exclusive": 10
      },
      "group_center": [
        0.13256696,
        0.62242898
      ],
      "camera_anchor": [
        0.15628348,
        0.61621449
      ],
      "architecture": {
        "module": "factory_furnace",
        "placement_index": 2,
        "foot": [
          0.18,
          0.61
        ],
        "offset_world_px": [
          -340,
          70
        ]
      },
      "ground_area_index": 4,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "supply",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "thorn"
      ],
      "prop_counts": {
        "supply": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "thorn": 1
      }
    },
    {
      "route": "old_factory",
      "site_id": "east-iron-coffin-transfer-apron",
      "capture_key": "factory-transfer-apron",
      "title": "East iron-coffin transfer apron",
      "purpose": "A wagon, supplies and fragments form one loading apron beside the east furnace; the field objective at [0.65,0.37] stays clear.",
      "decoration_indices": {
        "start": 10,
        "end_exclusive": 15
      },
      "group_center": [
        0.89743304,
        0.51242898
      ],
      "camera_anchor": [
        0.87371652,
        0.50621449
      ],
      "architecture": {
        "module": "factory_furnace",
        "placement_index": 6,
        "foot": [
          0.85,
          0.5
        ],
        "offset_world_px": [
          340,
          70
        ]
      },
      "ground_area_index": 5,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "wagon",
        "supply",
        "rubble_a",
        "waypost"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "wagon": 1,
        "supply": 1,
        "rubble_a": 1,
        "waypost": 1
      }
    },
    {
      "route": "ruined_metropolis",
      "site_id": "south-fallen-bell-courtyard",
      "capture_key": "city-bell-courtyard",
      "title": "South fallen-bell courtyard",
      "purpose": "Masonry and a waypost gather along the south bell module foot without crossing the central story approach.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 5
      },
      "group_center": [
        0.36420259,
        0.87871745
      ],
      "camera_anchor": [
        0.38710129,
        0.86935872
      ],
      "architecture": {
        "module": "metropolis_bell",
        "placement_index": 0,
        "foot": [
          0.41,
          0.86
        ],
        "offset_world_px": [
          -340,
          115
        ]
      },
      "ground_area_index": 3,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "waypost"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "waypost": 1
      }
    },
    {
      "route": "ruined_metropolis",
      "site_id": "east-clinic-loading-apron",
      "capture_key": "city-clinic-apron",
      "title": "East clinic loading apron",
      "purpose": "A wagon and supply drop sit beside the east bell-hall, away from the clinic approach and existing rubble collision areas.",
      "decoration_indices": {
        "start": 5,
        "end_exclusive": 10
      },
      "group_center": [
        0.89579741,
        0.39139323
      ],
      "camera_anchor": [
        0.87289871,
        0.38569661
      ],
      "architecture": {
        "module": "metropolis_bell",
        "placement_index": 6,
        "foot": [
          0.85,
          0.38
        ],
        "offset_world_px": [
          340,
          70
        ]
      },
      "ground_area_index": 4,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wagon",
        "supply",
        "rubble_a",
        "thorn",
        "waypost"
      ],
      "prop_counts": {
        "wagon": 1,
        "supply": 1,
        "rubble_a": 1,
        "thorn": 1,
        "waypost": 1
      }
    },
    {
      "route": "ruined_metropolis",
      "site_id": "west-arcade-ash-edge",
      "capture_key": "city-arcade-edge",
      "title": "West arcade ash edge",
      "purpose": "Small ash, grass and salvage mark the west edge of a bell arcade on the same worn ground, clear of the story walk-up and rubble blockers.",
      "decoration_indices": {
        "start": 10,
        "end_exclusive": 15
      },
      "group_center": [
        0.38420259,
        0.45139323
      ],
      "camera_anchor": [
        0.40710129,
        0.44569661
      ],
      "architecture": {
        "module": "metropolis_bell",
        "placement_index": 4,
        "foot": [
          0.43,
          0.44
        ],
        "offset_world_px": [
          -340,
          70
        ]
      },
      "ground_area_index": 5,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "thorn",
        "supply"
      ],
      "prop_counts": {
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "thorn": 1,
        "supply": 1
      }
    },
    {
      "route": "underground_facility",
      "site_id": "west-cistern-maintenance-yard",
      "capture_key": "facility-cistern-yard",
      "title": "West cistern maintenance yard",
      "purpose": "A service cache and low fragments sit west of the lab module, outside coolant pits and the supply-cache approach.",
      "decoration_indices": {
        "start": 0,
        "end_exclusive": 5
      },
      "group_center": [
        0.36891827,
        0.41139323
      ],
      "camera_anchor": [
        0.39445913,
        0.40569661
      ],
      "architecture": {
        "module": "facility_lab",
        "placement_index": 4,
        "foot": [
          0.42,
          0.4
        ],
        "offset_world_px": [
          -340,
          70
        ]
      },
      "ground_area_index": 3,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "waypost"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "waypost": 1
      }
    },
    {
      "route": "underground_facility",
      "site_id": "east-filter-valve-service-bay",
      "capture_key": "facility-filter-bay",
      "title": "East filter-valve service bay",
      "purpose": "A compact filter-service cache roots east of the lab module, clear of the broken-robot approach and coolant outlines.",
      "decoration_indices": {
        "start": 5,
        "end_exclusive": 10
      },
      "group_center": [
        0.90108173,
        0.46871745
      ],
      "camera_anchor": [
        0.87554087,
        0.45935872
      ],
      "architecture": {
        "module": "facility_lab",
        "placement_index": 6,
        "foot": [
          0.85,
          0.45
        ],
        "offset_world_px": [
          340,
          115
        ]
      },
      "ground_area_index": 4,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "supply",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "waypost"
      ],
      "prop_counts": {
        "supply": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "waypost": 1
      }
    },
    {
      "route": "underground_facility",
      "site_id": "upper-intake-service-spur",
      "capture_key": "facility-intake-spur",
      "title": "Upper intake service spur",
      "purpose": "Maintenance fragments and a waypost gather beside the intake-side lab module, while the main route remains open.",
      "decoration_indices": {
        "start": 10,
        "end_exclusive": 15
      },
      "group_center": [
        0.63305288,
        0.39139323
      ],
      "camera_anchor": [
        0.61652644,
        0.38569661
      ],
      "architecture": {
        "module": "facility_lab",
        "placement_index": 5,
        "foot": [
          0.6,
          0.38
        ],
        "offset_world_px": [
          220,
          70
        ]
      },
      "ground_area_index": 5,
      "apron": {
        "kind": "rubble",
        "blocking": false,
        "rect_world_px": [
          360,
          240
        ]
      },
      "exact_props": [
        "wall_stub",
        "rubble_a",
        "rubble_b",
        "dry_grass",
        "waypost"
      ],
      "prop_counts": {
        "wall_stub": 1,
        "rubble_a": 1,
        "rubble_b": 1,
        "dry_grass": 1,
        "waypost": 1
      }
    }
  ]
}
```

The data update preserves at least 96 world pixels between each apron rectangle and the authored road/return-lane corridor, current route exploration-site approaches, story walk-up approach, and the moving marsh `[0.415, 0.675]` / factory `[0.65, 0.37]` field-objective approaches. The marsh forecourt stays left-front of the pumphouse at `[0.37, 0.65]`, with the field site open on its right-front. The factory’s active objective remains right-front of the furnace at `[0.61, 0.35]`; the new yards use other furnace placements.

This is a data and documentation revision only. It does not claim post-revision rendering, whole-map visual acceptance, traversal/collision verification, tests, or QA. The 18 revised wide compositions still require a fresh parent render and visual review.
