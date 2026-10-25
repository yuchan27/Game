# Campaign and scene design — 灰燼之後的名字

Updated: 2026-10-25 (Asia/Taipei). This document records the integrated six-contract story bridge and the source-authored campaign outing sequence. Isolated Godot 4.6.3 GUI journeys verify the complete first contract (109/109 checks) and Chapter 2 (50/50 checks): two outings each, real extraction, Guild hand-in, isolated save reload and duplicate-reward prevention. The first-contract journey used 818 injected keyboard events and nine successful SceneRouter transitions. These are automated input journeys, not human playtesting, full campaign acceptance, death recovery, route balance or measured pacing. See [QA_REPORT.md](QA_REPORT.md) for the exact reports and limits.

The player selected a story-driven expedition roguelite with temporary abilities, varied mission actions, and persistent hub and story progress. The six chapters contain two outings each (12 total), represented by 25 ordered actions under the existing quest IDs. The first tutorial outing target of 6–8 minutes and regular outing target of 12–18 minutes are editorial estimates, not measured play times. The v5 run-haul ledger, extraction/death settlement, outing-action runtime, and optional two-site drafting are source-integrated. Isolated input journeys passed 109/109 checks for the first contract and 50/50 for Chapter 2, covering both outings, Guild hand-in and isolated save reload for each. These journeys do not establish human playtesting, death-loss behavior, the remaining four chapters, balance, the Chapter 2 alternative choice, or target play times. See [QA_REPORT.md](QA_REPORT.md) for their reports and limits.

The data keeps the six main quest IDs and six story-event IDs, and adds `campaign_outings` under the six main contracts: two outings and 25 actions total. The first contract also has a separate registered field objective, `highway_bypass_repair` on `scrap_highway`. Existing kill/material/discovery objectives, prerequisites, reward quantities and the first four optional clues remain as before. Active saves that predate the first contract's field-objective marker keep their old completion rules and are not forced into the new outing actions. Completing the outing sequence does not bypass the original objectives or the existing one-time Guild hand-in/reward. The verified first-contract and Chapter 2 journeys confirm the current debrief flow, physical Guild hand-in, optional-clue non-revelation and one-time settlement after save reload. Chapter 2's settle-sample branch and Chapters 3–6 still need journey acceptance.

## The story to tell

After the village well stops, residents follow a ration schedule; there is no in-game water countdown. Outing 1A reconnects the south-gate bypass but brings back only its readings and sealed test sample; outing 1B brings the replacement coupling after the recovery crew has already returned. Neither outing changes village water. Only the first-main hand-in, after both outings and the original contract objectives, lets Chen install the coupling and Ada approve a small, limited trickle. The final facility outing runs a controlled bypass test, but finite stable water appears only after the final-main hand-in. Both stages retain rationing; no water currency or timer is added. No one knows whether the full route is safe. In the collapse, a contamination alarm led human operators to send treated water to an underground shelter and isolate outer branches. That protected the shelter and cut off households beyond the barrier. The people who could reassess the choice are gone; an automated custodian has kept the emergency closure in force ever since.

R-17 held an evacuation door long enough for Alan and his mother Liu Qing to reach safety. Main’s prologue and Alan’s opening dialogue now recognize R-17 early; the child's red scarf belongs to Alan, while R-17 wears a separate crimson cape. The question is not who the child was. It is what the emergency allocation did to the people outside, what R-17 could know at the time, and why a temporary quarantine became a permanent rule. The evidence should clarify that decision without absolving R-17 or turning the custodian into a secretly evil machine. Quest/event/NPC copy now follows this direction. Staged presentation can show the copy, but actual dialogue interaction and the full campaign have not been exercised in this pass.

The authored campaign moves from emergency repair to measured investigation, then to a present-day decision about water distribution. Reading a chain of terminals is never the mission. Each outing changes something that can be seen or used: a pump, a route, a signal, a threat, a map, or the tested water supply. The optional draft fits the salvage loop as field tuning with equipment recovered at an exploration site: it changes how R-17 uses existing abilities for one run without adding a canon revelation or permanent village upgrade. Action records are source-integrated; ordinary runtime review remains open.

## Campaign structure

