extends Control

const BTN_NORMAL  := Color(0.80, 0.76, 0.72, 1.0)
const BTN_HOVER   := Color(0.96, 0.93, 0.88, 1.0)
const BTN_PRESSED := Color(0.55, 0.50, 0.46, 1.0)

var _menu_root      : Control     = null
var _settings_panel : Control     = null
var _confirm_panel  : Control     = null
var _no_save_label  : Label       = null
var _fs_toggle      : CheckButton = null


func _ready() -> void:
	_build_background()
	_build_title()
	_menu_root = _build_menu()
	add_child(_menu_root)
	_settings_panel = _build_settings()
	add_child(_settings_panel)
	_settings_panel.visible = false

	_confirm_panel = _build_confirm_panel()
	add_child(_confirm_panel)
	_confirm_panel.visible = false


# ── Background ─────────────────────────────────────────────────────────────────

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.034, 0.032, 0.047, 1.0)
	add_child(bg)

	# Subtle atmosphere bands
	_band(Color(0.07, 0.04, 0.12, 0.30), Vector2(0, 210),  Vector2(1280, 130))
	_band(Color(0.04, 0.03, 0.08, 0.22), Vector2(0, 570),  Vector2(1280, 150))


func _band(col: Color, pos: Vector2, sz: Vector2) -> void:
	var cr := ColorRect.new()
	cr.position = pos
	cr.size     = sz
	cr.color    = col
	add_child(cr)


# ── Title ──────────────────────────────────────────────────────────────────────

func _build_title() -> void:
	var title := Label.new()
	title.text = "DUSKHOLM"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.90, 0.87, 0.82, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 108)
	title.size     = Vector2(600, 106)
	add_child(title)

	var tagline := Label.new()
	tagline.text = "the embers do not lie"
	tagline.add_theme_font_size_override("font_size", 15)
	tagline.add_theme_color_override("font_color", Color(0.50, 0.43, 0.58, 0.75))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.position = Vector2(390, 220)
	tagline.size     = Vector2(500, 24)
	add_child(tagline)

	var line := ColorRect.new()
	line.position = Vector2(440, 258)
	line.size     = Vector2(400, 1)
	line.color    = Color(0.38, 0.24, 0.55, 0.5)
	add_child(line)


# ── Main menu ──────────────────────────────────────────────────────────────────

func _build_menu() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var new_game_btn  := _menu_button("New Game",  Vector2(490, 284.0))
	var load_game_btn := _menu_button("Load Game", Vector2(490, 348.0))
	var settings_btn  := _menu_button("Settings",  Vector2(490, 412.0))
	var quit_btn      := _menu_button("Quit",      Vector2(490, 476.0))

	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	settings_btn.pressed.connect(_on_open_settings)
	quit_btn.pressed.connect(func(): get_tree().quit())

	root.add_child(new_game_btn)
	root.add_child(load_game_btn)
	root.add_child(settings_btn)
	root.add_child(quit_btn)

	_no_save_label = Label.new()
	_no_save_label.text = "No save data found."
	_no_save_label.add_theme_font_size_override("font_size", 13)
	_no_save_label.add_theme_color_override("font_color", Color(0.72, 0.35, 0.35, 0.9))
	_no_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_save_label.position = Vector2(490, 500)
	_no_save_label.size     = Vector2(300, 22)
	_no_save_label.visible  = false
	root.add_child(_no_save_label)

	return root


# ── Settings panel ─────────────────────────────────────────────────────────────

