extends RefCounted
class_name CourseTheme
## CourseTheme - Defines course environment types with distinct visuals and gameplay

enum Type {
	PARKLAND,   # Default - lush green, deciduous trees, gentle hills
	DESERT,     # Arid sandy base, cacti, rocky outcroppings, minimal water
	LINKS,      # Coastal Scottish-style, fescue rough, pot bunkers, strong wind
	MOUNTAIN,   # Dramatic elevation, pine forests, thinner air (+distance)
	CITY,       # Flat, urban, chain-link OB, cheaper maintenance
	RESORT      # Tropical lush, palms, vibrant flowers, premium pricing
}

## Theme display information
static func get_name(theme_type: int) -> String:
	match theme_type:
		Type.PARKLAND: return "Parkland"
		Type.DESERT: return "Desert"
		Type.LINKS: return "Links"
		Type.MOUNTAIN: return "Mountain"
		Type.CITY: return "City/Municipal"
		Type.RESORT: return "Resort"
	return "Unknown"

static func get_description(theme_type: int) -> String:
	match theme_type:
		Type.PARKLAND:
			return "Classic parkland course with lush fairways, deciduous trees, and gentle rolling hills. A balanced, traditional golfing experience."
		Type.DESERT:
			return "Arid desert course with sandy terrain and cacti. Fairways are green oases amid hardpan. Bunkers blend into the landscape."
		Type.LINKS:
			return "Coastal links course with golden fescue rough, deep pot bunkers, and persistent ocean wind. A true test of golf."
		Type.MOUNTAIN:
			return "Mountain course with dramatic elevation changes and pine forests. Thinner air means longer drives but tricky slopes."
		Type.CITY:
			return "Urban municipal course. Flat and affordable with lower maintenance costs, but a lower satisfaction ceiling."
		Type.RESORT:
			return "Tropical resort course with palm trees, vibrant flowers, and lagoon-style water. Premium atmosphere commands higher fees."
	return ""

## Gameplay modifiers per theme
static func get_gameplay_modifiers(theme_type: int) -> Dictionary:
	match theme_type:
		Type.PARKLAND:
			return {
				"wind_base_strength": 1.0,
				"distance_modifier": 1.0,
				"maintenance_cost_multiplier": 1.0,
				"green_fee_baseline": 30,
				"land_cost_multiplier": 1.0,
				"satisfaction_ceiling": 1.0,
			}
		Type.DESERT:
			return {
				"wind_base_strength": 0.8,
				"distance_modifier": 1.02,  # Dry air, slight distance boost
				"maintenance_cost_multiplier": 0.7,  # Less water/mowing needed
				"green_fee_baseline": 25,
				"land_cost_multiplier": 0.6,  # Cheap desert land
				"satisfaction_ceiling": 1.0,
			}
		Type.LINKS:
			return {
				"wind_base_strength": 1.8,  # Strong persistent coastal wind
				"distance_modifier": 0.98,
				"maintenance_cost_multiplier": 0.85,  # Fescue is low-maintenance
				"green_fee_baseline": 40,
				"land_cost_multiplier": 1.2,  # Coastal premium
				"satisfaction_ceiling": 1.0,
			}
		Type.MOUNTAIN:
			return {
				"wind_base_strength": 1.2,
				"distance_modifier": 1.05,  # Thinner air = longer drives
				"maintenance_cost_multiplier": 1.15,
				"green_fee_baseline": 35,
				"land_cost_multiplier": 0.8,
				"satisfaction_ceiling": 1.0,
			}
		Type.CITY:
			return {
				"wind_base_strength": 0.7,  # Buildings block wind
				"distance_modifier": 1.0,
				"maintenance_cost_multiplier": 0.6,  # Municipal = cheap
				"green_fee_baseline": 20,
				"land_cost_multiplier": 1.5,  # Urban land is expensive
				"satisfaction_ceiling": 0.85,  # Can't reach 5 stars
			}
		Type.RESORT:
			return {
				"wind_base_strength": 1.0,
				"distance_modifier": 1.0,
				"maintenance_cost_multiplier": 1.4,  # Tropical gardens cost more
				"green_fee_baseline": 50,  # Premium pricing
				"land_cost_multiplier": 1.3,
				"satisfaction_ceiling": 1.0,
			}
	return {}

