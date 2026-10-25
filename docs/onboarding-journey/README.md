# Onboarding, controls and pause feedback

Historical source snapshot: later preparation/runtime edits are recorded in
[preparation-journey](../preparation-journey/README.md). Preserve these original
24 images and hashes; they do not identify the later product source.

2026-10-24, Asia/Taipei. The latest user stopped Gemini collaboration. Codex and
GPT-6-Luna/max workers implemented and reviewed this increment. Earlier returned
CLI drafts were available as untrusted input; no new Gemini call followed the
stop instruction. This is ordinary isolated presentation work, not a QA run.

## Integrated changes

- Main explains the actual first contract: J accepts in a hub, M views the map,
  and E at a physical gate departs or returns. Escort/hold-E relay work and the
  route-choice/coupling outing precede the original five defeats, twelve scrap,
  required field goal and single hub hand-in. The bus manifest stays optional;
  limited water starts at hand-in. The original emotional prologue is retained.
- Starting over with an existing save opens a cached native confirmation. Cancel
  is the default focused control and has no reset/save/travel callback. Confirm
  starts the old reset/intro path; the existing intro-finish save remains the
  overwrite point. The fixture directly opens the presentation helper, without
  exercising confirmation, cancellation or disk IO.
- J/K combat registrations were removed from GameState. Current defaults retain
  left-click primary, right-click ranged and Space melee, while J/K belong to
  contracts/notes. The guide removes unsupported arrow controls, boss shockwaves
  and guaranteed divine-weapon rewards. Shift dodge/sprint and EP rules match
  current source. Actual gameplay input remains unexercised.
- Help has a fixed header/close control and vertically scrolling wrapped content:
  current journey, five-step loop, two-outing hand-in, temporary drafts, chapter
  gates, water and new/legacy rules. Opening refreshes only read-only state.
  Legacy-trip clues count immediately; new unbanked clues require extraction.
  Help now acquires the existing reading pause: the old input lock stopped the
  player while enemy/projectile physics could continue. Tutorial ownership also
  participates in dialogue handoff and HUD exit; an external pause is retained.
- Pause shows save/load results inside its own scroll content. Existing IO calls
  and five buttons remain. Returning to title or quitting gains no automatic
  save. Status text explains that a field snapshot does not bank haul. Feedback
  scrolls into view without forcing a wrapped Label's minimum size.

## Evidence

[Source snapshot](source_snapshot.json) records112 matching listed source/mirror
inputs, three changed product files, recipe/scene/log/image hashes and historical
CLI receipt fields individually. These inputs are bounded, not every asset.
The dedicated mirror retains its separate custom user directory.

Final ordinary renders used Godot `4.6.3.stable.official.7d41c59c4`, Compatibility
on Intel Arc140V. Wide session69006 and narrow session84525 both exited0, with12
successful frame records each and no observed ERROR/WARNING lines.24 PNGs cover
title, staged load failure, confirmation, prologue, four help views and four
pause views at1280x720 and1024x768. Final pause rectangles are480x520 at(400,100)
and(272,124); every default/success/failure capture stays inside the viewport.

Independent review covered eight Main views on the same presentation source,
all eight pause views after the fit repair, and all eight final help images after
the pause-header change. The lead also inspected both narrow controls/journey views
and targeted final states. No visible blocker was found in this bounded set.

Examples: [narrow prologue](1024x768/prologue.png),
[narrow help loop](1024x768/help-journey.png),
[narrow legacy rules](1024x768/help-legacy.png),
[narrow save failure](1024x768/pause-save-failed.png).

## Rejected output and limits

The first recipe failed Variant inference and produced no valid image; its
renderer was identified and stopped, exit-1. [Draft parse log](wide-draft-parse.log)
is preserved. The next wide/narrow renders exited0 but their pause frames showed
an outer panel extending below the viewport. Those outputs were rejected:
[wide draft](wide-draft-layout.log), [narrow draft](narrow-draft-layout.log).
Moving status into ScrollContainer and removing `reset_size()` fixed the final
composition. An exit0 alone did not establish acceptable layout.

The [recipe](OnboardingJourneyPreview.gd.txt) freezes Main/Village simulation,
uses presentation-only helpers and assigns legacy/field state in RAM. Save/load
feedback is synthetic, using actual product messages. It performs no real input,
new-game confirmation/cancel, attack, action, quest, reward, extraction, death,
save/load payload access, migration, collision, pacing, FPS, export or QA. Title
checks only file-existence metadata in the isolated user directory. Default
keyboard focus is source-reviewed, not proven from screenshots. Real-save stat
remains1203bytes/1792682904815624900ns; its payload was not read or written.
Help's native helper acquires pause in the frozen scene and logs both tree and
owner flags as true. That does not exercise an enemy attack or live pause switches.

The preceding [map/label record](../ui-label-composition/README.md) retains its
historical26 PNGs and original112-input identity. All-interface, full campaign,
world-art,32-facing and release acceptance remain open.

繁體中文：這批將序章、操作與撤離交付說明接到目前玩法，加入重開進度確認、
暫停選單內的存讀檔回饋，並移除J/K攻擊衝突。24張隔離預置畫面已檢視；
曾發現並修正暫停外框超出畫面。尚未實際操作確認、戰鬥、存讀檔或通關。
