extends Node2D

const SOUL_ORB_SCENE = preload("res://scenes/SoulOrb.tscn")

@onready var player        : CharacterBody2D = $Player
@onready var hud           : CanvasLayer     = $HUD
@onready var death_screen  : CanvasLayer     = $DeathScreen
@onready var pause_menu    : CanvasLayer     = $PauseMenu
@onready var death_zone    : Area2D          = $DeathZone
@onready var boss          : CharacterBody2D = $Boss
@onready var boss_hpbar    : CanvasLayer     = $BossHealthBar
@onready var boss_gate     : StaticBody2D    = $BossGate
@onready var scaffold      : Node2D          = $BossScaffold
@onready var minimap       : CanvasLayer     = $MiniMap
@onready var boss2         : CharacterBody2D = $Boss2
@onready var boss2_hpbar   : CanvasLayer     = $BossHealthBar2
@onready var furnace_gate  : StaticBody2D    = $FurnaceGate

var camera    : Camera2D
var death_orb : Node = null

# ── Dev: room label ────────────────────────────────────────────────────────────
var _room_label : Label = null


func _ready() -> void:
	camera = player.get_node("Camera2D")

	# Place player at saved spawn (default on new game, well position on load)
	player.global_position = GameData.spawn_position
	player.spawn_position  = GameData.spawn_position
	_update_camera_room()

	minimap.setup(player)
	_build_room_label()
	hud.setup(GameData.get_max_health())
	hud.on_embers_changed(GameData.embers)
	hud.on_throwables_changed()

	player.health_changed.connect(hud.on_health_changed)
	player.died.connect(_on_player_died)
	player.respawned.connect(_update_camera_room)
	death_screen.continue_pressed.connect(player.respawn)
	death_screen.continue_pressed.connect(func(): pause_menu.can_pause = true)
	death_screen.continue_pressed.connect(func(): GameData.rested.emit())

	GameData.embers_changed.connect(hud.on_embers_changed)
	GameData.upgrade_purchased.connect(_on_upgrade_purchased)

	death_zone.body_entered.connect(_on_death_zone_entered)

	boss.health_changed.connect(boss_hpbar.on_health_changed)
	boss.boss_died.connect(boss_hpbar.on_boss_died)
	boss.boss_died.connect(_on_boss_died)
	GameData.rested.connect(boss_hpbar.deactivate)

	boss2.health_changed.connect(boss2_hpbar.on_health_changed)
	boss2.boss_died.connect(boss2_hpbar.on_boss_died)
	boss2.boss_died.connect(_on_boss2_died)
	GameData.rested.connect(boss2_hpbar.deactivate)


# ── Upgrade purchased ──────────────────────────────────────────────────────────

func _on_upgrade_purchased(key: String) -> void:
	# Rebuild HUD masks in case max health changed
	hud.setup(GameData.get_max_health())
	# Buying Vitality fully restores health
	if key == "vitality":
		player.health = GameData.get_max_health()
	hud.on_health_changed(player.health, GameData.get_max_health())


func _build_room_label() -> void:
	var cl := CanvasLayer.new()
	cl.layer        = 4
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	_room_label = Label.new()
	_room_label.add_theme_font_size_override("font_size", 11)
	_room_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 0.75))
	_room_label.position = Vector2(8.0, 8.0)
	cl.add_child(_room_label)


# ── Camera room tracking ───────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_update_camera_room()


func _update_camera_room() -> void:
	var pos := player.global_position
	var rid : String
	if pos.y >= 1440 and pos.x >= 2560:
		_set_room(2560, 3840, 1440, 2160)
		rid = "room8"
	elif pos.y >= 1440 and pos.x >= 1280:
		_set_room(1280, 2560, 1440, 2160)
		rid = "room5"
	elif pos.y >= 1440:
		_set_room(0, 1280, 1440, 2160)
		rid = "room4"
	elif pos.y >= 720 and pos.x < 0:
		_set_room(-1280, 0, 720, 1440)
		rid = "room6"
	elif pos.y >= 720 and pos.x >= 1280:
		_set_room(1280, 2560, 720, 1440)
		rid = "room7"
	elif pos.y >= 720:
		_set_room(0, 1280, 720, 1440)
		rid = "room3"
	elif pos.x < 0:
		_set_room(-1280, 0, 0, 720)
		rid = "room0"
	elif pos.x >= 1280:
		_set_room(1280, 2560, 0, 720)
		rid = "room2"
	else:
		_set_room(0, 1280, 0, 720)
		rid = "room1"
	GameData.discover_room(rid)
	if _room_label:
		const NAMES := {
			"room0": "0 — The Cradle",      "room1": "1 — The Entrance",
			"room2": "2 — The Spire",       "room3": "3 — The Vault",
			"room4": "4 — The Sunken Hall", "room5": "5 — The Beyond",
			"room6": "6 — The Hollow",      "room7": "7 — The Ossuary",
			"room8": "8 — The Foundry",
		}
		_room_label.text = "[DEV] Room " + NAMES.get(rid, rid)


func _set_room(left: int, right: int, top: int, bottom: int) -> void:
	camera.limit_left   = left
	camera.limit_right  = right
	camera.limit_top    = top
	camera.limit_bottom = bottom


# ── Death & ember orb ──────────────────────────────────────────────────────────

func _on_player_died(death_pos: Vector2, ember_amount: int) -> void:
	if is_instance_valid(death_orb):
		death_orb.queue_free()
	death_orb = null

	if ember_amount > 0:
		var orb: Area2D = SOUL_ORB_SCENE.instantiate()
		orb.setup(ember_amount)
		orb.global_position = death_pos
		orb.collected.connect(func(): death_orb = null)
		add_child(orb)
		death_orb = orb

	pause_menu.can_pause = false
	death_screen.show_death()


func _on_death_zone_entered(body: Node) -> void:
	if body == player:
		player.kill()


# ── Boss defeated ──────────────────────────────────────────────────────────────

func _on_boss_died() -> void:
	_shake_camera(1.4, 7.0)
	await get_tree().create_timer(0.9).timeout
	boss_gate.crumble()
	furnace_gate.crumble()
	await get_tree().create_timer(0.6).timeout
	_reveal_scaffold()


func _on_boss2_died() -> void:
	_shake_camera(1.8, 9.0)


func _reveal_scaffold() -> void:
	# Reveal scaffold platforms bottom-to-top with a staggered fade-in.
	var platforms := scaffold.get_children()
	for i in platforms.size():
		var plat : StaticBody2D = platforms[i]
		plat.get_node("CollisionShape2D").set_deferred("disabled", false)
		var vis : ColorRect = plat.get_node("Visual")
		var tw := create_tween()
		tw.tween_interval(i * 0.14)
		tw.tween_property(vis, "modulate:a", 1.0, 0.40)


func _shake_camera(duration: float, strength: float) -> void:
	var steps : int = int(duration / 0.055)
	var tween := create_tween()
	for i in steps:
		var decay  : float   = 1.0 - float(i) / float(steps)
		var offset : Vector2 = Vector2(
			randf_range(-strength, strength) * decay,
			randf_range(-strength, strength) * decay
		)
		tween.tween_property(camera, "offset", offset, 0.055)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.12)
