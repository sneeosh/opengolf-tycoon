extends Node
## SoundManager — Procedural audio system for OpenGolf Tycoon.
## Generates all sounds procedurally via AudioStreamGenerator.
## Subscribes to EventBus signals — zero coupling to game systems.

const SAMPLE_RATE := 22050
const SFX_POOL_SIZE := 4  # Max concurrent one-shot SFX
const SWING_COOLDOWN := 0.3  # Seconds between swing sounds
const IMPACT_COOLDOWN := 0.2  # Seconds between impact sounds

# ─── Volume settings ──────────────────────────────────────────────
var master_volume: float = 0.8
var sfx_volume: float = 1.0
var ambient_volume: float = 0.6
var is_muted: bool = false

# ─── Internal state ───────────────────────────────────────────────
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _ambient_wind: AudioStreamPlayer = null
var _ambient_birds: AudioStreamPlayer = null
var _ambient_rain: AudioStreamPlayer = null
var _bird_timer: Timer = null

var _last_swing_time: float = 0.0
var _last_impact_time: float = 0.0

# Current environment state for ambient updates
var _current_wind_speed: float = 0.0
var _current_weather_type: int = 0
var _current_weather_intensity: float = 0.0
var _wind_buffer_dirty: bool = true
var _rain_buffer_dirty: bool = true

# Pre-generated buffers for common sounds (avoid regenerating each time)
var _click_buffer: PackedVector2Array
var _cup_buffer: PackedVector2Array
var _chime_buffer: PackedVector2Array

func _ready() -> void:
	_create_sfx_pool()
	_create_ambient_players()
	_create_bird_timer()
	_pregenerate_buffers()
	_connect_signals()

# ─── Setup ────────────────────────────────────────────────────────

func _create_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_pool.append(player)

func _create_ambient_players() -> void:
	_ambient_wind = AudioStreamPlayer.new()
	_ambient_wind.bus = "Master"
	add_child(_ambient_wind)

	_ambient_rain = AudioStreamPlayer.new()
	_ambient_rain.bus = "Master"
	add_child(_ambient_rain)

	_ambient_birds = AudioStreamPlayer.new()
	_ambient_birds.bus = "Master"
	add_child(_ambient_birds)

func _create_bird_timer() -> void:
	_bird_timer = Timer.new()
	_bird_timer.one_shot = true
	_bird_timer.timeout.connect(_on_bird_timer)
	add_child(_bird_timer)
	_schedule_next_bird()

func _pregenerate_buffers() -> void:
	_click_buffer = ProceduralAudio.generate_click(SAMPLE_RATE, 0.3)
	_cup_buffer = ProceduralAudio.generate_cup_sound(SAMPLE_RATE, 0.5)
	_chime_buffer = ProceduralAudio.generate_chime(SAMPLE_RATE, 0.4)

func _connect_signals() -> void:
	EventBus.shot_taken.connect(_on_shot_taken)
	EventBus.ball_shot_landed_precise.connect(_on_ball_shot_landed)
	EventBus.ball_putt_landed_precise.connect(_on_ball_putt_landed)
	EventBus.ball_in_hole.connect(_on_ball_in_hole)
	EventBus.hazard_penalty.connect(_on_hazard_penalty)
	EventBus.record_broken.connect(_on_record_broken)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.wind_changed.connect(_on_wind_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)

# ─── Public API ───────────────────────────────────────────────────

func play_ui_click() -> void:
	if is_muted:
		return
	_play_buffer(_click_buffer, sfx_volume * master_volume * 0.5)

func play_placement_sound(placement_type: String) -> void:
	if is_muted:
		return
	var buffer: PackedVector2Array
	match placement_type:
		"tree", "rock":
			buffer = ProceduralAudio.generate_impact(SAMPLE_RATE, 0.6, 0.3)
		"building":
			buffer = ProceduralAudio.generate_impact(SAMPLE_RATE, 0.3, 0.4)
		"terrain":
			buffer = ProceduralAudio.generate_impact(SAMPLE_RATE, 0.8, 0.2)
		_:
			return
	_play_buffer(buffer, sfx_volume * master_volume)

func set_muted(muted: bool) -> void:
	is_muted = muted
	if muted:
		_stop_ambient()
	else:
		_update_ambient()
	_save_settings()

func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	_update_ambient_volumes()
	_save_settings()

func _save_settings() -> void:
	if SaveManager and SaveManager.has_method("save_user_settings"):
		SaveManager.save_user_settings()