Each chapter has two authored outings. Evidence comes through an action, with K offering optional concise reading; no chapter requires a long log read to advance. Combat and salvage support an outing but do not substitute for its signature action. The integrated temporary packages add levels to existing effects and do not gate contract actions. The outings use escort, carry, channel, defend and choice actions. They do not introduce temporary abilities such as barriers or pulses, nor extra mission gates beyond the authored action sequence.

| Chapter and route | Outing A | Outing B | Story result and bounded status |
| --- | --- | --- | --- |
| **1. 第一口水 — 村莊 / 廢鐵公路** | **南門護送與旁路試運：** 村民依配水表輪供，沒有缺水倒數。護送回收隊到旁路、接通臨時手動迴路，帶回旁路讀數與限量水樣；村內配給不變。 | **帶回正式接頭：** 回收隊已在上一趟返村待命，由 R-17 獨自選中央暴露短路（遭遇較多；選擇時把兩份變異藥草列入本趟攜回清單，安全返村後入庫）或掩蔽長路（遭遇較少，沒有額外補給），沿北行主路把正式替換接頭帶回。原合約擊退污染體 5 名、回收廢鐵 12 份是整章合計，可跨兩趟累積；安全返村才保留當趟成果。 | 完成兩趟、必需現場目標與原合約要求後交付，老陳才安裝接頭，艾達驗水後恢復有限細流，配給仍照表輪供。巴士名冊選讀，不阻擋交付；首章的實際兩趟與物理櫃台交付已由隔離注入輸入流程驗收。 |
| **2. 量水，不讀水 — 毒沼** | **泵站雙點取樣：** 封存上游水樣，再校準回流水樣，比較兩處讀數。舊合約仍要求收集兩枚生物晶體、擊敗三名敵人；帳冊線索仍可選讀。 | **控制第一輪回流：** 選沉降方案（回流閥按住 E 8 秒；選擇時把兩份變異藥草列入本趟攜回清單）或快速排氣（按住 E 3.5 秒；選擇時把四發彈藥列入本趟攜回清單），再開啟受控回流閥取得水樣；選擇所得物資安全返村後入庫。這是小流量取樣，不改變村莊配給。 | 取樣只提供兩處讀數及差異，尚不能確認污染來源、整條水路安全或歷史分流原因。西門帳本是選讀線索，才揭露污染警報下有人員手動將處理水留給地下避難所並隔離外線；帳本沒有複測紀錄。 |
| **3. 回波有方向 — 紫晶裂隙** | **裂隙共振校準：** 校準南側端點並重播門控回波。舊合約仍要求擊敗六名敵人、收集三枚生物晶體；訊號殘響仍是選讀。 | **帶回充能中繼器：** A 趟已核對回波；B 趟把充能設備搬到南側入口接線點，再守住輸出以保存副本。中繼器留在接線點；防守完成後，沿主路前往北側遠端回村門，靠近按 E 才完成撤離。 | 回波核對艾倫與柳青通過出口、R-17 撐住門扇的那一刻，並指向工廠警報；它不把艾倫的身分留作終章反轉。 |
| **4. 關門的理由 — 舊工廠** | **隔離舊警報：** 隔離污染警報分支，再讀操作員封鎖命令與未填的覆核欄。舊合約仍要求擊敗八名敵人與首領、收集兩枚變異核心；黑盒可選讀。 | **開啟並守住洩壓通道：** 手動洩壓，守住通道直到壓力回穩。這是主線行動；既有 `factory_sabotage` 支線仍是獨立的警報節點及後續普通敵人上限效果。 | 操作員因當時污染讀數把水留給避難所、隔離外線，並要求複測重開；程序卻沒有期限或覆核者。守門者仍沿用這份舊令。 |
| **5. 被截斷的街區 — 崩毀都心** | **逐戶補畫配水圖：** 接通都心底圖，先載入街區支線；再由下一步逐戶標出缺水欄。舊合約仍在前四主線完成後要求發現檔案、擊敗五名敵人、收集兩枚精密晶片。 | **封存兩份名冊：** 複製名冊；艾倫只決定自己的姓名是否公開。現有紀錄沒有柳青本人同意公開姓名的證明，她和其他住戶姓名留在受限公會副本；兩種選擇都公開受影響街區、配水線與戶號。 | Alan 已在開場被認出；這裡讓他決定自己的姓名公開範圍，不替柳青或其他住戶同意，也不隱去街區與戶號。 |
| **6. 閥門由人來開 — 地下設施** | **複測警報與隔離旗標：** 比對舊警報門檻與新水樣，標記缺乏複核的封鎖旗標。舊合約仍要求發現指定事件、擊敗首領並帶回一枚發電機核心。 | **有限供水實測：** 啟動受控旁路、守住艾達取樣期間的水壓，再記錄優先支援診療所（選擇時把兩份變異藥草列入本趟攜回清單）或優先安排村蓄水槽接口整修（四份廢鐵）；安全返村後入庫。這是支援優先次序，不是當場修好設施。 | 兩趟行動只留下測試紀錄；完成原目標並最終交付後，才呈現有限穩定供水與公開帳目。配給仍按表輪供，選擇只記錄支援優先次序並增加本趟攜回物資，不提供無限水或分支結局。 |

