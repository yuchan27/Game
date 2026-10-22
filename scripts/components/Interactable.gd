extends Area2D
class_name Interactable

signal interacted(interaction_id: String)

@export var interaction_id := ""
@export var prompt := "互動"
@export var radius := 42.0

var custom_center := Vector2.ZERO
var custom_box_size := Vector2.ZERO

var _player_near := false
var _label: Label
var _shape_node: CollisionShape2D

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
	_label.text = "E：%s" % prompt
	if custom_box_size != Vector2.ZERO:
		_label.position = custom_center + Vector2(-64, -custom_box_size.y * 0.5 - 24)
	else:
		_label.position = custom_center + Vector2(-64, -radius - 24)
	_label.visible = false
	_label.add_theme_font_size_override("font_size", 14)
	add_child(_label)

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
		_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_label.visible = false
