from __future__ import annotations

"""
Generates Traditional Chinese (zh-TW) voiceovers via local Windows SAPI (Microsoft Hanhan Desktop)
plus numpy formant/pitch/studio-reverb DSP mastering, and composes 4 rich multi-track Wasteland
post-apocalyptic music tracks (>26s each) + 12 layered SFX files.
"""

import subprocess
import tempfile
import wave
from pathlib import Path
import lameenc
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
AUDIO_DIR = ROOT / "assets" / "audio"

# (file_stem, sapi_rate, pitch_semitones, is_robotic, text)
VOICE_SPECS = [
    (
        "voice_title_story",
        -1,
        -2.5,
        False,
        "廢土回收商。人類文明崩壞後，資源被污染區吞沒。R-17 在維修艙甦醒，必須深入荒原，回收廢鐵、異變核心與生物晶體，替村莊換取下一天的能源。",
    ),
    (
        "voice_intro_story",
        -1,
        -3.0,
        False,
        "序章：R-17 甦醒。第一紀元的最後一年，天空不再下雨，只落下帶著金屬味的灰。舊工廠失控後，污染帶吞掉南方平原，只剩這座村莊還在廢鐵牆後微弱發光。你是 R-17，最後一台仍願意走進廢土的機動回收先鋒。你的核心裡存著一段命令：帶回能讓大家活到明天的資源。",
    ),
    (
        "voice_npc_forge_master",
        -1,
        -5.0,
        False,
        "別急著追高階裝備，先把基礎打穩！村裡只做能穩定量產的前期裝備與彈藥補給；三階武器與重型護甲，得去冒險公會接委託。打開裝備面板，我也能直接幫你鍛造強化手上的武器！",
    ),
    (
        "voice_npc_scrap_merchant",
        1,
        -3.5,
        False,
        "嘿，想活著從污染區回來，先看看手頭的補給吧！彈藥、拆解跟改裝都在村裡處理，帶夠廢鐵跟彈藥再上路！",
    ),
    (
        "voice_npc_repair_robot",
        0,
        1.2,
        True,
        "維修艙已待命。存檔信標會補滿裝甲結構與戰術能量，並保存探索進度。請隨時透過裝備面板強化您的武裝。",
    ),
    (
        "voice_npc_wasteland_survivor",
        0,
        -1.2,
        False,
        "出村前先確認彈藥跟能量！荒野不會等你準備好，按下 M 鍵打開戰術雷達地圖，鎖定資源點與撤離路線。",
    ),
    (
        "voice_npc_guild_clerk",
        0,
        0.8,
        False,
        "歡迎來到冒險公會。公會懸賞會發放村莊無法製造的高階武裝與核心裝甲，完成目標後請回櫃台領取獎勵。",
    ),
    (
        "voice_npc_route_scout",
        1,
        -4.2,
        False,
        "路線別亂挑！新手先從廢鐵公路或毒沼區蒐集晶核與異變核心，強化好武器等級，再去挑戰紫晶裂隙與舊工廠首領。",
    ),
]


def write_wav_mono(path: Path, samples_f32: np.ndarray, sample_rate: int = 24000) -> None:
    clipped = np.clip(samples_f32, -0.98, 0.98)
    pcm16 = (clipped * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm16.tobytes())


