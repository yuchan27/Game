# Story-action and dialogue continuity

2026-10-24. Source-integrated fixes plus ordinary frozen native presentation.
[Snapshot](source_snapshot.json) records seven product-file changes,112 bounded
source/mirror input hashes and12 final PNGs. No actual player journey or QA ran.

## Resulting behavior

Old CampaignAction nodes could flush cached progress while exiting, after a load
had already replaced GameState. Current quest/route/outing checks did not reject
an older snapshot with the same action/run. Actions now capture a generation +
run/quest/route/outing owner and supply it on progress writes. Load/reset/new run/
settlement advance the transient generation; the exact runtime checkpoint now
includes it (36 fields plus raw expedition state). Failed-load rollback restores
old actor ownership. Existing two-argument synchronous progress updates remain.
No new save field, version, quest ID, reward or settlement rule was introduced.

Router flushes current-scene actions under cover **before** changing scene
identity or capturing/applying a load. This preserves normal departure progress
without granting departing actors a bypass around ordinary status validation.
Periodic writes and exit writes both retain the owner guard. Same-run escort
positions/checkpoints and carry/defend progress retain their former rules;
unpersisted current-wave enemy nodes are recreated by the existing runtime.
This describes reviewed source, not an exercised reload or extraction result.

NPC actor dialogue now uses owner-scoped request/close signals. HUD keeps only a
transient Node identity; Player routes E solely to that owner. First page advances,
last page closes, and one-page dialogue also closes with E. Esc/panel changes or
a report reset the former speaker's page/signature. Another NPC's range exit
cannot close the current report. Voice reset stops only an active speaker; all
current NPC voice_enabled flags remain false. Generic three-argument dialogue
signals and the data-only NPC text helper remain compatible. Positions, gifts,
chapter copy, returned choices and reading-pause contracts were preserved.

The first escort capture exposed a visible bridge beam hiding the follower's
body while the player stood clear. Active escort actors now register as
campaign_follower; Wasteland includes only its own visible, non-deleting followers
in the existing five-point BitMap/alpha0.32 occlusion fade. Player behavior and
0.2-second refresh cadence remain; no collision/path/architecture position or
raster source changed. The frozen fixture refreshes after creating the escort
because its world simulation is disabled; production uses the existing cadence.

## Native output and review

| Final render | Observed result | Evidence |
| --- | --- | --- |
|1024x768|session88347 exit0, six successful frames|[narrow.log](narrow.log)|
|1280x720|session33910 exit0, six successful frames|[wide.log](wide.log)|

No ERROR/WARNING lines observed. All112 listed source/mirror inputs and recipe/
stub hashes match; this list is bounded, not every asset. All12 PNGs are full
viewports. Independent Luna/max review opened all eight final NPC/report views;
parent reviewed the four field views and representative NPC controls. Final
dialogue/footer compositions fit both sizes. Reports retain vertical scrolling.
Native helper handoff logs report owner_id=0 and old_npc_active=false; this
exercises presentation cleanup, not E input or actual quest completion.

| View |1024x768|1280x720|
| --- | --- | --- |
|Alan first: next-page footer|[Image](1024x768/alan-first.png)|[Image](1280x720/alan-first.png)|
|Alan last: close footer|[Image](1024x768/alan-last.png)|[Image](1280x720/alan-last.png)|
|Generic report after Alan|[Image](1024x768/report-after-alan.png)|[Image](1280x720/report-after-alan.png)|
|Mia first|[Image](1024x768/mia-first.png)|[Image](1280x720/mia-first.png)|
|Frozen escort checkpoint|[Image](1024x768/escort-resume.png)|[Image](1280x720/escort-resume.png)|
|Frozen carry checkpoint|[Image](1024x768/carry-resume.png)|[Image](1280x720/carry-resume.png)|

Earlier sessions48395/50297 exited0 with six frame records each, but the escort
views were rejected for the obscured body. Their logs and two selected
[before images](rejected/) are retained. Final matched cameras show the follower
through the faded foreground structure. No contemporaneous full input manifest
was captured for those rejected drafts; they are visual comparison evidence.
Root also corrected the fixture's staged carry outing_index to1 with its earlier
outing's actions marked done before any engine execution; that draft was not run.

## Scope and reproduction

Use a separate mirror, custom user directory exactly
R17-Ordinary-Art-Preview-20261023. Copy [recipe](StorySeamsPreview.gd.txt) and
[stub](StorySeamsPreview.tscn.txt) without `.txt`. Verify Godot4.6.3, then run the
mirror with Compatibility, a supported resolution and absolute `--seams-output=`.
`--seams-views=` accepts a comma-separated subset. Use a new output directory
for later source; preserve historical frames/hashes and source project.godot.

Actors/world are disabled before entry; HUD/camera render while paused. NPC
page/near flags and field checkpoint/player/actor positions are direct RAM
staging. Existing copy/result builders and presentation helpers draw the views;
the recipe never invokes NPC _talk/interact or CampaignAction interaction,
completion or progress-write callbacks,
transaction/rollback, payload IO, rewards or settlement. Native world readiness
can initialize RAM layout pools. Action-view dialogue layout metadata describes
an invisible control, not a displayed NPC footer. Carry retains existing weapon/
payload art, not a newly authored carry animation or new character facing.

Independent source review covered generation, preflush, rollback and scoped
dialogue routing. Manual data inspection covered25 normalized action positions,
six route IDs and escort/carry endpoint dependencies; no data-proven spatial
blocker was found. Architecture/ground collisions do not share all campaign
reservations, and a covered route shortcuts a road junction. These are unverified
traversal limits, not confirmed blocked points or a pathfinding pass.

No actual E paging/close/reopen/range, one-time gifts, F9/load-old-same-run,
failed-load owner recovery, departure/extraction/death, combat/waves, collision,
balance/pacing, save migration/IO, performance/export or QA ran. Real-save stat
remains1203bytes/1792682904815624900ns; payload unread/unwritten. Future acceptance
must exercise those paths. Native destination _ready exceptions retain the
previously documented recovery boundary. Full production remains open.

繁體中文：已接入行動版本／擁有者防護、NPC 分頁與回報隔離，並修正護送隊員被
前景遮住的呈現。12張圖是RAM預置畫面，沒有實際通關、存讀檔或執行測試。
