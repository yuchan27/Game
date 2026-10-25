extends Node2D
## Ordinary isolated art rendering only; no game state, save access or QA checks.
const SOURCE := "C:/Code/Game/first-game/assets/sprites/player/redesign_v2/source/r17_blade_contact_a_v007.png"
const OUTPUT := "C:/Code/Game/first-game/docs/art-direction/r17_v2/sprite_preview/contact_a_render.png"
const FEET := [Vector2(205, 425), Vector2(610, 430), Vector2(962, 430), Vector2(1300, 430), Vector2(187, 907), Vector2(598, 910), Vector2(949, 915), Vector2(1325, 915)]
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var source := Image.load_from_file(SOURCE)
	var texture := ImageTexture.create_from_image(source)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 pixel=texture(TEXTURE,UV); if(pixel.a<0.65){discard;} COLOR=vec4(pixel.rgb,1.0)*COLOR; }"
	var material := ShaderMaterial.new()
	material.shader = shader
	for index in 8:
		var cell := Vector2(index % 4, index / 4)
		var at := Vector2(150 + cell.x * 310, 300 + cell.y * 330)
		var region := Rect2(cell * Vector2(384, 512), Vector2(384, 512))
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		for zoom in [1.0, 2.0]:
			var figure := Sprite2D.new()
			figure.texture = atlas
			figure.material = material
			figure.centered = false
			figure.scale = Vector2.ONE * 96.0 / 310.0 * zoom
			figure.position = at + Vector2(-90 if zoom == 1.0 else 80, 0) - (FEET[index] - region.position) * figure.scale
			add_child(figure)
		var label := Label.new()
		label.text = NAMES[index] + "   96px / 2x"
		label.position = at + Vector2(-110, 12)
		label.add_theme_font_size_override("font_size", 18)
		add_child(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT)
	print("ART_PREVIEW: " + OUTPUT)
	get_tree().quit()
