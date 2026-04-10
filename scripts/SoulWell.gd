extends Node2D

var player_nearby := false
var player_ref    : CharacterBody2D = null
var activated     := false

var _glow_rect : ColorRect = null

@onready var prompt_label : Label  = $PromptLabel
@onready var detect_zone  : Area2D = $DetectZone


func _ready() -> void:
	_build_visual()
	prompt_label.visible = false
	detect_zone.body_entered.connect(_on_body_entered)
	detect_zone.body_exited.connect(_on_body_exited)


func _build_visual() -> void:
	var stone := Color(0.28, 0.25, 0.22, 1.0)
	var void_  := Color(0.04, 0.02, 0.07, 1.0)

	var vis := Node2D.new()
	vis.name = "Visual"
	add_child(vis)

	_rect(vis, -30, -12,  30,   0, stone)          # base
	_rect(vis, -30, -56, -18, -12, stone)          # left pillar
	_rect(vis,  18, -56,  30, -12, stone)          # right pillar
	_rect(vis, -30, -64,  30, -56, stone)          # crossbeam
	_rect(vis, -18, -56,  18, -12, void_)          # void opening
	_glow_rect = _rect(vis, -12, -28,  12, -16, Color(0.20, 0.06, 0.45, 0.5))  # soul glow


func _rect(parent: Node, l: float, t: float, r: float, b: float, col: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.offset_left   = l
	cr.offset_top    = t
	cr.offset_right  = r
	cr.offset_bottom = b
	cr.color = col
	parent.add_child(cr)
	return cr


func _process(_delta: float) -> void:
	if _glow_rect:
		var t     := Time.get_ticks_msec() * 0.001
		var speed := 2.2 if activated else 0.7
		var pulse := 0.5 + 0.5 * sin(t * speed)
		if activated:
			_glow_rect.color = Color(0.45, 0.15, 0.90, 0.6 + 0.35 * pulse)
		else:
			_glow_rect.color = Color(0.20, 0.06, 0.45, 0.30 + 0.20 * pulse)

	if player_nearby and Input.is_action_just_pressed("interact"):
		_ponder()


func _ponder() -> void:
	if player_ref == null:
		return
	activated = true
	GameData.spawn_position = global_position + Vector2(0, -8)
	player_ref.rest(global_position)
	GameData.save()
	prompt_label.text = "...the well remembers..."
	await get_tree().create_timer(2.0).timeout
	if player_nearby:
		prompt_label.text = "[ E ]  Ponder"
	else:
		prompt_label.visible = false


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		player_ref    = body
		prompt_label.text    = "[ E ]  Ponder"
		prompt_label.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		player_ref    = null
		prompt_label.visible = false
