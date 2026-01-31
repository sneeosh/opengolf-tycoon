extends Node
class_name UndoManager
## UndoManager - Tracks build mode actions for undo/redo

const MAX_UNDO_STACK: int = 50

## An UndoAction groups one or more individual changes into a single undoable step.
## For terrain painting, a single stroke (mouse down → mouse up) is one action.
## For entity placement, each individual placement is one action.
var undo_stack: Array = []  # Array of UndoAction
var redo_stack: Array = []  # Array of UndoAction

var _current_stroke: Array = []  # Collects tile changes during a paint stroke
var _is_recording_stroke: bool = false

signal undo_performed()
signal redo_performed()

## Begin recording a terrain paint stroke (call on mouse down)
func begin_stroke() -> void:
	_current_stroke = []
	_is_recording_stroke = true

## Record a single tile change within the current stroke
func record_tile_change(position: Vector2i, old_type: int, new_type: int) -> void:
	if not _is_recording_stroke:
		# Standalone tile change (e.g. from hole creation) - wrap as single action
		var action = {
			"type": "terrain",
			"changes": [{"position": position, "old_type": old_type, "new_type": new_type}]
		}
		_push_action(action)
		return
	_current_stroke.append({"position": position, "old_type": old_type, "new_type": new_type})

## End the current paint stroke and push it as a single undo action
func end_stroke() -> void:
	_is_recording_stroke = false
	if _current_stroke.is_empty():
		return
	var action = {
		"type": "terrain",
		"changes": _current_stroke.duplicate()
	}
	_push_action(action)
	_current_stroke = []

## Record an elevation paint stroke (array of changes from ElevationTool)
func record_elevation_stroke(changes: Array) -> void:
	if changes.is_empty():
		return
	var action = {
		"type": "elevation",
		"changes": changes.duplicate()
	}
	_push_action(action)

## Record an entity placement (tree, building, or rock)
func record_entity_placement(entity_type: String, grid_pos: Vector2i, subtype: String, cost: int) -> void:
	var action = {
		"type": "entity_place",
		"entity_type": entity_type,  # "tree", "building", "rock"
		"grid_pos": grid_pos,
		"subtype": subtype,  # tree_type, building_type, or rock_size
		"cost": cost
	}
	_push_action(action)

func _push_action(action: Dictionary) -> void:
	undo_stack.append(action)
	if undo_stack.size() > MAX_UNDO_STACK:
		undo_stack.pop_front()
	# Any new action clears the redo stack
	redo_stack.clear()

func can_undo() -> bool:
	return not undo_stack.is_empty()

func can_redo() -> bool:
	return not redo_stack.is_empty()

## Undo the last action. Returns the action dictionary for the caller to execute,
## or null if nothing to undo.
func undo() -> Dictionary:
	if undo_stack.is_empty():
		return {}
	var action = undo_stack.pop_back()
	redo_stack.append(action)
	undo_performed.emit()
	return action

## Redo the last undone action. Returns the action dictionary for the caller to execute,
## or null if nothing to redo.
func redo() -> Dictionary:
	if redo_stack.is_empty():
		return {}
	var action = redo_stack.pop_back()
	undo_stack.append(action)
	redo_performed.emit()
	return action

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_current_stroke.clear()
	_is_recording_stroke = false
