extends Node
class_name LandManager
## LandManager - Manages purchasable land parcels for course expansion
##
## Players start with a 40x40 central plot and can buy adjacent parcels.
## Parcels are 20x20 tile blocks. The full 128x128 grid is divided into
## a 6x6 parcel grid (with edge margin).
##
## Parcels have quality tiers: Standard (1x cost), Premium (2.5x, pre-painted
## terrain features), and Elite (5x, requires 50+ reputation, best features).

const PARCEL_SIZE: int = 20        # Tiles per parcel side
const PARCEL_GRID_COLS: int = 6    # Number of parcel columns
const PARCEL_GRID_ROWS: int = 6    # Number of parcel rows
const GRID_OFFSET: int = 4         # Tiles of margin from grid edge

const BASE_PARCEL_COST: int = 5000 # Cost of the first expansion parcel
const COST_ESCALATION: float = 1.3 # Each parcel costs 30% more than the last

enum ParcelTier { STANDARD, PREMIUM, ELITE }

const TIER_COST_MULTIPLIERS = {
	ParcelTier.STANDARD: 1.0,
	ParcelTier.PREMIUM: 2.5,
	ParcelTier.ELITE: 5.0,
}

## Per-theme premium/elite parcel positions. Center 2x2 (starting parcels) are always Standard.
## Positions are chosen at edges/corners for strategic interest.
const PREMIUM_PARCEL_LAYOUTS = {
	CourseTheme.Type.PARKLAND: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Pond with mature oaks"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Rolling hills with birch grove"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Stream and wildflower meadow"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Scenic overlook with pines"},
		{position = Vector2i(5, 2), tier = ParcelTier.ELITE, description = "Championship ridge with lake"},
		{position = Vector2i(0, 3), tier = ParcelTier.ELITE, description = "Grand water feature and paths"},
	],
	CourseTheme.Type.DESERT: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Oasis with palm trees"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Rocky mesa outcropping"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Cactus garden with arroyo"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Desert springs"},
		{position = Vector2i(5, 3), tier = ParcelTier.ELITE, description = "Grand canyon with bridges"},
		{position = Vector2i(0, 2), tier = ParcelTier.ELITE, description = "Resort oasis with lagoon"},
	],
	CourseTheme.Type.LINKS: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Coastal dunes with fescue"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Windswept headland"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Seaside pot bunker field"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Clifftop promontory"},
		{position = Vector2i(2, 0), tier = ParcelTier.ELITE, description = "Championship oceanfront"},
		{position = Vector2i(3, 5), tier = ParcelTier.ELITE, description = "Grand links with burn crossing"},
	],
	CourseTheme.Type.MOUNTAIN: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Alpine meadow with stream"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Pine forest ridge"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Mountain lake shore"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Granite outcrop vista"},
		{position = Vector2i(5, 3), tier = ParcelTier.ELITE, description = "Summit plateau with panorama"},
		{position = Vector2i(0, 2), tier = ParcelTier.ELITE, description = "Grand canyon with waterfall"},
	],
	CourseTheme.Type.CITY: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Park with ornamental pond"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Botanical garden section"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Riverside promenade"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Historic garden quarter"},
		{position = Vector2i(3, 0), tier = ParcelTier.ELITE, description = "Waterfront district"},
		{position = Vector2i(2, 5), tier = ParcelTier.ELITE, description = "Grand plaza with fountains"},
	],
	CourseTheme.Type.RESORT: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Lagoon with palm grove"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Tropical garden terrace"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Hibiscus garden with pools"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Beachfront paradise"},
		{position = Vector2i(5, 2), tier = ParcelTier.ELITE, description = "Championship lagoon course"},
		{position = Vector2i(0, 3), tier = ParcelTier.ELITE, description = "Grand resort water complex"},
	],
	CourseTheme.Type.HEATHLAND: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Heather-covered hillside"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Gorse-lined valley"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Sandy heath with pines"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Moorland pond"},
		{position = Vector2i(3, 0), tier = ParcelTier.ELITE, description = "Championship heathland ridge"},
		{position = Vector2i(2, 5), tier = ParcelTier.ELITE, description = "Grand heath with ancient oaks"},
	],
	CourseTheme.Type.WOODLAND: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Ancient oak grove"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Pine forest clearing"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Forest pond with birches"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Moss-covered rock garden"},
		{position = Vector2i(5, 2), tier = ParcelTier.ELITE, description = "Cathedral pine corridor"},
		{position = Vector2i(0, 3), tier = ParcelTier.ELITE, description = "Grand forest amphitheater"},
	],
	CourseTheme.Type.TROPICAL: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Volcanic rock garden"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Jungle canopy clearing"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Lava field with palms"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Ocean cove"},
		{position = Vector2i(2, 0), tier = ParcelTier.ELITE, description = "Championship oceanfront"},
		{position = Vector2i(3, 5), tier = ParcelTier.ELITE, description = "Grand volcanic plateau"},
	],
	CourseTheme.Type.MARSHLAND: [
		{position = Vector2i(0, 0), tier = ParcelTier.PREMIUM, description = "Live oak hammock"},
		{position = Vector2i(5, 0), tier = ParcelTier.PREMIUM, description = "Tidal creek bend"},
		{position = Vector2i(0, 5), tier = ParcelTier.PREMIUM, description = "Marsh overlook"},
		{position = Vector2i(5, 5), tier = ParcelTier.PREMIUM, description = "Oyster shell bluff"},
		{position = Vector2i(5, 3), tier = ParcelTier.ELITE, description = "Championship waterfront"},
		{position = Vector2i(0, 2), tier = ParcelTier.ELITE, description = "Grand tidal marshland"},
	],
}

