extends Node
class_name LandManager
## LandManager - Manages purchasable land parcels for course expansion
##
## Players start with a 40x40 central plot and can buy adjacent parcels.
## Parcels are 20x20 tile blocks. The full 128x128 grid is divided into
## a 6x6 parcel grid (with edge margin).
##
## Parcels have quality tiers (Standard/Premium/Elite) assigned per theme.
## Premium/Elite parcels cost more but generate terrain features on purchase.

const PARCEL_SIZE: int = 20        # Tiles per parcel side
const PARCEL_GRID_COLS: int = 6    # Number of parcel columns
const PARCEL_GRID_ROWS: int = 6    # Number of parcel rows
const GRID_OFFSET: int = 4         # Tiles of margin from grid edge

const BASE_PARCEL_COST: int = 5000 # Cost of the first expansion parcel
const COST_ESCALATION: float = 1.3 # Each parcel costs 30% more than the last

const TIER_STANDARD: int = 0
const TIER_PREMIUM: int = 1
const TIER_ELITE: int = 2

const TIER_COST_MULTIPLIER: Dictionary = {
	0: 1.0,  # STANDARD
	1: 2.5,  # PREMIUM
	2: 5.0,  # ELITE
}

const ELITE_REPUTATION_REQUIREMENT: float = 50.0

## Per-theme premium/elite parcel positions. Center 2x2 always Standard.
## Mix of adjacent-to-start (early decision) and edge/corner (late game).
## Starting parcels: (2,2), (2,3), (3,2), (3,3)
## First purchasable ring: (1,2), (1,3), (2,1), (3,1), (4,2), (4,3), (2,4), (3,4)
const THEME_PARCEL_TIERS: Dictionary = {
	0: {  # PARKLAND - lakefront premium nearby, hilltop elite adjacent
		Vector2i(4, 2): TIER_PREMIUM,   # Adjacent — pond-side land
		Vector2i(2, 4): TIER_PREMIUM,   # Adjacent — mature tree grove
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — scenic overlook
		Vector2i(5, 5): TIER_PREMIUM,   # Corner — distant meadow
		Vector2i(1, 3): TIER_ELITE,     # Adjacent — hilltop with lake view
		Vector2i(5, 0): TIER_ELITE,     # Far corner — premium estate
	},
	1: {  # DESERT - rocky outcrop nearby, oasis elite adjacent
		Vector2i(3, 1): TIER_PREMIUM,   # Adjacent — rocky outcrop
		Vector2i(1, 2): TIER_PREMIUM,   # Adjacent — desert canyon edge
		Vector2i(5, 0): TIER_PREMIUM,   # Edge — mesa overlook
		Vector2i(0, 5): TIER_PREMIUM,   # Edge — dune field
		Vector2i(4, 3): TIER_ELITE,     # Adjacent — oasis with palms
	},
	2: {  # LINKS - coastal premium nearby, clifftop elite adjacent
		Vector2i(2, 1): TIER_PREMIUM,   # Adjacent — coastal bluff
		Vector2i(4, 3): TIER_PREMIUM,   # Adjacent — dunes edge
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — headland
		Vector2i(0, 5): TIER_PREMIUM,   # Corner — beach cove
		Vector2i(3, 4): TIER_ELITE,     # Adjacent — dramatic clifftop
		Vector2i(5, 0): TIER_ELITE,     # Far edge — lighthouse point
	},
	3: {  # MOUNTAIN - forest premium nearby, cliff elite adjacent
		Vector2i(1, 3): TIER_PREMIUM,   # Adjacent — pine forest clearing
		Vector2i(3, 4): TIER_PREMIUM,   # Adjacent — alpine meadow
		Vector2i(5, 0): TIER_PREMIUM,   # Edge — ridgeline
		Vector2i(0, 5): TIER_PREMIUM,   # Edge — valley overlook
		Vector2i(4, 2): TIER_ELITE,     # Adjacent — cliff face with views
		Vector2i(0, 0): TIER_ELITE,     # Far corner — summit
	},
	4: {  # CITY - urban premium nearby, no elite (satisfaction ceiling)
		Vector2i(3, 1): TIER_PREMIUM,   # Adjacent — upscale development
		Vector2i(1, 3): TIER_PREMIUM,   # Adjacent — waterfront property
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — commercial district
		Vector2i(5, 5): TIER_PREMIUM,   # Corner — park-adjacent
	},
	5: {  # RESORT - lagoon premium nearby, tropical elite adjacent
		Vector2i(4, 2): TIER_PREMIUM,   # Adjacent — lagoon edge
		Vector2i(2, 1): TIER_PREMIUM,   # Adjacent — beach access
		Vector2i(0, 5): TIER_PREMIUM,   # Corner — cove
		Vector2i(5, 0): TIER_PREMIUM,   # Corner — promontory
		Vector2i(3, 4): TIER_ELITE,     # Adjacent — private island bridge
		Vector2i(0, 0): TIER_ELITE,     # Far corner — exclusive peninsula
	},
	6: {  # HEATHLAND - moorland premium nearby, exposed rock elite adjacent
		Vector2i(1, 2): TIER_PREMIUM,   # Adjacent — heather-covered moor
		Vector2i(3, 4): TIER_PREMIUM,   # Adjacent — rolling heath
		Vector2i(5, 0): TIER_PREMIUM,   # Edge — windswept ridge
		Vector2i(0, 5): TIER_PREMIUM,   # Edge — peat bog edge
		Vector2i(4, 3): TIER_ELITE,     # Adjacent — exposed rock outcrop
	},
	7: {  # WOODLAND - forest clearing premium nearby, deep woods elite adjacent
		Vector2i(2, 1): TIER_PREMIUM,   # Adjacent — birch clearing
		Vector2i(4, 3): TIER_PREMIUM,   # Adjacent — oak grove
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — ancient woodland
		Vector2i(5, 5): TIER_PREMIUM,   # Corner — forest lake
		Vector2i(1, 3): TIER_ELITE,     # Adjacent — deep old-growth forest
	},
	8: {  # TROPICAL - lagoon premium nearby, volcanic elite adjacent
		Vector2i(3, 1): TIER_PREMIUM,   # Adjacent — coral lagoon edge
		Vector2i(1, 2): TIER_PREMIUM,   # Adjacent — palm grove
		Vector2i(5, 5): TIER_PREMIUM,   # Corner — beach cove
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — jungle clearing
		Vector2i(2, 4): TIER_ELITE,     # Adjacent — volcanic ridge
		Vector2i(5, 0): TIER_ELITE,     # Far edge — caldera rim
	},
	9: {  # MARSHLAND - wetland premium nearby, island elite adjacent
		Vector2i(4, 2): TIER_PREMIUM,   # Adjacent — reed marsh edge
		Vector2i(2, 4): TIER_PREMIUM,   # Adjacent — cypress swamp
		Vector2i(0, 0): TIER_PREMIUM,   # Corner — tidal flat
		Vector2i(5, 5): TIER_PREMIUM,   # Corner — mangrove shore
		Vector2i(1, 3): TIER_ELITE,     # Adjacent — raised island hammock
	},
}

