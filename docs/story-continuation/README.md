# Story continuation and bounded CLI collaboration

Historical snapshot. Later HUD/action/terminal sources are recorded in
[field-action readability](../action-readability/README.md). Preserve this
record's original images, logs and source hashes.

2026-10-24, Asia/Taipei. This checkpoint continues the existing six-main,
twelve-outing campaign. It preserves the GUI's source work and records its QA
evidence separately from current production changes.

## Integrated changes

- Six existing story events retain IDs/rules and receive distinct physical clues:
  Highway manifest, Marsh valve ledger, Crystal voice echo, Factory order,
  City household archive and Facility historical record. Only their description,
  revelation and objective text changed. Unknown household fates and wider R-17
  memory remain unresolved. City reading does not imply public-name consent;
  Facility history does not determine present valves, Boss or water state.
- Twelve earned inter-chapter NPC responses describe their own chapter. The
  shared resolver appends the real journey hint instead of hardcoding a next
  route. Factory-first now points to the still-incomplete Highway contract;
  Marsh-before-Highway points to Crystal after those two chapters are complete.
  All prerequisites, optional discoveries and old-save fallbacks remain.
- Story clue dialogue footers say scroll/close/K; NPC paging remains specific to
  conversations. Existing six chapter debriefs, K replay and City consent survive.
- CampaignAction uses a nonpersistent `_wait_reason`, set by existing movement,
  enemy and wave branches. Local/map status can explain waiting for a follower,
  returning to defense range or clearing a wave. It replaces the progress line
  rather than expanding the existing two-line label. No extra enemy scans,
  save fields, frame signals, timing/position/radius/reward changes were added.
  The wait branches and their actual screen behavior still need gameplay review.

## Ordinary presentation

Fourteen final PNGs: seven each at 1280x720 and 1024x768. Five fixture scenes
produce two extra selected scroll-tail views:

| Fixture | Directly staged presentation |
| --- | --- |
| `factory-first` | Only Factory is complete; Alan's current next step is Highway |
| `marsh-then-highway` | Marsh followed by Highway; Ada's current next step is Crystal |
| `city-archive` / `city-archive-tail` | City archive description and consent-neutral interpretation |
| `facility-before` / `facility-before-tail` | Facility history while its first outing is pending |
| `facility-after` | The same historical text after a completed-Facility fixture |

The [recipe](StoryContinuationPreview.gd.txt) assigns state directly, instantiates
the native Village/Wasteland with simulation disabled and presents the actual
HUD/dialogue. It logs fixture prose/next hints and positions scroll tails directly.
It does not use NPC interaction, discover an event, complete an outing/contract,
award rewards, settle an expedition or load/write a save. All actors remain
disabled, so a frame cannot prove combat, collision, timing or travel behavior.

Both final Godot 4.6.3 Compatibility render processes completed with exit 0,
seven image-result-0 frame records each and no observed ERROR/WARNING lines.
The [source snapshot](source_snapshot.json) records 112 bounded source/mirror
inputs, recipe/log/image hashes, process receipts and isolated project settings.
This list is not every asset. Parent review covered both-size NPC instructions,
City and Facility text/selected tails. This frozen artifact remains historical;
later current-source QA verifies selected 800x600/960x600 task-panel layouts and
the 800x600 completed-list focus scroll, but arbitrary resizing, mouse-wheel
scrolling, action-wait labels and the complete journey are still unreviewed.

The mirror uses `R17-Ordinary-Art-Preview-20261023` user data and keeps its own
project settings. Real-save metadata stayed 1203 bytes / 1792682904815624900 ns;
the payload was not read or written. No new QA suite, export, image generation,
cleanup, commit or push occurred. Existing graph results still report
`metadata_changed`; direct source/caller inspection is authoritative.

## Antigravity production contribution

The human explicitly authorized CLI Gemini production collaboration. `agy 1.4.6`
reported `gemini-3.8-flash-medium` available; that exact slug was pinned. A neutral
temporary folder contained only six selected story excerpts and a task prompt.
The bounded sandboxed session owned one `story_events.patch.json`, while Codex
workers owned NPC copy and action feedback separately. No whole repository,
credential, private configuration or player save was supplied to the CLI.

Two CLI turns returned SUCCESS and OS exit 0. The first draft introduced
unsupported household identities, causal mechanisms and irreversible memory
loss. Root rejected those details and requested revision, then applied three
final editorial adjustments. Output was integrated only into the eighteen
approved prose fields; it was not treated as evidence of gameplay completion.

Reported CLI usage (provider accounting, not a monetary estimate):

| Turn | Input tokens | Output tokens | Cache-read tokens | Total tokens |
| --- | ---: | ---: | ---: | ---: |
| Initial production | 42,372 | 13,343 | 0 | 55,715 |
| Canon revision | 53,334 | 21,798 | 45,189 | 75,132 |

Current artifacts identify final integrated data; raw CLI working files remain
in the isolated temporary folder on the originating machine. Another platform
should discover its own CLI/model availability and use bounded file ownership.

## Recovered GUI QA and next work

[The recovered core report](../qa/gui_core_20261024.md) records 24/24 launcher
steps passed on an earlier source tree. Its passing snapshot is preserved;
later current story/runtime hashes differ. The current visual QA result and
scope are recorded in [`../QA_REPORT.md`](../QA_REPORT.md); it does not establish
a 12-outing walkthrough, measured pace, performance profile or export. Keep the full
[production ledger](../PRODUCTION_STATUS.md) open, with
[AI_HANDOFF.md](../../AI_HANDOFF.md) as the next-platform entrypoint.
