# Title and prologue identity

Updated: 2026-10-23. The source now carries the revised story and visual
direction. Ordinary isolated Title/Prologue renders at 1280×720 and 1024×768
were inspected in `captures/chapter-sites/`; this is local presentation review,
not full navigation/save behavior or player acceptance.

## Player-facing promise

The title and prologue introduce the first arc, **灰燼之後的名字**, through a
personal water crisis and R-17's damaged evacuation memory. The village water
supply is narrative urgency only: the campaign has no starvation or countdown
timer. The first outing gives the player a practical reason to leave and a
clear first task without claiming that every story clue is required by the
contract.

The title hook names Ada's empty cup, the south-gate evacuation bus, R-17, the
missing memory, and the six-region search. The prologue introduces Ada, Alan,
Old Chen, the red scarf, the matching bus and pipe-seal numbers, and the
evacuation manifest. Its first-trip directions preserve the campaign contract:
accept the 廢鐵公路 commission with J, use M to find the south gate, complete the
contract, and return to hand it in. Inspecting the bus with E is presented as
optional story evidence, not a completion requirement.

## Visual and interaction contract

Keep the current live wasteland backdrop, charcoal outer panel, and built-in
Godot controls. Use muted bronze for framing and selection, and a restrained
parchment inset for story text with dark ink. This ties the opening to the worn
medieval-industrial wasteland while keeping the story readable over the active
world art. Avoid the former cyan tactical-edition badge, voice playback claims,
and unearned sci-fi product copy. The opening is text-led; new recorded voice
work is outside the current campaign scope.

The title presents Continue (when a save is available), Begin New Run, and a
dedicated Exit Game button, in that order. The first available journey action
receives keyboard focus; Tab moves through the buttons and Enter confirms. The
prologue's village-entry button also receives focus and accepts Enter or mouse
input. The pause menu keeps its own Exit Game action for players already in a
run; the title action lets desktop players exit without entering the game.

Keep the existing PC keyboard and mouse instructions visible. Both panels stay
centered and clamp to the viewport with 24 logical pixels of clearance. The
title panel caps at 720×460; the prologue caps at 980×560. The three title
buttons remain in one vertical keyboard order within the existing panel. These
dimensions are intended for 1280×720 and 1024×768 layouts, with the same resize
handler used when the viewport changes.

## Preview and persistence boundary

`Main._show_intro()` builds the prologue presentation and starts its background
music; it does not reset `GameState`, mark the introduction as seen, or write a
save. For an isolated ordinary render, load Main normally and call
`_show_intro()` directly after `_ready()` has built the title. Do not call
`_new_game()` for a render: that method resets the current run. The prologue
button invokes `_finish_intro_to_game()`, which marks the introduction seen,
saves, and routes to the village; do not activate it during a read-only capture.

Continuing a saved run still goes through `SaveManager.load_game()` and the
existing `SceneRouter` destination. The new text and local UI styling do not
change save fields, quest IDs, rewards, or scene routing.

## Review limits

Source review was followed by the parent's isolated Godot renders at both
supported sizes. The parent and a separate read-only reviewer found the title
and prologue readable with all journey/exit controls within their panels. The
preview called `_show_intro()` directly; it did not activate New, Continue,
Exit or village entry. No automated test/QA suite or save-routing validation was
run. See `captures/chapter-sites/README.md` for the exact evidence boundary.
