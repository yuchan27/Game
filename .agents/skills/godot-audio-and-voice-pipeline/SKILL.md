---
name: godot-audio-and-voice-pipeline
description: Generate, post-process, and validate procedural BGM tracks, layered combat SFX, and neural zh-TW character voiceovers (with radio/robotic DSP filters) for Godot 4 games.
---

# Godot Audio, Procedural BGM & Neural Voiceover Pipeline

Use this skill when creating or upgrading background music (`BGM`), combat/UI sound effects (`SFX`), or localized character voiceovers (`Voice`) in Godot 4.

## 1. Architecture & Runtime Loading
- **Central Autoload**: `scripts/autoload/AudioManager.gd` manages dedicated `AudioStreamPlayer` buses/channels for Music, SFX pool, and Voiceover playback.
- **Format Support**:
  - `.wav`: 16-bit PCM (`44100 Hz` or `24000 Hz`), loaded via `AudioStreamWAV`.
  - `.mp3`: Validated ID3/MPEG frames, loaded via `AudioStreamMP3`.

## 2. Neural Voiceover + Radio/Mech DSP Pipeline (`overhaul_audio_voice_and_music.py`)
1. **Synthesis (`edge-tts`)**:
   - Use distinct voices (`zh-TW-HsiaoChenNeural`, `zh-TW-YunJheNeural`, `zh-TW-HsiaoYuNeural`) with per-character pitch and rate tuning.
2. **Post-Processing DSP**:
   - **Bandpass / Warm Radio Filter**: Soft high-pass + low-pass convolution and subtle saturation so voices sound like authentic wasteland tactical comms.
   - **Robotic Metallic Modulation (`repair_robot`)**: Ring modulation (`95 Hz` carrier mix) + short metallic delay comb filter.
   - **Peak Normalization**: Normalize to `-1.5 dBFS` (`peak > 512` required by `verify_visual_assets.py`).

## 3. Multi-Track Procedural BGM & Combat SFX
- **Intro & Biome BGM**: Multi-layered FM/subtractive synth pads, basslines, arpeggiators, and percussion loops (`music_intro.wav >= 45s`, `music_village.mp3`, `music_guild.mp3`, `music_wasteland.mp3 >= 24s`).
- **Combat SFX**: Layered transient impact + pitch-swept body + filtered noise tail for melee slashes (`melee`), firearms (`shoot`), dash (`sfx_player_dodge`), hit impacts (`hit`), and UI interactions (`ui`, `interact`).

## 4. Verification
Run `python scripts/tools/verify_visual_assets.py` to verify all audio files exist, meet minimum duration thresholds, and are non-silent.