signal land_purchased(parcel: Vector2i)
signal land_boundary_changed()

## Dictionary of owned parcel positions: Vector2i -> true
var owned_parcels: Dictionary = {}
var _total_parcels_purchased: int = 0

## Tier data: Vector2i -> ParcelTier (only stores PREMIUM/ELITE entries; absent = STANDARD)
var parcel_tiers: Dictionary = {}
var _elite_unlocked: bool = false

## References for premium feature generation
var terrain_grid = null  # TerrainGrid
var entity_layer = null  # EntityLayer

func _ready() -> void:
	# Start with the center 2x2 parcels (40x40 area)
	_grant_starting_parcels()
	# Listen for reputation changes to gate Elite parcels
	if EventBus.reputation_changed.is_connected(_on_reputation_changed):
		return
	EventBus.reputation_changed.connect(_on_reputation_changed)

func _grant_starting_parcels() -> void:
	# Center 2x2 parcels in the 6x6 grid = parcels (2,2), (2,3), (3,2), (3,3)
	var center_start = (PARCEL_GRID_COLS / 2) - 1  # = 2
	for x in range(center_start, center_start + 2):
		for y in range(center_start, center_start + 2):
			owned_parcels[Vector2i(x, y)] = true

func set_references(grid, entities) -> void:
	terrain_grid = grid
	entity_layer = entities

func initialize_parcel_tiers(theme: int) -> void:
	parcel_tiers.clear()
	var layout = PREMIUM_PARCEL_LAYOUTS.get(theme, [])
	for entry in layout:
		parcel_tiers[entry.position] = entry.tier

func get_parcel_tier(parcel: Vector2i) -> int:
	return parcel_tiers.get(parcel, ParcelTier.STANDARD)

func get_parcel_tier_description(parcel: Vector2i) -> String:
	var theme = GameManager.current_theme if GameManager else CourseTheme.Type.PARKLAND
	var layout = PREMIUM_PARCEL_LAYOUTS.get(theme, [])
	for entry in layout:
		if entry.position == parcel:
			return entry.get("description", "")
	return ""

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
	"""A parcel is purchasable if it's not owned, is adjacent to owned land,
	and (for Elite parcels) the reputation gate is met."""
	if owned_parcels.has(parcel):
		return false
	if parcel.x < 0 or parcel.x >= PARCEL_GRID_COLS:
		return false
	if parcel.y < 0 or parcel.y >= PARCEL_GRID_ROWS:
		return false
	# Elite parcels require 50+ reputation
	if get_parcel_tier(parcel) == ParcelTier.ELITE and not _elite_unlocked:
		return false
	# Must be adjacent to at least one owned parcel
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = parcel + offset
		if owned_parcels.has(neighbor):
			return true
	return false

func is_parcel_adjacent(parcel: Vector2i) -> bool:
	"""Check adjacency without tier gating (for UI display)."""
	if owned_parcels.has(parcel):
		return false
	if parcel.x < 0 or parcel.x >= PARCEL_GRID_COLS:
		return false
	if parcel.y < 0 or parcel.y >= PARCEL_GRID_ROWS:
		return false
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor = parcel + offset
		if owned_parcels.has(neighbor):
			return true
	return false

