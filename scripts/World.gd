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

	hud.setup(player.MAX_HEALTH)
	player.health_changed.connect(hud.on_health_changed)
	player.souls_changed.connect(hud.on_souls_changed)
	player.died.connect(_on_player_died)

	death_zone.body_entered.connect(_on_death_zone_entered)
	h_transition.body_entered.connect(_on_horizontal_transition)
	v_transition.body_entered.connect(_on_vertical_transition)


# ── Room transitions ───────────────────────────────────────────────────────────

func _on_horizontal_transition(body: Node) -> void:
	if body != player:
		return
	if player.velocity.x > 0.0:
		_set_room(1280, 2560, 0, 720)   # → Room 2
	elif player.velocity.x < 0.0:
		_set_room(0, 1280, 0, 720)      # ← Room 1


func _on_vertical_transition(body: Node) -> void:
	if body != player:
		return
	if player.velocity.y > 0.0:
		_set_room(0, 1280, 720, 1440)   # ↓ Room 3
	elif player.velocity.y < 0.0:
		_set_room(0, 1280, 0, 720)      # ↑ Room 1


func _set_room(left: int, right: int, top: int, bottom: int) -> void:
	camera.limit_left   = left
	camera.limit_right  = right
	camera.limit_top    = top
	camera.limit_bottom = bottom


# ── Death & souls ──────────────────────────────────────────────────────────────

func _on_player_died(death_pos: Vector2, soul_amount: int) -> void:
	if is_instance_valid(death_orb):
		death_orb.queue_free()
	death_orb = null

	if soul_amount <= 0:
		return

	var orb: Area2D = SOUL_ORB_SCENE.instantiate()
	orb.setup(soul_amount, player)
	orb.global_position = death_pos
	orb.collected.connect(func(): death_orb = null)
	add_child(orb)
	death_orb = orb


func _on_death_zone_entered(body: Node) -> void:
	if body == player:
		player.kill()
