# R17 Facing Production Workflow Contract

Historical provenance — 2026-10-24: Gemini 3.8 Flash medium wrote the builder
and prompts for that earlier Antigravity CLI run. After schema, identity,
pixel-style, and anchor corrections, the lead executed it once for blade
production: exit 0, 24 missing idle-facing requests, 8 active views, runtime
delta 0. [Request JSON](batch_requests.json), [prompts](prompts.txt), and
[provenance/CLI receipts](production_receipt.json) are retained. That CLI
context did not confirm a raster tool, did not inspect reference images, and
produced no candidate PNG. Codex approved request preparation only. Existing
active images, manifests, and Player remain unchanged.

Run the script as `python scripts/tools/prepare_r17_facing_batch.py` from the
project root, supplying `--project-root` and a new external `--output` directory.
It requires Python3.9+; current execution used the existing QA-venv Python solely
as a production interpreter, without running tests. Rifle/heavy input schemas
were source-reviewed but those production variants have not been executed.

If disk IO fails after directory creation, partial output can remain. Preserve
it for diagnosis and choose a new output path; there is no automatic deletion,
overwrite or resume. PNG header checks establish dimensions only, not visual
quality or full image integrity. Review one candidate at a time before a larger
batch; requested degrees cannot be mathematically certified from pixels.

## 1. Current Production Roles & Review Model

* **Current owner — Codex lead with GPT-6-Luna/xhigh workers**: The lead used built-in `imagegen`, rejected v018 and reviewed/registered v019 for blade idle only. [Intake record](intake-v019/README.md) preserves prompts, raw-source identity, native comparison and partial coverage. Shared base coverage is8; blade idle is9. This does not complete any32-facing action matrix.
* **Historical builder — Gemini 3.8 Flash medium**: Authored the request builder and prompts for the documented 2026-10-24 Antigravity CLI run. That run's missing raster tool was specific to that CLI context and is not a statement about current image-generation availability. Gemini is not the current production owner.
* **Review boundary**: Inspect image quality, screen-plane camera coherence, and anchors before registration. Visual review cannot certify mathematically exact angles. Do not claim unearned progress, register unreviewed assets, or synthesize programmatic pixel art.

---

## 2. Four-Stage Asset Lifecycle

Every character facing strictly progresses through four explicit lifecycle stages:

1. **Generation Request**: Prompt specifications, bracketing references, and candidate metadata templates emitted by `prepare_r17_facing_batch.py`.
2. **Actual Image**: The uninspected raster image returned by an art tool or external handoff (`review: pending`, `runtime_count_delta: 0`).
3. **Visually Accepted Angle**: Acceptance by Codex lead confirming character silhouette, armor identity, and perspective alignment without 2D mirror or flat rotation. (Visual inspection confirms perspective coherence, not exact mathematical angle certification).
4. **Runtime Registered Angle**: Frame registered into the weapon family manifest with resolved atlas coordinates, sole anchor, grip anchor, standing body height, and active facing angle list.

---

## 3. Canonical Actions & Facing Status Accounting

### The 11 Canonical Production Actions
The project target requires 32-facing coverage across the canonical **11 action animations**:
1. `idle`
2. `walk`
3. `run`
4. `dodge`
5. `aim/fire`
6. `lightstrike`
7. `heavystrike`
8. `weaponswap`
9. `hit`
10. `death`
11. `interaction`

*Note on current runtime manifests*: Existing family manifests define partial action subsets (e.g., `blade` currently defines 7 action keys: `idle`, `walk`, `draw_sword`, `slash`, `hit`, `interact`, `swap_tool`). Full 32-facing coverage across all 11 canonical actions remains pending lead review and atlas compilation.

### Current Facing Angle Accounting

The list below records the complete base set. v019 additionally registers
nominal11.25 degrees for **blade idle only** via `additional_action_facings`.
Idle has9 views and23 missing; other actions retain8 and24 missing. Historical
batch_requests.json still describes24 requested idle candidates at its earlier
snapshot; do not rewrite that immutable request receipt or count it as images.
* **Active Facings (8 Total on 11.25° Grid)**:
  * `0.00°` (East / Right)
  * `45.00°` (South-East)
  * `90.00°` (South / Front)
  * `135.00°` (South-West)
  * `180.00°` (West / Left)
  * `225.00°` (North-West)
  * `270.00°` (North / Back)
  * `315.00°` (North-East)
