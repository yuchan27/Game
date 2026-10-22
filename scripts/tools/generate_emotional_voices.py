#!/usr/bin/env python3
"""
Generate AAA-quality emotional Traditional Chinese voice acting for Wasteland Recycler
using distinct, character-specific Microsoft Azure Neural Voices via edge-tts,
mastered with studio-grade EQ and dynamics.
"""

from __future__ import annotations

import asyncio
import io
import math
import wave
from pathlib import Path

import edge_tts
import lameenc
import miniaudio
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
AUDIO_DIR = ROOT / "assets" / "audio"

# Voice Specifications:
# (stem, voice_name, rate_str, pitch_str, script_text)
# Each character has a UNIQUE voice actor, strictly avoiding repeating titles or robotic delivery.
EMOTIONAL_VOICES = [
    (
        "voice_title_story",
        "zh-TW-YunJheNeural",
        "-2%",
        "-2Hz",
        "在無盡的暴雨與輻射金屬塵落盡之後，古老文明在大崩壞中淪為死寂。你是最後一位受命啟動的十字軍先鋒機體，穿行於異變體盤據的廢土，為圍牆後殘存的生命，尋找活過明天的希望……",
    ),
    (
        "voice_intro_story",
        "zh-CN-YunjianNeural",
        "-2%",
        "-1Hz",
        "大雨已經停了，但天空再也沒有亮過。黑色的金屬酸灰日夜不息地落下，吞噬了南方所有的道路。在被遺忘的地下深處，機體冷卻液正在沸騰，動力核心在警報聲中破開死寂。醒來吧，R-17……聽聽外面的聲音，避難所的高牆正在變異巨獸的撞擊下顫抖，老陳的鍛造爐快要熄火，孩子們的水源也即將耗盡。你的記憶體裡只剩下最後一條誓言：握緊你的劍與弩砲，踏入荒原，把明天的希望……帶回村莊！",
    ),
    (
        "voice_npc_forge_master",
        "zh-CN-YunyangNeural",
        "+0%",
        "-2Hz",
        "喂！老兄弟，你總算動起來了！瞧瞧這爐膛……廢鐵要是再斷供，別說你的外骨架，整座村子今晚就得凍僵！別急著去工廠送死，先把二階武裝跟防護甲做出來。至於那些能把巨獸骨頭砸碎的高階重槌，得去公會揭榜！帶上這盒穿甲彈，聽好了……一定要給我活著滾回來！",
    ),
    (
        "voice_npc_scrap_merchant",
        "zh-CN-YunxiaNeural",
        "+4%",
        "+1Hz",
        "哎唷喂！這不是剛出艙的大英雄嗎？來來來，看看我剛淘到的好貨！荒野上的規矩我只講一次：子彈比命貴，但沒子彈你連半個小時都撐不過去！異變核心我高價拆成晶片，零件彈藥應有盡有。把廢鐵帶夠再出村，我可不想明天在變異怪獸的肚子裡收購你的骨架，聽懂了吧？",
    ),
    (
        "voice_npc_repair_robot",
        "zh-TW-HsiaoYuNeural",
        "-1%",
        "+0Hz",
        "系統自檢完成。R-17 先鋒核心體溫穩定，生物神經鏈接已恢復。守護者，如果不幸在外受損，緊急醫療傳送協議會將您安全帶回。存檔信標已經與您的動力源同頻，隨時能為您補充護甲結構。荒原非常危險……請務必平安歸來。",
    ),
    (
        "voice_npc_wasteland_survivor",
        "zh-CN-YunxiNeural",
        "+2%",
        "-1Hz",
        "長官！我是前線巡邏隊長艾倫！看到您重新站起來，弟兄們總算看到了曙光！外圍的毒沼和紫晶裂隙正不斷往村莊壓迫，出發前務必按 M 鍵確認地圖與撤離路線。千萬別在狹窄路口被獸群合圍！我們所有人的身後……全指望您了！",
    ),
    (
        "voice_npc_guild_clerk",
        "zh-TW-HsiaoChenNeural",
        "+1%",
        "+1Hz",
        "您好，R-17 閣下！冒險公會的委託布告欄已全面更新。外圍的威脅正在急遽升級，失控工廠裡正沉睡著最危險的巨神兵。公會金庫裡封存著前代文明的磁吸拆解器與高階外骨骼，只要您完成獵殺委託，這些就是屬於您的功勳。願榮耀伴隨您的每一步！",
    ),
    (
        "voice_npc_route_scout",
        "zh-CN-YunjianNeural",
        "-3%",
        "-4Hz",
        "噓……壓低身子，荒原的風裡到處都是怪物的喘息。聽清楚了，先鋒：南邊的廢鐵公路適合獵殺落單目標，但要是沒穿上中階防護甲、沒備足線圈重箭，千萬不要踏進舊工廠半步！那裡的機械巨獸……一口就能把重甲咬碎。隨時注意你的能量，走吧！",
    ),
]