三個防守行動的初始計時值為：`ch3b_defend_relay` 18 秒、`ch4b_hold_vent`
24 秒、`ch6b_hold_supply` 30 秒；清除威脅期間停表。這些是尚未平衡、
也未經遊玩驗收的設計初值。

The 12 outings and 25 ordered actions are source-authored under the existing
six main quest IDs, not new quest IDs. Existing side IDs, rewards, required
kill/collect/discovery objectives, prerequisites, and the first four optional
clues remain unchanged. A previously active contract is not retroactively
forced into the new outing flow. The outings add action progress; they do not
replace the old contract requirements or its single existing Guild hand-in.
Successful extraction commits only actions completed in the run. A partial
extraction keeps completed actions for later, while an unfinished timed action
starts over on a later run. Death discards the current run's haul and unextracted
actions, but keeps steps committed by earlier extractions. Choice-item rewards
are run haul, not extra contract rewards. The Guild board E-open and J-page
accept/claim button path now has an automated input pass; mission objectives in
that test are staged, and route actions, choice outcomes and extraction remain
unverified. See [GAME_DESIGN.md](GAME_DESIGN.md) for the canonical gameplay and
save rules.

## First 30 minutes

Continuity support is now source-integrated: live action nodes cannot write into
a replaced loaded run, and NPC dialogue closes/reopens at a clear page boundary
without replacing a shared quest report. This changes interaction ownership,
not the authored12 outings/25 actions, choices or rewards. Canonical runtime rules
and evidence are in [GAME_DESIGN](GAME_DESIGN.md) and
[continuity record](story-seams/README.md); actual interaction remains unexercised.

These are target pacing beats, not measured runtime or a live walkthrough:

- **0–2 min:** Alan recognizes R-17 and names the unresolved harm; the village needs a practical repair before a history lecture.
- **2–4 min:** Ada identifies the failing south bypass and Mia issues the contract. Teach movement and interaction as the player heads to the recovery crew.
- **4–6 min:** Prepare equipment and learn the combat/interact/return loop. The two-site field draft may be offered at existing route sites; its actual encounter and timing remain unreviewed.
- **6–14 min:** Editorial tutorial outing target: escort the recovery crew to the bypass, repair the relay, and complete the contract's existing scrap/defeat work. The bus manifest remains optional evidence.
- **14–17 min:** Extract, review the run, and prepare at the village/Guild. Completed outing actions should carry forward; a first-main hand-in is still gated by both authored outings and the old contract requirements.
- **17–30 min:** Begin the coupling return outing: the recovery crew is already back at the village, and R-17 travels alone. Choosing the short exposed route brings more ambush pressure and adds two mutant herbs to the trip's haul for banking after a safe return; the longer covered route has fewer encounters and no bonus supplies. Carry the coupling home. Minute marks are pacing targets only; no measured playtime is available.

## Agency and the ending

六章返村收尾現在有獨立的角色對話：第一口水帶來當下的喘息，毒沼讓艾倫
面對避難所得水與外線斷水的關係，裂隙把感謝與追查分開，工廠讓米婭承認
公會漏記住戶，都心由艾倫決定自己的姓名是否公開、並補回街區與戶號紀錄，
設施以有限輪供與繼續記錄收尾。
這些是交付回報中的文字場景，沒有新增過場動畫或角色配音。

