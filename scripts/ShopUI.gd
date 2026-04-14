extends CanvasLayer

## Upgrade shop overlay. Pauses the game while open.
## Opened by Merchant nodes; closed via button or Escape.

signal closed

@onready var embers_label : Label         = $Panel/Margin/VBox/EmbersLabel
@onready var upgrade_list : VBoxContainer = $Panel/Margin/VBox/UpgradeList
@onready var close_btn    : Button        = $Panel/Margin/VBox/CloseBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # run even while tree is paused
	close_btn.pressed.connect(close)
	GameData.embers_changed.connect(_on_embers_changed)
	visible = false


func open() -> void:
	_rebuild()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ── Ember display ──────────────────────────────────────────────────────────────

func _on_embers_changed(_current: int) -> void:
	if not visible:
		return
	_rebuild()


# ── Upgrade list ───────────────────────────────────────────────────────────────

func _rebuild() -> void:
	embers_label.text = "EMBERS   %d" % GameData.embers

	for child in upgrade_list.get_children():
		child.queue_free()

	for key in GameData.UPGRADES.keys():
		_add_row(key)

	_add_section_header("SUPPLIES")
	for type in GameData.THROWABLES.keys():
		_add_throwable_row(type)


func _add_row(key: String) -> void:
	var data    := GameData.UPGRADES[key] as Dictionary
	var level   := GameData.get_upgrade_level(key)
	var max_lvl := data.get("max_level", 0) as int
	var cost    := GameData.get_next_cost(key)
	var maxed   := level >= max_lvl
	var afford  := not maxed and GameData.embers >= cost

	var row := HBoxContainer.new()
	row.name = "Row_" + key
	row.add_theme_constant_override("separation", 8)

	# Upgrade name
	var name_lbl := Label.new()
	name_lbl.text = data.get("label", key)
	name_lbl.custom_minimum_size.x = 160
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 1))
	row.add_child(name_lbl)

	# Level
	var lvl_lbl := Label.new()
	lvl_lbl.text = "Lv %d/%d" % [level, max_lvl]
	lvl_lbl.custom_minimum_size.x = 64
	lvl_lbl.add_theme_font_size_override("font_size", 13)
	lvl_lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.46, 1))
	row.add_child(lvl_lbl)

	# Cost
	var cost_lbl := Label.new()
	cost_lbl.custom_minimum_size.x = 64
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_size_override("font_size", 15)
	if maxed:
		cost_lbl.text = "MAX"
		cost_lbl.add_theme_color_override("font_color", Color(0.40, 0.62, 0.40, 1))
	else:
		cost_lbl.text = str(cost)
		cost_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.78, 0.20, 1) if afford else Color(0.50, 0.32, 0.15, 1))
	row.add_child(cost_lbl)

	# Buy button
	var btn := Button.new()
	btn.text = "Buy"
	btn.disabled = maxed or not afford
	btn.custom_minimum_size = Vector2(60, 0)
	btn.pressed.connect(_on_buy.bind(key))
	row.add_child(btn)

	upgrade_list.add_child(row)


func _refresh_rows() -> void:
	for key in GameData.UPGRADES.keys():
		var row := upgrade_list.get_node_or_null("Row_" + key) as HBoxContainer
		if row == null:
			continue
		var cost   := GameData.get_next_cost(key)
		var maxed  := cost < 0
		var afford := not maxed and GameData.embers >= cost

		var cost_lbl := row.get_child(2) as Label
		var btn      := row.get_child(3) as Button

		if maxed:
			cost_lbl.text = "MAX"
			cost_lbl.add_theme_color_override("font_color", Color(0.40, 0.62, 0.40, 1))
		else:
			cost_lbl.text = str(cost)
			cost_lbl.add_theme_color_override("font_color",
				Color(0.95, 0.78, 0.20, 1) if afford else Color(0.50, 0.32, 0.15, 1))
		btn.disabled = not afford


func _on_buy(key: String) -> void:
	if GameData.purchase(key):
		AudioManager.play("purchase")
		_rebuild()


# ── Throwable section ──────────────────────────────────────────────────────────

func _add_section_header(title: String) -> void:
	var sep := HSeparator.new()
	upgrade_list.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46, 0.80))
	upgrade_list.add_child(lbl)


func _add_throwable_row(type: String) -> void:
	var data   := GameData.THROWABLES[type] as Dictionary
	var count  : int  = GameData.get_throwable_count(type)
	var cost   : int  = data.get("cost", 0)
	var amount : int  = data.get("amount", 0)
	var afford : bool = GameData.embers >= cost

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = data.get("label", type)
	name_lbl.custom_minimum_size.x = 160
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.88, 0.80, 1))
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "×%d" % count
	count_lbl.custom_minimum_size.x = 56
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.55, 0.53, 0.46, 1))
	row.add_child(count_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "%d for %d" % [cost, amount]
	cost_lbl.custom_minimum_size.x = 88
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_font_size_override("font_size", 15)
	cost_lbl.add_theme_color_override("font_color",
		Color(0.95, 0.78, 0.20, 1) if afford else Color(0.50, 0.32, 0.15, 1))
	row.add_child(cost_lbl)

	var btn := Button.new()
	btn.text = "Buy"
	btn.disabled = not afford
	btn.custom_minimum_size = Vector2(60, 0)
	btn.pressed.connect(_on_buy_throwable.bind(type))
	row.add_child(btn)

	upgrade_list.add_child(row)


func _on_buy_throwable(type: String) -> void:
	if GameData.buy_throwable(type):
		AudioManager.play("purchase")
		_rebuild()