## Color palettes for tileset generation per theme
static func get_terrain_colors(theme_type: int) -> Dictionary:
	match theme_type:
		Type.PARKLAND:
			return {
				"grass": Color(0.42, 0.58, 0.32),
				"fairway_light": Color(0.42, 0.78, 0.42),
				"fairway_dark": Color(0.36, 0.72, 0.36),
				"green_light": Color(0.38, 0.88, 0.48),
				"green_dark": Color(0.34, 0.82, 0.44),
				"fringe": Color(0.40, 0.80, 0.44),
				"rough": Color(0.36, 0.52, 0.30),
				"heavy_rough": Color(0.30, 0.45, 0.26),
				"bunker": Color(0.92, 0.85, 0.62),
				"water": Color(0.25, 0.55, 0.85),
				"empty": Color(0.18, 0.22, 0.18),
				"tee_box_light": Color(0.48, 0.76, 0.45),
				"tee_box_dark": Color(0.42, 0.70, 0.40),
				"path": Color(0.75, 0.72, 0.65),
				"oob": Color(0.40, 0.33, 0.30),
				"trees": Color(0.20, 0.42, 0.20),
				"flower_bed": Color(0.45, 0.32, 0.22),
				"rocks": Color(0.48, 0.46, 0.42),
			}
		Type.DESERT:
			return {
				"grass": Color(0.72, 0.62, 0.45),       # Sandy base
				"fairway_light": Color(0.45, 0.68, 0.38),# Green oasis
				"fairway_dark": Color(0.40, 0.62, 0.34),
				"green_light": Color(0.40, 0.82, 0.42),
				"green_dark": Color(0.36, 0.76, 0.38),
				"fringe": Color(0.42, 0.72, 0.38),
				"rough": Color(0.65, 0.55, 0.38),        # Sandy rough
				"heavy_rough": Color(0.60, 0.48, 0.32),
				"bunker": Color(0.88, 0.78, 0.52),       # Blends with terrain
				"water": Color(0.30, 0.55, 0.70),        # Oasis blue
				"empty": Color(0.62, 0.52, 0.38),        # Desert floor
				"tee_box_light": Color(0.48, 0.72, 0.42),
				"tee_box_dark": Color(0.42, 0.66, 0.38),
				"path": Color(0.78, 0.70, 0.55),         # Packed earth
				"oob": Color(0.55, 0.45, 0.32),          # Rocky desert
				"trees": Color(0.35, 0.45, 0.28),        # Sage green
				"flower_bed": Color(0.70, 0.50, 0.30),   # Terracotta
				"rocks": Color(0.65, 0.55, 0.42),        # Sandstone
			}
		Type.LINKS:
			return {
				"grass": Color(0.55, 0.58, 0.38),        # Golden-brown fescue
				"fairway_light": Color(0.48, 0.68, 0.40),# Muted green
				"fairway_dark": Color(0.42, 0.62, 0.36),
				"green_light": Color(0.42, 0.78, 0.45),
				"green_dark": Color(0.38, 0.72, 0.40),
				"fringe": Color(0.44, 0.70, 0.40),
				"rough": Color(0.52, 0.50, 0.32),        # Golden fescue
				"heavy_rough": Color(0.48, 0.42, 0.28),  # Deep fescue
				"bunker": Color(0.88, 0.82, 0.60),       # Pot bunker sand
				"water": Color(0.35, 0.52, 0.62),        # Grey-blue sea
				"empty": Color(0.45, 0.42, 0.32),        # Dune grass
				"tee_box_light": Color(0.48, 0.70, 0.42),
				"tee_box_dark": Color(0.42, 0.64, 0.38),
				"path": Color(0.68, 0.65, 0.55),         # Sandy path
				"oob": Color(0.45, 0.40, 0.30),          # Dune edge
				"trees": Color(0.30, 0.38, 0.25),        # Sparse scrub
				"flower_bed": Color(0.50, 0.42, 0.30),   # Sea grass
				"rocks": Color(0.55, 0.52, 0.48),        # Weathered stone
			}
		Type.MOUNTAIN:
			return {
				"grass": Color(0.32, 0.52, 0.28),        # Deep alpine green
				"fairway_light": Color(0.38, 0.72, 0.38),
				"fairway_dark": Color(0.32, 0.66, 0.32),
				"green_light": Color(0.36, 0.82, 0.42),
				"green_dark": Color(0.32, 0.76, 0.38),
				"fringe": Color(0.35, 0.74, 0.38),
				"rough": Color(0.28, 0.46, 0.24),        # Dense mountain grass
				"heavy_rough": Color(0.24, 0.38, 0.20),
				"bunker": Color(0.78, 0.72, 0.55),       # Gravelly sand
				"water": Color(0.22, 0.50, 0.75),        # Mountain stream blue
				"empty": Color(0.42, 0.40, 0.38),        # Rocky ground
				"tee_box_light": Color(0.42, 0.72, 0.42),
				"tee_box_dark": Color(0.36, 0.66, 0.36),
				"path": Color(0.62, 0.58, 0.50),         # Gravel path
				"oob": Color(0.38, 0.35, 0.30),          # Rock face
				"trees": Color(0.15, 0.35, 0.18),        # Dense pine
				"flower_bed": Color(0.42, 0.30, 0.22),   # Mountain wildflowers
				"rocks": Color(0.52, 0.50, 0.48),        # Granite
			}
		Type.CITY:
			return {
				"grass": Color(0.42, 0.52, 0.32),        # Muted urban green
				"fairway_light": Color(0.42, 0.70, 0.40),
				"fairway_dark": Color(0.38, 0.64, 0.36),
				"green_light": Color(0.40, 0.80, 0.44),
				"green_dark": Color(0.36, 0.74, 0.40),
				"fringe": Color(0.40, 0.72, 0.42),
				"rough": Color(0.38, 0.48, 0.30),
				"heavy_rough": Color(0.32, 0.40, 0.26),
				"bunker": Color(0.85, 0.80, 0.62),
				"water": Color(0.30, 0.48, 0.65),        # Pond grey-blue
				"empty": Color(0.35, 0.35, 0.33),        # Urban ground
				"tee_box_light": Color(0.45, 0.70, 0.42),
				"tee_box_dark": Color(0.40, 0.64, 0.38),
				"path": Color(0.68, 0.68, 0.65),         # Concrete
				"oob": Color(0.45, 0.42, 0.40),          # Chain-link edge
				"trees": Color(0.25, 0.38, 0.22),
				"flower_bed": Color(0.48, 0.35, 0.28),
				"rocks": Color(0.50, 0.50, 0.48),
			}
		Type.RESORT:
			return {
				"grass": Color(0.38, 0.62, 0.35),        # Vivid tropical green
				"fairway_light": Color(0.40, 0.82, 0.45),# Lush fairway
				"fairway_dark": Color(0.35, 0.76, 0.40),
				"green_light": Color(0.38, 0.90, 0.50),
				"green_dark": Color(0.34, 0.84, 0.46),
				"fringe": Color(0.38, 0.82, 0.46),
				"rough": Color(0.34, 0.55, 0.32),        # Tropical rough
				"heavy_rough": Color(0.28, 0.48, 0.26),
				"bunker": Color(0.95, 0.92, 0.78),       # White sand
				"water": Color(0.20, 0.62, 0.82),        # Turquoise lagoon
				"empty": Color(0.22, 0.28, 0.22),
				"tee_box_light": Color(0.48, 0.80, 0.48),
				"tee_box_dark": Color(0.42, 0.74, 0.42),
				"path": Color(0.80, 0.78, 0.72),         # White shell path
				"oob": Color(0.42, 0.36, 0.30),
				"trees": Color(0.18, 0.45, 0.22),        # Tropical foliage
				"flower_bed": Color(0.55, 0.30, 0.35),   # Hibiscus red
				"rocks": Color(0.55, 0.52, 0.45),        # Coral stone
			}
	# Default fallback
	return get_terrain_colors(Type.PARKLAND)