func _build_settings() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	root.add_child(dim)

	var panel := ColorRect.new()
	panel.position = Vector2(380, 160)
	panel.size     = Vector2(520, 390)
	panel.color    = Color(0.08, 0.07, 0.11, 1.0)
	root.add_child(panel)

	# Border lines
	for bd in [
		[Vector2(380, 160), Vector2(520, 1)],
		[Vector2(380, 549), Vector2(520, 1)],
		[Vector2(380, 160), Vector2(1,   390)],
		[Vector2(899, 160), Vector2(1,   390)],
	]:
		var b := ColorRect.new()
		b.position = bd[0]
		b.size     = bd[1]
		b.color    = Color(0.38, 0.24, 0.55, 0.55)
		root.add_child(b)

	var stitle := Label.new()
	stitle.text = "SETTINGS"
	stitle.add_theme_font_size_override("font_size", 26)
	stitle.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78, 1.0))
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.position = Vector2(380, 192)
	stitle.size     = Vector2(520, 38)
	root.add_child(stitle)

	var sdiv := ColorRect.new()
	sdiv.position = Vector2(420, 242)
	sdiv.size     = Vector2(440, 1)
	sdiv.color    = Color(0.38, 0.24, 0.55, 0.40)
	root.add_child(sdiv)

	# Fullscreen row
	var fslabel := Label.new()
	fslabel.text = "Fullscreen"
	fslabel.add_theme_font_size_override("font_size", 18)
	fslabel.add_theme_color_override("font_color", BTN_NORMAL)
	fslabel.position = Vector2(430, 272)
	fslabel.size     = Vector2(280, 30)
	root.add_child(fslabel)

	_fs_toggle = CheckButton.new()
	_fs_toggle.position      = Vector2(754, 270)
	_fs_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_fs_toggle.toggled.connect(_on_fullscreen_toggled)
	root.add_child(_fs_toggle)

	var back := _menu_button("Back", Vector2(490, 464))
	back.pressed.connect(_on_close_settings)
	root.add_child(back)

	return root


# ── Shared button factory ──────────────────────────────────────────────────────

func _menu_button(txt: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(300, 44)
	btn.flat     = true
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color",         BTN_NORMAL)
	btn.add_theme_color_override("font_hover_color",   BTN_HOVER)
	btn.add_theme_color_override("font_pressed_color", BTN_PRESSED)
	return btn


# ── Confirm new game panel ─────────────────────────────────────────────────────

func _build_confirm_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	root.add_child(dim)

	var panel := ColorRect.new()
	panel.position = Vector2(430, 240)
	panel.size     = Vector2(420, 240)
	panel.color    = Color(0.08, 0.07, 0.11, 1.0)
	root.add_child(panel)

	for bd in [
		[Vector2(430, 240), Vector2(420, 1)],
		[Vector2(430, 479), Vector2(420, 1)],
		[Vector2(430, 240), Vector2(1,   240)],
		[Vector2(849, 240), Vector2(1,   240)],
	]:
		var b := ColorRect.new()
		b.position = bd[0]
		b.size     = bd[1]
		b.color    = Color(0.55, 0.20, 0.20, 0.7)
		root.add_child(b)

	var warn := Label.new()
	warn.text = "Start a New Game?"
	warn.add_theme_font_size_override("font_size", 22)
	warn.add_theme_color_override("font_color", Color(0.90, 0.87, 0.82, 1.0))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.position = Vector2(430, 268)
	warn.size     = Vector2(420, 34)
	root.add_child(warn)

	var sub := Label.new()
	sub.text = "Your existing save will be erased.\nThis cannot be undone."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.62, 0.55, 0.58, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(430, 316)
	sub.size     = Vector2(420, 52)
	root.add_child(sub)

	var erase := _menu_button("Erase & Begin", Vector2(450, 386))
	erase.add_theme_color_override("font_color",       Color(0.88, 0.42, 0.42, 1.0))
	erase.add_theme_color_override("font_hover_color", Color(1.00, 0.60, 0.60, 1.0))
	erase.pressed.connect(_start_new_game)
	root.add_child(erase)

	var cancel := _menu_button("Cancel", Vector2(450, 434))
	cancel.add_theme_font_size_override("font_size", 16)
	cancel.pressed.connect(func():
		_confirm_panel.visible = false
		_menu_root.visible     = true
	)
	root.add_child(cancel)

	return root


# ── Handlers ───────────────────────────────────────────────────────────────────

func _on_new_game() -> void:
	if GameData.has_save():
		_menu_root.visible     = false
		_confirm_panel.visible = true
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameData.reset()
	GameData.delete_save()
	get_tree().change_scene_to_file("res://scenes/World.tscn")


func _on_load_game() -> void:
	if not GameData.has_save():
		_no_save_label.visible = true
		await get_tree().create_timer(2.2).timeout
		_no_save_label.visible = false
		return
	GameData.load_save()
	get_tree().change_scene_to_file("res://scenes/World.tscn")


func _on_open_settings() -> void:
	_menu_root.visible      = false
	_settings_panel.visible = true


func _on_close_settings() -> void:
	_settings_panel.visible = false
	_menu_root.visible      = true


func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
