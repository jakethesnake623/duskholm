## Persistent game state — autoloaded as "GameData".
## Holds embers (currency), upgrade levels, and derived stats.
extends Node

signal embers_changed(current: int)
signal upgrade_purchased(key: String)
signal throwables_changed
signal rested

var embers         := 0
var spawn_position := Vector2(200.0, 620.0)

# ── Throwable inventory ────────────────────────────────────────────────────────

const THROWABLES: Dictionary = {
	"flask": {
		"label":  "Ember Flask",
		"desc":   "Arcs on throw. Deals 2 damage on impact.",
		"cost":    80,
		"amount":  3,
	},
	"shard": {
		"label":  "Ash Shard",
		"desc":   "Fast straight shot. Deals 1 damage.",
		"cost":    50,
		"amount":  5,
	},
}

var throwable_counts : Dictionary = {"flask": 0, "shard": 0}
var active_throwable : String     = "flask"

# ── Upgrade catalogue ──────────────────────────────────────────────────────────

const UPGRADES: Dictionary = {
	"vitality": {
		"label": "Vitality",
		"desc":  "Gain one more health mask",
		"max_level": 5,
		"costs": [150, 300, 550, 900, 1500],
	},
	"swiftness": {
		"label": "Swiftness",
		"desc":  "Move with greater speed",
		"max_level": 3,
		"costs": [200, 450, 800],
	},
	"edge": {
		"label": "Keen Edge",
		"desc":  "Your nail strikes harder",
		"max_level": 3,
		"costs": [250, 550, 1000],
	},
	"reach": {
		"label": "Long Reach",
		"desc":  "Strike from further away",
		"max_level": 2,
		"costs": [300, 700],
	},
	"double_jump": {
		"label": "Feather Step",
		"desc":  "Jump once more while airborne",
		"max_level": 1,
		"costs": [800],
	},
	"dash": {
		"label": "Shadow Dash",
		"desc":  "Dash through the darkness",
		"max_level": 1,
		"costs": [1200],
	},
}

var upgrade_levels := {
	"vitality": 0, "swiftness": 0, "edge": 0,
	"reach": 0,    "double_jump": 0, "dash": 0,
}


# ── Save / Load ────────────────────────────────────────────────────────────────

const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var data := {
		"embers":           embers,
		"upgrade_levels":   upgrade_levels.duplicate(),
		"spawn_x":          spawn_position.x,
		"spawn_y":          spawn_position.y,
		"throwable_counts": throwable_counts.duplicate(),
		"active_throwable": active_throwable,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var data := parsed as Dictionary
	embers          = data.get("embers", 0)
	spawn_position  = Vector2(data.get("spawn_x", 200.0), data.get("spawn_y", 620.0))
	var levels      = data.get("upgrade_levels", {})
	for key in upgrade_levels:
		upgrade_levels[key] = int(levels.get(key, 0))
	var tcounts = data.get("throwable_counts", {})
	for key in throwable_counts:
		throwable_counts[key] = int(tcounts.get(key, 0))
	active_throwable = data.get("active_throwable", "flask")
	embers_changed.emit(embers)
	throwables_changed.emit()
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ── Reset ─────────────────────────────────────────────────────────────────────

func reset() -> void:
	embers         = 0
	spawn_position = Vector2(200.0, 620.0)
	for key in upgrade_levels:
		upgrade_levels[key] = 0
	for key in throwable_counts:
		throwable_counts[key] = 0
	active_throwable = "flask"
	embers_changed.emit(0)
	throwables_changed.emit()


# ── Ember economy ──────────────────────────────────────────────────────────────

func gain_embers(amount: int) -> void:
	embers += amount
	embers_changed.emit(embers)


func drop_all() -> int:
	## Zero the ember count and return the dropped amount (for the death orb).
	var amount := embers
	embers = 0
	embers_changed.emit(0)
	return amount


func spend_embers(amount: int) -> bool:
	if embers < amount:
		return false
	embers -= amount
	embers_changed.emit(embers)
	return true


# ── Upgrade purchasing ─────────────────────────────────────────────────────────

func get_upgrade_level(key: String) -> int:
	return upgrade_levels.get(key, 0)


func get_next_cost(key: String) -> int:
	## Returns the cost of the next level, or -1 if already maxed.
	var level   := get_upgrade_level(key)
	var data    := UPGRADES.get(key, {}) as Dictionary
	if level >= (data.get("max_level", 0) as int):
		return -1
	var costs := data.get("costs", []) as Array
	return costs[level] if level < costs.size() else -1


func purchase(key: String) -> bool:
	var cost := get_next_cost(key)
	if cost < 0 or not spend_embers(cost):
		return false
	upgrade_levels[key] += 1
	upgrade_purchased.emit(key)
	return true


# ── Derived player stats ───────────────────────────────────────────────────────

func get_max_health() -> int:
	return 5 + upgrade_levels.get("vitality", 0)

func get_speed() -> float:
	return 200.0 + upgrade_levels.get("swiftness", 0) * 28.0

func get_nail_damage() -> int:
	return 1 + upgrade_levels.get("edge", 0)

func get_nail_range() -> float:
	return 40.0 + upgrade_levels.get("reach", 0) * 18.0

func has_double_jump() -> bool:
	return upgrade_levels.get("double_jump", 0) > 0

func has_dash() -> bool:
	return upgrade_levels.get("dash", 0) > 0


# ── Throwable methods ──────────────────────────────────────────────────────────

func get_throwable_count(type: String) -> int:
	return throwable_counts.get(type, 0)


func use_throwable() -> bool:
	## Decrement the active throwable count. Returns false if empty.
	var count : int = throwable_counts.get(active_throwable, 0)
	if count <= 0:
		return false
	throwable_counts[active_throwable] -= 1
	throwables_changed.emit()
	return true


func cycle_throwable() -> void:
	var keys : Array = THROWABLES.keys()
	var idx  : int   = keys.find(active_throwable)
	active_throwable = keys[(idx + 1) % keys.size()]
	throwables_changed.emit()


func add_throwables(type: String, amount: int) -> void:
	throwable_counts[type] = throwable_counts.get(type, 0) + amount
	throwables_changed.emit()


func buy_throwable(type: String) -> bool:
	var data   := THROWABLES.get(type, {}) as Dictionary
	var cost   : int = data.get("cost", 0)
	var amount : int = data.get("amount", 0)
	if not spend_embers(cost):
		return false
	add_throwables(type, amount)
	return true
