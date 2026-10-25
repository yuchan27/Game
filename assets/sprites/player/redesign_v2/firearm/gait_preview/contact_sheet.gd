extends Node2D
## Ordinary candidate gait art presentation only, no game or QA code.
const ROOT := "C:/Code/Game/first-game/"
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const KEYS := ["contact_a", "passing", "contact_b"]
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "docs/art-direction/r17_v2/rifle_gait.json"))
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 p=texture(TEXTURE,UV);if(p.a<0.65){discard;}COLOR=vec4(p.rgb,1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	var textures: Dictionary = {}
	for key in KEYS:
		textures[key] = ImageTexture.create_from_image(Image.load_from_file(ROOT + str(data.keys[key].path).trim_prefix("res://")))
	for i in 8:
		var origin := Vector2((i % 4) * 350, (i / 4) * 330)
		for k in 3:
			var key: String = KEYS[k]
			var cell: Array = data.keys[key].cells[i]
			var region := Rect2(cell[0], cell[1], cell[2], cell[3])
			var atlas := AtlasTexture.new()
			atlas.atlas = textures[key]
			atlas.region = region
			var sprite := Sprite2D.new()
			sprite.texture = atlas
			sprite.material = material
			sprite.scale = Vector2.ONE * 96.0 / float(cell[8])
			sprite.offset = region.get_center() - Vector2(cell[4], cell[5])
			sprite.position = origin + Vector2(65 + k * 110, 220)
			add_child(sprite)
			var label := Label.new()
			label.text = ["A", "passing", "B"][k]
			label.position = origin + Vector2(35 + k * 110, 235)
			label.add_theme_font_size_override("font_size", 16)
			add_child(label)
		var direction := Label.new()
		direction.text = NAMES[i] + " - 96px body"
		direction.position = origin + Vector2(45, 80)
		direction.add_theme_font_size_override("font_size", 18)
		add_child(direction)
	var title := Label.new()
	title.text = "Rifle gait source candidates: approved A / new passing / new B. Eight actual facings."
	title.position = Vector2(25, 25)
	title.add_theme_font_size_override("font_size", 21)
	add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var target := ROOT + "assets/sprites/player/redesign_v2/firearm/gait_preview/rifle_gait_96_contact_sheet.png"
	get_viewport().get_texture().get_image().save_png(target)
	print("RIFLE_GAIT_ART: " + target)
	get_tree().quit()