func get_settings_data() -> Dictionary:
	return {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume,
		"is_muted": is_muted,
	}

func load_settings_data(data: Dictionary) -> void:
	master_volume = data.get("master_volume", 0.8)
	sfx_volume = data.get("sfx_volume", 1.0)
	ambient_volume = data.get("ambient_volume", 0.6)
	is_muted = data.get("is_muted", false)
	if is_muted:
		_stop_ambient()
	else:
		_update_ambient()

# ─── Signal handlers ──────────────────────────────────────────────

func _on_shot_taken(golfer_id: int, _hole_number: int, _strokes: int) -> void:
	if is_muted:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_swing_time < SWING_COOLDOWN:
		return

	# Check if golfer is on screen
	if not _is_golfer_on_screen(golfer_id):
		return

	_last_swing_time = now

	# Determine club type from golfer for sound variation
	var club_type := _get_golfer_club_type(golfer_id)
	var buffer := _generate_swing_buffer(club_type)
	_play_buffer(buffer, sfx_volume * master_volume)

func _on_ball_shot_landed(_golfer_id: int, _from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int, _carry_screen: Vector2) -> void:
	_play_impact_at_screen_position(to_screen)

func _on_ball_putt_landed(_golfer_id: int, _from_screen: Vector2, to_screen: Vector2,
		_distance_yards: int) -> void:
	if is_muted:
		return
	if not _is_screen_position_visible(to_screen):
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_impact_time < IMPACT_COOLDOWN:
		return
	_last_impact_time = now

	# Putts always land on green — crisp short sound
	var buffer := ProceduralAudio.generate_impact(SAMPLE_RATE, 0.0, 0.3)
	_play_buffer(buffer, sfx_volume * master_volume * 0.6)

func _on_ball_in_hole(_golfer_id: int, _hole_number: int) -> void:
	if is_muted:
		return
	_play_buffer(_cup_buffer, sfx_volume * master_volume)

func _on_hazard_penalty(_golfer_id: int, hazard_type: String, _reset_position: Vector2i) -> void:
	if is_muted:
		return
	if hazard_type == "water":
		var buffer := ProceduralAudio.generate_splash(SAMPLE_RATE, 0.5)
		_play_buffer(buffer, sfx_volume * master_volume)

func _on_record_broken(_record_type: String, _golfer_name: String, _value: int, _hole_number: int) -> void:
	if is_muted:
		return
	_play_buffer(_chime_buffer, sfx_volume * master_volume)

func _on_building_placed(_building_type: String, _position: Vector2i) -> void:
	play_placement_sound("building")

func _on_building_removed(_position: Vector2i) -> void:
	if is_muted:
		return
	var buffer := ProceduralAudio.generate_impact(SAMPLE_RATE, 0.5, 0.3)
	_play_buffer(buffer, sfx_volume * master_volume)

func _on_wind_changed(_direction: float, speed: float) -> void:
	_current_wind_speed = speed
	_wind_buffer_dirty = true
	_update_ambient()

func _on_weather_changed(weather_type: int, intensity: float) -> void:
	_current_weather_type = weather_type
	_current_weather_intensity = intensity
	_rain_buffer_dirty = true
	_update_ambient()

func _on_hour_changed(_new_hour: float) -> void:
	# Adjust bird frequency by time of day
	_schedule_next_bird()

func _on_game_mode_changed(_old_mode: int, new_mode: int) -> void:
	# Mute ambient during menu
	if new_mode == GameManager.GameMode.MAIN_MENU:
		_stop_ambient()
	elif not is_muted:
		_update_ambient()

# ─── Swing sound generation ──────────────────────────────────────

func _generate_swing_buffer(club_type: int) -> PackedVector2Array:
	# Club type maps to Golfer.Club enum: 0=DRIVER, 1=FW, 2=IRON, 3=WEDGE, 4=PUTTER
	match club_type:
		0:  # DRIVER — deep powerful whoosh
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.25, 80.0, 250.0, 0.5)
		1:  # FAIRWAY_WOOD — medium whoosh
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.2, 120.0, 350.0, 0.4)
		2:  # IRON — sharp mid whoosh
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.15, 200.0, 500.0, 0.35)
		3:  # WEDGE — short crisp swish
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.1, 300.0, 700.0, 0.25)
		4:  # PUTTER — very soft tap
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.05, 800.0, 1200.0, 0.15)
		_:
			return ProceduralAudio.generate_noise_burst(SAMPLE_RATE, 0.15, 200.0, 500.0, 0.3)