新收尾必須同時有已完成委託與既有的行動結案標記，舊存檔保留原回報。
艾倫、艾達與米婭各補上四段章節間回應，共十二段；只在沒有進行中委託，
且確有對應行動結案紀錄時使用。K 手記可展開章節回顧，不重新領獎或寫檔。
回顧是當時的故事，現在應做什麼仍看 J；前四章可依原規則自由承接。
[章節收尾畫面紀錄](chapter-resolution/README.md) 保存本輪呈現與限制。

後續已用 Antigravity CLI 的 Gemini 3.8 Flash 協作六筆調查事件，經主代理退修
與整合。公路名冊、泵站帳本、裂隙回波、工廠命令、都心戶號與設施舊日誌
各保留不同物證，沒有新增住戶身分、死亡結論或記憶永久消失的設定。
十二段章節間對話也已移除固定下一站，實際下一步交由任務狀態提供。
例如先完成工廠時，艾倫仍能回應封鎖命令，但提示會指回尚未完成的南門委託，
不要求玩家進入尚未解鎖的都心。[本輪呈現與協作紀錄](story-continuation/README.md)
清楚區分預置介面、已追回的 core QA 報告與仍待遊玩的完整旅程。

Keep choices few, legible, and material.

- The chapter-one route choice already has a clear data consequence: the recovery crew returns during outing A; R-17 alone carries the coupling in outing B. The exposed short route has more ambush waves and selecting it adds two mutant herbs to the provisional haul, banked only after safe return; the longer covered route has fewer waves and no extra supplies.
- The existing factory sabotage side contract still cuts the alarm node and lowers future normal-enemy capacity. It remains separate from the main story's isolation and vent-defense actions.
- In the city, Alan's consent governs only his own name. The current record has no Liu Qing consent to publish her name; hers and other residents' names stay in the restricted Guild copy. Both options keep the affected districts, water lines and household numbers public.
- The final hand-in and K ending read Alan's saved City choice. The choice IDs remain stable, but an older `ch5b_publish_consent` selection now publishes Alan's name only. A legacy completion without a recorded choice receives neutral archive wording rather than invented consent. The limited-water outcome remains the same.
- At the final manifold, the choice records clinic-first support (two mutant herbs added to the provisional haul) or priority for a cistern-interface repair (four scrap added to the provisional haul). Neither performs the repair immediately; the selected supplies bank only after safe return. Both retain finite scheduled water, one authored ending, and the same public account.

Do not promise alternate endings. The resolution is that the village has a limited safe supply and a more honest account of its origin. The earlier choices change preparation, recorded support priorities, and how people respond to R-17. The game does not need to claim that one planned pipe repair erases the old allocation or that every memory is restored.

## Existing cast: motives and sample lines

These are target lines for the current named cast. They are not present-day dialogue claims.

| Character | Independent motive | Sample Traditional Chinese line |
| --- | --- | --- |
| **艾達** | Wants safe water, not a fast-looking pressure reading; she will not send villagers to an untested outlet. | 「有水不等於能喝。上游和出口各取一份樣本，先讓讀數自己說話。」 |
| **艾倫** | Knows R-17 saved him and Liu Qing. Wants the harm to other households faced honestly, not a heroic story that asks him to forgive. | 「我認得你，R-17。你把我和我媽帶過那道門；外面的水閘為什麼關上，我還不知道。先查清楚，不用先求我原諒。」 |
| **米婭** | Wants the Guild to own the route plan and return risk instead of treating a water network as a salvage contract. | 「公會把這條線登成廢料路。帶回閥位和可走的路，我才敢把它改成供水委託。」 |
| **鍛造老陳** | Must divide scarce alloy between a working pump and expedition protection. | 「這批合金只夠先做泵軸或護甲扣。你告訴我哪一樣能讓下一趟少一個人受傷。」 |
| **補給商阿洛** | Keeps supplies available by tracking what the Guild borrows and what a run actually consumes. | 「濾芯我可以先記在公會帳上。用掉幾枚，回來就照實報；下趟的彈藥也得留著。」 |
| **路線斥候赫伯** | Wants a route a squad can return from, not the shortest line on a map. | 「低路省時間，回程沒掩體。高線多繞一段，至少看得見追兵。」 |

