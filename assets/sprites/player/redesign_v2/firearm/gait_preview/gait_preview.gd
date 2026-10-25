extends Node2D
## Isolated ordinary art render and source measurements, without game/save/QA code.
var source_path := "C:/Code/Game/first-game/assets/sprites/player/redesign_v2/firearm/r17_firearm_ready_v002.png"
var output_path := "C:/Code/Game/first-game/assets/sprites/player/redesign_v2/firearm/preview/ready_v002_native.png"
var measurements_path := "C:/Code/Game/first-game/assets/sprites/player/redesign_v2/firearm/preview/ready_v002_measurements.json"
var normalization_heights := PackedFloat32Array()
var foot_centers := PackedFloat32Array()
var root_xs := PackedFloat32Array()
var lower_first_boundary := 410
var third_boundary := 1160
const NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const X_BOUNDS := [0,410,800,1160,1536]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(0,args.size()-1,2):
		match args[index]:
			"--source": source_path = args[index+1]
			"--output": output_path = args[index+1]
			"--measurements": measurements_path = args[index+1]
			"--body-heights":
				for value in args[index+1].split(","):
					normalization_heights.append(float(value))
			"--foot-centers":
				for value in args[index+1].split(","):
					foot_centers.append(float(value))
			"--root-x":
				for value in args[index+1].split(","):
					root_xs.append(float(value))
			"--lower-first-boundary": lower_first_boundary = int(args[index+1])
			"--third-boundary": third_boundary = int(args[index+1])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var source := Image.load_from_file(source_path)
	var texture := ImageTexture.create_from_image(source)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 pixel=texture(TEXTURE,UV); if(pixel.a<0.65){discard;} COLOR=vec4(pixel.rgb,1.0)*COLOR; }"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var measured: Array = []
	for index in 8:
		var col := index % 4
		var row := index / 4
		var bounds := X_BOUNDS.duplicate()
		bounds[3] = third_boundary
		if row == 1:
			bounds[1] = lower_first_boundary
		var rect := Rect2i(bounds[col],row*512,bounds[col+1]-bounds[col],512)
		var low := Vector2i(rect.end)
		var high := rect.position
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if source.get_pixel(x,y).a >= 0.65:
					low = low.min(Vector2i(x,y))
					high = high.max(Vector2i(x,y))
		var foot_y := high.y
		var foot_low_x := low.x
		var foot_high_x := high.x
		if foot_centers.size() == 8:
			foot_low_x = int(foot_centers[index])-40
			foot_high_x = int(foot_centers[index])+40
			foot_y = row*512+350
			for y in range(row*512+350,row*512+512):
				for x in range(foot_low_x,foot_high_x+1):
					if source.get_pixel(x,y).a >= 0.65:
						foot_y = maxi(foot_y,y)
		var sole_x := 0.0
		var sole_count := 0
		for x in range(foot_low_x,foot_high_x+1):
			if source.get_pixel(x,foot_y).a >= 0.65:
				sole_x += x
				sole_count += 1
		var support_sole := Vector2(sole_x/maxi(1,sole_count),foot_y)
		var sole := support_sole
		if root_xs.size() == 8:
			sole.x = root_xs[index]
		var body_height := normalization_heights[index] if normalization_heights.size()==8 else float(high.y-low.y+1)
		measured.append({"direction":NAMES[index],"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"solid_bbox":[low.x,low.y,high.x-low.x+1,high.y-low.y+1],"sole":[sole.x,sole.y],"supporting_sole":[support_sole.x,support_sole.y],"helmet_to_sole_height":body_height,"scale_96":96.0/body_height})
		var at := Vector2(180+col*340,285+row*345)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(rect)
		for zoom in [1.0,1.6]:
			var figure := Sprite2D.new()
			figure.texture = atlas
			figure.material = mat
			figure.centered = false
			figure.scale = Vector2.ONE*96.0/body_height*zoom
			figure.position = at+Vector2(-100 if zoom==1.0 else 40,0)-(sole-Vector2(rect.position))*figure.scale
			add_child(figure)
		var label := Label.new()
		label.text = NAMES[index]+"   96px / 1.6x"
		label.position = at+Vector2(-120,12)
		label.add_theme_font_size_override("font_size",18)
		add_child(label)
	var file := FileAccess.open(measurements_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"path":source_path,"sha256":FileAccess.get_sha256(source_path),"alpha_cutoff":0.65,"source_preserved":true,"directions":measured},"  "))
	file.close()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output_path)
	print("ART_PREVIEW: "+output_path)
	get_tree().quit()
