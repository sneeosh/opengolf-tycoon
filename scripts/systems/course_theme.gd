extends RefCounted
class_name CourseTheme
## CourseTheme - Defines course environment types with distinct visuals and gameplay

enum Type {
	PARKLAND,   # Default - lush green, deciduous trees, gentle hills
	DESERT,     # Arid sandy base, cacti, rocky outcroppings, minimal water
	LINKS,      # Coastal Scottish-style, fescue rough, pot bunkers, strong wind
	MOUNTAIN,   # Dramatic elevation, pine forests, thinner air (+distance)
	CITY,       # Flat, urban, chain-link OB, cheaper maintenance
	RESORT,     # Tropical lush, palms, vibrant flowers, premium pricing
	HEATHLAND,  # Inland sandy soil, heather/gorse rough, scattered pines, pot bunkers
	WOODLAND,   # Dense forest corridors, tight fairways, tree-lined, accuracy-focused
	TROPICAL,   # Volcanic island, ocean carries, jungle rough, trade winds
	MARSHLAND   # Coastal wetlands, marsh grass, omnipresent water, tidal lowcountry
}

## Theme display information
static func get_theme_name(theme_type: int) -> String:
	match theme_type:
		Type.PARKLAND: return "Parkland"
		Type.DESERT: return "Desert"
		Type.LINKS: return "Links"
		Type.MOUNTAIN: return "Mountain"
		Type.CITY: return "City/Municipal"
		Type.RESORT: return "Resort"
		Type.HEATHLAND: return "Heathland"
		Type.WOODLAND: return "Woodland"
		Type.TROPICAL: return "Tropical"
		Type.MARSHLAND: return "Marshland"
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
		Type.HEATHLAND:
			return "Inland course on sandy soil with penal heather and gorse rough. Scattered pines and deep pot bunkers demand accuracy over power."
		Type.WOODLAND:
			return "Dense forest course with tight, tree-lined fairways. Trees are the primary hazard — shot shaping and club selection are paramount."
		Type.TROPICAL:
			return "Volcanic island course with ocean carries, jungle rough, and trade winds. Dramatic forced carries over lava rock and sea."
		Type.MARSHLAND:
			return "Coastal lowcountry course woven through marshes and tidal creeks. Water is everywhere — strategic routing is essential."
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
		Type.HEATHLAND:
			return {
				"wind_base_strength": 1.2,   # Moderate — open inland terrain
				"distance_modifier": 1.01,   # Firm turf gives extra roll
				"maintenance_cost_multiplier": 0.75,  # Heathland is low-maintenance
				"green_fee_baseline": 35,
				"land_cost_multiplier": 1.1,  # Desirable heathland is limited
				"satisfaction_ceiling": 1.0,
				"rough_penalty_multiplier": 1.4,  # Heather/gorse is brutally penal
			}
		Type.WOODLAND:
			return {
				"wind_base_strength": 0.6,   # Dense canopy blocks wind heavily
				"distance_modifier": 0.98,   # Trees limit club choices
				"maintenance_cost_multiplier": 0.9,  # Natural forest, less landscaping
				"green_fee_baseline": 35,
				"land_cost_multiplier": 0.7,  # Forested land is affordable
				"satisfaction_ceiling": 1.0,
				"tree_collision_multiplier": 1.5,  # Dense trees punish errant shots
			}
		Type.TROPICAL:
			return {
				"wind_base_strength": 1.4,   # Persistent trade winds
				"distance_modifier": 1.02,   # Warm sea-level air
				"maintenance_cost_multiplier": 1.2,  # Tropical growth requires management
				"green_fee_baseline": 45,    # Destination premium
				"land_cost_multiplier": 1.4,  # Island real estate
				"satisfaction_ceiling": 1.0,
			}
		Type.MARSHLAND:
			return {
				"wind_base_strength": 1.3,   # Coastal, open terrain
				"distance_modifier": 1.0,
				"maintenance_cost_multiplier": 1.1,  # Drainage and environmental mgmt
				"green_fee_baseline": 40,
				"land_cost_multiplier": 0.5,  # Swampland is cheap
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
		Type.HEATHLAND:
			return {
				"grass": Color(0.50, 0.52, 0.35),        # Sandy golden-brown base
				"fairway_light": Color(0.45, 0.68, 0.38),# Muted green on sandy soil
				"fairway_dark": Color(0.40, 0.62, 0.34),
				"green_light": Color(0.40, 0.80, 0.44),
				"green_dark": Color(0.36, 0.74, 0.40),
				"fringe": Color(0.42, 0.72, 0.40),
				"rough": Color(0.48, 0.38, 0.42),        # Purple-brown heather
				"heavy_rough": Color(0.42, 0.30, 0.38),  # Dense heather/gorse
				"bunker": Color(0.88, 0.82, 0.58),       # Deep pot bunker sand
				"water": Color(0.28, 0.52, 0.72),        # Inland pond blue
				"empty": Color(0.52, 0.48, 0.36),        # Sandy heath ground
				"tee_box_light": Color(0.48, 0.70, 0.42),
				"tee_box_dark": Color(0.42, 0.64, 0.38),
				"path": Color(0.65, 0.60, 0.48),         # Sandy path
				"oob": Color(0.45, 0.38, 0.32),          # Scrubby edge
				"trees": Color(0.22, 0.38, 0.22),        # Scattered pine/birch
				"flower_bed": Color(0.55, 0.35, 0.48),   # Heather purple accent
				"rocks": Color(0.52, 0.50, 0.45),        # Sandy stone
			}
		Type.WOODLAND:
			return {
				"grass": Color(0.28, 0.42, 0.25),        # Dark forest floor
				"fairway_light": Color(0.35, 0.65, 0.35),# Emerald green corridor
				"fairway_dark": Color(0.30, 0.58, 0.30),
				"green_light": Color(0.34, 0.80, 0.42),
				"green_dark": Color(0.30, 0.74, 0.38),
				"fringe": Color(0.32, 0.72, 0.38),
				"rough": Color(0.32, 0.40, 0.25),        # Undergrowth
				"heavy_rough": Color(0.26, 0.32, 0.20),  # Dense bracken/fern
				"bunker": Color(0.82, 0.76, 0.55),       # Pine needle-tinted sand
				"water": Color(0.22, 0.45, 0.62),        # Shaded forest pond
				"empty": Color(0.30, 0.28, 0.22),        # Pine needle ground
				"tee_box_light": Color(0.38, 0.68, 0.38),
				"tee_box_dark": Color(0.32, 0.62, 0.32),
				"path": Color(0.55, 0.48, 0.35),         # Bark/mulch path
				"oob": Color(0.22, 0.24, 0.18),          # Deep forest
				"trees": Color(0.12, 0.30, 0.14),        # Dense pine canopy
				"flower_bed": Color(0.38, 0.28, 0.18),   # Fern brown-green
				"rocks": Color(0.42, 0.40, 0.38),        # Mossy stone
			}
		Type.TROPICAL:
			return {
				"grass": Color(0.35, 0.58, 0.32),        # Lush tropical green
				"fairway_light": Color(0.38, 0.78, 0.42),# Vivid fairway
				"fairway_dark": Color(0.33, 0.72, 0.38),
				"green_light": Color(0.36, 0.88, 0.48),
				"green_dark": Color(0.32, 0.82, 0.44),
				"fringe": Color(0.36, 0.80, 0.44),
				"rough": Color(0.28, 0.48, 0.28),        # Jungle undergrowth
				"heavy_rough": Color(0.22, 0.40, 0.22),  # Dense jungle
				"bunker": Color(0.92, 0.88, 0.80),       # Coral-white sand
				"water": Color(0.15, 0.58, 0.82),        # Vivid turquoise ocean
				"empty": Color(0.25, 0.22, 0.20),        # Black volcanic rock
				"tee_box_light": Color(0.42, 0.76, 0.45),
				"tee_box_dark": Color(0.36, 0.70, 0.40),
				"path": Color(0.72, 0.68, 0.58),         # Crushed coral path
				"oob": Color(0.20, 0.18, 0.16),          # Dark lava rock
				"trees": Color(0.15, 0.42, 0.20),        # Dense tropical canopy
				"flower_bed": Color(0.65, 0.32, 0.28),   # Plumeria/orchid red
				"rocks": Color(0.30, 0.28, 0.26),        # Volcanic basalt
			}
		Type.MARSHLAND:
			return {
				"grass": Color(0.45, 0.52, 0.35),        # Sage-green marsh grass
				"fairway_light": Color(0.42, 0.72, 0.40),# Green fairway amid marsh
				"fairway_dark": Color(0.38, 0.66, 0.36),
				"green_light": Color(0.40, 0.82, 0.45),
				"green_dark": Color(0.36, 0.76, 0.42),
				"fringe": Color(0.40, 0.74, 0.42),
				"rough": Color(0.42, 0.48, 0.32),        # Marsh grass rough
				"heavy_rough": Color(0.38, 0.42, 0.28),  # Dense reeds/cattails
				"bunker": Color(0.82, 0.78, 0.62),       # Muddy sand
				"water": Color(0.32, 0.45, 0.48),        # Murky tidal brown-grey
				"empty": Color(0.38, 0.36, 0.30),        # Muddy ground
				"tee_box_light": Color(0.45, 0.72, 0.42),
				"tee_box_dark": Color(0.40, 0.66, 0.38),
				"path": Color(0.62, 0.58, 0.48),         # Oyster shell path
				"oob": Color(0.35, 0.32, 0.28),          # Tidal mud flat
				"trees": Color(0.28, 0.40, 0.25),        # Live oak with Spanish moss
				"flower_bed": Color(0.52, 0.45, 0.30),   # Golden marsh reed
				"rocks": Color(0.45, 0.42, 0.38),        # Weathered tabby/oyster
			}
	# Default fallback
	return get_terrain_colors(Type.PARKLAND)

## Tree/vegetation type distributions per theme
static func get_tree_types(theme_type: int) -> Array:
	match theme_type:
		Type.PARKLAND: return ["oak", "pine", "maple", "birch", "bush", "cattails"]
		Type.DESERT: return ["cactus", "dead_tree", "bush", "palm"]
		Type.LINKS: return ["fescue", "heather", "bush", "pine"]
		Type.MOUNTAIN: return ["pine", "birch", "bush", "heather"]
		Type.CITY: return ["oak", "maple", "bush", "cattails"]
		Type.RESORT: return ["palm", "oak", "cactus", "bush", "birch"]
		Type.HEATHLAND: return ["pine", "birch", "heather", "bush", "fescue"]
		Type.WOODLAND: return ["pine", "oak", "birch", "maple", "bush"]
		Type.TROPICAL: return ["palm", "dead_tree", "bush", "oak", "cactus"]
		Type.MARSHLAND: return ["oak", "pine", "cattails", "bush", "birch"]
	return ["oak", "pine", "maple", "birch"]

## Natural terrain generation parameters per theme
static func get_generation_params(theme_type: int) -> Dictionary:
	match theme_type:
		Type.PARKLAND:
			return {
				"elevation_range": 3,
				"water_ponds": Vector2i(1, 3),
				"large_water_body": false,
				"tree_clusters": Vector2i(12, 20),    # Dense woodland coverage
				"scattered_trees": Vector2i(80, 140),  # Lots of individual trees
				"tree_cluster_radius": Vector2(10, 25), # Larger clusters
				"tree_density": Vector2(0.25, 0.45),    # Denser within clusters
				"rocks": Vector2i(40, 80),
				"rough_patches": Vector2i(8, 14),      # Overgrown areas
				"heavy_rough_patches": Vector2i(4, 8),  # Wild undergrowth
				"flower_patches": Vector2i(3, 6),       # Wildflower meadows
			}
		Type.DESERT:
			return {
				"elevation_range": 2,
				"water_ponds": Vector2i(0, 1),
				"large_water_body": false,
				"tree_clusters": Vector2i(1, 3),       # Very sparse
				"scattered_trees": Vector2i(5, 15),
				"tree_cluster_radius": Vector2(5, 12),
				"tree_density": Vector2(0.10, 0.20),
				"rocks": Vector2i(100, 180),            # Rocky desert landscape
				"rough_patches": Vector2i(10, 18),      # Scrubland patches
				"heavy_rough_patches": Vector2i(2, 4),   # Sparse brush
				"flower_patches": Vector2i(0, 1),        # Rare desert blooms
			}
		Type.LINKS:
			return {
				"elevation_range": 2,                  # Dune mounds
				"water_ponds": Vector2i(0, 1),
				"large_water_body": true,              # Coastal ocean/lake
				"large_water_edge": "random",          # Which map edge gets water
				"large_water_depth": Vector2i(8, 14),  # How far inland water extends
				"tree_clusters": Vector2i(0, 2),       # Minimal trees on links
				"scattered_trees": Vector2i(3, 10),
				"tree_cluster_radius": Vector2(4, 10),
				"tree_density": Vector2(0.10, 0.20),
				"rocks": Vector2i(30, 60),
				"rough_patches": Vector2i(14, 22),     # Heavy fescue rough everywhere
				"heavy_rough_patches": Vector2i(8, 14), # Deep fescue dunes
				"flower_patches": Vector2i(1, 3),       # Sea grass clumps
			}
		Type.MOUNTAIN:
			return {
				"elevation_range": 5,                  # Dramatic elevation
				"water_ponds": Vector2i(1, 3),         # Mountain streams/lakes
				"large_water_body": false,
				"tree_clusters": Vector2i(15, 25),     # Dense pine forests
				"scattered_trees": Vector2i(100, 180),  # Heavily forested
				"tree_cluster_radius": Vector2(12, 28), # Large forest areas
				"tree_density": Vector2(0.30, 0.50),    # Very dense clusters
				"rocks": Vector2i(80, 150),             # Rocky mountain terrain
				"rough_patches": Vector2i(6, 12),       # Mountain grass patches
				"heavy_rough_patches": Vector2i(5, 10), # Dense undergrowth
				"flower_patches": Vector2i(2, 5),        # Mountain wildflowers
			}
		Type.CITY:
			return {
				"elevation_range": 1,                  # Very flat
				"water_ponds": Vector2i(0, 2),
				"large_water_body": false,
				"tree_clusters": Vector2i(3, 7),
				"scattered_trees": Vector2i(20, 40),
				"tree_cluster_radius": Vector2(6, 14),
				"tree_density": Vector2(0.15, 0.30),
				"rocks": Vector2i(10, 25),
				"rough_patches": Vector2i(4, 8),        # Unmowed city lots
				"heavy_rough_patches": Vector2i(2, 5),
				"flower_patches": Vector2i(2, 4),        # Overgrown flower beds
			}
		Type.RESORT:
			return {
				"elevation_range": 2,
				"water_ponds": Vector2i(1, 3),
				"large_water_body": true,              # Lagoon/lake feature
				"large_water_edge": "interior",        # Interior lagoon, not edge
				"large_water_depth": Vector2i(10, 16), # Larger interior body
				"tree_clusters": Vector2i(10, 18),     # Lush tropical coverage
				"scattered_trees": Vector2i(60, 120),
				"tree_cluster_radius": Vector2(10, 22),
				"tree_density": Vector2(0.25, 0.40),
				"rocks": Vector2i(20, 40),
				"rough_patches": Vector2i(6, 10),       # Tropical undergrowth
				"heavy_rough_patches": Vector2i(3, 6),
				"flower_patches": Vector2i(5, 10),       # Abundant tropical flowers
			}
		Type.HEATHLAND:
			return {
				"elevation_range": 2,                  # Gentle undulation
				"water_ponds": Vector2i(0, 2),
				"large_water_body": false,
				"tree_clusters": Vector2i(4, 8),       # Scattered pine clusters
				"scattered_trees": Vector2i(15, 35),   # Open, not heavily wooded
				"tree_cluster_radius": Vector2(6, 14),
				"tree_density": Vector2(0.15, 0.30),
				"rocks": Vector2i(30, 60),
				"rough_patches": Vector2i(16, 26),     # Heavy heather coverage
				"heavy_rough_patches": Vector2i(10, 18), # Dense gorse thickets
				"flower_patches": Vector2i(4, 8),       # Heather blooms
			}
		Type.WOODLAND:
			return {
				"elevation_range": 2,                  # Gentle forest hills
				"water_ponds": Vector2i(0, 2),         # Occasional forest pond
				"large_water_body": false,
				"tree_clusters": Vector2i(20, 32),     # Very dense forest — highest
				"scattered_trees": Vector2i(120, 200), # Heavily forested
				"tree_cluster_radius": Vector2(12, 30), # Large forest blocks
				"tree_density": Vector2(0.35, 0.55),   # Very dense within clusters
				"rocks": Vector2i(30, 60),             # Forest floor rocks
				"rough_patches": Vector2i(6, 10),      # Undergrowth
				"heavy_rough_patches": Vector2i(4, 8),  # Bracken/fern patches
				"flower_patches": Vector2i(1, 3),       # Sparse forest wildflowers
			}
		Type.TROPICAL:
			return {
				"elevation_range": 3,                  # Volcanic terrain variation
				"water_ponds": Vector2i(1, 3),
				"large_water_body": true,              # Coastal ocean
				"large_water_edge": "random",          # Ocean on random map edge
				"large_water_depth": Vector2i(6, 12),  # Moderate coastline
				"tree_clusters": Vector2i(10, 16),     # Tropical groves
				"scattered_trees": Vector2i(50, 100),
				"tree_cluster_radius": Vector2(8, 20),
				"tree_density": Vector2(0.25, 0.45),
				"rocks": Vector2i(80, 140),            # Volcanic rock outcroppings
				"rough_patches": Vector2i(8, 14),      # Jungle undergrowth
				"heavy_rough_patches": Vector2i(5, 10), # Dense jungle
				"flower_patches": Vector2i(4, 8),       # Tropical flowers
			}
		Type.MARSHLAND:
			return {
				"elevation_range": 1,                  # Very flat lowcountry
				"water_ponds": Vector2i(3, 6),         # Lots of water features
				"large_water_body": true,              # Tidal creek/marsh edge
				"large_water_edge": "random",          # Water on random map edge
				"large_water_depth": Vector2i(6, 10),  # Tidal marsh extent
				"tree_clusters": Vector2i(6, 12),      # Live oak groves
				"scattered_trees": Vector2i(30, 60),   # Spanish moss oaks
				"tree_cluster_radius": Vector2(8, 18),
				"tree_density": Vector2(0.20, 0.35),
				"rocks": Vector2i(15, 30),             # Minimal rocks
				"rough_patches": Vector2i(12, 20),     # Marsh grass everywhere
				"heavy_rough_patches": Vector2i(8, 14), # Dense reed beds
				"flower_patches": Vector2i(2, 5),       # Marsh wildflowers
			}
	return get_generation_params(Type.PARKLAND)

## Get all theme types for iteration
static func get_all_types() -> Array:
	return [Type.PARKLAND, Type.DESERT, Type.LINKS, Type.MOUNTAIN, Type.CITY, Type.RESORT, Type.HEATHLAND, Type.WOODLAND, Type.TROPICAL, Type.MARSHLAND]

## Convert string to theme type (for save/load)
static func from_string(theme_name: String) -> int:
	match theme_name.to_lower():
		"parkland": return Type.PARKLAND
		"desert": return Type.DESERT
		"links": return Type.LINKS
		"mountain": return Type.MOUNTAIN
		"city": return Type.CITY
		"resort": return Type.RESORT
		"heathland": return Type.HEATHLAND
		"woodland": return Type.WOODLAND
		"tropical": return Type.TROPICAL
		"marshland": return Type.MARSHLAND
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
		Type.HEATHLAND: return "heathland"
		Type.WOODLAND: return "woodland"
		Type.TROPICAL: return "tropical"
		Type.MARSHLAND: return "marshland"
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
		Type.HEATHLAND: return Color(0.62, 0.42, 0.58)  # Heather purple
		Type.WOODLAND: return Color(0.30, 0.52, 0.30)   # Forest green
		Type.TROPICAL: return Color(0.85, 0.55, 0.25)   # Volcanic orange
		Type.MARSHLAND: return Color(0.55, 0.62, 0.42)  # Sage green
	return Color(0.35, 0.70, 0.35)
