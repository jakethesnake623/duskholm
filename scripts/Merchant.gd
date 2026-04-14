extends Node2D

## Stationary merchant NPC (a Remnant — an ember-derived construct of old Duskholm).
## Player presses E to begin dialogue; lines appear as subtitles.
## After dialogue ends the upgrade shop opens.

@export var dialogue_lines: PackedStringArray = PackedStringArray()

var player_nearby := false

@onready var detect   : Area2D      = $DetectZone
@onready var prompt   : Label       = $PromptLabel
@onready var shop_ui  : CanvasLayer = $ShopUI

# Dialogue state
var _dialogue_active   := false
var _dialogue_sequence : Array       = []
var _dialogue_index    : int         = 0

# Subtitle nodes (built in _ready)
var _subtitle_layer : CanvasLayer = null
var _subtitle_text  : Label       = null
var _subtitle_hint  : Label       = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visual()
	_build_subtitle()
	prompt.visible = false

	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)
	shop_ui.closed.connect(_on_shop_closed)


func _process(_delta: float) -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	if _dialogue_active:
		_advance_dialogue()
	elif player_nearby:
		_start_dialogue()


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


# ── Subtitle bar ───────────────────────────────────────────────────────────────

func _build_subtitle() -> void:
	_subtitle_layer         = CanvasLayer.new()
	_subtitle_layer.layer   = 5
	_subtitle_layer.visible = false
	add_child(_subtitle_layer)

	# Dark bar across the bottom
	var bg := ColorRect.new()
	bg.position = Vector2(0.0, 578.0)
	bg.size     = Vector2(1280.0, 142.0)
	bg.color    = Color(0.0, 0.0, 0.0, 0.80)
	_subtitle_layer.add_child(bg)

	# Thin accent line at top of bar
	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 578.0)
	accent.size     = Vector2(1280.0, 1.0)
	accent.color    = Color(0.40, 0.28, 0.62, 0.60)
	_subtitle_layer.add_child(accent)

	# Speaker tag
	var speaker := Label.new()
	speaker.text = "Remnant"
	speaker.add_theme_font_size_override("font_size", 11)
	speaker.add_theme_color_override("font_color", Color(0.62, 0.48, 0.88, 0.80))
	speaker.position = Vector2(64.0, 586.0)
	speaker.size     = Vector2(300.0, 18.0)
	_subtitle_layer.add_child(speaker)

	# Dialogue text
	_subtitle_text = Label.new()
	_subtitle_text.add_theme_font_size_override("font_size", 17)
	_subtitle_text.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1.0))
	_subtitle_text.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle_text.position = Vector2(64.0, 608.0)
	_subtitle_text.size     = Vector2(1152.0, 56.0)
	_subtitle_layer.add_child(_subtitle_text)

	# Continue / enter-shop hint
	_subtitle_hint = Label.new()
	_subtitle_hint.add_theme_font_size_override("font_size", 11)
	_subtitle_hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46, 0.75))
	_subtitle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_subtitle_hint.position = Vector2(64.0, 674.0)
	_subtitle_hint.size     = Vector2(1152.0, 18.0)
	_subtitle_layer.add_child(_subtitle_hint)


# ── Dialogue ───────────────────────────────────────────────────────────────────

func _start_dialogue() -> void:
	if dialogue_lines.size() == 0:
		shop_ui.open()
		return

	# Pick 2 unique random lines
	var indices : Array = range(dialogue_lines.size())
	indices.shuffle()
	var pick := mini(2, indices.size())
	_dialogue_sequence.clear()
	for i in pick:
		_dialogue_sequence.append(dialogue_lines[indices[i]])

	_dialogue_index  = 0
	_dialogue_active = true
	prompt.visible   = false
	get_tree().paused = true
	_show_line()


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index >= _dialogue_sequence.size():
		_finish_dialogue()
	else:
		_show_line()


func _finish_dialogue() -> void:
	_dialogue_active        = false
	_subtitle_layer.visible = false
	# shop_ui.open() handles its own tree pause
	shop_ui.open()


func _cancel_dialogue() -> void:
	_dialogue_active        = false
	_subtitle_layer.visible = false
	get_tree().paused       = false


func _show_line() -> void:
	_subtitle_text.text = _dialogue_sequence[_dialogue_index]
	var last := _dialogue_index >= _dialogue_sequence.size() - 1
	_subtitle_hint.text     = "[ E ]  Enter Shop" if last else "[ E ]  Continue"
	_subtitle_layer.visible = true


# ── Detection ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_nearby  = true
	prompt.text    = "[ E ]  Talk"
	prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	player_nearby  = false
	prompt.visible = false
	if _dialogue_active:
		_cancel_dialogue()


func _on_shop_closed() -> void:
	if player_nearby:
		prompt.text    = "[ E ]  Talk"
		prompt.visible = true
