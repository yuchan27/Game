# Single intermediate blade facing checkpoint

2026-10-23. Candidate production only. No tests/QA or runtime integration.

## Result and current boundary

Built-in imagegen produced one new idle candidate requested at E22.5, using
`source/r17_blade_idle_v011.png` as the accepted E0/SE45 perspective reference
and `source/r17_blade_contact_a_v007.png` as the approved character identity.
The candidate has a visibly narrow front helmet/cross plane, a compressed far
shoulder and a chest plane intermediate between the two approved views. It is
useful for the next art decision. Exact camera azimuth cannot be certified from
a generated drawing; this is not an accepted 32-facing production atlas.

Parent decision: approved as a visually intermediate identity reference only.
It remains inactive and is not certified as exact22.5 degrees. No active
facing count or runtime integration follows from this art-reference approval.

The raw 1024x1536 RGBA image is preserved byte-for-byte at
`assets/sprites/player/redesign_v2/source/angular_candidates/r17_blade_idle_e22_5_v017.png`.
SHA256: `b4df7433c2ba92d90e96ecf21188f8621e2042329052ee1a0fc1f8ca8e583a70`.
The exact generation prompt is `angular_e22_5_v017_prompt.txt` beside this file.
No flat rotation, mirroring or anatomical repainting was used. Alpha clipping in
the preview matches the existing native presentation; source alpha is unchanged.

Crop: `[0,0,1024,1536]`. Manual sole preview registration: `(590,1338)`;
head crown y184, body height1154. These are source-image coordinates. Grip is
not registered and no runtime cell was created. All original approved sources,
Player code and active manifests were left untouched by this bounded task.

## Ordinary art comparison

`angular_e22_5_v017_comparison.png` shows approved E0, candidate v017, approved
SE45 side by side at 288px and 96px body heights. The latter is the current
gameplay body scale. It was rendered by the separate source-only project
`angular_e22_5_preview/project.godot`, using Godot
`4.6.3.stable.official.7d41c59c4`, Compatibility, Intel Arc140V, exit0.
The source-only renderer uses its own custom user directory and never opens
the real player save. This is art-production output, not gameplay validation.

## Resume on another platform

1. Read repository `AGENTS.md`, `AI_HANDOFF.md`, this checkpoint and the active
   blade manifest before changing art. Eight actual active facings remain.
2. Inspect the saved comparison and obtain the integration owner's decision.
   If accepted as a visually intermediate drawing, preserve the exact-degree
   limitation and register its actual grip/crop through that owner's schema.
3. Keep v016 outside active runtime. Its E22.5 view repeats the E0 profile too
   closely; its later views also drift. Its eight labels do not prove eight
   uniformly intermediate views.
4. Twenty-four intermediate active facings remain unfulfilled: 11.25,22.5,33.75;
   56.25,67.5,78.75; 101.25,112.5,123.75; 146.25,157.5,168.75;
   191.25,202.5,213.75; 236.25,247.5,258.75; 281.25,292.5,303.75;
   326.25,337.5,348.75 degrees. This isolated requested E22.5 candidate does not
   remove an angle from that active-production list.
5. Generate one bounded, reviewed perspective at a time if a complete batch
   drifts. Keep identity, perspective, pixels, handedness and sole plane
   coherent. Never derive new camera views by mirroring/rotating flat sprites.

The project is portable; only the optional local preview source currently uses
this machine's absolute root. Change its `ROOT` constant on another platform.
No API key or paid CLI fallback is required for the saved source/prompt.
