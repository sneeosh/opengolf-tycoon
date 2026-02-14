extends PanelContainer
class_name CenteredPanel
## CenteredPanel - Base class for panels that center themselves on screen
##
## Provides consistent centering behavior with proper layout calculation.
## Subclasses should call show_centered() instead of show() to display centered.

func _ready() -> void:
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_build_ui()
	hide()

## Override this in subclasses to build the panel's UI
func _build_ui() -> void:
	pass

## Shows the panel centered on screen with proper layout calculation
func show_centered() -> void:
	# Position offscreen first to trigger layout calculation without visual flash
	position = Vector2(-1000, -1000)
	show()
	# Wait for layout engine to process children sizes
	await get_tree().process_frame
	# Now resize and center with correct calculated sizes
	size = get_combined_minimum_size()
	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - size) / 2

## Toggle visibility - shows centered when opening
func toggle() -> void:
	if visible:
		hide()
	else:
		show_centered()
