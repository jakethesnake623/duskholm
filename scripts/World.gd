extends Node2D

const SOUL_ORB_SCENE = preload("res://scenes/SoulOrb.tscn")

@onready var player    : CharacterBody2D = $Player
@onready var hud       : CanvasLayer     = $HUD
@onready var death_zone: Area2D          = $DeathZone

var death_orb: Node = null   # the one retrievable orb; lost if player dies again


func _ready() -> void:
	hud.setup(player.MAX_HEALTH)

	player.health_changed.connect(hud.on_health_changed)
	player.souls_changed.connect(hud.on_souls_changed)
	player.died.connect(_on_player_died)

	death_zone.body_entered.connect(_on_death_zone_entered)


func _on_player_died(death_pos: Vector2, soul_amount: int) -> void:
	# Destroy any existing orb — it's gone forever (Dark Souls rule)
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