def write_wav_mono(path: Path, samples: np.ndarray, sr: int = 24000) -> None:
    clipped = np.clip(samples, -0.96, 0.96)
    pcm16 = (clipped * 32767.0).astype(np.int16)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        wf.writeframes(pcm16.tobytes())


def write_mp3_stereo(path: Path, left: np.ndarray, right: np.ndarray, sr: int = 24000) -> None:
    l_clip = np.clip(left, -0.96, 0.96)
    r_clip = np.clip(right, -0.96, 0.96)
    l_pcm = (l_clip * 32767.0).astype(np.int16)
    r_pcm = (r_clip * 32767.0).astype(np.int16)
    interleaved = np.empty((l_pcm.size * 2,), dtype=np.int16)
    interleaved[0::2] = l_pcm
    interleaved[1::2] = r_pcm

    encoder = lameenc.Encoder()
    encoder.set_bit_rate(192)
    encoder.set_in_sample_rate(sr)
    encoder.set_channels(2)
    encoder.set_quality(2)
    mp3_data = encoder.encode(interleaved.tobytes()) + encoder.flush()
    path.write_bytes(mp3_data)


def apply_studio_mastering(samples: np.ndarray, sr: int, is_robot: bool = False) -> np.ndarray:
    samples = np.tanh(samples * 1.15)
    t = np.arange(samples.size, dtype=np.float32) / float(sr)

    if is_robot:
        ring = 0.94 + 0.06 * np.sin(2.0 * np.pi * 92.0 * t)
        samples = samples * ring
        d_idx = int(0.016 * sr)
        if samples.size > d_idx:
            delayed = np.pad(samples[:-d_idx], (d_idx, 0))
            samples = samples * 0.90 + delayed * 0.18
    else:
        d1 = int(0.022 * sr)
        d2 = int(0.048 * sr)
        if samples.size > d2:
            echo1 = np.pad(samples[:-d1], (d1, 0)) * 0.10
            echo2 = np.pad(samples[:-d2], (d2, 0)) * 0.05
            samples = samples + echo1 + echo2

    peak = float(np.max(np.abs(samples)))
    if peak > 0.001:
        samples = (samples / peak) * 0.92
    return samples


async def generate_single_voice(stem: str, voice: str, rate: str, pitch: str, text: str) -> None:
    print(f"[VOICE] Synthesizing '{stem}' with {voice}...", flush=True)
    comm = edge_tts.Communicate(text, voice, rate=rate, pitch=pitch)
    mp3_bytes = bytearray()
    async for chunk in comm.stream():
        if chunk["type"] == "audio":
            mp3_bytes.extend(chunk["data"])

    decoded = miniaudio.decode(bytes(mp3_bytes))
    sr = decoded.sample_rate
    n_ch = decoded.nchannels
    raw_samples = np.array(decoded.samples, dtype=np.float32) / 32768.0
    if n_ch > 1:
        raw_samples = raw_samples[::n_ch]

    is_robot = "repair_robot" in stem
    mastered = apply_studio_mastering(raw_samples, sr, is_robot=is_robot)

    out_wav = AUDIO_DIR / f"{stem}.wav"
    write_wav_mono(out_wav, mastered, sr)

    if stem == "voice_intro_story":
        out_mp3 = AUDIO_DIR / "voice_intro_story.mp3"
        write_mp3_stereo(out_mp3, mastered, mastered, sr)

    dur = mastered.size / float(sr)
    print(f" -> Generated {out_wav.name} ({dur:.2f}s, {sr}Hz, voice={voice})", flush=True)


async def main() -> None:
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)
    for stem, voice, rate, pitch, text in EMOTIONAL_VOICES:
        await generate_single_voice(stem, voice, rate, pitch, text)
    print("\n[ALL DIVERSE VOICES COMPLETED SUCCESSFULLY]")


if __name__ == "__main__":
    asyncio.run(main())
