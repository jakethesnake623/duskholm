extends Node2D

## Export one or more inner-voice lines. On the very first interaction they
## play in sequence before the well menu opens. Leave empty to skip.
@export var inner_voice_lines : PackedStringArray = PackedStringArray()
## The room this well belongs to. Set in the scene; used to reveal the room on the minimap.
@export var room_id           : String            = ""

var player_nearby := false
var player_ref    : CharacterBody2D = null
var activated     := false
var _menu_open    := false

# Inner-voice dialogue state (first visit only)
var _first_visit   := true
var _voice_active  := false
var _voice_index   := 0

# Typewriter state
const CHARS_PER_SEC : float = 44.0
var _typing         := false
var _type_elapsed   := 0.0
var _type_full_text := ""

var _glow_rect  : ColorRect   = null
var _well_menu  : CanvasLayer = null
var _status_lbl : Label       = null
var _voice_layer : CanvasLayer = null
var _voice_text  : Label       = null
var _voice_hint  : Label       = null

@onready var prompt_label : Label       = $PromptLabel
@onready var detect_zone  : Area2D      = $DetectZone
@onready var shop_ui      : CanvasLayer = $ShopUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visual()
	_build_well_menu()
	_build_voice_display()
	prompt_label.visible = false
	detect_zone.body_entered.connect(_on_body_entered)
	detect_zone.body_exited.connect(_on_body_exited)
	shop_ui.closed.connect(_on_shop_closed)


# ── Visual ─────────────────────────────────────────────────────────────────────

func _build_visual() -> void:
	var stone := Color(0.28, 0.25, 0.22, 1.0)
	var void_  := Color(0.04, 0.02, 0.07, 1.0)

	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)

	_rect(vis, -30, -12,  30,   0, stone)
	_rect(vis, -30, -56, -18, -12, stone)
	_rect(vis,  18, -56,  30, -12, stone)
	_rect(vis, -30, -64,  30, -56, stone)
	_rect(vis, -18, -56,  18, -12, void_)
	_glow_rect = _rect(vis, -12, -28, 12, -16, Color(0.20, 0.06, 0.45, 0.5))


func _rect(parent: Node, l: float, t: float, r: float, b: float, col: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.offset_left   = l
	cr.offset_top    = t
	cr.offset_right  = r
	cr.offset_bottom = b
	cr.color = col
	parent.add_child(cr)
	return cr


# ── Well menu ──────────────────────────────────────────────────────────────────

func _build_well_menu() -> void:
	_well_menu = CanvasLayer.new()
	_well_menu.layer        = 8
	_well_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_well_menu.visible      = false
	add_child(_well_menu)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	_well_menu.add_child(bg)

	var panel := ColorRect.new()
	panel.position = Vector2(440.0, 240.0)
	panel.size     = Vector2(400.0, 250.0)
	panel.color    = Color(0.06, 0.04, 0.09, 0.96)
	_well_menu.add_child(panel)

	var title := Label.new()
	title.text = "SOUL WELL"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.62, 0.48, 0.88, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(440.0, 256.0)
	title.size     = Vector2(400.0, 42.0)
	_well_menu.add_child(title)

	var divider := ColorRect.new()
	divider.position = Vector2(490.0, 304.0)
	divider.size     = Vector2(300.0, 1.0)
	divider.color    = Color(0.35, 0.22, 0.50, 0.6)
	_well_menu.add_child(divider)

	var ponder    := _well_btn("Ponder",    Vector2(540.0, 318.0))
	var offerings := _well_btn("Offerings", Vector2(540.0, 368.0))
	var depart    := _well_btn("Depart",    Vector2(540.0, 418.0))

	ponder.pressed.connect(_do_ponder)
	offerings.pressed.connect(_do_offerings)
	depart.pressed.connect(_close_menu)

	_well_menu.add_child(ponder)
	_well_menu.add_child(offerings)
	_well_menu.add_child(depart)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color(0.62, 0.48, 0.88, 0.85))
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.position = Vector2(440.0, 458.0)
	_status_lbl.size     = Vector2(400.0, 22.0)
	_status_lbl.visible  = false
	_well_menu.add_child(_status_lbl)


