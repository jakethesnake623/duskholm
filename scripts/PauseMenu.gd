extends CanvasLayer

## Pause menu — toggled with Escape. Freezes the game tree while open.
## Has two views: main (Resume / Save / Settings / Quit) and Settings.

var can_pause := true

var _main_panel      : Control
var _settings_panel  : Control
var _controls_panel  : Control
var _save_label      : Label


func _ready() -> void:
	layer        = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()

func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action("ui_cancel") and event.is_pressed() and not event.is_echo()):
		return
	if visible:
		if _settings_panel.visible or _controls_panel.visible:
			_show_main()
		else:
			_resume()
	elif can_pause and not get_tree().paused:
		_pause()
	get_viewport().set_input_as_handled()


# ── Build UI ───────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(bg)

	_build_main_panel()
	_build_settings_panel()
	_build_controls_panel()


func _build_main_panel() -> void:
	_main_panel = Control.new()
	_main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main_panel)

	_add_panel_bg(_main_panel, Vector2(440.0, 200.0), Vector2(400.0, 380.0))
	_add_title(_main_panel, "PAUSED", 32, Vector2(440.0, 216.0))
	_add_divider(_main_panel, Vector2(490.0, 270.0))

	var resume   := _make_button("Resume",            Vector2(540.0, 285.0), 20)
	var save_btn := _make_button("Save Game",         Vector2(540.0, 335.0), 20)
	var settings := _make_button("Settings",          Vector2(540.0, 385.0), 20)
	var controls := _make_button("Controls",          Vector2(540.0, 435.0), 20)
	var quit     := _make_button("Quit to Main Menu", Vector2(490.0, 502.0), 16)
	quit.size = Vector2(300.0, 36.0)

	resume.pressed.connect(_resume)
	save_btn.pressed.connect(_save_game)
	settings.pressed.connect(_show_settings)
	controls.pressed.connect(_show_controls)
	quit.pressed.connect(_quit)

	_main_panel.add_child(resume)
	_main_panel.add_child(save_btn)
	_main_panel.add_child(settings)
	_main_panel.add_child(controls)
	_main_panel.add_child(quit)

	_save_label = Label.new()
	_save_label.text = "Game saved."
	_save_label.add_theme_font_size_override("font_size", 13)
	_save_label.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55, 0.90))
	_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_label.position = Vector2(440.0, 482.0)
	_save_label.size     = Vector2(400.0, 22.0)
	_save_label.visible  = false
	_main_panel.add_child(_save_label)


func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	add_child(_settings_panel)

	_add_panel_bg(_settings_panel, Vector2(440.0, 210.0), Vector2(400.0, 260.0))
	_add_title(_settings_panel, "SETTINGS", 28, Vector2(440.0, 226.0))
	_add_divider(_settings_panel, Vector2(490.0, 278.0))

	# Fullscreen row
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.add_theme_font_size_override("font_size", 18)
	fs_label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.68, 1.0))
	fs_label.position = Vector2(480.0, 298.0)
	fs_label.size     = Vector2(180.0, 36.0)
	_settings_panel.add_child(fs_label)

	var fs_toggle := CheckButton.new()
	fs_toggle.position      = Vector2(710.0, 298.0)
	fs_toggle.size          = Vector2(80.0, 36.0)
	fs_toggle.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	fs_toggle.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)
	_settings_panel.add_child(fs_toggle)

	var back := _make_button("Back", Vector2(540.0, 365.0), 20)
	back.pressed.connect(_show_main)
	_settings_panel.add_child(back)


