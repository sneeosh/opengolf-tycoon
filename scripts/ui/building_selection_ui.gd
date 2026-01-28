extends PopupPanel
class_name BuildingSelectionUI
## BuildingSelectionUI - Allows players to select which building to place

signal building_selected(building_type: String)
signal closed

var building_registry: Node

func _ready() -> void:
	hide()
	if has_node("VBoxContainer/CloseBtn"):
		$VBoxContainer/CloseBtn.pressed.connect(close_menu)

func set_building_registry(registry: Node) -> void:
	building_registry = registry
	_populate_buildings()

func show_menu(position: Vector2) -> void:
	if building_registry == null:
		push_error("Building registry not set")
		return
	
	global_position = position
	show()

func _populate_buildings() -> void:
	"""Populate the menu with available building types"""
	if building_registry == null:
		return
	
	# Clear existing buttons
	for child in get_tree().get_nodes_in_group("building_button"):
		child.queue_free()
	
	var building_names = building_registry.get_building_names()
	var container = $VBoxContainer if has_node("VBoxContainer") else null
	
	if container == null:
		container = VBoxContainer.new()
		add_child(container)
	
	for building_type in building_names:
		var building_data = building_registry.get_building(building_type)
		var name_text = building_data.get("name", building_type)
		var cost = building_data.get("cost", 0)
		
		var btn = Button.new()
		btn.text = "%s ($%d)" % [name_text, cost]
		btn.add_to_group("building_button")
		btn.pressed.connect(_on_building_selected.bind(building_type))
		container.add_child(btn)

func _on_building_selected(building_type: String) -> void:
	building_selected.emit(building_type)
	close_menu()

func close_menu() -> void:
	hide()
	closed.emit()