func _well_btn(txt: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(200.0, 40.0)
	btn.flat     = true
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color",         Color(0.78, 0.73, 0.68, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.96, 0.92, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.50, 0.46, 0.42, 1.0))
	return btn


# ── Inner voice display ────────────────────────────────────────────────────────

func _build_voice_display() -> void:
	_voice_layer         = CanvasLayer.new()
	_voice_layer.layer   = 9
	_voice_layer.visible = false
	add_child(_voice_layer)

	# Minimal dark veil — no thick bar, just enough to separate text from world
	var bg := ColorRect.new()
	bg.position = Vector2(0.0, 558.0)
	bg.size     = Vector2(1280.0, 162.0)
	bg.color    = Color(0.0, 0.0, 0.0, 0.72)
	_voice_layer.add_child(bg)

	# Cold thin accent line — distinct from the merchant's purple
	var accent := ColorRect.new()
	accent.position = Vector2(0.0, 558.0)
	accent.size     = Vector2(1280.0, 1.0)
	accent.color    = Color(0.24, 0.28, 0.60, 0.50)
	_voice_layer.add_child(accent)

	# Inner voice text — cool off-white, wide margins
	_voice_text = Label.new()
	_voice_text.add_theme_font_size_override("font_size", 17)
	_voice_text.add_theme_color_override("font_color", Color(0.80, 0.82, 0.90, 0.95))
	_voice_text.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_voice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_voice_text.position = Vector2(160.0, 576.0)
	_voice_text.size     = Vector2(960.0, 60.0)
	_voice_layer.add_child(_voice_text)

	# Continue hint — right-aligned, dim
	_voice_hint = Label.new()
	_voice_hint.add_theme_font_size_override("font_size", 11)
	_voice_hint.add_theme_color_override("font_color", Color(0.42, 0.44, 0.58, 0.70))
	_voice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_voice_hint.position = Vector2(160.0, 648.0)
	_voice_hint.size     = Vector2(960.0, 18.0)
	_voice_layer.add_child(_voice_hint)


func _start_voice() -> void:
	_voice_active        = true
	_voice_index         = 0
	prompt_label.visible = false
	_show_voice_line()


func _advance_voice() -> void:
	_voice_index += 1
	if _voice_index >= inner_voice_lines.size():
		_finish_voice()
	else:
		_show_voice_line()


func _finish_voice() -> void:
	_typing              = false
	_voice_active        = false
	_first_visit         = false
	_voice_layer.visible = false
	_open_menu()


func _cancel_voice() -> void:
	_typing              = false
	_voice_active        = false
	_first_visit         = false
	_voice_layer.visible = false


func _show_voice_line() -> void:
	var line := inner_voice_lines[_voice_index] as String
	var last := _voice_index >= inner_voice_lines.size() - 1
	_voice_hint.text     = "[ E ]  Rest" if last else "[ E ]  Continue"
	_voice_layer.visible = true
	_begin_typing(line)


# ── Typewriter ──────────────────────────────────────────────────────────────────

func _begin_typing(text: String) -> void:
	_type_full_text  = text
	_type_elapsed    = 0.0
	_typing          = true
	_voice_text.text = ""


func _tick_typing(delta: float) -> void:
	if not _typing:
		return
	_type_elapsed += delta
	var revealed : int = mini(int(_type_elapsed * CHARS_PER_SEC), _type_full_text.length())
	_voice_text.text = _type_full_text.left(revealed)
	if revealed >= _type_full_text.length():
		_typing = false


func _skip_typing() -> void:
	_typing          = false
	_voice_text.text = _type_full_text


# ── Process ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _glow_rect:
		var t     := Time.get_ticks_msec() * 0.001
		var speed := 2.2 if activated else 0.7
		var pulse : float = 0.5 + 0.5 * sin(t * speed)
		if activated:
			_glow_rect.color = Color(0.45, 0.15, 0.90, 0.6 + 0.35 * pulse)
		else:
			_glow_rect.color = Color(0.20, 0.06, 0.45, 0.30 + 0.20 * pulse)

	_tick_typing(delta)

	if _typing and Input.is_action_just_pressed("interact"):
		_skip_typing()
	elif _voice_active and Input.is_action_just_pressed("interact"):
		_advance_voice()
	elif _menu_open and Input.is_action_just_pressed("ui_cancel"):
		_close_menu()
	elif player_nearby and not _menu_open and not _voice_active and Input.is_action_just_pressed("interact"):
		if _first_visit and inner_voice_lines.size() > 0:
			_start_voice()
		else:
			_open_menu()


# ── Menu actions ───────────────────────────────────────────────────────────────

func _open_menu() -> void:
	_menu_open         = true
	_well_menu.visible = true
	get_tree().paused  = true


func _close_menu() -> void:
	_menu_open         = false
	_well_menu.visible = false
	get_tree().paused  = false
	if not player_nearby:
		prompt_label.visible = false


func _do_ponder() -> void:
	if player_ref == null:
		return
	activated = true
	GameData.spawn_position = global_position + Vector2(0, -8)
	player_ref.rest(global_position)
	GameData.discover_room(room_id)
	GameData.save()
	GameData.rested.emit()
	_show_status("...the well remembers...")


func _do_offerings() -> void:
	_well_menu.visible = false
	shop_ui.open()


func _on_shop_closed() -> void:
	_well_menu.visible = true
	get_tree().paused  = true


func _show_status(msg: String) -> void:
	_status_lbl.text    = msg
	_status_lbl.visible = true
	await get_tree().create_timer(2.0).timeout
	_status_lbl.visible = false


# ── Detection ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby        = true
		player_ref           = body
		prompt_label.text    = "[ E ]  Rest"
		prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		player_ref    = null
		if _voice_active:
			_cancel_voice()
		if not _menu_open:
			prompt_label.visible = false
