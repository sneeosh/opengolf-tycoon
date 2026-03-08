extends CenteredPanel
class_name LandPanel
## LandPanel - UI for viewing and purchasing land parcels
##
## Displays a 6x6 grid representing the parcel layout.
## Green = owned, Gold = premium, Platinum = elite, Yellow = purchasable, Gray = unavailable

signal close_requested
signal open_packages_requested

const COLOR_OWNED = Color(0.3, 0.7, 0.3)              # Green
const COLOR_PURCHASABLE = Color(0.9, 0.8, 0.3)        # Yellow
const COLOR_UNAVAILABLE = Color(0.4, 0.4, 0.4)        # Gray
const COLOR_HOVER = Color(1.0, 0.9, 0.5)              # Light yellow for hover
const COLOR_PREMIUM = Color(0.9, 0.75, 0.2)           # Gold for premium purchasable
const COLOR_ELITE = Color(0.7, 0.8, 0.95)             # Platinum for elite purchasable
const COLOR_PREMIUM_OWNED = Color(0.5, 0.75, 0.2)     # Green-gold for owned premium
const COLOR_ELITE_OWNED = Color(0.4, 0.65, 0.8)       # Green-platinum for owned elite
const COLOR_LOCKED = Color(0.5, 0.4, 0.4)             # Darker gray for locked elite

var _grid_container: GridContainer = null
var _parcel_buttons: Dictionary = {}  # Vector2i -> Button
var _info_label: Label = null
var _cost_label: Label = null

func _build_ui() -> void:
	custom_minimum_size = Vector2(380, 500)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Title row with close button
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Land Management"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Info row
	_info_label = Label.new()
	_info_label.text = "Owned: 4/36 parcels (1,600 tiles)"
	main_vbox.add_child(_info_label)

	_cost_label = Label.new()
	_cost_label.text = "Hover a parcel to see cost"
	_cost_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_cost_label.add_theme_font_size_override("font_size", 12)
	main_vbox.add_child(_cost_label)

	main_vbox.add_child(HSeparator.new())

	# Grid and legend row
	var grid_row = HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(grid_row)

	# 6x6 parcel grid
	_grid_container = GridContainer.new()
	_grid_container.columns = 6
	_grid_container.add_theme_constant_override("h_separation", 4)
	_grid_container.add_theme_constant_override("v_separation", 4)
	grid_row.add_child(_grid_container)

	# Create 36 buttons
	for y in range(6):
		for x in range(6):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(36, 36)
			btn.pressed.connect(_on_parcel_pressed.bind(Vector2i(x, y)))
			btn.mouse_entered.connect(_on_parcel_hovered.bind(Vector2i(x, y)))
			btn.mouse_exited.connect(_on_parcel_unhovered)
			_grid_container.add_child(btn)
			_parcel_buttons[Vector2i(x, y)] = btn

	# Legend
	var legend_vbox = VBoxContainer.new()
	legend_vbox.add_theme_constant_override("separation", 4)
	grid_row.add_child(legend_vbox)

	var legend_title = Label.new()
	legend_title.text = "Legend:"
	legend_title.add_theme_font_size_override("font_size", 12)
	legend_vbox.add_child(legend_title)

	_add_legend_item(legend_vbox, COLOR_OWNED, "Owned")
	_add_legend_item(legend_vbox, COLOR_PURCHASABLE, "Available")
	_add_legend_item(legend_vbox, COLOR_PREMIUM, "Premium")
	_add_legend_item(legend_vbox, COLOR_ELITE, "Elite")
	_add_legend_item(legend_vbox, COLOR_LOCKED, "Locked")
	_add_legend_item(legend_vbox, COLOR_UNAVAILABLE, "N/A")

	main_vbox.add_child(HSeparator.new())

	# Course Packages button
	var packages_btn = Button.new()
	packages_btn.text = "Course Packages"
	packages_btn.tooltip_text = "Purchase prebuilt course layouts (P)"
	packages_btn.pressed.connect(_on_packages_pressed)
	main_vbox.add_child(packages_btn)

	main_vbox.add_child(HSeparator.new())

	# Instructions
	var instructions = Label.new()
	instructions.text = "Click a parcel to purchase"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(instructions)

func _add_legend_item(parent: VBoxContainer, color: Color, text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(14, 14)
	color_rect.color = color
	row.add_child(color_rect)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)