In the authored campaign, Alan recognizes R-17 in the opening and the public account is earned across the outings: see the pressure failure, measure the water, follow the signal, inspect the isolation command, and compare the distribution map. The current quest/event/NPC copy follows this arc and the prologue introduces the practical repair first. The outing action data is integrated; the ordinary full sequence remains pending runtime review.

## Authoring constraints

- Keep Alan's childhood red scarf separate from R-17's crimson cape. The evacuation manifest, human water allocation, and R-17 escort are continuity anchors; presenting a delayed identity twist as live is not.
- Treat a discovered clue's `紀錄指向` as a later lead, not the immediate action. If a clue can appear during a multi-outing chapter, state that the remaining outings and required contract goals still precede the village hand-in; J remains the source for the immediate next step.
- Deliver a clue in the action that earns it. K may preserve an optional reading for replay, but no six-stop terminal-reading chain.
- Give every outing a primary verb beyond defeating enemies and gathering materials. Keep fights to make the action dangerous and the temporary ability choices relevant.
- The bridge derives visible water states at first-main and final hand-in. Chapter 1A's test readings and 1B's coupling do not change the village water stage; only the first-main hand-in after all goals creates the trickle. The chapter-six hand-in creates the final finite supply after its controlled test and existing contract goals.
- This is source behavior, not an exercised return or hand-in. Rationing remains, and no outing result by itself changes village water.
- Keep the chapter flow and save mapping in the existing game architecture. This target does not require a story engine, cinematic scenes, new voice work, or an additional ending system.
- The current game has six route regions and an expedition/return loop. Refer to [GAME_DESIGN.md](GAME_DESIGN.md) for the gameplay and save contract. The duration estimates above have not been playtested.

## Appendix A — current source snapshot and integrated bridge

The current data implements six main contracts, six story events, and two authored campaign outings under each main contract. The action model is integrated in source; runtime review remains open.

- Main quest IDs in [data/maps/quests.json](../data/maps/quests.json): clear_scrap_route, toxic_sample, crystal_scar_recon, old_factory_core, metropolis_archive, and facility_memory.
- Existing side quest IDs in the same file: drainage_rescue and factory_sabotage. Their field actions are separate from the six-chapter target. The factory sabotage currently reduces the old-factory normal-enemy spawn cap.
- The current six story event IDs in [data/maps/events.json](../data/maps/events.json) are story_scrap_manifest, story_marsh_ledger, story_crystal_echo, story_factory_blackbox, story_metropolis_archive, and story_facility_memory. The first four discoveries are optional quest objectives in the current data; city and facility discoveries are required. City completion currently requires the four earlier main contracts, and facility completion requires the city contract.
- The six events now tell a consistent account: R-17 escorted Alan and Liu Qing; Alan's childhood scarf is separate from R-17's crimson cape; contaminated sensor readings prompted human operators to reserve treated water for the shelter and isolate outer households; no later review was recorded; the custodian persists with that stale order. The required city/facility findings and the first four optional discoveries keep their existing status.
- `clear_scrap_route` now has one field objective, `highway_bypass_repair`, on `scrap_highway`. `GameState` sets its `field_objective_version` marker for new acceptances. An older active save without the marker keeps its previous requirements and receives `legacy_completion_text`, which credits Chen with using returned salvage to connect a temporary line instead of claiming that the player repaired it.
- All six main IDs, both side IDs, six event IDs, existing rewards, required defeat/collect/discovery conditions, and prerequisites remain unchanged. The first four story discoveries are still optional. Each main quest contains two `campaign_outings` (12 total) with 25 ordered actions: escort/repair, route choice/carry, sample/flush, resonator/relay, alarm/vent, map/register, and sensor/supply test. Every action has `interaction_verb`, `instruction`, `active_instruction` and `result_text`; the two carry records reference existing payload icons `broken_coil` and `precision_chip`. These actions do not replace old contract requirements or the single Guild hand-in. Existing active quests are not retroactively forced into the new outings. The side contract `factory_sabotage` retains its separate alarm-node action and normal-enemy-cap effect.
- Each route's first two existing exploration points carry one run-local draft milestone. At a new unclaimed site, the offer follows guard clearance and crediting existing loot; a previously claimed site can offer in a later run without duplicate loot. Three packages each raise two existing effects by +1. The same package can be selected at both sites or mixed with another; a pending choice survives panel dismissal/reload and a new site does not overwrite it. No mission gate, currency, reroll or permanent perk change is added. Temporary Salvager bonuses affect field pickup benefits, not hub disassembly; the permanent Scavenger perk keeps its current effect. Legacy v1–v4 trips receive no draft before their first return, and pre-draft v5 saves default missing draft fields to empty.
- [data/maps/npcs.json](../data/maps/npcs.json) now gives Alan immediate recognition and the existing cast useful active/ready/discovery/completion responses, including 12 `requires_campaign_outing` lines and six `requires_campaign_finished` lines. `GameState` resolves those gates. Main’s prologue and K’s premise agree. NPC IDs, gifts, positions, roles and disabled old-voice settings are preserved. Village’s water stages derive from the existing first/final hand-ins and need no extra water-state field. The current save version is 5 with its existing v1–v4 load path; the campaign marker described below is optional and does not add a version or autoload.
- Active-step hints refresh only when an action starts or reaches a checkpoint. The J contract panel and K codex can expand field notes labeled `本趟待帶回` or `已帶回`. Active quest notes combine previously extracted `quest_progress.campaign.actions` with the current run; completed quests reconstruct notes from saved choices only when `route_states[route].campaign_completed` names that completed quest. Legacy completed quests without the marker receive no invented notes. The validator requires the marker's quest to be complete on that route and every authored choice to have a legal value.
- Ada, Alan, Mia, Chen, A-Luo, and Herbert are existing Village/Guild NPCs; the sample lines above are story copy examples, not proof of a played dialogue path. The six existing contracts retain their defeat/collect/event objectives and original reward behavior, alongside the authored outing actions for new progression.

