extends Node2D
## Candidate perspective review. Does not activate or certify exact angles.
const ROOT := "C:/Code/Game/first-game/docs/art-direction/r17_v2/"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("#23282d"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "angular_candidates.json"))
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 pixel=texture(TEXTURE,UV);if(pixel.a<0.96){discard;}COLOR=vec4(pixel.rgb,1.0);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	for facing in 8:
		var at := Vector2(155 + (facing % 4) * 315, 295 + (facing / 4) * 335)
		for side in 2:
			var entry: Dictionary = manifest["baseline"] if side == 0 else manifest["candidates"][0]
			var image := Image.load_from_file(entry["path"])
			var region := Rect2(Vector2(facing % 4, facing / 4) * Vector2(384, 512), Vector2(384, 512))
			var atlas := AtlasTexture.new()
			atlas.atlas = ImageTexture.create_from_image(image)
			atlas.region = region
			var sprite := Sprite2D.new()
			sprite.texture = atlas
			sprite.material = material
			sprite.scale = Vector2.ONE * 192.0 / (float(entry["sole_y"][facing]) - float(entry["head_y"][facing]))
			var sole := Vector2(float(entry["sole_x"][facing]), float(entry["sole_y"][facing]))
			sprite.offset = region.get_center() - sole
			sprite.position = at + Vector2(-75 if side == 0 else 75, 0)
			add_child(sprite)
		var label := Label.new()
		label.text = str(manifest["baseline"]["angles"][facing]) + "  / candidate " + str(manifest["candidates"][0]["requested_angles"][facing])
		label.position = at + Vector2(-135, 12)
		label.add_theme_font_size_override("font_size", 16)
		add_child(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ROOT + "sprite_preview/angular_offset_22_5_comparison.png")
	print("ANGULAR_CANDIDATE_ART: " + ROOT + "sprite_preview/angular_offset_22_5_comparison.png")
	get_tree().quit()