# ─── Impact at screen position ───────────────────────────────────

func _play_impact_at_screen_position(world_pos: Vector2) -> void:
	if is_muted:
		return
	if not _is_screen_position_visible(world_pos):
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_impact_time < IMPACT_COOLDOWN:
		return
	_last_impact_time = now

	# Look up terrain type at the world position
	var terrain_type := _get_terrain_at_world(world_pos)
	var buffer := _generate_impact_for_terrain(terrain_type)

	# Distance-based volume: world pos closer to camera center = louder
	var viewport := get_viewport()
	var vol_scale := 0.8
	if viewport:
		var canvas_transform := viewport.get_canvas_transform()
		var screen_pos := canvas_transform * world_pos
		var viewport_center := viewport.get_visible_rect().size / 2.0
		var dist_to_center := screen_pos.distance_to(viewport_center)
		var max_dist := viewport_center.length()
		vol_scale = clampf(1.0 - (dist_to_center / max_dist) * 0.6, 0.3, 1.0)

	_play_buffer(buffer, sfx_volume * master_volume * vol_scale)

func _generate_impact_for_terrain(terrain_type: int) -> PackedVector2Array:
	# TerrainTypes.Type enum values
	match terrain_type:
		5:  # GREEN — crisp tick
			return ProceduralAudio.generate_impact(SAMPLE_RATE, 0.0, 0.35)
		1, 2:  # GRASS, FAIRWAY — medium thud
			return ProceduralAudio.generate_impact(SAMPLE_RATE, 0.4, 0.3)
		3, 4:  # ROUGH, HEAVY_ROUGH — soft thud
			return ProceduralAudio.generate_impact(SAMPLE_RATE, 0.6, 0.25)
		7:  # BUNKER — muffled crunch
			return ProceduralAudio.generate_impact(SAMPLE_RATE, 0.9, 0.35)
		8:  # WATER — splash
			return ProceduralAudio.generate_splash(SAMPLE_RATE, 0.4)
		_:  # Default — generic thud
			return ProceduralAudio.generate_impact(SAMPLE_RATE, 0.5, 0.3)

# ─── Ambient system ───────────────────────────────────────────────

func _update_ambient() -> void:
	if is_muted or GameManager.game_mode == GameManager.GameMode.MAIN_MENU:
		_stop_ambient()
		return

	_update_wind_ambient()
	_update_rain_ambient()
	_update_ambient_volumes()

func _update_wind_ambient() -> void:
	if _current_wind_speed < 2.0:
		if _ambient_wind.playing:
			_ambient_wind.stop()
		return

	if _wind_buffer_dirty or not _ambient_wind.playing:
		_wind_buffer_dirty = false
		# Cutoff frequency scales with wind speed: calm=low, strong=higher
		var cutoff := lerpf(100.0, 1500.0, clampf(_current_wind_speed / 30.0, 0.0, 1.0))
		var wind_amp := clampf(_current_wind_speed / 30.0, 0.05, 0.4)
		var buffer := ProceduralAudio.generate_filtered_noise(SAMPLE_RATE, 2.0, wind_amp, cutoff)
		_play_ambient_loop(_ambient_wind, buffer)

func _update_rain_ambient() -> void:
	# Weather types: 0=SUNNY, 1=PARTLY_CLOUDY, 2=OVERCAST, 3=LIGHT_RAIN, 4=RAIN, 5=HEAVY_RAIN
	if _current_weather_type < 3:
		if _ambient_rain.playing:
			_ambient_rain.stop()
		return

	if _rain_buffer_dirty or not _ambient_rain.playing:
		_rain_buffer_dirty = false
		var rain_amp := clampf(_current_weather_intensity * 0.5, 0.05, 0.35)
		var cutoff := lerpf(800.0, 3000.0, _current_weather_intensity)
		var buffer := ProceduralAudio.generate_filtered_noise(SAMPLE_RATE, 2.0, rain_amp, cutoff)
		_play_ambient_loop(_ambient_rain, buffer)

func _play_ambient_loop(player: AudioStreamPlayer, buffer: PackedVector2Array) -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 2.0
	player.stream = stream
	player.play()

	# Fill the playback buffer
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback:
		for sample in buffer:
			if playback.can_push_buffer(1):
				playback.push_frame(sample)