## Tree type distributions per theme
static func get_tree_types(theme_type: int) -> Array:
	match theme_type:
		Type.PARKLAND: return ["oak", "pine", "maple", "birch"]
		Type.DESERT: return ["pine"]      # Sparse desert pines (cacti visual later)
		Type.LINKS: return ["pine"]       # Wind-bent pines only
		Type.MOUNTAIN: return ["pine", "birch"]
		Type.CITY: return ["oak", "maple"]
		Type.RESORT: return ["oak", "pine", "maple", "birch"]  # Palm visual later
	return ["oak", "pine", "maple", "birch"]

## Natural terrain generation parameters per theme
static func get_generation_params(theme_type: int) -> Dictionary:
	match theme_type:
		Type.PARKLAND:
			return {
				"elevation_range": 3,
				"water_ponds": Vector2i(1, 3),      # min, max ponds
				"tree_clusters": Vector2i(5, 10),
				"scattered_trees": Vector2i(30, 60),
				"rocks": Vector2i(40, 80),
			}
		Type.DESERT:
			return {
				"elevation_range": 2,
				"water_ponds": Vector2i(0, 1),       # Minimal water
				"tree_clusters": Vector2i(1, 3),     # Very sparse
				"scattered_trees": Vector2i(5, 15),
				"rocks": Vector2i(80, 150),          # Lots of rocks
			}
		Type.LINKS:
			return {
				"elevation_range": 2,                # Dune mounds
				"water_ponds": Vector2i(0, 1),
				"tree_clusters": Vector2i(0, 2),     # Minimal trees
				"scattered_trees": Vector2i(3, 10),
				"rocks": Vector2i(20, 50),
			}
		Type.MOUNTAIN:
			return {
				"elevation_range": 5,                # Dramatic elevation
				"water_ponds": Vector2i(1, 2),       # Mountain streams
				"tree_clusters": Vector2i(8, 15),    # Dense forests
				"scattered_trees": Vector2i(50, 100),
				"rocks": Vector2i(60, 120),          # Rocky terrain
			}
		Type.CITY:
			return {
				"elevation_range": 1,                # Very flat
				"water_ponds": Vector2i(0, 2),       # Small ponds
				"tree_clusters": Vector2i(2, 5),
				"scattered_trees": Vector2i(15, 30),
				"rocks": Vector2i(10, 25),           # Few rocks
			}
		Type.RESORT:
			return {
				"elevation_range": 2,
				"water_ponds": Vector2i(2, 4),       # Lagoon-style water
				"tree_clusters": Vector2i(6, 12),
				"scattered_trees": Vector2i(40, 80),
				"rocks": Vector2i(20, 40),
			}
	return get_generation_params(Type.PARKLAND)