## Appendix B — existing story art references

The story art referenced by the earlier implementation notes remains unchanged:

- assets/sprites/props/expanded/evacuation_archive.png — native 1312×1199; world envelope 248×226. Its focal details are the municipal archive, paper lists, route display, and a child's red scarf.
- assets/sprites/props/expanded/memory_vault.png — native 1536×1024; world envelope 264×176. It depicts the water-purification/memory vault with valves, a cyan lens, and surviving seedlings.
- Related art records remain under [docs/art-direction/world_v4/late_story_courts.md](art-direction/world_v4/late_story_courts.md) and [docs/art-direction/world_v4/city_street_block.md](art-direction/world_v4/city_street_block.md). Those art records are bounded reviews of their listed captures, not acceptance of the full world or campaign runtime.

The historical image prompts for the two existing props are retained below as production-input references, not in-game text.

**Evacuation archive**

> Use case: stylized-concept. Asset type: game world landmark sprite, isolated transparent PNG. Primary request: a derelict municipal evacuation archive kiosk for a medieval-industrial wasteland pixel-art RPG, containing a scratched cyan route display, pigeonhole drawers full of faded paper evacuation lists, brass loudspeaker horn, a weathered canvas awning and dark riveted iron frame. A small child's red scarf is tied to one drawer, the narrative focal point. Rusty gray-brown metal, muted slate stone base, warm parchment, restrained cyan screen. Three-quarter overhead RPG camera, approximately 30 degree downward view, ground aligned horizontal rather than isometric diamond; visible top and front face. Whole subject fully in frame with 10 percent clear transparent padding, grounded feet and small tight contact shadow only. Pixel-art medium, crisp clustered pixels, handmade 16-bit RPG asset, coherent strong silhouette, detail readable when displayed at 220 pixels wide. No people, no letters, no text, no background, no tile ground plane, no UI, no photorealism, no smooth 3D shading, no watermark.

**Memory vault**

> Use case: stylized-concept. Asset type: isolated game environment landmark sprite for Wasteland Recycler, a medieval-industrial wasteland pixel-art RPG. Primary request: a dormant underground memory and water-purification vault, one compact squat brass-and-dark-iron shrine machine with two thick vertical clear glass preservation cylinders holding tiny green seedlings, a central circular cyan memory lens, stout pipe valves along a stone plinth, and broken red emergency beacon. This is where a guardian knight restores the village's water and recovers evacuation testimony. Must look like a functional repaired relic with rust and scratches, hope in surviving seedlings, rather than a magical treasure chest. Three-quarter overhead RPG camera, approximately 30 degree downward view with visible top and front, horizontal ground aligned composition, whole subject fully in frame with 10 percent transparent padding. Strong compact silhouette, crisp clustered pixel-art 16-bit game style, readable at 220 pixels wide. Muted iron gray, oxidized brass, restrained turquoise light and fresh tiny green leaves, narrow tight contact shadow. No people, no text, no glyphs, no UI, no background, no ground tile, no smooth 3D look, no watermark. Truly transparent PNG.

