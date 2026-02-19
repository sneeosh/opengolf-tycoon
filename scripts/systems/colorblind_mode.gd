extends RefCounted
class_name ColorblindMode
## ColorblindMode - Provides alternative color palettes for color-blind players
##
## Three modes: OFF (default), DEUTERANOPIA (red-green), TRITANOPIA (blue-yellow).
## When active, remaps terrain colors via modified palettes that CourseTheme
## and TilesetGenerator can query.

enum Mode { OFF, DEUTERANOPIA, TRITANOPIA }

## Get display name for a mode
static func get_mode_name(mode: int) -> String:
	match mode:
		Mode.DEUTERANOPIA: return "Deuteranopia (Red-Green)"
		Mode.TRITANOPIA: return "Tritanopia (Blue-Yellow)"
		_: return "Off"

## Get all modes for UI iteration
static func get_all_modes() -> Array:
	return [Mode.OFF, Mode.DEUTERANOPIA, Mode.TRITANOPIA]

## Remap a terrain color dictionary for the given colorblind mode.
## Returns the original dict if mode is OFF.
static func remap_colors(colors: Dictionary, mode: int) -> Dictionary:
	if mode == Mode.OFF:
		return colors
	var remapped := {}
	for key in colors:
		remapped[key] = _remap_color(colors[key], mode)
	return remapped

## Remap a single color for the given colorblind mode
static func _remap_color(color: Color, mode: int) -> Color:
	match mode:
		Mode.DEUTERANOPIA:
			return _deuteranopia_remap(color)
		Mode.TRITANOPIA:
			return _tritanopia_remap(color)
	return color

## Deuteranopia simulation: shift green channel toward blue, boost contrast
## between red/green elements. Uses a perceptual-approximation matrix.
static func _deuteranopia_remap(c: Color) -> Color:
	# Simplified Brettel/Vienot deuteranopia simulation
	var r := c.r * 0.625 + c.g * 0.375
	var g := c.r * 0.700 + c.g * 0.300
	var b := c.b * 0.800 + c.g * 0.200

	# Boost luminance contrast slightly so terrain types remain distinct
	var lum := r * 0.299 + g * 0.587 + b * 0.114
	var contrast := 1.15
	r = clampf(lum + (r - lum) * contrast, 0.0, 1.0)
	g = clampf(lum + (g - lum) * contrast, 0.0, 1.0)
	b = clampf(lum + (b - lum) * contrast, 0.0, 1.0)

	return Color(r, g, b, c.a)

## Tritanopia simulation: shift blue toward warmer tones, maintain red/green
static func _tritanopia_remap(c: Color) -> Color:
	var r := c.r * 0.950 + c.g * 0.050
	var g := c.g * 0.850 + c.b * 0.150
	var b := c.r * 0.300 + c.g * 0.250 + c.b * 0.450

	var lum := r * 0.299 + g * 0.587 + b * 0.114
	var contrast := 1.10
	r = clampf(lum + (r - lum) * contrast, 0.0, 1.0)
	g = clampf(lum + (g - lum) * contrast, 0.0, 1.0)
	b = clampf(lum + (b - lum) * contrast, 0.0, 1.0)

	return Color(r, g, b, c.a)

## Convert mode to string for save/load
static func to_string_name(mode: int) -> String:
	match mode:
		Mode.DEUTERANOPIA: return "deuteranopia"
		Mode.TRITANOPIA: return "tritanopia"
		_: return "off"

## Convert string to mode for save/load
static func from_string(name: String) -> int:
	match name.to_lower():
		"deuteranopia": return Mode.DEUTERANOPIA
		"tritanopia": return Mode.TRITANOPIA
		_: return Mode.OFF
