extends CanvasLayer

signal continue_pressed

var _bg    : ColorRect
var _title : Label
var _btns  : Control

# Each entry: [ColorRect core, ColorRect glow, float speed, float phase_offset]
var _embers : Array = []


func _ready() -> void:
	layer        = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_bg)

	_build_embers()

	_title = Label.new()
	_title.text = "The Embers are swallowed by darkness"
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.68, 0.16, 0.10, 1.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position   = Vector2(240, 268)
	_title.size       = Vector2(800, 64)
	_title.modulate.a = 0.0
	add_child(_title)

	var divider := ColorRect.new()
	divider.position   = Vector2(440, 346)
	divider.size       = Vector2(400, 1)
	divider.color      = Color(0.45, 0.12, 0.10, 0.6)
	_title.add_child(divider)

	_btns = Control.new()
	_btns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_btns.visible = false
	add_child(_btns)

	var cont := _death_button("Continue",          Vector2(490, 390))
	var quit := _death_button("Quit to Main Menu", Vector2(440, 454))
	quit.add_theme_font_size_override("font_size", 16)
	quit.size = Vector2(400, 40)

	cont.pressed.connect(_on_continue)
	quit.pressed.connect(_on_quit)

	_btns.add_child(cont)
	_btns.add_child(quit)


func _build_embers() -> void:
	# [x, y, core_w, core_h, speed, phase]
	var spots : Array = [
		# bottom-left cluster
		[38,  694, 12,  8, 1.10, 0.00],
		[95,  702,  7,  5, 0.80, 1.30],
		[165, 690, 15, 10, 1.40, 2.60],
		[240, 698,  9,  6, 0.95, 0.70],
		[310, 703,  6,  4, 1.25, 3.50],
		# bottom-centre
		[570, 700, 10,  7, 1.05, 1.80],
		[640, 706,  7,  5, 0.75, 0.40],
		[715, 700, 11,  8, 1.30, 2.10],
		# bottom-right cluster
		[960, 690, 14,  9, 0.90, 3.00],
		[1040, 702,  8,  6, 1.20, 1.60],
		[1115, 695, 11,  8, 0.85, 0.20],
		[1185, 703,  7,  5, 1.45, 2.90],
		[1240, 692, 13,  9, 1.00, 1.10],
		# left edge
		[10,  620,  8, 12, 1.15, 0.50],
		[18,  520,  6,  9, 0.70, 2.20],
		[6,   430, 10, 14, 1.35, 3.80],
		# right edge
		[1262, 610,  8, 12, 0.88, 1.40],
		[1270, 510,  6,  9, 1.20, 0.80],
		[1258, 400, 10, 14, 1.05, 2.70],
	]

	for s in spots:
		var gx : float = s[0]
		var gy : float = s[1]
		var cw : float = s[2]
		var ch : float = s[3]
		var sp : float = s[4]
		var ph : float = s[5]

		# Glow (larger, dimmer halo behind the core)
		var glow := ColorRect.new()
		glow.position = Vector2(gx - cw * 0.8, gy - ch * 0.8)
		glow.size     = Vector2(cw * 2.6, ch * 2.6)
		glow.color    = Color(0.70, 0.18, 0.02, 0.0)
		add_child(glow)

		# Core ember dot
		var core := ColorRect.new()
		core.position = Vector2(gx, gy)
		core.size     = Vector2(cw, ch)
		core.color    = Color(1.00, 0.52, 0.08, 0.0)
		add_child(core)

		_embers.append([core, glow, sp, ph])


func _process(_delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() * 0.001
	for entry in _embers:
		var core  : ColorRect = entry[0]
		var glow  : ColorRect = entry[1]
		var speed : float     = entry[2]
		var phase : float     = entry[3]
		var flicker : float   = 0.5 + 0.5 * sin(t * speed + phase)
		var blink   : float   = clampf(sin(t * speed * 3.1 + phase) * 0.3 + 0.7, 0.0, 1.0)
		var alpha := _bg.color.a  # embers only appear as screen fades in
		core.color.a = flicker * blink * 0.65 * alpha
		glow.color.a = flicker * 0.22 * alpha


func show_death() -> void:
	visible           = true
	_bg.modulate.a    = 0.0
	_title.modulate.a = 0.0
	_btns.visible     = false

	var bg_tween := create_tween()
	bg_tween.tween_property(_bg, "color:a", 0.96, 1.8)

	var title_tween := create_tween()
	title_tween.tween_interval(1.1)
	title_tween.tween_property(_title, "modulate:a", 1.0, 1.2)

	var btn_tween := create_tween()
	btn_tween.tween_interval(2.8)
	btn_tween.tween_callback(func(): _btns.visible = true)


func _on_continue() -> void:
	_btns.visible = false
	var tween := create_tween()
	tween.tween_property(_bg,    "color:a",     0.0, 0.5)
	tween.parallel().tween_property(_title, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		visible = false
		continue_pressed.emit()
	)


func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _death_button(txt: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(300, 44)
	btn.flat     = true
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color",         Color(0.78, 0.73, 0.68, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.96, 0.92, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.50, 0.46, 0.42, 1.0))
	return btn
