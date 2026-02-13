extends Node
class_name LandManager
## LandManager - Manages purchasable land parcels for course expansion
##
## Players start with a 40x40 central plot and can buy adjacent parcels.
## Parcels are 20x20 tile blocks. The full 128x128 grid is divided into
## a 6x6 parcel grid (with edge margin).

const PARCEL_SIZE: int = 20        # Tiles per parcel side
const PARCEL_GRID_COLS: int = 6    # Number of parcel columns
const PARCEL_GRID_ROWS: int = 6    # Number of parcel rows
const GRID_OFFSET: int = 4         # Tiles of margin from grid edge

const BASE_PARCEL_COST: int = 5000 # Cost of the first expansion parcel
const COST_ESCALATION: float = 1.3 # Each parcel costs 30% more than the last

signal land_purchased(parcel: Vector2i)
signal land_boundary_changed()

## Dictionary of owned parcel positions: Vector2i -> true
var owned_parcels: Dictionary = {}
var _total_parcels_purchased: int = 0

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

func get_parcel_cost() -> int:
	"""Get the cost of the next parcel purchase."""
	return int(BASE_PARCEL_COST * pow(COST_ESCALATION, _total_parcels_purchased))

func purchase_parcel(parcel: Vector2i) -> bool:
	"""Attempt to purchase a parcel. Returns true on success."""
	if not is_parcel_purchasable(parcel):
		return false

	var cost = get_parcel_cost()
	if not GameManager.can_afford(cost):
		EventBus.notify("Not enough money! Need $%d" % cost, "error")
		return false

	GameManager.modify_money(-cost)
	EventBus.log_transaction("Land purchase", -cost)
	owned_parcels[parcel] = true
	_total_parcels_purchased += 1
	land_purchased.emit(parcel)
	land_boundary_changed.emit()
	EventBus.notify("Land purchased for $%d!" % cost, "success")
	return true

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
	return {
		"owned_parcels": parcels_arr,
		"total_purchased": _total_parcels_purchased,
	}

func deserialize(data: Dictionary) -> void:
	owned_parcels.clear()
	_total_parcels_purchased = data.get("total_purchased", 0)
	for p in data.get("owned_parcels", []):
		owned_parcels[Vector2i(int(p.x), int(p.y))] = true
	if owned_parcels.is_empty():
		_grant_starting_parcels()
