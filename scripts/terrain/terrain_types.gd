extends RefCounted
class_name TerrainTypes
## TerrainTypes - Definitions for all terrain types

enum Type {
	EMPTY = 0, GRASS = 1, FAIRWAY = 2, ROUGH = 3, HEAVY_ROUGH = 4,
	GREEN = 5, TEE_BOX = 6, BUNKER = 7, WATER = 8, PATH = 9,
	OUT_OF_BOUNDS = 10, TREES = 11, FLOWER_BED = 12, ROCKS = 13
}

const PROPERTIES: Dictionary = {
	# Prettier, more vibrant colors for better visual appeal
	Type.EMPTY: {"name": "Empty", "color": Color(0.18, 0.22, 0.18), "playable": false, "placement_cost": 0, "maintenance_cost": 0},
	Type.GRASS: {"name": "Natural Grass", "color": Color(0.45, 0.62, 0.35), "playable": true, "placement_cost": 0, "maintenance_cost": 0, "shot_difficulty": 0.3},
	Type.FAIRWAY: {"name": "Fairway", "color": Color(0.4, 0.78, 0.4), "playable": true, "placement_cost": 10, "maintenance_cost": 5, "shot_difficulty": 0.0},
	Type.ROUGH: {"name": "Rough", "color": Color(0.38, 0.55, 0.32), "playable": true, "placement_cost": 5, "maintenance_cost": 2, "shot_difficulty": 0.2},
	Type.HEAVY_ROUGH: {"name": "Heavy Rough", "color": Color(0.32, 0.48, 0.28), "playable": true, "placement_cost": 0, "maintenance_cost": 0, "shot_difficulty": 0.5},
	Type.GREEN: {"name": "Green", "color": Color(0.35, 0.88, 0.45), "playable": true, "placement_cost": 50, "maintenance_cost": 20, "shot_difficulty": 0.0},
	Type.TEE_BOX: {"name": "Tee Box", "color": Color(0.45, 0.75, 0.42), "playable": true, "placement_cost": 30, "maintenance_cost": 10, "shot_difficulty": 0.0},
	Type.BUNKER: {"name": "Bunker", "color": Color(0.95, 0.88, 0.65), "playable": true, "placement_cost": 25, "maintenance_cost": 8, "shot_difficulty": 0.6, "is_hazard": true},
	Type.WATER: {"name": "Water", "color": Color(0.25, 0.55, 0.85), "playable": false, "placement_cost": 40, "maintenance_cost": 15, "is_hazard": true, "penalty_strokes": 1},
	Type.PATH: {"name": "Cart Path", "color": Color(0.78, 0.75, 0.68), "playable": true, "placement_cost": 15, "maintenance_cost": 1, "shot_difficulty": 0.1, "speed_modifier": 1.5},
	Type.OUT_OF_BOUNDS: {"name": "Out of Bounds", "color": Color(0.42, 0.35, 0.32), "playable": false, "placement_cost": 0, "maintenance_cost": 0, "penalty_strokes": 2},
	Type.TREES: {"name": "Trees", "color": Color(0.22, 0.45, 0.22), "playable": true, "placement_cost": 20, "maintenance_cost": 3, "shot_difficulty": 0.7, "blocks_shots": true},
	Type.FLOWER_BED: {"name": "Flower Bed", "color": Color(0.85, 0.5, 0.6), "playable": false, "placement_cost": 35, "maintenance_cost": 10, "beauty_bonus": 5},
	Type.ROCKS: {"name": "Rocks", "color": Color(0.55, 0.52, 0.48), "playable": true, "placement_cost": 15, "maintenance_cost": 0, "shot_difficulty": 0.8},
}

static func get_properties(type: Type) -> Dictionary:
	return PROPERTIES.get(type, PROPERTIES[Type.EMPTY])

static func get_type_name(type: Type) -> String:
	return get_properties(type).get("name", "Unknown")

static func get_color(type: Type) -> Color:
	return get_properties(type).get("color", Color.MAGENTA)

static func is_playable(type: Type) -> bool:
	return get_properties(type).get("playable", false)

static func is_hazard(type: Type) -> bool:
	return get_properties(type).get("is_hazard", false)

static func get_placement_cost(type: Type) -> int:
	return get_properties(type).get("placement_cost", 0)

static func get_maintenance_cost(type: Type) -> int:
	return get_properties(type).get("maintenance_cost", 0)

static func get_speed_modifier(type: Type) -> float:
	return get_properties(type).get("speed_modifier", 1.0)
