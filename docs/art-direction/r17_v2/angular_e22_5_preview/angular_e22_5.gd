extends Node2D
## Isolated candidate art rendering only. No runtime integration or QA.
const ROOT := "C:/Code/Game/first-game/"
const TARGET := ROOT + "docs/art-direction/r17_v2/angular_e22_5_v017_comparison.png"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 pixel=texture(TEXTURE,UV);if(pixel.a<0.96){discard;}COLOR=vec4(pixel.rgb,1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	var entries := [
		["E0 approved", "r17_blade_idle_v011.png", Rect2(0, 0, 384, 512), Vector2(200, 448), 340.0],
		["E22.5 requested - candidate v017", "angular_candidates/r17_blade_idle_e22_5_v017.png", Rect2(0, 0, 1024, 1536), Vector2(590, 1338), 1154.0],
		["SE45 approved", "r17_blade_idle_v011.png", Rect2(384, 0, 384, 512), Vector2(585, 448), 339.0]
	]
	for i in 3:
		var entry: Array = entries[i]
		var image := Image.load_from_file(ROOT + "assets/sprites/player/redesign_v2/source/" + str(entry[1]))
		var atlas := AtlasTexture.new()
		atlas.atlas = ImageTexture.create_from_image(image)
		atlas.region = entry[2]
		for row in 2:
			var sprite := Sprite2D.new()
			sprite.texture = atlas
			sprite.material = material
			var body_height := 288.0 if row == 0 else 96.0
			sprite.scale = Vector2.ONE * body_height / float(entry[4])
			sprite.offset = atlas.region.get_center() - Vector2(entry[3])
			sprite.position = Vector2(220 + i * 420, 395 if row == 0 else 655)
			add_child(sprite)
		var label := Label.new()
		label.text = str(entry[0])
		label.position = Vector2(55 + i * 420, 415)
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)
	var note := Label.new()
	note.text = "288px comparison / 96px gameplay size. Candidate only; exact azimuth unproven."
	note.position = Vector2(30, 25)
	note.add_theme_font_size_override("font_size", 20)
	add_child(note)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TARGET)
	print("ANGULAR_SINGLE_CANDIDATE_ART: " + TARGET)
	get_tree().quit()
