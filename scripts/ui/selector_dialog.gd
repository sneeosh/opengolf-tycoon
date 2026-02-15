extends RefCounted
class_name SelectorDialog
## SelectorDialog - Reusable popup for selecting items from a list with hotkey toggle
##
## Eliminates boilerplate for AcceptDialog-based selection menus (trees, rocks, buildings).
## Each instance manages one dialog and its lifecycle, including toggle-on-same-key behavior.
##
## Usage:
##   var selector = SelectorDialog.new(self, KEY_T)
##   var items = [{"id": "oak", "label": "Oak Tree ($20)"}, ...]
##   selector.show_items("Select Tree", items, _on_selected)

var _dialog: AcceptDialog = null
var _toggle_key: Key = KEY_NONE
var _parent: Node = null

func _init(parent: Node, toggle_key: Key = KEY_NONE) -> void:
	_parent = parent
	_toggle_key = toggle_key

func is_open() -> bool:
	return _dialog != null and is_instance_valid(_dialog)

func close() -> void:
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null

## Show a selection dialog, or close it if already open (toggle behavior).
## items: Array of {id: String, label: String, disabled: bool (optional)}
## on_selected: Callable receiving the chosen item's id String
func show_items(title: String, items: Array, on_selected: Callable, dialog_size: Vector2i = Vector2i(350, 250), popup_ratio: float = 0.3) -> void:
	if is_open():
		close()
		return

	_dialog = AcceptDialog.new()
	_dialog.title = title
	_dialog.size = dialog_size

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var vbox = VBoxContainer.new()

	for item in items:
		var btn = Button.new()
		btn.text = item.get("label", str(item.get("id", "")))
		btn.custom_minimum_size = Vector2(dialog_size.x - 50, 35)
		if item.get("disabled", false):
			btn.disabled = true
		else:
			var item_id: String = item.get("id", "")
			btn.pressed.connect(_on_item_pressed.bind(item_id, on_selected))
		vbox.add_child(btn)

	scroll.add_child(vbox)
	_dialog.add_child(scroll)

	_dialog.canceled.connect(close)
	_dialog.confirmed.connect(close)
	if _toggle_key != KEY_NONE:
		_dialog.window_input.connect(_on_dialog_input)

	_parent.get_tree().root.add_child(_dialog)
	_dialog.popup_centered_ratio(popup_ratio)

func _on_item_pressed(item_id: String, callback: Callable) -> void:
	close()
	callback.call(item_id)

func _on_dialog_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == _toggle_key:
			close()
