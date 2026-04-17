extends Node2D

## One-way zipline. Place the node at the grab anchor (bottom/start).
## Set land_pos to the world-space landing point (top/end).
## The player presses [E] while nearby to ride it.

@export var land_pos : Vector2 = Vector2.ZERO

const CABLE_COLOR  := Color(0.50, 0.40, 0.22, 0.90)
const HOOK_COLOR   := Color(0.70, 0.58, 0.28, 1.00)
const PROMPT_COLOR := Color(1.00, 0.90, 0.60, 0.85)
const ZIP_SPEED    := 180.0   # world pixels per second

var _player_nearby : bool                = false
var _player_ref    : CharacterBody2D     = null
var _prompt        : Label               = null

@onready var _grab_zone : Area2D = $GrabZone


func _ready() -> void:
	_grab_zone.body_entered.connect(_on_body_entered)
	_grab_zone.body_exited.connect(_on_body_exited)
	_build_hook_visual()
	_build_prompt()


# ── Visuals ─────────────────────────────────────────────────────────────────────

func _build_hook_visual() -> void:
	# Simple hook shape: a vertical peg with a small horizontal top bar
	_hook_rect(Vector2(-5.0, -14.0), Vector2(10.0,  3.0))  # top bar
	_hook_rect(Vector2(-2.0, -11.0), Vector2( 4.0, 14.0))  # shaft
	_hook_rect(Vector2( 2.0,  0.0),  Vector2( 5.0,  3.0))  # bottom hook-tip


func _hook_rect(offset: Vector2, sz: Vector2) -> void:
	var r    := ColorRect.new()
	r.size     = sz
	r.position = offset
	r.color    = HOOK_COLOR
	add_child(r)


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = "[E] Grab"
	_prompt.add_theme_font_size_override("font_size", 10)
	_prompt.add_theme_color_override("font_color", PROMPT_COLOR)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size    = Vector2(72.0, 14.0)
	_prompt.position = Vector2(-36.0, -30.0)
	_prompt.visible = false
	add_child(_prompt)


func _draw() -> void:
	var local_land := to_local(land_pos)
	# Cable
	draw_line(Vector2.ZERO, local_land, CABLE_COLOR, 2.0, true)
	# Landing peg
	draw_circle(local_land, 5.0, HOOK_COLOR)
	_draw_peg(local_land)


func _draw_peg(lp: Vector2) -> void:
	# A small cross at the landing end to indicate the anchor
	draw_line(lp + Vector2(-6.0, 0.0), lp + Vector2(6.0, 0.0), HOOK_COLOR, 2.0)
	draw_line(lp + Vector2(0.0, -6.0), lp + Vector2(0.0, 6.0), HOOK_COLOR, 2.0)


# ── Interaction ─────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _player_nearby and is_instance_valid(_player_ref):
		if event.is_action_pressed("interact"):
			_launch()


func _launch() -> void:
	if not is_instance_valid(_player_ref):
		return
	if not _player_ref.has_method("start_zip"):
		return

	var dist : float = global_position.distance_to(land_pos)
	var dur  : float = dist / ZIP_SPEED

	_player_ref.start_zip(land_pos, dur)

	# Hide prompt immediately — player is now riding
	_player_nearby  = false
	_prompt.visible = false


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_player_ref    = body as CharacterBody2D
		_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby  = false
		_player_ref     = null
		_prompt.visible = false
