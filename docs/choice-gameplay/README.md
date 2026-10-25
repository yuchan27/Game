# Expedition choices — production record

2026-10-24. Source integration with ordinary frozen native presentation; no QA
or gameplay acceptance. This snapshot precedes the subsequent J-layout work.

The marsh's settling/purge choice previously changed supplies while both valve
operations used the same5-second definition. It now selects8s or3.5s through
`CampaignProgress.effective_duration()`. Both CampaignAction's timer/presentation
and GameState's completion gate use that helper. The action's base8s remains the
saved-elapsed upper bound, also accepting older5-second progress. No saved field,
option ID, original reward quantity or settlement rule changed.

Four choice actions/eight options were reviewed. Highway routing already has
different waypoint/wave data; its two herbs are choice haul, not a roadside
pickup. Facility priority records intended clinic/cistern support and grants
the existing provisional supplies; it does not instantly repair a village
facility or change water allocation. City name-consent remains a narrative
scope decision in the single-player story. Canonical design/story prose now
matches those meanings.

| Frozen view | Native presentation |
| --- | --- |
| `ch1b-choice` | Two routing options; explicit provisional herbs and return banking |
| `ch2b-choice` | Two valve options show8s/3.5s and existing2herbs/4ammo |
| `ch2b-settling` | Elapsed1.5, maximum8.0 in world label and HUD card |
| `ch2b-purge` | Elapsed1.5, maximum3.5 in world label and HUD card |

Eight final PNGs are in `wide/` and `narrow/`, four each at1280x720 and1024x768.
The lead opened all8. Both option buttons and deferred-close control fit; action
labels and HUD use the matching maxima. The wide process was observed exiting0.
The narrow session handle later became unavailable; its engine process was
confirmed absent, all four successful PNG records are present, and its final
exit code was **not observed**. Do not upgrade that boundary to a passing run.

[source_snapshot.json](source_snapshot.json) records113 matching listed mirror/
root inputs at capture bookkeeping, seven product/tool before/after hashes,
recipes/logs/images and the source scope. It is a bounded list, not every asset.
Earlier story-seam hashes remain unchanged. The frozen scene uses staged RAM
outings, prior results, selected options and elapsed1.5. Only native display
helpers ran; no selection callback, input, timer completion, reward, extraction,
save/load payload, collision, pacing, performance or QA was exercised. World
readiness can populate layout RAM. Real-save stat stayed1203bytes and
1792682904815624900ns; its payload was not read/written.

Replay the saved `.gd.txt`/`.tscn.txt` in a project mirror with custom user dir
`R17-Ordinary-Art-Preview-20261023`; pass an absolute `--choice-output=` directory.
Discover Godot and verify its version before rendering. Never run the recipe
against the real player-data directory.

繁體中文：這批讓沖洗選擇真正影響操作時間，並修正選項中不存在的拾取／即時
建設承諾。八張預置圖只檢視文字與版面，沒有實際選擇、完成行動或存讀檔。