signal land_purchased(parcel: Vector2i)
signal land_boundary_changed()

## Dictionary of owned parcel positions: Vector2i -> true
var owned_parcels: Dictionary = {}
var _total_parcels_purchased: int = 0
## Tracks which parcels have had premium features generated (to avoid re-generation)
var _parcel_features_generated: Dictionary = {}

func _ready() -> void:
	# Start with the center 2x2 parcels (40x40 area)
	_grant_starting_parcels()

func _grant_starting_parcels() -> void:
	# Center 2x2 parcels in the 6x6 grid = parcels (2,2), (2,3), (3,2), (3,3)
	var center_start = (PARCEL_GRID_COLS / 2) - 1  # = 2
	for x in range(center_start, center_start + 2):
		for y in range(center_start, center_start + 2):
			owned_parcels[Vector2i(x, y)] = true

func is_tile_owned(tile_pos: Vector2i) -> bool:
	"""Check if a tile position is within owned land."""
	var parcel = tile_to_parcel(tile_pos)
	if parcel == Vector2i(-1, -1):
		return false
	return owned_parcels.has(parcel)

func tile_to_parcel(tile_pos: Vector2i) -> Vector2i:
	"""Convert a tile position to its parcel coordinate."""
	var px = (tile_pos.x - GRID_OFFSET) / PARCEL_SIZE
	var py = (tile_pos.y - GRID_OFFSET) / PARCEL_SIZE
	if px < 0 or px >= PARCEL_GRID_COLS or py < 0 or py >= PARCEL_GRID_ROWS:
		return Vector2i(-1, -1)
	return Vector2i(px, py)

func parcel_to_tile_rect(parcel: Vector2i) -> Rect2i:
	"""Get the tile rectangle for a parcel."""
	var x = GRID_OFFSET + parcel.x * PARCEL_SIZE
	var y = GRID_OFFSET + parcel.y * PARCEL_SIZE
	return Rect2i(x, y, PARCEL_SIZE, PARCEL_SIZE)

