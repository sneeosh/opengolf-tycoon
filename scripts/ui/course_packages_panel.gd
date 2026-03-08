extends CenteredPanel
class_name CoursePackagesPanel
## CoursePackagesPanel - UI for purchasing prebuilt course packages

signal close_requested
signal build_course_requested(package_type: int)

var _package_buttons: Dictionary = {}  # PackageType -> Button
var _package_status_labels: Dictionary = {}  # PackageType -> Label

func _build_ui() -> void:
	custom_minimum_size = Vector2(400, 520)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Title row
	var title_row = HBoxContainer.new()
	main_vbox.add_child(title_row)

	var title = Label.new()
	title.text = "Course Packages"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(close_btn)

	main_vbox.add_child(HSeparator.new())

	# Scroll container for package cards
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	main_vbox.add_child(scroll)

	var cards_vbox = VBoxContainer.new()
	cards_vbox.add_theme_constant_override("separation", 10)
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_vbox)

	# Create a card for each package
	for pkg_type in PrebuiltCourses.get_all_package_types():
		_create_package_card(cards_vbox, pkg_type)

	main_vbox.add_child(HSeparator.new())

	var note = Label.new()
	note.text = "Packages are starting points — modify freely!"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(note)


func _create_package_card(parent: VBoxContainer, pkg_type: int) -> void:
	var data = PrebuiltCourses.get_package_data(pkg_type)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.18)
	card_style.set_border_width_all(1)
	card_style.border_color = Color(0.3, 0.3, 0.35)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	# Title and cost row
	var title_row = HBoxContainer.new()
	card_vbox.add_child(title_row)

	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)

	var cost_label = Label.new()
	cost_label.text = "$%d" % data.cost
	cost_label.add_theme_font_size_override("font_size", 15)
	cost_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	title_row.add_child(cost_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = data.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(desc_label)

	# Requirements text
	var req_label = Label.new()
	req_label.add_theme_font_size_override("font_size", 11)
	card_vbox.add_child(req_label)
	_package_status_labels[pkg_type] = req_label

	# Purchase button
	var buy_btn = Button.new()
	buy_btn.text = "Purchase"
	buy_btn.custom_minimum_size = Vector2(100, 32)
	buy_btn.pressed.connect(_on_purchase_pressed.bind(pkg_type))
	card_vbox.add_child(buy_btn)
	_package_buttons[pkg_type] = buy_btn


func _update_display() -> void:
	for pkg_type in PrebuiltCourses.get_all_package_types():
		var data = PrebuiltCourses.get_package_data(pkg_type)
		var check = PrebuiltCourses.can_purchase(pkg_type)
		var btn = _package_buttons.get(pkg_type)
		var status_label = _package_status_labels.get(pkg_type)

		if not btn or not status_label:
			continue

		# Build requirements string
		var reqs: Array = []
		var owned = GameManager.land_manager.owned_parcels.size() if GameManager.land_manager else 0
		var has_parcels = owned >= data.min_parcels
		reqs.append("%s %d+ parcels (%d owned)" % ["[ok]" if has_parcels else "[!!]", data.min_parcels, owned])

		var has_money = GameManager.can_afford(data.cost)
		reqs.append("%s $%d" % ["[ok]" if has_money else "[!!]", data.cost])

		if data.min_stars > 0:
			var stars = 0
			if GameManager.current_course:
				var rating = CourseRatingSystem.calculate_rating(
					GameManager.terrain_grid, GameManager.current_course,
					GameManager.daily_stats, GameManager.green_fee, GameManager.reputation)
				stars = rating.get("stars", 0)
			var has_stars = stars >= data.min_stars
			reqs.append("%s %d-star rating" % ["[ok]" if has_stars else "[!!]", data.min_stars])

		if data.min_reputation > 0.0:
			var has_rep = GameManager.reputation >= data.min_reputation
			reqs.append("%s %.0f reputation" % ["[ok]" if has_rep else "[!!]", data.min_reputation])

		if GameManager.current_course and GameManager.current_course.holes.size() > 0:
			reqs.append("[!!] Course already has holes")

		status_label.text = "  ".join(reqs)

		if check.can_buy:
			status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			btn.disabled = false
		else:
			status_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.5))
			btn.disabled = true
			btn.tooltip_text = check.reason


func _on_purchase_pressed(package_type: int) -> void:
	var check = PrebuiltCourses.can_purchase(package_type)
	if not check.can_buy:
		EventBus.notify(check.reason, "error")
		return

	build_course_requested.emit(package_type)
	_update_display()
	# Close panel after purchase
	hide()
	close_requested.emit()


func _on_close_pressed() -> void:
	close_requested.emit()
	hide()

func toggle() -> void:
	if visible:
		hide()
	else:
		_update_display()
		show_centered()
