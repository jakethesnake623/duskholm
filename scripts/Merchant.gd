extends Node2D

## Stationary merchant NPC (a Remnant — an ember-derived construct of old Duskholm).
## Shows ambient dialogue when the player is nearby, opens the shop on interact.

@export var dialogue_lines: PackedStringArray = PackedStringArray()

var player_nearby := false

@onready var detect   : Area2D      = $DetectZone
@onready var prompt   : Label       = $PromptLabel
@onready var shop_ui  : CanvasLayer = $ShopUI

var _dialogue_label : Label = null


func _ready() -> void:
	_build_visual()
	_build_dialogue_label()
	prompt.visible = false

	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		shop_ui.open()


# ── Visual ─────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var robe_col := Color(0.22, 0.20, 0.28, 1.0)
	var hood_col := Color(0.14, 0.13, 0.17, 1.0)
	var eye_col  := Color(0.92, 0.72, 0.15, 1.0)

	_add_rect(Vector2(0, -25), Vector2(28, 50), robe_col)
	_add_rect(Vector2(0, -59), Vector2(22, 20), hood_col)
	_add_rect(Vector2(-5, -63), Vector2(5, 4),  eye_col)
	_add_rect(Vector2( 3, -63), Vector2(5, 4),  eye_col)


func _add_rect(center: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.size     = size
	r.position = center - size * 0.5
	r.color    = color
	add_child(r)


func _build_dialogue_label() -> void:
	_dialogue_label = Label.new()
	_dialogue_label.position             = Vector2(-120, -148)
	_dialogue_label.custom_minimum_size  = Vector2(240, 0)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 10)
	_dialogue_label.add_theme_color_override("font_color",    Color(0.72, 0.65, 0.50, 0.80))
	_dialogue_label.visible = false
	add_child(_dialogue_label)


# ── Detection ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_nearby  = true
	prompt.visible = true
	if dialogue_lines.size() > 0 and _dialogue_label:
		_dialogue_label.text    = dialogue_lines[randi() % dialogue_lines.size()]
		_dialogue_label.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_nearby           = false
	prompt.visible          = false
	if _dialogue_label:
		_dialogue_label.visible = false