## Get all theme types for iteration
static func get_all_types() -> Array:
	return [Type.PARKLAND, Type.DESERT, Type.LINKS, Type.MOUNTAIN, Type.CITY, Type.RESORT]

## Convert string to theme type (for save/load)
static func from_string(theme_name: String) -> int:
	match theme_name.to_lower():
		"parkland": return Type.PARKLAND
		"desert": return Type.DESERT
		"links": return Type.LINKS
		"mountain": return Type.MOUNTAIN
		"city": return Type.CITY
		"resort": return Type.RESORT
	return Type.PARKLAND

## Convert theme type to string (for save/load)
static func to_string_name(theme_type: int) -> String:
	match theme_type:
		Type.PARKLAND: return "parkland"
		Type.DESERT: return "desert"
		Type.LINKS: return "links"
		Type.MOUNTAIN: return "mountain"
		Type.CITY: return "city"
		Type.RESORT: return "resort"
	return "parkland"

## Get theme accent color (for UI elements)
static func get_accent_color(theme_type: int) -> Color:
	match theme_type:
		Type.PARKLAND: return Color(0.35, 0.70, 0.35)  # Green
		Type.DESERT: return Color(0.85, 0.65, 0.35)    # Sandy gold
		Type.LINKS: return Color(0.60, 0.55, 0.38)     # Golden brown
		Type.MOUNTAIN: return Color(0.40, 0.55, 0.70)   # Steel blue
		Type.CITY: return Color(0.55, 0.55, 0.55)       # Urban gray
		Type.RESORT: return Color(0.30, 0.70, 0.80)     # Turquoise
	return Color(0.35, 0.70, 0.35)
