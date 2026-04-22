extends CanvasLayer

## Minimap — procedural CanvasLayer UI drawn in the top-right corner.
## All 8 rooms are visible as dim outlines from the start (so the player can
## see the world's shape). Resting at a Soul Well in a room reveals it with
## its atmospheric colour. The player dot is always visible.

const WORLD_ORIGIN := Vector2(-1280.0, 0.0)
const WORLD_SIZE   := Vector2(5120.0, 2880.0)

# Minimap panel position and size (in 1280×720 viewport/screen pixels)
const PANEL_POS  := Vector2(1098.0, 8.0)
const PANEL_SIZE := Vector2(174.0, 102.0)
const MAP_PAD    := 6.0   # gap between panel edge and room cells

# room_id → [world Rect2, revealed Color]
const ROOM_DATA := {
	"room0": [Rect2(-1280,    0, 1280, 720), Color(0.30, 0.22, 0.50, 0.88)],
	"room1": [Rect2(    0,    0, 1280, 720), Color(0.55, 0.25, 0.10, 0.88)],
	"room2": [Rect2( 1280,    0, 1280, 720), Color(0.25, 0.28, 0.42, 0.88)],
	"room6": [Rect2(-1280,  720, 1280, 720), Color(0.18, 0.32, 0.30, 0.88)],
	"room3": [Rect2(    0,  720, 1280, 720), Color(0.22, 0.14, 0.40, 0.88)],
	"room7": [Rect2( 1280,  720, 1280, 720), Color(0.36, 0.28, 0.16, 0.88)],
	"room4": [Rect2(    0, 1440, 1280, 720), Color(0.44, 0.14, 0.10, 0.88)],
	"room5": [Rect2( 1280, 1440, 1280, 720), Color(0.22, 0.10, 0.36, 0.88)],
	"room8":  [Rect2( 2560, 1440, 1280, 720), Color(0.38, 0.18, 0.06, 0.88)],
	"room16": [Rect2(-1280, 2160, 1280, 720), Color(0.06, 0.18, 0.22, 0.88)],
	"room17": [Rect2(    0, 2160, 1280, 720), Color(0.24, 0.16, 0.08, 0.88)],
	"room18": [Rect2( 1280, 2160, 1280, 720), Color(0.28, 0.10, 0.04, 0.88)],
}

var _player     : CharacterBody2D = null
var _room_fills : Dictionary      = {}   # room_id → ColorRect (the revealed fill)
var _player_dot : ColorRect       = null


func _ready() -> void:
	layer = 5
	_build_panel()
	GameData.room_discovered.connect(_on_room_discovered)
	# Restore rooms that were already discovered in a previous session
	for rid in GameData.discovered_rooms:
		_on_room_discovered(rid)


func setup(p: CharacterBody2D) -> void:
	_player = p


# ── Build ───────────────────────────────────────────────────────────────────────

func _build_panel() -> void:
	var map_area := _map_area()

	# Dark background
	var bg := ColorRect.new()
	bg.position = PANEL_POS
	bg.size     = PANEL_SIZE
	bg.color    = Color(0.04, 0.03, 0.06, 0.84)
	add_child(bg)

	# Dim room backgrounds (always visible — show world structure)
	for rid in ROOM_DATA:
		var entry  : Array  = ROOM_DATA[rid]
		var wrect  : Rect2  = entry[0]
		var mrect  := _world_to_map(wrect, map_area)

		var dim := ColorRect.new()
		dim.position = mrect.position
		dim.size     = mrect.size
		dim.color    = Color(0.14, 0.12, 0.18, 0.72)
		add_child(dim)

		# Revealed colour fill (hidden until well is used in this room)
		var fill := ColorRect.new()
		fill.position   = mrect.position
		fill.size       = mrect.size
		fill.color      = entry[1]
		fill.modulate.a = 0.0
		add_child(fill)
		_room_fills[rid] = fill

	# Room cell borders drawn after all fills so they're always on top
	for rid in ROOM_DATA:
		var mrect := _world_to_map(ROOM_DATA[rid][0], map_area)
		_border_rect(mrect.position, mrect.size, Color(0.30, 0.24, 0.42, 0.55), 1.0)

	# Panel outer border
	_border_rect(PANEL_POS, PANEL_SIZE, Color(0.35, 0.28, 0.50, 0.80), 1.0)

	# [DEV] Room numbers — remove before ship
	const ROOM_NUMBERS := {
		"room0": "0",  "room1": "1",  "room2": "2",  "room3": "3",
		"room4": "4",  "room5": "5",  "room6": "6",  "room7": "7",
		"room8": "8",  "room16": "16", "room17": "17", "room18": "18",
	}
	for rid in ROOM_DATA:
		var mrect := _world_to_map(ROOM_DATA[rid][0], map_area)
		var lbl   := Label.new()
		lbl.text = ROOM_NUMBERS[rid]
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4, 0.70))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = mrect.position + Vector2(0.0, mrect.size.y * 0.5 - 5.0)
		lbl.size     = Vector2(mrect.size.x, 10.0)
		add_child(lbl)

	# Player dot — rendered last so it's always on top
	_player_dot = ColorRect.new()
	_player_dot.size  = Vector2(4.0, 4.0)
	_player_dot.color = Color(1.0, 0.78, 0.25, 1.0)
	add_child(_player_dot)


func _border_rect(pos: Vector2, sz: Vector2, col: Color, thickness: float) -> void:
	for i in 4:
		var r := ColorRect.new()
		r.color = col
		match i:
			0: r.position = pos;                            r.size = Vector2(sz.x, thickness)        # top
			1: r.position = pos + Vector2(0, sz.y - thickness); r.size = Vector2(sz.x, thickness)   # bottom
			2: r.position = pos;                            r.size = Vector2(thickness, sz.y)        # left
			3: r.position = pos + Vector2(sz.x - thickness, 0); r.size = Vector2(thickness, sz.y)   # right
		add_child(r)


# ── Helpers ─────────────────────────────────────────────────────────────────────

func _map_area() -> Rect2:
	return Rect2(
		PANEL_POS + Vector2(MAP_PAD, MAP_PAD),
		PANEL_SIZE - Vector2(MAP_PAD * 2.0, MAP_PAD * 2.0)
	)


func _world_to_map(world_rect: Rect2, map_area: Rect2) -> Rect2:
	var map_scale := map_area.size / WORLD_SIZE
	var tl        := map_area.position + (world_rect.position - WORLD_ORIGIN) * map_scale
	return Rect2(tl.round(), (world_rect.size * map_scale).round())


func _world_pos_to_screen(world_pos: Vector2) -> Vector2:
	var map_area  := _map_area()
	var map_scale := map_area.size / WORLD_SIZE
	return map_area.position + (world_pos - WORLD_ORIGIN) * map_scale


# ── Signals ─────────────────────────────────────────────────────────────────────

func _on_room_discovered(rid: String) -> void:
	if not _room_fills.has(rid):
		return
	var fill : ColorRect = _room_fills[rid]
	if fill.modulate.a >= 1.0:
		return
	var tw := create_tween()
	tw.tween_property(fill, "modulate:a", 1.0, 0.65)


# ── Per-frame: track player dot ─────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _player == null or _player_dot == null:
		return
	var dot_center := _world_pos_to_screen(_player.global_position)
	_player_dot.position = (dot_center - Vector2(2.0, 2.0)).round()