* **Missing from the complete base/action matrix (24 Total)**:
  * `11.25°`, `22.50°`, `33.75°`, `56.25°`, `67.50°`, `78.75°`, `101.25°`, `112.50°`, `123.75°`, `146.25°`, `157.50°`, `168.75°`, `191.25°`, `202.50°`, `213.75°`, `236.25°`, `247.50°`, `258.75°`, `281.25°`, `292.50°`, `303.75°`, `326.25°`, `337.50°`, `348.75°`
* **This intake registration delta**: complete base `0`; blade idle `+1`.
  The request builder itself never changes runtime art; its output delta is0.

---

## 4. CLI Execution & Safety Guards

```bash
python prepare_r17_facing_batch.py \
  --project-root /path/to/godot_project \
  --output /path/to/facing_batch_out \
  --family blade
```

### Production Safety Specifications
* **Path Security**: Resolves all relative paths and `res://` URLs using `Path.resolve().is_relative_to(root)` across drive letters on Windows. Rejects symlink output destinations (even dangling), backslashes, `..` traversals, and root escapes.
* **Manifest Containment**: The manifest itself (`r17_presentation_v2.json` or `r17_weapon_families_v2.json`) is verified to be contained within the project root.
* **Cell & Anchor Validation**: Validates 9-element or 11-element cells. Rejects silent float truncations on crops, verifies anchors reside inside crops, and validates index 8 as a positive standing body height divisor without arbitrary crouch clipping.
* **Strict Pre-condition Guard**: No directories created and no files written until all inputs, angles, and referenced PNG IHDR headers are validated. Output directory must not previously exist and writes use exclusive creation mode (`'x'`).

---

## 5. 繁體中文工作流程摘要 (Traditional Chinese Summary)

### 職責分工與審核規範
* **目前負責者 — Codex 主代理與 GPT-6-Luna／xhigh 子代理**：主代理以內建 `imagegen` 產生、審查並登記 v019，僅持劍待機增加一個視角。待機為9方向，其餘動作與完整基礎組仍為8方向；未完成32方向與11種動作。
* **歷史建構者 — Gemini 3.8 Flash medium**：僅記錄 2026-10-24 Antigravity CLI 那次建構器與提示詞來源。當時 CLI 未確認可用的光柵生圖工具，這是該次 CLI 工作環境的限制，不代表目前工具狀態；Gemini 不是本輪負責者。
* **審核界線**：登記前檢視圖像、畫面平面視角一致性與錨點；視覺審查不能證明精確數學角度。不得把未審候選圖登記或虛報進度，也不得用程式繪圖偽造美術成品。

### 四階段資產生命週期
1. **生成請求 (Generation Request)**：建構器產出之提示詞、括弧參考角度與待填登記範本。
2. **實體圖像 (Actual Image)**：生成之候選圖片檔案（狀態維持 `review: pending`，運行時增量為 0）。
3. **視覺認可角度 (Visually Accepted Angle)**：經 Codex 審核確認符合 3D 視角、金屬盔甲特徵與正面頭盔金色十字，無平面旋轉或鏡像。
4. **運行時已註冊角度 (Runtime Registered Angle)**：正式寫入圖集與 manifest 之有效角度。

### 盤點與動作狀態
* **規範 11 項動作**：`idle`, `walk`, `run`, `dodge`, `aim/fire`, `lightstrike`, `heavystrike`, `weaponswap`, `hit`, `death`, `interaction`。現有 manifest 僅定義部分動作（例如 blade 僅包含 7 項），全 32 視角矩陣仍待後續補齊。
* **視角盤點**：現有 8 個 active 視角，缺少 24 個；運行時增量維持 0。11 項規範動作的完整視角矩陣仍未完成。