func _update_ambient_volumes() -> void:
	var vol := ambient_volume * master_volume
	_ambient_wind.volume_db = linear_to_db(vol) if vol > 0.001 else -80.0
	_ambient_rain.volume_db = linear_to_db(vol) if vol > 0.001 else -80.0
	_ambient_birds.volume_db = linear_to_db(vol * 0.7) if vol > 0.001 else -80.0

func _stop_ambient() -> void:
	_ambient_wind.stop()
	_ambient_rain.stop()
	_ambient_birds.stop()

# ─── Bird chirps ──────────────────────────────────────────────────

func _schedule_next_bird() -> void:
	if not _bird_timer:
		return
	# Birds chirp more at dawn/dusk, less at night
	var hour: float = GameManager.current_hour if GameManager else 12.0
	var base_interval: float
	if hour < 6.0 or hour > 20.0:
		base_interval = 30.0  # Rare at night
	elif hour < 8.0 or hour > 18.0:
		base_interval = 3.0  # Frequent at dawn/dusk
	else:
		base_interval = 6.0  # Moderate during day
	_bird_timer.start(randf_range(base_interval * 0.5, base_interval * 1.5))

func _on_bird_timer() -> void:
	if is_muted or GameManager.game_mode == GameManager.GameMode.MAIN_MENU:
		_schedule_next_bird()
		return

	# Don't chirp during rain
	if _current_weather_type >= 3:
		_schedule_next_bird()
		return

	# Random chirp parameters
	var freq_start := randf_range(2000.0, 3500.0)
	var freq_end := randf_range(freq_start * 0.8, freq_start * 1.3)
	var duration := randf_range(0.08, 0.15)
	var buffer := ProceduralAudio.generate_chirp(SAMPLE_RATE, duration, freq_start, freq_end, 0.15)
	_play_buffer(buffer, ambient_volume * master_volume * 0.5)

	# Sometimes do a double chirp
	if randf() < 0.4:
		await get_tree().create_timer(randf_range(0.1, 0.2)).timeout
		freq_start = randf_range(2500.0, 4000.0)
		freq_end = randf_range(freq_start * 0.9, freq_start * 1.2)
		buffer = ProceduralAudio.generate_chirp(SAMPLE_RATE, duration * 0.8, freq_start, freq_end, 0.12)
		_play_buffer(buffer, ambient_volume * master_volume * 0.4)

	_schedule_next_bird()

# ─── Playback helpers ─────────────────────────────────────────────

func _play_buffer(buffer: PackedVector2Array, volume: float) -> void:
	if volume < 0.001:
		return

	# Find a free player from the pool
	var player: AudioStreamPlayer = null
	for i in SFX_POOL_SIZE:
		var idx := (_sfx_pool_index + i) % SFX_POOL_SIZE
		if not _sfx_pool[idx].playing:
			player = _sfx_pool[idx]
			_sfx_pool_index = (idx + 1) % SFX_POOL_SIZE
			break

	# If all busy, steal the oldest one
	if not player:
		player = _sfx_pool[_sfx_pool_index]
		_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = buffer.size() / float(SAMPLE_RATE) + 0.1
	player.stream = stream
	player.volume_db = linear_to_db(volume) if volume > 0.001 else -80.0
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	if playback:
		for sample in buffer:
			if playback.can_push_buffer(1):
				playback.push_frame(sample)

# ─── Visibility checks ───────────────────────────────────────────

func _is_screen_position_visible(world_pos: Vector2) -> bool:
	# Check if a world-space position is within the camera's visible area
	var viewport := get_viewport()
	if not viewport:
		return true
	var camera := viewport.get_camera_2d()
	if not camera:
		return true
	var canvas_transform := viewport.get_canvas_transform()
	var screen_pos := canvas_transform * world_pos
	var viewport_rect := viewport.get_visible_rect()
	var margin := 150.0
	return Rect2(viewport_rect.position - Vector2(margin, margin),
		viewport_rect.size + Vector2(margin * 2, margin * 2)).has_point(screen_pos)

func _is_golfer_on_screen(golfer_id: int) -> bool:
	var golfer = _find_golfer(golfer_id)
	if not golfer:
		return true  # Default to playing sound if we can't find the golfer
	return _is_screen_position_visible(golfer.global_position)