func is_parcel_purchasable(parcel: Vector2i) -> bool:
	"""A parcel is purchasable if it's not owned and is adjacent to owned land."""
	if owned_parcels.has(parcel):
		return false
	if parcel.x < 0 or parcel.x >= PARCEL_GRID_COLS:
		return false
	if parcel.y < 0 or parcel.y >= PARCEL_GRID_ROWS:
		return false
	# Must be adjacent to at least one owned parcel
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = parcel + offset
		if owned_parcels.has(neighbor):
			return true
	return false

func get_parcel_tier(parcel: Vector2i) -> int:
	"""Returns the tier for a parcel position based on current theme."""
	var theme_tiers: Dictionary = THEME_PARCEL_TIERS.get(GameManager.current_theme, {})
	return theme_tiers.get(parcel, TIER_STANDARD)

func get_parcel_cost(parcel: Vector2i = Vector2i(-1, -1)) -> int:
	"""Get the cost of purchasing a specific parcel (or base cost if no pos given)."""
	var base := int(BASE_PARCEL_COST * pow(COST_ESCALATION, _total_parcels_purchased))
	if parcel == Vector2i(-1, -1):
		return base
	var tier := get_parcel_tier(parcel)
	return int(base * TIER_COST_MULTIPLIER[tier])

func can_purchase_parcel(parcel: Vector2i) -> Dictionary:
	"""Returns {can_buy: bool, reason: String} for UI and validation."""
	if not is_parcel_purchasable(parcel):
		if owned_parcels.has(parcel):
			return {"can_buy": false, "reason": "Already owned"}
		return {"can_buy": false, "reason": "Not adjacent to owned land"}
	var tier := get_parcel_tier(parcel)
	if tier == TIER_ELITE and GameManager.reputation < ELITE_REPUTATION_REQUIREMENT:
		return {
			"can_buy": false,
			"reason": "Elite land requires %d reputation (you have %.0f)" \
				% [int(ELITE_REPUTATION_REQUIREMENT), GameManager.reputation]
		}
	var cost := get_parcel_cost(parcel)
	if not GameManager.can_afford(cost):
		return {"can_buy": false, "reason": "Not enough money ($%d needed)" % cost}
	return {"can_buy": true, "reason": ""}

func purchase_parcel(parcel: Vector2i) -> bool:
	"""Attempt to purchase a parcel. Returns true on success."""
	var check := can_purchase_parcel(parcel)
	if not check.can_buy:
		EventBus.notify(check.reason, "error")
		return false

	var cost := get_parcel_cost(parcel)
	var tier := get_parcel_tier(parcel)
	var tier_name := get_tier_name(tier)
	GameManager.modify_money(-cost)
	EventBus.log_transaction("%s land purchase" % tier_name, -cost)
	owned_parcels[parcel] = true
	_total_parcels_purchased += 1
	land_purchased.emit(parcel)
	land_boundary_changed.emit()
	EventBus.notify("%s land purchased for $%d!" % [tier_name, cost], "success")
	return true

func mark_features_generated(parcel: Vector2i) -> void:
	_parcel_features_generated[parcel] = true

func has_features_generated(parcel: Vector2i) -> bool:
	return _parcel_features_generated.has(parcel)

static func get_tier_name(tier: int) -> String:
	match tier:
		TIER_PREMIUM: return "Premium"
		TIER_ELITE: return "Elite"
		_: return "Standard"

func get_purchasable_parcels() -> Array:
	"""Get all parcels that can currently be purchased."""
	var result: Array = []
	for x in range(PARCEL_GRID_COLS):
		for y in range(PARCEL_GRID_ROWS):
			var pos = Vector2i(x, y)
			if is_parcel_purchasable(pos):
				result.append(pos)
	return result

func get_owned_tile_count() -> int:
	return owned_parcels.size() * PARCEL_SIZE * PARCEL_SIZE

## Serialization
func serialize() -> Dictionary:
	var parcels_arr: Array = []
	for parcel in owned_parcels:
		parcels_arr.append({"x": parcel.x, "y": parcel.y})
	var features_arr: Array = []
	for parcel in _parcel_features_generated:
		features_arr.append({"x": parcel.x, "y": parcel.y})
	return {
		"owned_parcels": parcels_arr,
		"total_purchased": _total_parcels_purchased,
		"features_generated": features_arr,
	}

func deserialize(data: Dictionary) -> void:
	owned_parcels.clear()
	_total_parcels_purchased = data.get("total_purchased", 0)
	for p in data.get("owned_parcels", []):
		owned_parcels[Vector2i(int(p.x), int(p.y))] = true
	if owned_parcels.is_empty():
		_grant_starting_parcels()
	_parcel_features_generated.clear()
	for p in data.get("features_generated", []):
		_parcel_features_generated[Vector2i(int(p.x), int(p.y))] = true
