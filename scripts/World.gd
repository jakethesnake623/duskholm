extends Node2D

const SOUL_ORB_SCENE = preload("res://scenes/SoulOrb.tscn")

@onready var player       : CharacterBody2D = $Player
@onready var hud          : CanvasLayer     = $HUD
@onready var death_zone   : Area2D          = $DeathZone
@onready var h_transition : Area2D          = $Transitions/HorizontalTransition
@onready var v_transition : Area2D          = $Transitions/VerticalTransition

var camera    : Camera2D
var death_orb : Node = null


func _ready() -> void:
	camera = player.get_node("Camera2D")

	hud.setup(GameData.get_max_health())
	hud.on_embers_changed(GameData.embers)

	player.health_changed.connect(hud.on_health_changed)
	player.died.connect(_on_player_died)

	GameData.embers_changed.connect(hud.on_embers_changed)
	GameData.upgrade_purchased.connect(_on_upgrade_purchased)

	death_zone.body_entered.connect(_on_death_zone_entered)
	h_transition.body_entered.connect(_on_horizontal_transition)
	v_transition.body_entered.connect(_on_vertical_transition)


# ── Upgrade purchased ──────────────────────────────────────────────────────────

func _on_upgrade_purchased(key: String) -> void:
	# Rebuild HUD masks in case max health changed
	hud.setup(GameData.get_max_health())
	# Buying Vitality fully restores health
	if key == "vitality":
		player.health = GameData.get_max_health()
	hud.on_health_changed(player.health, GameData.get_max_health())


# ── Room transitions ───────────────────────────────────────────────────────────

func _on_horizontal_transition(body: Node) -> void:
	if body != player:
		return
	if player.velocity.x > 0.0:
		_set_room(1280, 2560, 0, 720)
	elif player.velocity.x < 0.0:
		_set_room(0, 1280, 0, 720)


func _on_vertical_transition(body: Node) -> void:
	if body != player:
		return
	if player.velocity.y > 0.0:
		_set_room(0, 1280, 720, 1440)
	elif player.velocity.y < 0.0:
		_set_room(0, 1280, 0, 720)


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

	if ember_amount <= 0:
		return

	var orb: Area2D = SOUL_ORB_SCENE.instantiate()
	orb.setup(ember_amount)
	orb.global_position = death_pos
	orb.collected.connect(func(): death_orb = null)
	add_child(orb)
	death_orb = orb


func _on_death_zone_entered(body: Node) -> void:
	if body == player:
		player.kill()
