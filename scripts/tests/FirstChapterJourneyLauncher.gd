extends Node

const JOURNEY_DRIVER := preload("res://scripts/tests/FirstChapterJourneyDriver.gd")



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var driver := JOURNEY_DRIVER.new() as Node
	driver.name = "PersistentFirstChapterJourneyDriver"
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.call_deferred("add_child", driver)
