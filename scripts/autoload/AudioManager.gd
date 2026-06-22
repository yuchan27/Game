extends Node

const ASSET_LOADER := preload("res://scripts/utils/RuntimeAssetLoader.gd")

const MUSIC := {
	"village": "res://assets/audio/music_village.wav",
	"guild": "res://assets/audio/music_guild.wav",
	"wasteland": "res://assets/audio/music_wasteland.wav",
	"intro": "res://assets/audio/music_intro.wav"
}

const VOICE := {
	"title_story": "res://assets/audio/voice_title_story.wav",
	"intro_story": "res://assets/audio/voice_intro_story.wav"
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

var music_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor := 0
var current_music := ""

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -14.0
	music_player.finished.connect(func() -> void:
		if music_player.stream != null:
			music_player.play()
	)
	add_child(music_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -2.0
	add_child(voice_player)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		sfx_players.append(player)
		add_child(player)

func play_music(id: String) -> void:
	if current_music == id:
		return
	var path := String(MUSIC.get(id, ""))
	if path.is_empty():
		return
	var stream := ASSET_LOADER.load_wav(path)
	if stream == null:
		return
	current_music = id
	music_player.stream = stream
	music_player.play()

func play_voice(id: String) -> bool:
	var path := String(VOICE.get(id, ""))
	if path.is_empty():
		return false
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

func play_sfx(id: String) -> void:
	var path := String(SFX.get(id, ""))
	if path.is_empty() or sfx_players.is_empty():
		return
	var stream := ASSET_LOADER.load_wav(path)
	if stream == null:
		return
	var player := sfx_players[sfx_cursor % sfx_players.size()]
	sfx_cursor += 1
	player.stream = stream
	player.play()
