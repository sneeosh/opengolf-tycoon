extends Control
class_name ThoughtBubble
## ThoughtBubble - Floating thought bubble that appears above golfers
##
## Usage: var bubble = ThoughtBubble.create("Great shot!", ThoughtBubble.Sentiment.POSITIVE)
##        golfer.add_child(bubble)

enum Sentiment { POSITIVE, NEGATIVE, NEUTRAL }

const SENTIMENT_COLORS: Dictionary = {
	Sentiment.POSITIVE: Color(0.2, 0.9, 0.3),   # Green
	Sentiment.NEGATIVE: Color(0.9, 0.3, 0.2),   # Red
	Sentiment.NEUTRAL: Color(0.9, 0.9, 0.9),    # White/Gray
}

const BUBBLE_DURATION: float = 2.5
const FLOAT_DISTANCE: float = 25.0
const START_OFFSET_Y: float = -45.0

var _message: String
var _sentiment: Sentiment
var _panel: Panel
var _label: Label

static func create(message: String, sentiment: Sentiment = Sentiment.NEUTRAL) -> ThoughtBubble:
	var bubble = ThoughtBubble.new()
	bubble._message = message
	bubble._sentiment = sentiment
	return bubble

func _ready() -> void:
	_build_ui()
	_animate()

func _build_ui() -> void:
	# Position above golfer's head
	position = Vector2(-50, START_OFFSET_Y)

	# Create panel background
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(100, 30)

	# Create stylebox for bubble appearance
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = SENTIMENT_COLORS[_sentiment]
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# Create label for message
	_label = Label.new()
	_label.text = _message
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", SENTIMENT_COLORS[_sentiment])

	# Center label in panel
	_label.position = Vector2(8, 4)
	_label.custom_minimum_size = Vector2(84, 22)
	_panel.add_child(_label)

	# Adjust panel size to fit text
	var text_width = _label.get_theme_font("font").get_string_size(_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var panel_width = max(100, text_width + 24)
	_panel.custom_minimum_size.x = panel_width
	_label.custom_minimum_size.x = panel_width - 16
	position.x = -panel_width / 2

func _animate() -> void:
	var tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(self, "position:y", START_OFFSET_Y - FLOAT_DISTANCE, BUBBLE_DURATION).set_ease(Tween.EASE_OUT)

	# Fade out (start fading after 60% of duration)
	tween.tween_property(self, "modulate:a", 0.0, BUBBLE_DURATION * 0.4).set_delay(BUBBLE_DURATION * 0.6)

	# Clean up when done
	tween.finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	queue_free()
