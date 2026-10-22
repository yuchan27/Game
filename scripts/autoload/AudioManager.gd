extends Node

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

const MUSIC := {
	"village": "res://assets/audio/music_village.mp3",
	"guild": "res://assets/audio/music_guild.mp3",
	"wasteland": "res://assets/audio/music_wasteland.mp3",
	"intro": "res://assets/audio/music_intro.wav"
}

const VOICE := {
	"title_story": "res://assets/audio/voice_title_story.wav",
	"intro_story": "res://assets/audio/voice_intro_story.wav",
	"npc_forge_master": "res://assets/audio/voice_npc_forge_master.wav",
	"npc_scrap_merchant": "res://assets/audio/voice_npc_scrap_merchant.wav",
	"npc_repair_robot": "res://assets/audio/voice_npc_repair_robot.wav",
	"npc_wasteland_survivor": "res://assets/audio/voice_npc_wasteland_survivor.wav",
	"npc_guild_clerk": "res://assets/audio/voice_npc_guild_clerk.wav",
	"npc_route_scout": "res://assets/audio/voice_npc_route_scout.wav"
}

const SFX := {
	"melee": "res://assets/audio/sfx_melee.wav",
	"sfx_melee_heavy": "res://assets/audio/sfx_melee_heavy.wav",
	"shoot": "res://assets/audio/sfx_shoot.wav",
	"sfx_shoot_coil": "res://assets/audio/sfx_shoot_coil.wav",
	"hit": "res://assets/audio/sfx_hit.wav",
	"pickup": "res://assets/audio/sfx_pickup.wav",
	"interact": "res://assets/audio/sfx_interact.wav",
	"death": "res://assets/audio/sfx_death.wav",
	"hurt": "res://assets/audio/sfx_player_hurt.wav",
	"level_up": "res://assets/audio/sfx_level_up.wav",
	"transition": "res://assets/audio/sfx_transition.wav",
	"ui": "res://assets/audio/sfx_ui_select.wav"
}

# Procedural synthesized profiles for expanded AAA combat/UI/biome audio
const SYNTH_PROFILES := {
	"slash_knife": {"freq_start": 680.0, "freq_end": 220.0, "dur": 0.09, "noise": 0.55, "vol": 0.55},
	"slash_machete": {"freq_start": 520.0, "freq_end": 160.0, "dur": 0.13, "noise": 0.60, "vol": 0.65},
	"slash_sword": {"freq_start": 740.0, "freq_end": 260.0, "dur": 0.14, "noise": 0.40, "vol": 0.68},
	"slash_axe": {"freq_start": 340.0, "freq_end": 110.0, "dur": 0.18, "noise": 0.65, "vol": 0.75},
	"slash_hammer": {"freq_start": 220.0, "freq_end": 65.0, "dur": 0.24, "noise": 0.75, "vol": 0.85},
	"slash_spear": {"freq_start": 620.0, "freq_end": 190.0, "dur": 0.12, "noise": 0.45, "vol": 0.65},
	"slash_chainsaw": {"freq_start": 160.0, "freq_end": 210.0, "dur": 0.19, "noise": 0.82, "vol": 0.72},
	"shoot_pistol": {"freq_start": 480.0, "freq_end": 120.0, "dur": 0.11, "noise": 0.70, "vol": 0.68},
	"shoot_revolver": {"freq_start": 380.0, "freq_end": 85.0, "dur": 0.18, "noise": 0.78, "vol": 0.82},
	"shoot_smg": {"freq_start": 560.0, "freq_end": 150.0, "dur": 0.08, "noise": 0.65, "vol": 0.58},
	"shoot_rifle": {"freq_start": 440.0, "freq_end": 105.0, "dur": 0.13, "noise": 0.72, "vol": 0.72},
	"shoot_shotgun": {"freq_start": 260.0, "freq_end": 62.0, "dur": 0.22, "noise": 0.88, "vol": 0.88},
	"shoot_sniper": {"freq_start": 640.0, "freq_end": 75.0, "dur": 0.26, "noise": 0.76, "vol": 0.88},
	"shoot_crossbow": {"freq_start": 820.0, "freq_end": 280.0, "dur": 0.12, "noise": 0.25, "vol": 0.62},
	"shoot_energy": {"freq_start": 960.0, "freq_end": 340.0, "dur": 0.15, "noise": 0.18, "vol": 0.70},
	"shoot_explosive": {"freq_start": 190.0, "freq_end": 48.0, "dur": 0.30, "noise": 0.92, "vol": 0.90},
	"reload": {"freq_start": 420.0, "freq_end": 680.0, "dur": 0.14, "noise": 0.30, "vol": 0.52},
	"dodge": {"freq_start": 360.0, "freq_end": 180.0, "dur": 0.14, "noise": 0.62, "vol": 0.55},
	"crit_hit": {"freq_start": 880.0, "freq_end": 240.0, "dur": 0.16, "noise": 0.50, "vol": 0.80},
	"footstep_dust": {"freq_start": 180.0, "freq_end": 90.0, "dur": 0.05, "noise": 0.85, "vol": 0.26},
	"footstep_marsh": {"freq_start": 240.0, "freq_end": 130.0, "dur": 0.07, "noise": 0.70, "vol": 0.28},
	"footstep_metal": {"freq_start": 520.0, "freq_end": 210.0, "dur": 0.05, "noise": 0.45, "vol": 0.30},
	"hazard_warn": {"freq_start": 540.0, "freq_end": 720.0, "dur": 0.16, "noise": 0.15, "vol": 0.48},
	"ui_hover": {"freq_start": 660.0, "freq_end": 780.0, "dur": 0.04, "noise": 0.05, "vol": 0.32},
	"upgrade_pick": {"freq_start": 520.0, "freq_end": 1040.0, "dur": 0.22, "noise": 0.10, "vol": 0.70},
	"victory": {"freq_start": 440.0, "freq_end": 880.0, "dur": 0.35, "noise": 0.08, "vol": 0.75}
}

