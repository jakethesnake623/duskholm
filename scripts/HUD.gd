extends CanvasLayer

const MASK_FULL  = Color(0.85, 0.18, 0.18, 1.0)
const MASK_EMPTY = Color(0.18, 0.18, 0.20, 1.0)

@onready var mask_container: HBoxContainer = $MaskContainer
@onready var embers_label  : Label         = $EmbersContainer/EmbersLabel

var masks: Array[ColorRect] = []


func setup(maximum: int) -> void:
	for child in mask_container.get_children():
		child.queue_free()
	masks.clear()

	for i in maximum:
		var m := ColorRect.new()
		m.custom_minimum_size = Vector2(22.0, 22.0)
		m.color = MASK_FULL
		mask_container.add_child(m)
		masks.append(m)


func on_health_changed(current: int, _maximum: int) -> void:
	for i in masks.size():
		masks[i].color = MASK_FULL if i < current else MASK_EMPTY


func on_embers_changed(current: int) -> void:
	embers_label.text = str(current)
