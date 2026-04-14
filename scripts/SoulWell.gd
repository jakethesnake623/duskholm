extends Node2D

var player_nearby := false
var player_ref    : CharacterBody2D = null
var activated     := false
var _menu_open    := false

var _glow_rect  : ColorRect   = null
var _well_menu  : CanvasLayer = null
var _status_lbl : Label       = null

@onready var prompt_label : Label       = $PromptLabel
@onready var detect_zone  : Area2D      = $DetectZone
@onready var shop_ui      : CanvasLayer = $ShopUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_visual()
	_build_well_menu()
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


# ── Process ────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _glow_rect:
		var t     := Time.get_ticks_msec() * 0.001
		var speed := 2.2 if activated else 0.7
		var pulse : float = 0.5 + 0.5 * sin(t * speed)
		if activated:
			_glow_rect.color = Color(0.45, 0.15, 0.90, 0.6 + 0.35 * pulse)
		else:
			_glow_rect.color = Color(0.20, 0.06, 0.45, 0.30 + 0.20 * pulse)

	if _menu_open and Input.is_action_just_pressed("ui_cancel"):
		_close_menu()
	elif player_nearby and not _menu_open and Input.is_action_just_pressed("interact"):
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
		if not _menu_open:
			prompt_label.visible = false