var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0
var current_music := ""
var _synth_cache: Dictionary = {}
var _last_play_ms: Dictionary = {}
var master_volume_db := 0.0
var music_volume_db := -9.0
var sfx_volume_db := -6.0

func _is_headless_audio() -> bool:
	return DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy"

func stop_all() -> void:
	for player in [music_player, voice_player] + sfx_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	current_music = ""
	_synth_cache.clear()
	ASSET_LOADER.clear_cache()

func _exit_tree() -> void:
	stop_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		stop_all()

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = music_volume_db
	music_player.finished.connect(func() -> void:
		if music_player.stream != null and not _is_headless_audio():
			music_player.play()
	)
	add_child(music_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = 1.5
	add_child(voice_player)
	for i in range(10):
		var player := AudioStreamPlayer.new()
		player.volume_db = sfx_volume_db
		sfx_players.append(player)
		add_child(player)

func set_volumes(master_linear: float, music_linear: float, sfx_linear: float) -> void:
	master_volume_db = linear_to_db(clampf(master_linear, 0.001, 1.5))
	music_volume_db = linear_to_db(clampf(music_linear, 0.001, 1.5)) - 10.0
	sfx_volume_db = linear_to_db(clampf(sfx_linear, 0.001, 1.5)) - 6.0
	if is_instance_valid(music_player):
		music_player.volume_db = music_volume_db + master_volume_db
	for player in sfx_players:
		if is_instance_valid(player):
			player.volume_db = sfx_volume_db + master_volume_db

func play_music(id: String) -> void:
	if current_music == id:
		return
	var path := String(MUSIC.get(id, ""))
	if path.is_empty():
		return
	current_music = id
	if _is_headless_audio():
		return
	var stream := ASSET_LOADER.load_wav(path)
	if stream == null:
		return
	music_player.stream = stream
	music_player.play()

func play_voice(id: String) -> bool:
	var path := String(VOICE.get(id, ""))
	if path.is_empty():
		return false
	if _is_headless_audio():
		return FileAccess.file_exists(ProjectSettings.globalize_path(path)) or ResourceLoader.exists(path)
	var stream := ASSET_LOADER.load_wav(path)
	if stream == null:
		return false
	voice_player.stop()
	voice_player.stream = stream
	voice_player.play()
	return true

func stop_voice() -> void:
	if voice_player != null:
		voice_player.stop()
		voice_player.stream = null

func play_sfx(id: String, pitch_variance := 0.05) -> void:
	if sfx_players.is_empty() or _is_headless_audio():
		return
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_last_play_ms.get(id, -9999))
	if now_ms - last_ms < 28:
		return
	_last_play_ms[id] = now_ms

	var stream: AudioStream = null
	var path := String(SFX.get(id, ""))
	if not path.is_empty():
		stream = ASSET_LOADER.load_wav(path)
	elif SYNTH_PROFILES.has(id):
		stream = _get_or_build_synth_stream(id)
	elif SFX.has("melee"):
		stream = ASSET_LOADER.load_wav(String(SFX["melee"]))

	if stream == null:
		return
	var player := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	player.stream = stream
	player.pitch_scale = clampf(1.0 + randf_range(-pitch_variance, pitch_variance), 0.78, 1.28)
	player.volume_db = sfx_volume_db + master_volume_db
	player.play()

func _get_or_build_synth_stream(id: String) -> AudioStreamWAV:
	if _synth_cache.has(id):
		return _synth_cache[id] as AudioStreamWAV
	var profile: Dictionary = SYNTH_PROFILES.get(id, {})
	if profile.is_empty():
		return null
	var sample_rate := 22050
	var duration := float(profile.get("dur", 0.12))
	var sample_count := maxi(64, int(round(duration * float(sample_rate))))
	var freq_start := float(profile.get("freq_start", 440.0))
	var freq_end := float(profile.get("freq_end", 220.0))
	var noise_mix := float(profile.get("noise", 0.35))
	var vol := float(profile.get("vol", 0.6))

	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash()

	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var env := sin(minf(1.0, t * 8.0) * PI * 0.5) * pow(1.0 - t, 1.45)
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(sample_rate)
		var tone := sin(phase) * (1.0 - noise_mix * 0.65)
		var grit := rng.randf_range(-1.0, 1.0) * noise_mix
		var sample := clampf((tone + grit) * env * vol, -0.95, 0.95)
		var int_sample := int(round(sample * 32767.0))
		pcm.encode_s16(i * 2, int_sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm
	_synth_cache[id] = wav
	return wav
