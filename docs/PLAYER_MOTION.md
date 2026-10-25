# R-17 motion and combat presentation

Canonical motion contract, updated 2026-10-24. Exact active art/key counts belong
to the v2 manifests and `art-direction/r17_v2/PRODUCTION_STATUS.md`.
Traditional Chinese summary follows. Current production QA is deferred.

## Intent

Keep immediate PC movement and crisp pixel silhouettes. Simulation runs at 60 Hz
with Godot physics interpolation enabled for rendered movement between ticks.
This is not a claim of 60 distinct hand-drawn frames or guaranteed 60 FPS on every
machine. Frame-time evidence belongs in `RELEASE_READINESS.md`.

## Body and weapon contract

- The blue/gold helmet, crimson cape and eight viewing directions preserve R-17.
  The original PNGs and legacy animations remain available.
- `data/art/r17_presentation_v2.json` and `r17_weapon_families_v2.json` register
  integrated body, hands and held weapon per source/facing, with explicit crop,
  sole, grip, optional muzzle and standing normalization height. Source PNGs are
  unchanged. Action crouches retain the standing reference scale; raised weapons
  and shorter crouched bounds must not change the body scale.
- A 112-world-pixel stride selects each family's authored walk sequence.
  The phase advances with movement distance, survives direction changes and
  continues while strafing with a firearm. Body bob and native pose motion update
  every physics tick; pixel key poses are held between contacts.
- The approved v2 sources bake body, hands and weapon together at matching scale.
  Their unrelated icon overlay is hidden. Projectiles and muzzle flashes use the
  registered muzzle transformed by the rendered sprite. Missing family actions
  retain the existing legacy fallback; its separate weapon layer is temporary.
- Eight complete base camera facings remain registered. v019 adds nominal11.25
  degrees for blade idle only, making that action9 views; walk/strike and other
  families remain8. Per-action extra views use independently validated crop/
  sole/grip data and cached action-angle lists. Thirty-two at11.25-degree
  intervals across all requested actions remain a production requirement. Gait/action frames,
  timing slots and a new idle candidate do not increase the active facing count.
- Mouse aiming continues between shots. Each shot starts its recoil immediately
  and recovers over 0.24 seconds. Firearm cadence and projectile damage/count
  remain equipment data. Empty-ammo feedback is throttled while fire is held.
- Blade/heavy strikes have a 0.16-second anticipation, one impact, and a
  0.42-second presentation including recovery. Blade/heavy use windup, impact and
  ready with explicit 0.16/0.12/0.14-second timing. Alternating strokes reverse
  the native effect arc but currently share source poses; separately authored
  backhand keys remain open. A 0.12-second input buffer accepts a slightly early follow-up strike.
  Damage, range, knockback and cooldown continue to come from equipment/stats.
- Hit, death, dodge, a modal or changing action cancels a pending melee strike.
  Death and weapon switching also clear buffered input. A strike is consumed
  before damage callbacks, preventing duplicate impact on re-entry.
- V2 switch/interaction/hit currently reuse a ready source with native motion;
  fully authored action-specific keys remain open. Dodge costs six energy once and locks its travel
  direction; modal input locks stop an in-progress dodge. The existing death
  strip is retained as a compatibility fallback.

## Evidence and deferred verification

Ordinary isolated Player sheets for blade, rifle and heavy were rendered and
inspected; paths, source boundaries and logs are in the production checkpoint.
They establish art integration only. The current user explicitly deferred tests.

The retained `DirectionalPresentationRegression` historically checks source hashes, eight distinct views,
all three loadouts, grounded soles, grip/muzzle/depth agreement, anticipation,
single impact, cancellation, input buffer and recoil. Rendered runs additionally
save `directional_contact_sheet.png` and `player_motion_sheet.png`. The central
 launcher runs the functional regression headlessly. Its assumptions may require
 alignment with the v2 source contract before later use. The active full-production
 objective now authorizes affected QA; run it with isolated user/output paths and
 inspect current rendered sheets before accepting motion or grip quality.

## 繁體中文說明

主角以每秒 60 次物理更新與畫面插值移動；新版像素圖把身體、雙手和武器一起繪製，
搭配連續的身體起伏與後座力。走路步頻會跟速度一起變化，轉向不會
重置步伐，射擊時可以邊走邊瞄準。這不是 60 張獨立手繪逐格動畫。

近戰先起手再命中，受傷或閃避可以中斷尚未發生的攻擊；連擊支援短暫輸入緩衝。
刀、重武器、槍械使用各自的姿勢與手部／槍口對位；換裝等完整動作仍待補齊。
目前啟用八方向，32 個實際朝向尚未完成。這輪只做普通隔離美術展示，沒有執行測試。
