extends Node
## UIConstants - Centralized color and size constants for UI theming
## Registered as autoload singleton - access via UIConstants.COLOR_PRIMARY, etc.

# =============================================================================
# PRIMARY COLOR PALETTE (Golf green theme)
# =============================================================================

const COLOR_PRIMARY := Color(0.18, 0.35, 0.24)        # #2D5A3D - Main green
const COLOR_PRIMARY_HOVER := Color(0.29, 0.56, 0.36)  # #4A8F5C - Hover state
const COLOR_PRIMARY_PRESSED := Color(0.12, 0.24, 0.16) # #1E3D29 - Pressed state

# =============================================================================
# BACKGROUND COLORS
# =============================================================================

const COLOR_BG_PANEL := Color(0.1, 0.1, 0.1, 0.95)    # Panel background
const COLOR_BG_BUTTON := Color(0.15, 0.15, 0.15)      # Button normal
const COLOR_BG_HOVER := Color(0.2, 0.2, 0.2)          # Button hover (neutral)
const COLOR_BG_DARK := Color(0.07, 0.07, 0.07)        # Darker background
const COLOR_BORDER := Color(0.23, 0.23, 0.23)         # Border color

# =============================================================================
# TEXT COLORS
# =============================================================================

const COLOR_TEXT := Color(1.0, 1.0, 1.0)              # Primary text
const COLOR_TEXT_DIM := Color(0.7, 0.7, 0.7)          # Secondary text
const COLOR_TEXT_MUTED := Color(0.4, 0.4, 0.4)        # Disabled/muted text

# =============================================================================
# SEMANTIC STATUS COLORS
# =============================================================================

const COLOR_SUCCESS := Color(0.4, 0.9, 0.4)           # Profit, positive
const COLOR_SUCCESS_DIM := Color(0.5, 0.8, 0.5)       # Dim green
const COLOR_WARNING := Color(0.9, 0.9, 0.4)           # Caution, moderate
const COLOR_DANGER := Color(0.9, 0.4, 0.4)            # Loss, negative
const COLOR_DANGER_DIM := Color(0.8, 0.5, 0.5)        # Dim red
const COLOR_INFO := Color(0.4, 0.7, 1.0)              # Neutral info
const COLOR_GOLD := Color(1.0, 0.85, 0.0)             # Premium, special

# =============================================================================
# TYPOGRAPHY SCALE
# =============================================================================

const FONT_SIZE_XS := 10   # Wind labels, tiny text
const FONT_SIZE_SM := 12   # Tooltips, secondary labels
const FONT_SIZE_BASE := 14 # Body text, stat rows
const FONT_SIZE_MD := 16   # Section headers
const FONT_SIZE_LG := 18   # Panel titles
const FONT_SIZE_XL := 24   # Major titles

# =============================================================================
# SPACING CONSTANTS
# =============================================================================

const MARGIN_XS := 4
const MARGIN_SM := 8
const MARGIN_MD := 12
const MARGIN_LG := 16
const MARGIN_XL := 24

const SEPARATION_SM := 4
const SEPARATION_MD := 6
const SEPARATION_LG := 8

# =============================================================================
# PANEL SIZES (base at 1080p)
# =============================================================================

const TOP_HUD_HEIGHT := 48
const BOTTOM_BAR_HEIGHT := 50
const BUILD_TOOLS_WIDTH := 260
const TOOL_BUTTON_HEIGHT := 36

# =============================================================================
# TOOL ICONS (Unicode)
# =============================================================================

const TOOL_ICONS := {
	"fairway": "[=]",
	"rough": "[~]",
	"green": "[O]",
	"tee_box": "[T]",
	"bunker": "[:]",
	"water": "[w]",
	"out_of_bounds": "[X]",
	"path": "[.]",
	"tree": "[^]",
	"rock": "[*]",
	"flower": "[f]",
	"building": "[B]",
	"bulldozer": "[D]",
	"raise": "[+]",
	"lower": "[-]",
	"create_hole": "[H]",
	"staff": "[P]",
}

# =============================================================================
# WEATHER ICONS (Unicode)
# =============================================================================

const WEATHER_ICONS := {
	0: "* *",   # SUNNY
	1: "~~~",   # PARTLY_CLOUDY
	2: "===",   # OVERCAST
	3: "~:~",   # LIGHT_RAIN
	4: ":|:",   # RAIN
	5: "|:|",   # HEAVY_RAIN
}

const WEATHER_NAMES := {
	0: "Sunny",
	1: "Partly Cloudy",
	2: "Overcast",
	3: "Light Rain",
	4: "Rain",
	5: "Heavy Rain",
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

static func get_scale_factor() -> float:
	var viewport_height := DisplayServer.window_get_size().y
	var scale := viewport_height / 1080.0
	return clampf(scale, 0.8, 1.5)

static func get_scaled_size(base_size: Vector2) -> Vector2:
	return base_size * get_scale_factor()

static func get_scaled_font_size(base_size: int) -> int:
	var scale := get_scale_factor()
	if scale > 1.1:
		return base_size + 2
	return base_size

static func get_tool_icon(tool_type) -> String:
	if tool_type is int:
		# TerrainTypes enum
		match tool_type:
			1: return TOOL_ICONS.get("grass", "[.]")
			2: return TOOL_ICONS.get("fairway", "[=]")
			3: return TOOL_ICONS.get("rough", "[~]")
			4: return TOOL_ICONS.get("rough", "[~]")  # HEAVY_ROUGH
			5: return TOOL_ICONS.get("green", "[O]")
			6: return TOOL_ICONS.get("tee_box", "[T]")
			7: return TOOL_ICONS.get("bunker", "[:]")
			8: return TOOL_ICONS.get("water", "[w]")
			9: return TOOL_ICONS.get("path", "[.]")
			10: return TOOL_ICONS.get("out_of_bounds", "[X]")
		return "[?]"
	else:
		return TOOL_ICONS.get(str(tool_type), "[?]")

static func get_weather_icon(weather_type: int) -> String:
	return WEATHER_ICONS.get(weather_type, "???")

static func get_weather_name(weather_type: int) -> String:
	return WEATHER_NAMES.get(weather_type, "Unknown")
