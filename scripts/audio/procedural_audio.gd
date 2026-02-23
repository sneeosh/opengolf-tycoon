extends RefCounted
class_name ProceduralAudio
## Static utility for generating procedural audio buffers.
## All methods return PackedVector2Array (stereo samples) at the given sample rate.

const TWO_PI := TAU


# ─── Bird Song Generation ────────────────────────────────────────────────────
# Multiple bird species with realistic multi-note songs, trills, and harmonics.

enum BirdSpecies {
	ROBIN,         # Cheerful warbling phrases
	SPARROW,       # Short repeated chirps
	CARDINAL,      # Clear whistled notes with slides
	WREN,          # Fast cascading trills
	MOURNING_DOVE, # Low cooing
	BLACKBIRD,     # Rich flute-like phrases
}

## Generate a realistic bird call from a random species.
static func generate_bird_call(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var species: int = randi() % 6
	return generate_bird_call_species(sample_rate, amplitude, species)

## Generate a bird call for a specific species.
static func generate_bird_call_species(sample_rate: int, amplitude: float,
		species: int) -> PackedVector2Array:
	match species:
		BirdSpecies.ROBIN:
			return _generate_robin_song(sample_rate, amplitude)
		BirdSpecies.SPARROW:
			return _generate_sparrow_chirp(sample_rate, amplitude)
		BirdSpecies.CARDINAL:
			return _generate_cardinal_whistle(sample_rate, amplitude)
		BirdSpecies.WREN:
			return _generate_wren_trill(sample_rate, amplitude)
		BirdSpecies.MOURNING_DOVE:
			return _generate_mourning_dove(sample_rate, amplitude)
		BirdSpecies.BLACKBIRD:
			return _generate_blackbird_song(sample_rate, amplitude)
		_:
			return _generate_robin_song(sample_rate, amplitude)


static func _generate_robin_song(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Robin: 2-4 warbling notes with vibrato, cheerful ascending phrases
	var note_count := randi_range(2, 4)
	var buffers: Array[PackedVector2Array] = []
	var base_freq := randf_range(1800.0, 2800.0)

	for n in note_count:
		var note_dur := randf_range(0.08, 0.18)
		var freq := base_freq + n * randf_range(80.0, 250.0)  # Generally ascending
		if randf() < 0.3:
			freq -= randf_range(100.0, 300.0)  # Occasional dip
		var vibrato_rate := randf_range(25.0, 45.0)
		var vibrato_depth := randf_range(0.02, 0.06)
		var note := _synth_bird_note(sample_rate, note_dur, freq, amplitude * randf_range(0.7, 1.0),
			vibrato_rate, vibrato_depth, 2)
		buffers.append(note)
		# Gap between notes
		if n < note_count - 1:
			var gap := _silence(sample_rate, randf_range(0.03, 0.08))
			buffers.append(gap)

	return _concat_buffers(buffers)


static func _generate_sparrow_chirp(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Sparrow: 2-5 short staccato chips, similar pitch
	var chip_count := randi_range(2, 5)
	var buffers: Array[PackedVector2Array] = []
	var base_freq := randf_range(3000.0, 4500.0)

	for n in chip_count:
		var dur := randf_range(0.03, 0.06)
		var freq := base_freq + randf_range(-200.0, 200.0)
		var note := _synth_bird_note(sample_rate, dur, freq, amplitude * randf_range(0.6, 1.0),
			0.0, 0.0, 1)
		buffers.append(note)
		if n < chip_count - 1:
			buffers.append(_silence(sample_rate, randf_range(0.04, 0.12)))

	return _concat_buffers(buffers)


static func _generate_cardinal_whistle(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Cardinal: 2-3 clear sliding whistles, descending then ascending
	var note_count := randi_range(2, 3)
	var buffers: Array[PackedVector2Array] = []
	var base_freq := randf_range(1600.0, 2400.0)

	for n in note_count:
		var dur := randf_range(0.15, 0.35)
		var freq_start: float
		var freq_end: float
		if n % 2 == 0:
			freq_start = base_freq + randf_range(400.0, 800.0)
			freq_end = base_freq
		else:
			freq_start = base_freq
			freq_end = base_freq + randf_range(300.0, 600.0)
		var note := _synth_sliding_whistle(sample_rate, dur, freq_start, freq_end,
			amplitude * randf_range(0.7, 1.0), 3)
		buffers.append(note)
		if n < note_count - 1:
			buffers.append(_silence(sample_rate, randf_range(0.05, 0.15)))

	return _concat_buffers(buffers)


static func _generate_wren_trill(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Wren: Rapid cascading trill — fast alternating notes
	var trill_dur := randf_range(0.3, 0.6)
	var sample_count := int(sample_rate * trill_dur)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var base_freq := randf_range(2500.0, 4000.0)
	var trill_rate := randf_range(18.0, 30.0)  # Notes per second
	var phase := 0.0
	var phase2 := 0.0  # Second harmonic

	for i in sample_count:
		var t := float(i) / sample_count
		# Envelope: fade in quickly, sustain, fade out
		var env := amplitude
		if t < 0.05:
			env *= t / 0.05
		elif t > 0.85:
			env *= (1.0 - t) / 0.15

		# Trill: alternate between two close frequencies
		var trill_phase := t * trill_rate
		var trill_blend := (sin(TWO_PI * trill_phase) + 1.0) * 0.5
		var freq := lerpf(base_freq, base_freq * 1.15, trill_blend)
		# Descending pitch over time
		freq *= lerpf(1.0, 0.75, t)

		phase += TWO_PI * freq / sample_rate
		phase2 += TWO_PI * freq * 2.03 / sample_rate  # Slight detuned 2nd harmonic

		var sample := sin(phase) * 0.7 + sin(phase2) * 0.2
		# Add a touch of noise for breathiness
		sample += randf_range(-0.08, 0.08)
		sample *= env
		buffer[i] = Vector2(sample, sample)

	return buffer


static func _generate_mourning_dove(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Mourning dove: Low, soft "coo-OOO-oo-oo" — breathy with gentle pitch curves
	var buffers: Array[PackedVector2Array] = []
	var base_freq := randf_range(350.0, 500.0)

	# 3-4 coo notes, second one is longest and loudest
	var note_durs := [0.15, 0.35, 0.2, 0.15]
	var note_freqs := [base_freq, base_freq * 1.12, base_freq * 0.95, base_freq * 0.9]
	var note_amps := [0.5, 1.0, 0.6, 0.4]
	var note_count := randi_range(3, 4)

	for n in note_count:
		var dur: float = note_durs[n]
		var freq: float = note_freqs[n]
		var amp: float = note_amps[n] * amplitude
		var note := _synth_coo_note(sample_rate, dur, freq, amp)
		buffers.append(note)
		if n < note_count - 1:
			buffers.append(_silence(sample_rate, randf_range(0.08, 0.15)))

	return _concat_buffers(buffers)


static func _generate_blackbird_song(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Blackbird: Rich flute-like notes with slight vibrato, 2-3 note phrase
	var note_count := randi_range(2, 3)
	var buffers: Array[PackedVector2Array] = []
	var base_freq := randf_range(1200.0, 2000.0)

	for n in note_count:
		var dur := randf_range(0.2, 0.4)
		var freq := base_freq + randf_range(-200.0, 400.0)
		var vibrato_rate := randf_range(4.0, 8.0)
		var vibrato_depth := randf_range(0.01, 0.03)
		var note := _synth_bird_note(sample_rate, dur, freq, amplitude * randf_range(0.7, 1.0),
			vibrato_rate, vibrato_depth, 4)
		buffers.append(note)
		if n < note_count - 1:
			buffers.append(_silence(sample_rate, randf_range(0.1, 0.25)))

	return _concat_buffers(buffers)


## Synthesize a single bird note with harmonics and optional vibrato.
## harmonic_count: how many overtones (1 = pure sine, 4 = rich/flute-like)
static func _synth_bird_note(sample_rate: int, duration: float, freq: float,
		amplitude: float, vibrato_rate: float, vibrato_depth: float,
		harmonic_count: int) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phases := PackedFloat64Array()
	phases.resize(harmonic_count)
	for h in harmonic_count:
		phases[h] = randf() * TWO_PI  # Random start phase per harmonic

	# Harmonic amplitudes decay: 1.0, 0.35, 0.15, 0.08, ...
	var harm_amps := PackedFloat64Array()
	harm_amps.resize(harmonic_count)
	for h in harmonic_count:
		harm_amps[h] = 1.0 / (1.0 + h * 2.0)

	for i in sample_count:
		var t := float(i) / sample_count
		# Envelope: smooth attack and release
		var env := amplitude
		var attack := 0.08
		var release := 0.15
		if t < attack:
			env *= t / attack
		elif t > 1.0 - release:
			env *= (1.0 - t) / release

		# Vibrato
		var vib := 0.0
		if vibrato_rate > 0.0:
			vib = sin(TWO_PI * vibrato_rate * t * duration) * vibrato_depth

		var inst_freq := freq * (1.0 + vib)
		var sample := 0.0
		for h in harmonic_count:
			phases[h] += TWO_PI * inst_freq * (h + 1) / sample_rate
			sample += sin(phases[h]) * harm_amps[h]

		# Normalize and apply envelope
		sample = sample / harmonic_count * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Synthesize a sliding whistle note (cardinal-style).
static func _synth_sliding_whistle(sample_rate: int, duration: float,
		freq_start: float, freq_end: float, amplitude: float,
		harmonic_count: int) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phases := PackedFloat64Array()
	phases.resize(harmonic_count)
	var harm_amps := PackedFloat64Array()
	harm_amps.resize(harmonic_count)
	for h in harmonic_count:
		phases[h] = 0.0
		harm_amps[h] = 1.0 / (1.0 + h * 1.8)

	for i in sample_count:
		var t := float(i) / sample_count
		# Smooth envelope
		var env := amplitude
		if t < 0.06:
			env *= t / 0.06
		elif t > 0.9:
			env *= (1.0 - t) / 0.1

		# Smooth frequency slide (use ease curve for more natural feel)
		var slide_t := t * t * (3.0 - 2.0 * t)  # smoothstep
		var freq := lerpf(freq_start, freq_end, slide_t)

		var sample := 0.0
		for h in harmonic_count:
			phases[h] += TWO_PI * freq * (h + 1) / sample_rate
			sample += sin(phases[h]) * harm_amps[h]

		sample = sample / harmonic_count * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Synthesize a breathy coo note (mourning dove style).
static func _synth_coo_note(sample_rate: int, duration: float, freq: float,
		amplitude: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase := 0.0
	var phase2 := 0.0
	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		# Soft rounded envelope
		var env := sin(t * PI) * amplitude
		# Gentle pitch swell in the middle
		var pitch_mod := 1.0 + sin(t * PI) * 0.04
		var inst_freq := freq * pitch_mod

		phase += TWO_PI * inst_freq / sample_rate
		phase2 += TWO_PI * inst_freq * 2.01 / sample_rate

		# Core tone + octave + breathy noise
		var tone := sin(phase) * 0.6 + sin(phase2) * 0.2
		var noise := randf_range(-1.0, 1.0) * 0.15
		# Lowpass the noise for breathiness
		var rc := 1.0 / (TWO_PI * 800.0)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		lp_out += alpha * (noise - lp_out)

		var sample := (tone + lp_out) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Golf Shot Sounds ─────────────────────────────────────────────────────────

## Generate a club swing sound with whoosh + contact crack layered together.
## club_type: 0=DRIVER, 1=FW_WOOD, 2=IRON, 3=WEDGE, 4=PUTTER
static func generate_swing_sound(sample_rate: int, club_type: int,
		amplitude: float) -> PackedVector2Array:
	match club_type:
		0:  # DRIVER — powerful whoosh with deep resonant crack
			return _generate_driver_swing(sample_rate, amplitude)
		1:  # FAIRWAY_WOOD — medium whoosh with solid thwack
			return _generate_wood_swing(sample_rate, amplitude)
		2:  # IRON — crisp whoosh with sharp metallic click
			return _generate_iron_swing(sample_rate, amplitude)
		3:  # WEDGE — short controlled swish with clean strike
			return _generate_wedge_swing(sample_rate, amplitude)
		4:  # PUTTER — gentle tap
			return _generate_putter_tap(sample_rate, amplitude)
		_:
			return _generate_iron_swing(sample_rate, amplitude)


static func _generate_driver_swing(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Duration: whoosh builds up then crack at ~70% point, tail decays
	var duration := 0.4
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var contact_point := 0.55  # Where club hits ball
	var lp_out := 0.0
	var lp_out2 := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var sample := 0.0

		# WHOOSH: filtered noise that builds in pitch and volume
		var whoosh_env := 0.0
		if t < contact_point:
			var wt := t / contact_point
			whoosh_env = wt * wt * amplitude * 0.6  # Accelerating build
		else:
			var wt := (t - contact_point) / (1.0 - contact_point)
			whoosh_env = (1.0 - wt * wt) * amplitude * 0.3  # Quick decay after contact

		var whoosh_freq := lerpf(60.0, 400.0, minf(t / contact_point, 1.0))
		var rc := 1.0 / (TWO_PI * whoosh_freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		sample += lp_out * whoosh_env

		# CRACK: sharp transient at contact point
		var crack_t := t - contact_point
		if crack_t > 0.0 and crack_t < 0.06:
			var ct := crack_t / 0.06
			var crack_env := exp(-ct * 40.0) * amplitude * 1.2
			# Mix of high-freq burst + resonant tone
			var crack_noise := randf_range(-1.0, 1.0)
			var rc2 := 1.0 / (TWO_PI * 2500.0)
			var alpha2 := dt / (rc2 + dt)
			lp_out2 += alpha2 * (crack_noise - lp_out2)
			# Add a low resonant thump
			var thump_phase := TWO_PI * 180.0 * crack_t
			sample += (lp_out2 * 0.7 + sin(thump_phase) * 0.3) * crack_env

		buffer[i] = Vector2(sample, sample)

	return buffer


static func _generate_wood_swing(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.35
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var contact_point := 0.5
	var lp_out := 0.0
	var lp_out2 := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var sample := 0.0

		# Whoosh
		var whoosh_env := 0.0
		if t < contact_point:
			var wt := t / contact_point
			whoosh_env = wt * wt * amplitude * 0.5
		else:
			var wt := (t - contact_point) / (1.0 - contact_point)
			whoosh_env = (1.0 - wt) * amplitude * 0.2

		var whoosh_freq := lerpf(80.0, 450.0, minf(t / contact_point, 1.0))
		var rc := 1.0 / (TWO_PI * whoosh_freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		lp_out += alpha * (randf_range(-1.0, 1.0) - lp_out)
		sample += lp_out * whoosh_env

		# Thwack: slightly softer than driver, more woody resonance
		var crack_t := t - contact_point
		if crack_t > 0.0 and crack_t < 0.05:
			var ct := crack_t / 0.05
			var crack_env := exp(-ct * 35.0) * amplitude * 1.0
			var rc2 := 1.0 / (TWO_PI * 2000.0)
			var alpha2 := dt / (rc2 + dt)
			lp_out2 += alpha2 * (randf_range(-1.0, 1.0) - lp_out2)
			var thump := sin(TWO_PI * 220.0 * crack_t)
			sample += (lp_out2 * 0.6 + thump * 0.35) * crack_env

		buffer[i] = Vector2(sample, sample)

	return buffer


static func _generate_iron_swing(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.3
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var contact_point := 0.45
	var lp_out := 0.0
	var hp_out := 0.0
	var hp_prev := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var sample := 0.0
		var dt := 1.0 / sample_rate

		# Whoosh — shorter and crisper than woods
		var whoosh_env := 0.0
		if t < contact_point:
			var wt := t / contact_point
			whoosh_env = wt * wt * amplitude * 0.4
		else:
			var wt := (t - contact_point) / (1.0 - contact_point)
			whoosh_env = maxf(0.0, 1.0 - wt * 3.0) * amplitude * 0.15

		var whoosh_freq := lerpf(120.0, 600.0, minf(t / contact_point, 1.0))
		var rc := 1.0 / (TWO_PI * whoosh_freq)
		var alpha := dt / (rc + dt)
		lp_out += alpha * (randf_range(-1.0, 1.0) - lp_out)
		sample += lp_out * whoosh_env

		# Crisp metallic click at contact — higher frequency, sharper attack
		var crack_t := t - contact_point
		if crack_t > 0.0 and crack_t < 0.04:
			var ct := crack_t / 0.04
			var crack_env := exp(-ct * 50.0) * amplitude * 1.1
			# High-pass filtered noise for that crisp iron "ting"
			var noise := randf_range(-1.0, 1.0)
			var hp_rc := 1.0 / (TWO_PI * 3000.0)
			var hp_alpha := hp_rc / (hp_rc + dt)
			hp_out = hp_alpha * (hp_prev + noise - lp_out)
			hp_prev = noise
			# Mix with a metallic ring
			var ring := sin(TWO_PI * 4000.0 * crack_t) * exp(-ct * 30.0) * 0.3
			sample += (hp_out * 0.6 + ring) * crack_env

		buffer[i] = Vector2(sample, sample)

	return buffer


static func _generate_wedge_swing(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.22
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var contact_point := 0.4
	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var sample := 0.0
		var dt := 1.0 / sample_rate

		# Short swish
		var whoosh_env := 0.0
		if t < contact_point:
			var wt := t / contact_point
			whoosh_env = wt * amplitude * 0.3
		else:
			var wt := (t - contact_point) / (1.0 - contact_point)
			whoosh_env = maxf(0.0, 1.0 - wt * 4.0) * amplitude * 0.1

		var whoosh_freq := lerpf(200.0, 800.0, minf(t / contact_point, 1.0))
		var rc := 1.0 / (TWO_PI * whoosh_freq)
		var alpha := dt / (rc + dt)
		lp_out += alpha * (randf_range(-1.0, 1.0) - lp_out)
		sample += lp_out * whoosh_env

		# Clean divot/clip sound
		var crack_t := t - contact_point
		if crack_t > 0.0 and crack_t < 0.035:
			var ct := crack_t / 0.035
			var clip_env := exp(-ct * 45.0) * amplitude * 0.9
			# Bright transient
			var clip_noise := randf_range(-1.0, 1.0)
			var clip_tone := sin(TWO_PI * 3500.0 * crack_t) * 0.4
			sample += (clip_noise * 0.3 + clip_tone) * clip_env

		buffer[i] = Vector2(sample, sample)

	return buffer


static func _generate_putter_tap(sample_rate: int, amplitude: float) -> PackedVector2Array:
	# Putter: no whoosh, just a clean soft "tick" contact
	var duration := 0.12
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	for i in sample_count:
		var t := float(i) / sample_count
		# Clean percussive tap with a gentle metallic quality
		var env := exp(-t * 35.0) * amplitude * 0.5
		# Mix of a mid tone + gentle noise
		var tone := sin(TWO_PI * 1800.0 * t * duration) * 0.6
		var tone2 := sin(TWO_PI * 3200.0 * t * duration) * 0.2  # Harmonic overtone
		var noise := randf_range(-0.15, 0.15)
		var sample := (tone + tone2 + noise) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Ball Impact / Landing Sounds ─────────────────────────────────────────────

## Generate a ball landing impact sound.
## softness 0.0 = hard surface (green), 1.0 = soft surface (bunker).
static func generate_impact(sample_rate: int, softness: float,
		amplitude: float) -> PackedVector2Array:
	var duration := lerpf(0.05, 0.2, softness)
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	# Hard surfaces: bright thud with bounce character
	# Soft surfaces: muffled with longer decay
	var main_freq := lerpf(1800.0, 200.0, softness)
	var noise_freq := lerpf(4000.0, 600.0, softness)
	var decay_rate := lerpf(40.0, 15.0, softness)

	var lp_out := 0.0
	var phase := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var env := exp(-t * decay_rate) * amplitude

		# Tonal component — ball bounce resonance
		phase += TWO_PI * main_freq / sample_rate
		var tone := sin(phase) * 0.4

		# Noise component — surface texture
		var noise := randf_range(-1.0, 1.0)
		var rc := 1.0 / (TWO_PI * noise_freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		lp_out += alpha * (noise - lp_out)

		var sample := (tone + lp_out * 0.6) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a ball landing on green — distinctive "thud-bounce" with backspin character.
static func generate_green_landing(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.08
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase := 0.0
	for i in sample_count:
		var t := float(i) / sample_count
		# Sharp initial thud that quickly resolves
		var env := exp(-t * 50.0) * amplitude
		# Crisp mid-frequency with slight pitch drop (ball embedding slightly)
		var freq := lerpf(2200.0, 1500.0, t)
		phase += TWO_PI * freq / sample_rate
		var tone := sin(phase) * 0.5
		var noise := randf_range(-0.3, 0.3)
		var sample := (tone + noise) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a bunker sand impact — muffled crunch with sand scatter.
static func generate_bunker_impact(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.25
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		# Two-phase: initial thud + sand scatter
		var env: float
		if t < 0.15:
			env = exp(-t * 20.0) * amplitude * 1.0  # Initial thud
		else:
			var scatter_t := (t - 0.15) / 0.85
			env = (1.0 - scatter_t) * amplitude * 0.3  # Trailing sand

		# Heavy lowpass for muffled quality
		var noise := randf_range(-1.0, 1.0)
		var cutoff := lerpf(600.0, 200.0, t)
		var rc := 1.0 / (TWO_PI * cutoff)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		lp_out += alpha * (noise - lp_out)

		# Add intermittent crackle for sand grains
		var crackle := 0.0
		if randf() < 0.08 * (1.0 - t):
			crackle = randf_range(-0.3, 0.3)

		var sample := (lp_out + crackle) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a water splash — cascading frequency with bubbling.
static func generate_splash(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.4
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var lp_out := 0.0
	var bubble_phase := 0.0

	for i in sample_count:
		var t := float(i) / sample_count

		# Main splash: bright noise burst that quickly dulls
		var splash_env := exp(-t * 8.0) * amplitude
		var splash_cutoff := lerpf(5000.0, 300.0, t * t)
		var rc := 1.0 / (TWO_PI * splash_cutoff)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		var splash := lp_out * splash_env

		# Bubbling: random pitched tones in the tail
		var bubble := 0.0
		if t > 0.08:
			var bubble_env := (t - 0.08) * (1.0 - t) * amplitude * 0.6
			# Randomly shift bubble frequency for organic feel
			if randi() % 200 == 0:
				bubble_phase = 0.0
			var bubble_freq := randf_range(200.0, 600.0) * (1.0 + sin(t * 30.0) * 0.3)
			bubble_phase += TWO_PI * bubble_freq / sample_rate
			bubble = sin(bubble_phase) * bubble_env * 0.3

		buffer[i] = Vector2(splash + bubble, splash + bubble)

	return buffer


## Generate a "ball in cup" sound — satisfying hollow metallic rattle + drop.
static func generate_cup_sound(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.3
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase1 := 0.0
	var phase2 := 0.0
	var phase3 := 0.0

	for i in sample_count:
		var t := float(i) / sample_count

		# Initial rim hit — sharp metallic ping
		var rim_env := exp(-t * 30.0) * amplitude * 0.7
		phase1 += TWO_PI * 2400.0 / sample_rate
		var rim := sin(phase1) * rim_env

		# Ball rattling down — descending pitch with intermittent contact
		var rattle_env := 0.0
		if t > 0.03 and t < 0.25:
			var rt := (t - 0.03) / 0.22
			rattle_env = (1.0 - rt) * amplitude * 0.5
			# Intermittent bouncing pattern (accelerating)
			var bounce_rate := lerpf(8.0, 25.0, rt)
			rattle_env *= maxf(0.0, sin(TWO_PI * bounce_rate * rt * 3.0))
		var rattle_freq := lerpf(2000.0, 800.0, minf(t * 5.0, 1.0))
		phase2 += TWO_PI * rattle_freq / sample_rate
		var rattle := sin(phase2) * rattle_env

		# Final settle — low thud at bottom of cup
		var settle_env := 0.0
		if t > 0.15:
			var st := (t - 0.15) / 0.85
			settle_env = exp(-st * 8.0) * sin(st * PI * 0.5) * amplitude * 0.4
		phase3 += TWO_PI * 600.0 / sample_rate
		var settle := sin(phase3) * settle_env

		# Mix with a touch of noise for metallic character
		var noise := randf_range(-0.08, 0.08) * exp(-t * 20.0) * amplitude
		var sample := rim + rattle + settle + noise
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Celebratory Sounds ──────────────────────────────────────────────────────

## Generate a celebratory chime — ascending arpeggio with harmonics.
static func generate_chime(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.8
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	# C major arpeggio: C5, E5, G5, C6
	var freqs := [523.0, 659.0, 784.0, 1047.0]
	var phases := [0.0, 0.0, 0.0, 0.0]
	var note_starts := [0.0, 0.12, 0.24, 0.36]

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var time_s := float(i) / sample_rate
		var sample := 0.0

		for n in 4:
			if time_s >= note_starts[n]:
				var nt := time_s - note_starts[n]
				# Each note has attack + long decay with shimmer
				var note_env := minf(nt * 20.0, 1.0) * exp(-nt * 4.0) * amplitude * 0.4
				phases[n] += TWO_PI * freqs[n] / sample_rate
				# Fundamental + soft octave for shimmer
				sample += (sin(phases[n]) * 0.7 + sin(phases[n] * 2.0) * 0.2) * note_env

		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Ambient Sounds ───────────────────────────────────────────────────────────

## Generate filtered noise — used for wind and rain ambient loops.
static func generate_filtered_noise(sample_rate: int, duration: float,
		amplitude: float, lowpass_freq: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var rc := 1.0 / (TWO_PI * lowpass_freq)
	var dt := 1.0 / sample_rate
	var alpha := dt / (rc + dt)
	var lp_out := 0.0

	# Add slow amplitude modulation for organic feel
	var mod_phase := randf() * TWO_PI
	var mod_rate := randf_range(0.3, 1.2)

	for i in sample_count:
		var t := float(i) / sample_count
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		# Gentle amplitude modulation
		var mod := 1.0 + sin(mod_phase + TWO_PI * mod_rate * t * duration) * 0.15
		var sample := lp_out * amplitude * mod
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── UI Sounds ────────────────────────────────────────────────────────────────

## Generate a short UI click sound.
static func generate_click(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.025
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase := 0.0
	var freq := 1000.0
	for i in sample_count:
		var t := float(i) / sample_count
		var env := (1.0 - t) * amplitude
		phase += TWO_PI * freq / sample_rate
		var sample := sin(phase) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Legacy compatibility (kept for noise_burst calls if any remain) ──────────

## Generate a noise burst with pitch sweep — used for swing whooshes.
static func generate_noise_burst(sample_rate: int, duration: float,
		freq_start: float, freq_end: float, amplitude: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var env := (1.0 - t) * amplitude
		if t < 0.05:
			env *= t / 0.05

		var freq := lerpf(freq_start, freq_end, t)
		var rc := 1.0 / (TWO_PI * freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)

		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)

		var sample := lp_out * env
		buffer[i] = Vector2(sample, sample)

	return buffer


# ─── Buffer Utilities ─────────────────────────────────────────────────────────

static func _silence(sample_rate: int, duration: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)
	for i in sample_count:
		buffer[i] = Vector2.ZERO
	return buffer

static func _concat_buffers(buffers: Array[PackedVector2Array]) -> PackedVector2Array:
	var total_size := 0
	for b in buffers:
		total_size += b.size()
	var result := PackedVector2Array()
	result.resize(total_size)
	var offset := 0
	for b in buffers:
		for i in b.size():
			result[offset + i] = b[i]
		offset += b.size()
	return result