func _build_controls_panel() -> void:
	_controls_panel = Control.new()
	_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_panel.visible = false
	add_child(_controls_panel)

	_add_panel_bg(_controls_panel, Vector2(380.0, 168.0), Vector2(520.0, 400.0))
	_add_title(_controls_panel, "CONTROLS", 28, Vector2(380.0, 182.0))
	_add_divider(_controls_panel, Vector2(430.0, 234.0))

	# Column headers
	_add_ctrl_header(_controls_panel, "ACTION",    480.0, 248.0)
	_add_ctrl_header(_controls_panel, "KEYBOARD",  660.0, 248.0)
	_add_ctrl_header(_controls_panel, "GAMEPAD",   780.0, 248.0)

	var rows := [
		["Move",         "A / D",    "Left Stick"],
		["Jump",         "Space",    "A"],
		["Attack",       "Z",        "X"],
		["Dash",         "Shift",    "LB"],
		["Throw Item",   "Q",        "RB"],
		["Cycle Item",   "R",        "R3"],
		["Interact",     "E",        "Y"],
		["Pause",        "Escape",   "Start"],
	]

	var row_y := 278.0
	for row in rows:
		_add_ctrl_row(_controls_panel, row[0], row[1], row[2], row_y)
		row_y += 28.0

	var back := _make_button("Back", Vector2(540.0, 510.0), 20)
	back.pressed.connect(_show_main)
	_controls_panel.add_child(back)


func _add_ctrl_header(parent: Control, text: String, x: float, y: float) -> void:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = Vector2(x, y)
	lbl.size     = Vector2(120.0, 20.0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.47, 0.42, 0.80))
	parent.add_child(lbl)


func _add_ctrl_row(parent: Control, action: String, kb: String, gp: String, y: float) -> void:
	# Action name
	var act_lbl := Label.new()
	act_lbl.text     = action
	act_lbl.position = Vector2(480.0, y)
	act_lbl.size     = Vector2(180.0, 26.0)
	act_lbl.add_theme_font_size_override("font_size", 16)
	act_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.72, 1.0))
	parent.add_child(act_lbl)

	# Keyboard binding — styled like a key chip
	var kb_lbl := Label.new()
	kb_lbl.text     = kb
	kb_lbl.position = Vector2(660.0, y)
	kb_lbl.size     = Vector2(116.0, 26.0)
	kb_lbl.add_theme_font_size_override("font_size", 15)
	kb_lbl.add_theme_color_override("font_color", Color(0.94, 0.88, 0.70, 1.0))
	parent.add_child(kb_lbl)

	# Gamepad binding
	var gp_lbl := Label.new()
	gp_lbl.text     = gp
	gp_lbl.position = Vector2(780.0, y)
	gp_lbl.size     = Vector2(116.0, 26.0)
	gp_lbl.add_theme_font_size_override("font_size", 15)
	gp_lbl.add_theme_color_override("font_color", Color(0.68, 0.78, 0.94, 1.0))
	parent.add_child(gp_lbl)


# ── Shared helpers ─────────────────────────────────────────────────────────────

func _add_panel_bg(parent: Control, pos: Vector2, size: Vector2) -> void:
	var panel := ColorRect.new()
	panel.position = pos
	panel.size     = size
	panel.color    = Color(0.08, 0.07, 0.10, 0.95)
	parent.add_child(panel)


func _add_title(parent: Control, text: String, font_size: int, pos: Vector2) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color(0.78, 0.73, 0.68, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = pos
	title.size     = Vector2(400.0, 44.0)
	parent.add_child(title)


func _add_divider(parent: Control, pos: Vector2) -> void:
	var divider := ColorRect.new()
	divider.position = pos
	divider.size     = Vector2(300.0, 1.0)
	divider.color    = Color(0.35, 0.30, 0.25, 0.6)
	parent.add_child(divider)


func _make_button(txt: String, pos: Vector2, font_size: int) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(200.0, 40.0)
	btn.flat     = true
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color",         Color(0.78, 0.73, 0.68, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.96, 0.92, 0.88, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.50, 0.46, 0.42, 1.0))
	return btn


# ── Actions ────────────────────────────────────────────────────────────────────

func _pause() -> void:
	visible           = true
	get_tree().paused = true
	_show_main()


func _resume() -> void:
	visible           = false
	get_tree().paused = false


func _show_main() -> void:
	_main_panel.visible     = true
	_settings_panel.visible = false
	_controls_panel.visible = false


func _show_settings() -> void:
	_main_panel.visible     = false
	_settings_panel.visible = true
	_controls_panel.visible = false


func _show_controls() -> void:
	_main_panel.visible     = false
	_settings_panel.visible = false
	_controls_panel.visible = true


func _save_game() -> void:
	GameData.save()
	_save_label.visible = true
	await get_tree().create_timer(2.0).timeout
	_save_label.visible = false


func _quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