## Review boundary

The source integrates six-contract quest/event/NPC prose, prologue recognition, the first highway bypass field objective, journey/water guidance, v5 run-haul and outing settlement, 12 campaign outings with 25 actions, J/K field notes, and optional per-route chapter-completion markers. Successful partial extraction commits completed outing actions; unfinished timed actions restart on a later run; death loses the current unextracted run while earlier extracted actions remain. Original objectives and the single hand-in/reward remain required. No outing changes village water before the corresponding main-contract hand-in.

Both NPC entry paths now share `GameState.campaign_npc_record()`; the actual `DialogueNpc._talk()` includes returned choices before comparing its dialogue signature. Authored campaigns ignore stale generic earlier-chapter advice and use the current outing or a neutral line plus current journey hint. Compact world labels carry progress; full instructions stay in HUD/J and results in J/K. [journey-guidance/README.md](journey-guidance/README.md) records 26 staged PNGs at two sizes, two render exits 0 and 112 matching listed inputs. The NPC frame composes the same first-line/record presentation directly; it does not perform E interaction, gift handling or page reset. No player journey, save/load, migration, balance or QA acceptance is claimed, and the real save was not written.

Chapter completion/preparation copy now treats free-order chapter clues as
evidence rather than fixed next-quest commands. The completion report already
appends the current journey hint, so J remains authoritative for the immediate
next step. Chapter 5's debrief describes its register handoff and Alan's
verification as completed before equipment preparation for the Facility chapter.
When a delivered campaign contract also has a discovered optional story
objective, `quest_completion_story()` now retains the authored chapter ending
and appends that event's revelation to Mia's Guild record. This closes the
Chapter 1 bus-manifest hand-in seam without changing quest IDs or save data; the
source change has not yet been runtime-verified.

The return-feedback continuation names extracted/lost steps and the first
unfinished action after a partial return, plus side-contract field outcomes.
K retains one expandable last-report view using the existing saved result;
reopening it does not grant resources or advance a quest. The report is marked
as its historical state, with current goals in J. `quest_completion_story()`
supplies both the ending dialogue and K premise, keeping the same saved consent
scope. Hand-in autosave failure is now surfaced in the report, with source
review only for actual IO behavior. The newer ordinary staged views are recorded
in [return-consequences/README.md](return-consequences/README.md); the guidance
snapshot above is historical and its hashes remain unchanged.

進場交代現在沿用實際趟次與 HUD／J 的下一步：第一次公路行動交代護送，
第二趟已選路後交代搬運；走到別區時會指出目前委託不計入這條路線。
返村與進公會時也顯示當前接續工作。文字最多停留三秒再淡出，可立即略過；
轉場期間 HUD 通知與快捷鍵讓位給進場畫面。
[arrival-briefing/README.md](arrival-briefing/README.md) 記錄十張預置畫面，
不代表實際轉場、按鍵、計時手感或完整旅程已驗收。

章節兩趟行動與原委託條件在 J 中分列：已帶回的趟次、仍缺的材料與擊敗數、
必需調查、以及不阻擋交付的選讀線索。野外數字包含本趟尚未帶回的成果，
G 顯示目前主線時也使用相同數字。最後一趟已做完但原條件不足時，下一步會
先指出缺項，讓玩家決定繼續補齊或先撤離；全部齊備則提示返村交付，沒有
憑空再安排一趟。這次沒有更動材料數量、報酬或舊委託條件。
[contract-readiness/README.md](contract-readiness/README.md) 保存預置介面紀錄；
仍須實際遊玩才能判斷清剿／材料需求是否造成多餘折返。

六條路線的返村閘門現在依資料放在遠端道路終點，並為互動區保留空間；
這修正了來源中閘門緊鄰初始出生點的問題。實際走圖距離、撤離互動與回村
結算仍未驗收。
