extends Node
## BuildingRegistry - Manages all building types and their properties

var buildings: Dictionary = {}

func _ready() -> void:
	_load_buildings()

func _load_buildings() -> void:
	var file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file == null:
		push_error("Failed to load buildings.json")
		return
	
	var json_string = file.get_as_text()
	var data = JSON.parse_string(json_string)
	
	if data and data.has("buildings"):
		buildings = data["buildings"]
		print("Loaded %d building types" % buildings.size())
	else:
		push_error("Invalid buildings.json format")

func get_building(building_type: String) -> Dictionary:
	return buildings.get(building_type, {})

func get_all_buildings() -> Dictionary:
	return buildings.duplicate(true)

func get_building_names() -> Array:
	return buildings.keys()

func is_valid_building(building_type: String) -> bool:
	return building_type in buildings

func get_building_cost(building_type: String) -> int:
	return buildings.get(building_type, {}).get("cost", 0)

func get_building_size(building_type: String) -> Array:
	return buildings.get(building_type, {}).get("size", [1, 1])

func get_building_name(building_type: String) -> String:
	return buildings.get(building_type, {}).get("name", building_type)

func can_place_on_course(building_type: String) -> bool:
	return buildings.get(building_type, {}).get("placeable_on_course", false)