func get_parcel_cost(parcel: Vector2i = Vector2i(-1, -1)) -> int:
	"""Get the cost of purchasing a specific parcel (or the base next-parcel cost)."""
	var base_cost = int(BASE_PARCEL_COST * pow(COST_ESCALATION, _total_parcels_purchased))
	if parcel == Vector2i(-1, -1):
		return base_cost
	var tier = get_parcel_tier(parcel)
	return int(base_cost * TIER_COST_MULTIPLIERS[tier])

func purchase_parcel(parcel: Vector2i) -> bool:
	"""Attempt to purchase a parcel. Returns true on success."""
	if not is_parcel_purchasable(parcel):
		# Provide specific message for locked Elite parcels
		if get_parcel_tier(parcel) == ParcelTier.ELITE and not _elite_unlocked:
			EventBus.notify("Elite parcel requires 50+ reputation!", "error")
		return false

	var cost = get_parcel_cost(parcel)
	if not GameManager.can_afford(cost):
		EventBus.notify("Not enough money! Need $%d" % cost, "error")
		return false

	var tier = get_parcel_tier(parcel)
	var tier_name = _tier_name(tier)
	GameManager.modify_money(-cost)
	EventBus.log_transaction("%s land purchase" % tier_name, -cost)
	owned_parcels[parcel] = true
	_total_parcels_purchased += 1
	land_purchased.emit(parcel)
	land_boundary_changed.emit()
	EventBus.notify("%s parcel purchased for $%d!" % [tier_name, cost], "success")

	# Generate terrain features for premium/elite parcels
	if tier == ParcelTier.PREMIUM or tier == ParcelTier.ELITE:
		call_deferred("_generate_parcel_features", parcel, tier)

	return true

func _generate_parcel_features(parcel: Vector2i, tier: int) -> void:
	if not terrain_grid or not entity_layer:
		return
	var tile_rect = parcel_to_tile_rect(parcel)
	var seed_val = parcel.x * 1000 + parcel.y + (GameManager.current_theme if GameManager else 0) * 10000
	var theme = GameManager.current_theme if GameManager else CourseTheme.Type.PARKLAND
	terrain_grid.begin_batch()
	if tier == ParcelTier.ELITE:
		PremiumLandFeatures.generate_elite_features(terrain_grid, entity_layer, parcel, tile_rect, theme, seed_val)
	else:
		PremiumLandFeatures.generate_premium_features(terrain_grid, entity_layer, parcel, tile_rect, theme, seed_val)
	terrain_grid.end_batch()
	terrain_grid.refresh_all_overlays()

func _on_reputation_changed(_old_rep: float, new_rep: float) -> void:
	if not _elite_unlocked and new_rep >= 50.0:
		_elite_unlocked = true
		EventBus.notify("Elite land parcels now available!", "success")

func _tier_name(tier: int) -> String:
	match tier:
		ParcelTier.PREMIUM: return "Premium"
		ParcelTier.ELITE: return "Elite"
	return "Standard"

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

	# Serialize tier data (only non-standard tiers)
	var tiers_dict: Dictionary = {}
	for pos in parcel_tiers:
		var tier = parcel_tiers[pos]
		if tier != ParcelTier.STANDARD:
			var key = "%d,%d" % [pos.x, pos.y]
			tiers_dict[key] = "elite" if tier == ParcelTier.ELITE else "premium"

	return {
		"owned_parcels": parcels_arr,
		"total_purchased": _total_parcels_purchased,
		"parcel_tiers": tiers_dict,
		"elite_unlocked": _elite_unlocked,
	}

func deserialize(data: Dictionary) -> void:
	owned_parcels.clear()
	_total_parcels_purchased = data.get("total_purchased", 0)
	for p in data.get("owned_parcels", []):
		owned_parcels[Vector2i(int(p.x), int(p.y))] = true
	if owned_parcels.is_empty():
		_grant_starting_parcels()

	# Restore tier data (backward compatible — old saves have no tiers)
	parcel_tiers.clear()
	var tiers_data = data.get("parcel_tiers", {})
	for key in tiers_data:
		var parts = key.split(",")
		if parts.size() == 2:
			var pos = Vector2i(int(parts[0]), int(parts[1]))
			var tier_str = tiers_data[key]
			if tier_str == "elite":
				parcel_tiers[pos] = ParcelTier.ELITE
			elif tier_str == "premium":
				parcel_tiers[pos] = ParcelTier.PREMIUM

	_elite_unlocked = data.get("elite_unlocked", false)
