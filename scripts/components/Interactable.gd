extends Area2D
class_name Interactable

signal interacted(interaction_id: String)

@export var interaction_id := ""
@export var prompt := "互動":
	set(value):
		if prompt == value:
			return
		prompt = value
		if is_instance_valid(_label):
			_label.text = "E：%s" % prompt
@export var radius := 42.0

var custom_center := Vector2.ZERO
var custom_box_size := Vector2.ZERO

var _player_near := false
var _label: Label
var _shape_node: CollisionShape2D
var _prompt_anchor := Vector2(INF, INF)
var _screen_safe_prompt_anchor := Vector2(INF, INF)

func set_screen_safe_prompt(local_anchor: Vector2) -> void:
	# Opt into the existing HUD hint row instead of covering world art with a label.
	if not is_finite(local_anchor.x) or not is_finite(local_anchor.y):
		return
	_screen_safe_prompt_anchor = local_anchor
	if _label != null:
		_label.visible = false

func get_screen_safe_prompt_text() -> String:
	if not _player_near or not _uses_screen_safe_prompt():
		return ""
	# Eligibility follows E reach even when a tall target's visual center is off-screen.
	return "[E] %s" % prompt

func _uses_screen_safe_prompt() -> bool:
	return is_finite(_screen_safe_prompt_anchor.x) and is_finite(_screen_safe_prompt_anchor.y)

func set_prompt_anchor(local_anchor: Vector2) -> void:
	# A visual target can differ from the walk-up trigger (for example a tall relic).
	# Only the label moves; interaction reach and collision remain unchanged.
	if not is_finite(local_anchor.x) or not is_finite(local_anchor.y):
		return
	_prompt_anchor = local_anchor
	if _label != null:
		_label.position = _prompt_anchor + Vector2(-64, 0)

func setup_box(center: Vector2, size: Vector2) -> void:
	custom_center = center
	custom_box_size = size
	if _shape_node != null:
		var rect := RectangleShape2D.new()
		rect.size = size
		_shape_node.shape = rect
		_shape_node.position = center
	if _label != null:
		_label.position = center + Vector2(-64, -size.y * 0.5 - 24)

func setup_circle(center: Vector2, new_radius: float) -> void:
	custom_center = center
	radius = new_radius
	custom_box_size = Vector2.ZERO
	if _shape_node != null:
		var circle := CircleShape2D.new()
		circle.radius = radius
		_shape_node.shape = circle
		_shape_node.position = center
	if _label != null:
		_label.position = center + Vector2(-64, -radius - 24)

func _ready() -> void:
	add_to_group("interactable")
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_shape_node = CollisionShape2D.new()
	if custom_box_size != Vector2.ZERO:
		var rect := RectangleShape2D.new()
		rect.size = custom_box_size
		_shape_node.shape = rect
		_shape_node.position = custom_center
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius
		_shape_node.shape = circle
		_shape_node.position = custom_center
	add_child(_shape_node)

	_label = Label.new()
	# Keep world prompts readable when the actor stands in front of their owner.
	_label.z_index = 10
	_label.text = "E：%s" % prompt
	if custom_box_size != Vector2.ZERO:
		_label.position = custom_center + Vector2(-64, -custom_box_size.y * 0.5 - 24)
	else:
		_label.position = custom_center + Vector2(-64, -radius - 24)
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)
	if is_finite(_prompt_anchor.x) and is_finite(_prompt_anchor.y):
		_label.position = _prompt_anchor + Vector2(-64, 0)

func can_interact() -> bool:
	return _player_near

func interact() -> void:
	if not can_interact():
		return
	AudioManager.play_sfx("interact")
	interacted.emit(interaction_id)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_label.visible = not _uses_screen_safe_prompt()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_label.visible = false