func _find_golfer(golfer_id: int):
	# Find golfer through the scene tree's GolferManager node
	var golfer_mgr = _get_golfer_manager()
	if golfer_mgr and golfer_mgr.has_method("get_golfer"):
		return golfer_mgr.get_golfer(golfer_id)
	return null

var _cached_golfer_manager = null

func _get_golfer_manager():
	if _cached_golfer_manager and is_instance_valid(_cached_golfer_manager):
		return _cached_golfer_manager
	# GolferManager is a child of the Main scene node
	var main_scene := get_tree().current_scene if get_tree() else null
	if main_scene and main_scene.has_node("GolferManager"):
		_cached_golfer_manager = main_scene.get_node("GolferManager")
		return _cached_golfer_manager
	return null

# ─── Terrain lookup ───────────────────────────────────────────────

func _get_terrain_at_world(world_pos: Vector2) -> int:
	if not GameManager or not GameManager.terrain_grid:
		return 1  # Default to GRASS
	var grid_pos: Vector2i = GameManager.terrain_grid.screen_to_grid(world_pos)
	return GameManager.terrain_grid.get_tile(grid_pos)

# ─── Club type lookup ─────────────────────────────────────────────

func _get_golfer_club_type(golfer_id: int) -> int:
	# Infer club from golfer's terrain and distance to hole.
	# shot_taken doesn't carry club info, so we use heuristics.
	if not GameManager or not GameManager.terrain_grid:
		return 2  # Default to IRON
	var golfer = _find_golfer(golfer_id)
	if not golfer:
		return 2

	# Check terrain at golfer's position to guess club
	var terrain := GameManager.terrain_grid.get_tile(golfer.ball_position)
	match terrain:
		6:  # TEE_BOX — likely driver or wood
			return 0  # DRIVER
		5:  # GREEN — putter
			return 4  # PUTTER
		7:  # BUNKER — wedge
			return 3  # WEDGE
		_:
			# Check distance to hole for a rough estimate
			if golfer.get("current_hole") != null and golfer.current_hole >= 0:
				var holes = GameManager.course_data.holes
				if golfer.current_hole < holes.size():
					var hole_data = holes[golfer.current_hole]
					var dist: float = Vector2i(golfer.ball_position).distance_to(hole_data.hole_position)
					if dist > 8:
						return 1  # FAIRWAY_WOOD
					elif dist > 4:
						return 2  # IRON
					else:
						return 3  # WEDGE
			return 2  # Default IRON

# ─── Ambient buffer refill (called from _process) ─────────────────

var _wind_refill_timer: float = 0.0
var _rain_refill_timer: float = 0.0
const AMBIENT_REFILL_INTERVAL := 1.8  # Refill before the 2s buffer runs out

func _process(delta: float) -> void:
	if is_muted or GameManager.game_mode == GameManager.GameMode.MAIN_MENU:
		return

	# Periodically refill ambient buffers to create continuous loops
	_wind_refill_timer += delta
	_rain_refill_timer += delta

	if _wind_refill_timer >= AMBIENT_REFILL_INTERVAL and _ambient_wind.playing:
		_wind_refill_timer = 0.0
		_refill_wind_buffer()

	if _rain_refill_timer >= AMBIENT_REFILL_INTERVAL and _ambient_rain.playing:
		_rain_refill_timer = 0.0
		_refill_rain_buffer()

func _refill_wind_buffer() -> void:
	if not _ambient_wind.playing:
		return
	var playback = _ambient_wind.get_stream_playback()
	if not playback:
		return
	var cutoff := lerpf(100.0, 1500.0, clampf(_current_wind_speed / 30.0, 0.0, 1.0))
	var wind_amp := clampf(_current_wind_speed / 30.0, 0.05, 0.4)
	var buffer := ProceduralAudio.generate_filtered_noise(SAMPLE_RATE, 1.0, wind_amp, cutoff)
	for sample in buffer:
		if playback.can_push_buffer(1):
			playback.push_frame(sample)

func _refill_rain_buffer() -> void:
	if not _ambient_rain.playing:
		return
	var playback = _ambient_rain.get_stream_playback()
	if not playback:
		return
	var rain_amp := clampf(_current_weather_intensity * 0.5, 0.05, 0.35)
	var cutoff := lerpf(800.0, 3000.0, _current_weather_intensity)
	var buffer := ProceduralAudio.generate_filtered_noise(SAMPLE_RATE, 1.0, rain_amp, cutoff)
	for sample in buffer:
		if playback.can_push_buffer(1):
			playback.push_frame(sample)
