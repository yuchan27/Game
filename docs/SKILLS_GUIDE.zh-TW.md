# Godot 4 2.5D 像素遊戲開發 Skills 完整指南 (`SKILLS_GUIDE.zh-TW.md`)

本專案於 `.agents/skills/` 目錄下建立了一套**完整、模組化、可直接移植供他人或其他專案重複使用**的 AI Agent Skills 套件。任何支援 `SKILL.md` 規範的 AI 助理（如 Antigravity / Claude Code / Cursor / Codex）只需將 `.agents/skills/` 複製到目標專案根目錄，即可自動載入這 6 大專業能力。

---

## 📦 6 大核心 Skills 清單與結構

```text
.agents/skills/
├── godot-development/                    # 1. Godot 4 核心功能與多介面 UI 開發規範
│   ├── SKILL.md
│   └── references/
│       └── architecture-and-ui-patterns.md
├── godot-2p5d-pixel-art-and-animation/   # 2. 2.5D 像素美術、8向動作、流暢近戰揮砍與地形瓦片管線
│   ├── SKILL.md
│   ├── scripts/
│   │   └── clear_godot_import_cache.py   # 一鍵清除 .godot/imported 快取並重新匯入工具
│   └── references/
│       └── 2p5d-proportions-and-melee-spec.md
├── godot-audio-and-voice-pipeline/       # 3. 合成器 BGM、戰鬥音效與中文神經語音 (Edge-TTS + DSP) 管線
│   ├── SKILL.md
│   └── references/
│       └── audio-manifest-spec.md
├── godot-visual-review/                  # 4. 29 張實機渲染截圖與雙解析度 (1280x720 / 1024x768) 視覺審查
│   ├── SKILL.md
│   └── references/
│       └── visual-review-checklist.md
├── godot-testing/                        # 5. 自動化回歸測試、碰撞測試、存檔隔離與效能驗證
│   ├── SKILL.md
│   └── references/
│       └── qa-runner-guide.md
└── godot-safe-refactor/                  # 6. 安全重構規範（保護 Signal、Group、存檔相容性與測試介面）
    ├── SKILL.md
    └── references/
        └── refactor-safety-checklist.md
```

---

## 🚀 如何將這套 Skills 分享給別人或用於新專案？

1. **直接複製 `.agents/skills/` 資料夾**：
   將 `.agents/skills/` 放到任何 Godot 4 專案的根目錄（或放到全域 `~/.gemini/antigravity/skills/`）。
2. **一鍵清除 Godot 快取並重新匯入 (`clear_godot_import_cache.py`)**：
   當外部工具更新圖片或音訊時，執行：
   ```powershell
   python .agents/skills/godot-2p5d-pixel-art-and-animation/scripts/clear_godot_import_cache.py --godot "C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
   ```
3. **執行完整美工、動作與快取更新管線**：
   - 重建主角 8 方向 × 9 動作（576 格無破洞圖集與水平刀柄錨點武器圖層）：
     `python scripts/tools/build_r17_vanguard_8dir_atlas.py`
   - 重建荒野廢土風 2.5D 地板瓦片：
     `python scripts/tools/build_2p5d_terrain_tilesets.py`
   - 重建全 NPC (`84×98`)、建築、污染體與 Manifest 雜湊：
     `python scripts/tools/overhaul_all_visual_assets.py`
4. **執行自動化驗證 (`run_qa.py`)**：
   ```powershell
   python scripts/tools/run_qa.py --godot "C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --profile core
   ```
