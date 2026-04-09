extends Node2D

## Stationary merchant NPC.
## Shows a prompt when the player is nearby; opens the shop on interact.

var player_nearby := false

@onready var detect   : Area2D      = $DetectZone
@onready var prompt   : Label       = $PromptLabel
@onready var shop_ui  : CanvasLayer = $ShopUI


func _ready() -> void:
	_build_visual()
	prompt.visible = false

	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		shop_ui.open()


# ── Visual ─────────────────────────────────────────────────────────────────────
# Hooded figure assembled from ColorRects — replace with sprites later.

func _build_visual() -> void:
	var robe_col  := Color(0.22, 0.20, 0.28, 1.0)
	var hood_col  := Color(0.14, 0.13, 0.17, 1.0)
	var eye_col   := Color(0.92, 0.72, 0.15, 1.0)

	_add_rect(Vector2(0, -25), Vector2(28, 50), robe_col)    # robe
	_add_rect(Vector2(0, -59), Vector2(22, 20), hood_col)    # hood/head
	_add_rect(Vector2(-5, -63), Vector2(5, 4),  eye_col)     # left eye
	_add_rect(Vector2( 3, -63), Vector2(5, 4),  eye_col)     # right eye


func _add_rect(center: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.size     = size
	r.position = center - size * 0.5
	r.color    = color
	add_child(r)


# ── Detection ──────────────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby  = true
		prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby  = false
		prompt.visible = false
