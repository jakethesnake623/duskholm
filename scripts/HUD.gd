extends CanvasLayer

const MASK_FULL  = Color(0.85, 0.18, 0.18, 1.0)
const MASK_EMPTY = Color(0.18, 0.18, 0.20, 1.0)

const FLASK_COLOR = Color(0.90, 0.42, 0.06, 1.0)
const SHARD_COLOR = Color(0.78, 0.86, 0.94, 1.0)

@onready var mask_container   : HBoxContainer = $MaskContainer
@onready var embers_label     : Label         = $EmbersContainer/EmbersLabel
@onready var throwable_icon   : ColorRect     = $ThrowableBox/Row/Icon
@onready var throwable_name   : Label         = $ThrowableBox/Row/NameLabel
@onready var throwable_count  : Label         = $ThrowableBox/Row/CountLabel

var masks: Array[ColorRect] = []


func _ready() -> void:
	GameData.throwables_changed.connect(on_throwables_changed)
	on_throwables_changed()


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


func on_throwables_changed() -> void:
	var type  : String = GameData.active_throwable
	var count : int    = GameData.get_throwable_count(type)
	var data  := GameData.THROWABLES.get(type, {}) as Dictionary
	throwable_name.text  = data.get("label", type)
	throwable_count.text = "×%d" % count
	throwable_icon.color = FLASK_COLOR if type == "flask" else SHARD_COLOR
	var dim : float = 1.0 if count > 0 else 0.40
	throwable_icon.modulate.a  = dim
	throwable_name.modulate.a  = dim
	throwable_count.modulate.a = dim