func _ready() -> void:
	super._ready()
	# Connect to land manager signals for reactive updates
	if GameManager.land_manager:
		GameManager.land_manager.land_purchased.connect(_on_land_purchased)
		GameManager.land_manager.land_boundary_changed.connect(_on_land_changed)

func _on_land_purchased(_parcel: Vector2i) -> void:
	_update_display()

func _on_land_changed() -> void:
	_update_display()

func _update_display() -> void:
	if not GameManager.land_manager:
		return

	var lm = GameManager.land_manager
	var owned_count = lm.owned_parcels.size()
	var tile_count = lm.get_owned_tile_count()

	_info_label.text = "Owned: %d/36 parcels (%d tiles)" % [owned_count, tile_count]

	# Update button colors based on tier
	for pos in _parcel_buttons:
		var btn = _parcel_buttons[pos]
		var tier = lm.get_parcel_tier(pos)

		if lm.owned_parcels.has(pos):
			# Owned — color by tier
			var color = COLOR_OWNED
			var tier_label = "Owned"
			if tier == LandManager.ParcelTier.PREMIUM:
				color = COLOR_PREMIUM_OWNED
				tier_label = "Owned (Premium)"
			elif tier == LandManager.ParcelTier.ELITE:
				color = COLOR_ELITE_OWNED
				tier_label = "Owned (Elite)"
			_set_button_color(btn, color)
			btn.disabled = true
			btn.tooltip_text = tier_label
		elif lm.is_parcel_purchasable(pos):
			# Purchasable — color by tier
			var color = COLOR_PURCHASABLE
			var cost = lm.get_parcel_cost(pos)
			var desc = lm.get_parcel_tier_description(pos)
			if tier == LandManager.ParcelTier.PREMIUM:
				color = COLOR_PREMIUM
				btn.tooltip_text = "Premium - $%d\n%s" % [cost, desc]
			elif tier == LandManager.ParcelTier.ELITE:
				color = COLOR_ELITE
				btn.tooltip_text = "Elite - $%d\n%s" % [cost, desc]
			else:
				btn.tooltip_text = "Click to purchase ($%d)" % cost
			_set_button_color(btn, color)
			btn.disabled = false
		elif tier == LandManager.ParcelTier.ELITE and not lm._elite_unlocked and lm.is_parcel_adjacent(pos):
			# Adjacent Elite but locked
			_set_button_color(btn, COLOR_LOCKED)
			btn.disabled = true
			var desc = lm.get_parcel_tier_description(pos)
			btn.tooltip_text = "Elite (Locked)\nRequires 50+ reputation\n%s" % desc
		else:
			_set_button_color(btn, COLOR_UNAVAILABLE)
			btn.disabled = true
			btn.tooltip_text = "Not adjacent to owned land"

func _set_button_color(btn: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = color.darkened(0.3)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = color.lightened(0.2)
	hover_style.set_border_width_all(1)
	hover_style.border_color = color
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = color.darkened(0.2)
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = color.darkened(0.4)
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = color
	disabled_style.set_border_width_all(1)
	disabled_style.border_color = color.darkened(0.3)
	disabled_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", disabled_style)

func _on_parcel_hovered(parcel: Vector2i) -> void:
	if not GameManager.land_manager:
		return
	var lm = GameManager.land_manager
	if lm.owned_parcels.has(parcel):
		var tier = lm.get_parcel_tier(parcel)
		_cost_label.text = "Owned (%s)" % lm._tier_name(tier)
	elif lm.is_parcel_purchasable(parcel):
		var cost = lm.get_parcel_cost(parcel)
		var tier = lm.get_parcel_tier(parcel)
		_cost_label.text = "%s parcel: $%d" % [lm._tier_name(tier), cost]
	elif lm.get_parcel_tier(parcel) == LandManager.ParcelTier.ELITE and not lm._elite_unlocked:
		_cost_label.text = "Elite - Requires 50+ reputation"
	else:
		_cost_label.text = "Not available"

func _on_parcel_unhovered() -> void:
	_cost_label.text = "Hover a parcel to see cost"

func _on_parcel_pressed(parcel: Vector2i) -> void:
	if not GameManager.land_manager:
		return

	if GameManager.land_manager.purchase_parcel(parcel):
		_update_display()

func _on_packages_pressed() -> void:
	open_packages_requested.emit()

func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func toggle() -> void:
	if visible:
		hide()
	else:
		_update_display()
		show_centered()