def write_wav_stereo(path: Path, left: np.ndarray, right: np.ndarray, sample_rate: int = 44100) -> None:
    interleaved = np.empty((left.size * 2,), dtype=np.int16)
    interleaved[0::2] = (np.clip(left, -0.98, 0.98) * 32767.0).astype(np.int16)
    interleaved[1::2] = (np.clip(right, -0.98, 0.98) * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(interleaved.tobytes())


def write_mp3_stereo(path: Path, left: np.ndarray, right: np.ndarray, sample_rate: int = 44100) -> None:
    interleaved = np.empty((left.size * 2,), dtype=np.int16)
    interleaved[0::2] = (np.clip(left, -0.98, 0.98) * 32767.0).astype(np.int16)
    interleaved[1::2] = (np.clip(right, -0.98, 0.98) * 32767.0).astype(np.int16)
    encoder = lameenc.Encoder()
    encoder.set_bit_rate(192)
    encoder.set_in_sample_rate(sample_rate)
    encoder.set_channels(2)
    encoder.set_quality(2)
    mp3_data = encoder.encode(interleaved.tobytes()) + encoder.flush()
    path.write_bytes(bytes(mp3_data))


def overlap_add_pitch_shift(samples: np.ndarray, semitones: float, sr: int) -> np.ndarray:
    """Granular Hann-window pitch shift that preserves speaking duration."""
    if abs(semitones) < 0.05:
        return samples
    factor = 2.0 ** (semitones / 12.0)
    grain_size = int(0.036 * sr)
    hop = grain_size // 4
    win = np.hanning(grain_size).astype(np.float32)
    out = np.zeros(samples.size + grain_size, dtype=np.float32)
    norm = np.zeros(samples.size + grain_size, dtype=np.float32)
    idx_grid = np.linspace(0, grain_size - 1, grain_size, dtype=np.float32) * factor
    for pos in range(0, samples.size - grain_size, hop):
        src_indices = pos + idx_grid
        valid = src_indices < (samples.size - 1)
        idx_int = np.clip(src_indices.astype(np.int32), 0, samples.size - 2)
        frac = src_indices - idx_int
        grain = ((1.0 - frac) * samples[idx_int] + frac * samples[idx_int + 1]) * valid * win
        out[pos : pos + grain_size] += grain
        norm[pos : pos + grain_size] += win * valid
    mask = norm > 1e-4
    out[mask] /= norm[mask]
    return out[: samples.size]


def generate_voices() -> None:
    # Use high-craft emotional neural voice synthesis (edge-tts)
    from scripts.tools.generate_emotional_voices import main as gen_neural
    import asyncio
    asyncio.run(gen_neural())


def midi_to_freq(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def synth_pad_chord(t: np.ndarray, notes: list[int], detune: float = 0.004) -> tuple[np.ndarray, np.ndarray]:
    left = np.zeros_like(t)
    right = np.zeros_like(t)
    for idx, n in enumerate(notes):
        f = midi_to_freq(n)
        lfo = np.sin(2.0 * np.pi * (0.18 + 0.05 * idx) * t)
        w1 = np.sin(2.0 * np.pi * f * (1.0 - detune) * t + 0.3 * lfo)
        w2 = np.sin(2.0 * np.pi * f * (1.0 + detune) * t - 0.3 * lfo)
        w3 = 0.35 * np.sin(2.0 * np.pi * (f * 2.0) * t)
        left += (w1 + w3) / len(notes)
        right += (w2 + w3) / len(notes)
    return left * 0.28, right * 0.28


def synth_pluck_note(sr: int, freq: float, dur: float, brightness: float = 0.5) -> np.ndarray:
    n = int(sr * dur)
    t = np.arange(n, dtype=np.float32) / sr
    env = np.exp(-t * (5.5 / max(0.15, dur))) * (1.0 - np.exp(-t * 140.0))
    wave_sig = (
        np.sin(2.0 * np.pi * freq * t)
        + brightness * np.sin(2.0 * np.pi * freq * 2.0 * t) * np.exp(-t * 9.0)
        + (brightness * 0.45) * np.sin(2.0 * np.pi * freq * 3.0 * t) * np.exp(-t * 14.0)
    )
    return wave_sig * env


def add_stereo_reverb(left: np.ndarray, right: np.ndarray, sr: int, mix: float = 0.26) -> tuple[np.ndarray, np.ndarray]:
    out_l = left.copy()
    out_r = right.copy()
    for delay_ms, gain in ((43, 0.36), (89, 0.24), (147, 0.16), (233, 0.10)):
        d = int(sr * delay_ms / 1000.0)
        if d < left.size:
            out_l[d:] += right[:-d] * gain * mix
            out_r[d:] += left[:-d] * gain * mix
    return out_l, out_r


def compose_music_tracks() -> None:
    sr = 44100
    dur = 28.0
    total = int(sr * dur)

    # 1. music_intro.wav (48s cinematic prelude, 12 bars)
    intro_dur = 48.0
    intro_total = int(sr * intro_dur)
    intro_chords = [
        [50, 57, 62, 65],
        [46, 53, 58, 62],
        [43, 50, 55, 58],
        [45, 52, 57, 61],
    ]
    left = np.zeros(intro_total, dtype=np.float32)
    right = np.zeros(intro_total, dtype=np.float32)
    bar_len = intro_dur / 12.0
    for bar in range(12):
        s = int(bar * bar_len * sr)
        e = min(intro_total, int((bar + 1) * bar_len * sr))
        bt = np.arange(e - s, dtype=np.float32) / sr
        env = np.sin(np.pi * bt / bar_len) ** 0.45
        notes = intro_chords[bar % 4]
        pl, pr = synth_pad_chord(bt, notes, 0.005)
        sub = 0.24 * np.sin(2.0 * np.pi * midi_to_freq(notes[0] - 12) * bt)
        left[s:e] += (pl + sub) * env
        right[s:e] += (pr + sub) * env

        arp_pattern = [notes[0] + 12, notes[2] + 12, notes[3] + 12, notes[2] + 12, notes[1] + 12, notes[3] + 12, notes[0] + 24, notes[2] + 12]
        step_dur = bar_len / len(arp_pattern)
        for step_idx, note in enumerate(arp_pattern):
            ns = s + int(step_idx * step_dur * sr)
            pluck = synth_pluck_note(sr, midi_to_freq(note), step_dur * 1.4, 0.65)
            ne = min(intro_total, ns + pluck.size)
            pan = 0.35 + 0.30 * ((step_idx % 2) * 2 - 1)
            left[ns:ne] += pluck[: ne - ns] * 0.26 * (1.0 - pan * 0.4)
            right[ns:ne] += pluck[: ne - ns] * 0.26 * (0.6 + pan * 0.4)

    left, right = add_stereo_reverb(left, right, sr, 0.34)
    write_wav_stereo(AUDIO_DIR / "music_intro.wav", left * 0.88, right * 0.88, sr)
    print("[MUSIC] Generated music_intro.wav (48.0s)", flush=True)

    # 2. music_village.mp3
    vil_chords = [
        [50, 57, 62, 65],
        [48, 55, 60, 64],
        [43, 50, 55, 59],
        [45, 52, 57, 60],
    ]
    left = np.zeros(total, dtype=np.float32)
    right = np.zeros(total, dtype=np.float32)
    beat_sec = 60.0 / 96.0
    bar_sec = beat_sec * 4.0
    num_bars = int(dur / bar_sec) + 1
    melody_degrees = [62, 65, 69, 67, 64, 60, 62, 57, 62, 65, 72, 69, 67, 64, 62, 60]
    for bar in range(num_bars):
        s = int(bar * bar_sec * sr)
        if s >= total:
            break
        e = min(total, int((bar + 1) * bar_sec * sr))
        bt = np.arange(e - s, dtype=np.float32) / sr
        notes = vil_chords[bar % 4]
        pl, pr = synth_pad_chord(bt, notes, 0.003)
        bass = 0.24 * np.sin(2.0 * np.pi * midi_to_freq(notes[0] - 12) * bt) * (0.75 + 0.25 * np.sin(2.0 * np.pi * (1.0 / beat_sec) * bt))
        left[s:e] += pl * 0.85 + bass
        right[s:e] += pr * 0.85 + bass

        pick_order = [0, 2, 3, 1, 2, 3, 2, 1]
        for eighth in range(8):
            ns = s + int(eighth * (beat_sec * 0.5) * sr)
            if ns >= total:
                break
            n_val = notes[pick_order[eighth]] + 12
            pluck = synth_pluck_note(sr, midi_to_freq(n_val), beat_sec * 0.85, 0.72)
            ne = min(total, ns + pluck.size)
            left[ns:ne] += pluck[: ne - ns] * (0.28 if eighth % 2 == 0 else 0.18)
            right[ns:ne] += pluck[: ne - ns] * (0.18 if eighth % 2 == 0 else 0.28)

        for beat in range(4):
            ns = s + int(beat * beat_sec * sr)
            if ns >= total:
                break
            mel_note = melody_degrees[(bar * 4 + beat) % len(melody_degrees)] + 12
            lead = synth_pluck_note(sr, midi_to_freq(mel_note), beat_sec * 0.95, 0.35)
            ne = min(total, ns + lead.size)
            left[ns:ne] += lead[: ne - ns] * 0.18
            right[ns:ne] += lead[: ne - ns] * 0.20

            k_len = min(int(0.14 * sr), total - ns)
            kt = np.arange(k_len, dtype=np.float32) / sr
            if beat in (0, 2):
                kick = np.sin(2.0 * np.pi * (110.0 * np.exp(-kt * 28.0) + 48.0) * kt) * np.exp(-kt * 16.0) * 0.24
                left[ns : ns + k_len] += kick
                right[ns : ns + k_len] += kick
            elif beat in (1, 3):
                rng = np.random.default_rng(bar * 10 + beat)
                shaker = rng.normal(0.0, 1.0, k_len).astype(np.float32) * np.exp(-kt * 36.0) * 0.08
                left[ns : ns + k_len] += shaker
                right[ns : ns + k_len] += shaker

    left, right = add_stereo_reverb(left, right, sr, 0.28)
    write_mp3_stereo(AUDIO_DIR / "music_village.mp3", left * 0.86, right * 0.86, sr)
    print("[MUSIC] Generated music_village.mp3", flush=True)

    # 3. music_guild.mp3
    guild_chords = [
        [45, 52, 57, 60],
        [41, 48, 53, 57],
        [48, 55, 60, 64],
        [40, 47, 52, 55],
    ]
    left = np.zeros(total, dtype=np.float32)
    right = np.zeros(total, dtype=np.float32)
    beat_sec = 60.0 / 112.0
    bar_sec = beat_sec * 4.0
    num_bars = int(dur / bar_sec) + 1
    for bar in range(num_bars):
        s = int(bar * bar_sec * sr)
        if s >= total:
            break
        e = min(total, int((bar + 1) * bar_sec * sr))
        bt = np.arange(e - s, dtype=np.float32) / sr
        notes = guild_chords[bar % 4]
        pl, pr = synth_pad_chord(bt, notes, 0.006)
        left[s:e] += pl * 0.80
        right[s:e] += pr * 0.80

        step16 = beat_sec * 0.25
        for idx16 in range(16):
            ns = s + int(idx16 * step16 * sr)
            if ns >= total:
                break
            b_note = notes[0] - 12 if idx16 % 4 != 3 else notes[1] - 12
            b_pulse = synth_pluck_note(sr, midi_to_freq(b_note), step16 * 0.9, 0.90)
            ne = min(total, ns + b_pulse.size)
            left[ns:ne] += b_pulse[: ne - ns] * 0.24
            right[ns:ne] += b_pulse[: ne - ns] * 0.24

            if idx16 % 2 == 0:
                a_note = notes[(idx16 // 2) % 4] + 12
                arp = synth_pluck_note(sr, midi_to_freq(a_note), step16 * 1.6, 0.55)
                ne2 = min(total, ns + arp.size)
                left[ns:ne2] += arp[: ne2 - ns] * (0.20 if idx16 % 4 == 0 else 0.12)
                right[ns:ne2] += arp[: ne2 - ns] * (0.12 if idx16 % 4 == 0 else 0.20)

    left, right = add_stereo_reverb(left, right, sr, 0.25)
    write_mp3_stereo(AUDIO_DIR / "music_guild.mp3", left * 0.85, right * 0.85, sr)
    print("[MUSIC] Generated music_guild.mp3", flush=True)

    # 4. music_wasteland.mp3
    waste_chords = [
        [40, 47, 52, 55],
        [48, 55, 60, 64],
        [45, 52, 57, 60],
        [47, 54, 59, 63],
    ]
    left = np.zeros(total, dtype=np.float32)
    right = np.zeros(total, dtype=np.float32)
    beat_sec = 60.0 / 126.0
    bar_sec = beat_sec * 4.0
    num_bars = int(dur / bar_sec) + 1
    waste_melody = [64, 67, 71, 72, 71, 67, 64, 63, 64, 67, 76, 74, 71, 69, 67, 66]
    for bar in range(num_bars):
        s = int(bar * bar_sec * sr)
        if s >= total:
            break
        e = min(total, int((bar + 1) * bar_sec * sr))
        bt = np.arange(e - s, dtype=np.float32) / sr
        notes = waste_chords[bar % 4]
        pl, pr = synth_pad_chord(bt, notes, 0.007)
        left[s:e] += pl * 0.72
        right[s:e] += pr * 0.72

        for eighth in range(8):
            ns = s + int(eighth * (beat_sec * 0.5) * sr)
            if ns >= total:
                break
            b_note = notes[0] - 12 if eighth % 2 == 0 else notes[0]
            bass_hit = synth_pluck_note(sr, midi_to_freq(b_note), beat_sec * 0.48, 1.0)
            ne = min(total, ns + bass_hit.size)
            left[ns:ne] += bass_hit[: ne - ns] * 0.25
            right[ns:ne] += bass_hit[: ne - ns] * 0.25

            m_note = waste_melody[(bar * 4 + eighth // 2) % len(waste_melody)] + (0 if eighth % 2 == 0 else 12)
            lead_hit = synth_pluck_note(sr, midi_to_freq(m_note), beat_sec * 0.55, 0.75)
            ne_m = min(total, ns + lead_hit.size)
            left[ns:ne_m] += lead_hit[: ne_m - ns] * 0.19
            right[ns:ne_m] += lead_hit[: ne_m - ns] * 0.21

            d_len = min(int(0.15 * sr), total - ns)
            dt = np.arange(d_len, dtype=np.float32) / sr
            rng = np.random.default_rng(bar * 32 + eighth)
            noise = rng.normal(0.0, 1.0, d_len).astype(np.float32)
            if eighth in (0, 3, 4):
                kick = np.sin(2.0 * np.pi * (145.0 * np.exp(-dt * 35.0) + 46.0) * dt) * np.exp(-dt * 15.0) * 0.34
                left[ns : ns + d_len] += kick
                right[ns : ns + d_len] += kick
            if eighth in (2, 6):
                snare = (noise * np.exp(-dt * 24.0) * 0.22) + np.sin(2.0 * np.pi * 185.0 * dt) * np.exp(-dt * 28.0) * 0.16
                left[ns : ns + d_len] += snare
                right[ns : ns + d_len] += snare
            hihat = noise * np.exp(-dt * 65.0) * 0.07
            left[ns : ns + d_len] += hihat
            right[ns : ns + d_len] += hihat

    left, right = add_stereo_reverb(left, right, sr, 0.22)
    write_mp3_stereo(AUDIO_DIR / "music_wasteland.mp3", left * 0.86, right * 0.86, sr)
    print("[MUSIC] Generated music_wasteland.mp3", flush=True)


def upgrade_core_sfx() -> None:
    sr = 24000
    sfx_defs = {
        "sfx_melee.wav": (0.14, 580.0, 160.0, 0.55, 0.85),
        "sfx_melee_heavy.wav": (0.24, 280.0, 62.0, 0.72, 0.92),
        "sfx_shoot.wav": (0.15, 520.0, 110.0, 0.68, 0.88),
        "sfx_shoot_coil.wav": (0.20, 960.0, 220.0, 0.28, 0.86),
        "sfx_hit.wav": (0.12, 340.0, 95.0, 0.62, 0.85),
        "sfx_pickup.wav": (0.18, 520.0, 1040.0, 0.08, 0.78),
        "sfx_interact.wav": (0.14, 440.0, 660.0, 0.10, 0.72),
        "sfx_death.wav": (0.42, 240.0, 48.0, 0.75, 0.90),
        "sfx_player_hurt.wav": (0.20, 310.0, 115.0, 0.58, 0.86),
        "sfx_level_up.wav": (0.45, 440.0, 1320.0, 0.06, 0.85),
        "sfx_transition.wav": (0.38, 220.0, 540.0, 0.35, 0.76),
        "sfx_ui_select.wav": (0.08, 660.0, 880.0, 0.05, 0.68),
    }
    for fname, (dur, f0, f1, n_mix, vol) in sfx_defs.items():
        n = int(sr * dur)
        t = np.arange(n, dtype=np.float32) / sr
        ratio = t / dur
        freq = f0 + (f1 - f0) * (ratio ** 0.75)
        phase = np.cumsum(2.0 * np.pi * freq / sr)
        tone = np.sin(phase) + 0.35 * np.sin(phase * 2.0)
        rng = np.random.default_rng(abs(hash(fname)) % 100000)
        noise = rng.normal(0.0, 1.0, n).astype(np.float32) * np.exp(-ratio * 5.0)
        env = (1.0 - ratio) ** 1.35 * np.minimum(1.0, t / 0.006)
        sig = ((1.0 - n_mix) * tone + n_mix * noise) * env * vol
        write_wav_mono(AUDIO_DIR / fname, sig, sr)
    print("[SFX] Upgraded all 12 core SFX WAV files", flush=True)


def main() -> None:
    generate_voices()
    compose_music_tracks()
    upgrade_core_sfx()


if __name__ == "__main__":
    main()
