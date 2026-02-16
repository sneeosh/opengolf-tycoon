extends RefCounted
class_name ProceduralAudio
## Static utility for generating procedural audio buffers.
## All methods return PackedVector2Array (stereo samples) at the given sample rate.

const TWO_PI := TAU


## Generate a noise burst with pitch sweep — used for swing whooshes.
## freq_start/freq_end control the resonant peak of a bandpass on white noise.
static func generate_noise_burst(sample_rate: int, duration: float,
		freq_start: float, freq_end: float, amplitude: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	# Simple state for one-pole lowpass filter
	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count  # 0..1 progress
		# Envelope: quick attack, gradual decay
		var env := (1.0 - t) * amplitude
		if t < 0.05:
			env *= t / 0.05  # 5% attack

		# Sweep the lowpass cutoff from freq_start to freq_end
		var freq := lerpf(freq_start, freq_end, t)
		var rc := 1.0 / (TWO_PI * freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)

		# White noise through one-pole lowpass
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)

		var sample := lp_out * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a sine chirp — used for birdsong.
static func generate_chirp(sample_rate: int, duration: float,
		freq_start: float, freq_end: float, amplitude: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase := 0.0
	for i in sample_count:
		var t := float(i) / sample_count
		var freq := lerpf(freq_start, freq_end, t)
		# Envelope: bell curve
		var env := sin(t * PI) * amplitude
		phase += TWO_PI * freq / sample_rate
		var sample := sin(phase) * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate filtered noise — used for wind and rain ambient loops.
## lowpass_freq controls the cutoff; lower = more muffled.
static func generate_filtered_noise(sample_rate: int, duration: float,
		amplitude: float, lowpass_freq: float) -> PackedVector2Array:
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var rc := 1.0 / (TWO_PI * lowpass_freq)
	var dt := 1.0 / sample_rate
	var alpha := dt / (rc + dt)
	var lp_out := 0.0

	for i in sample_count:
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		var sample := lp_out * amplitude
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate an impact sound — short percussive hit.
## softness 0.0 = hard click (green), 1.0 = muffled thud (bunker).
static func generate_impact(sample_rate: int, softness: float,
		amplitude: float) -> PackedVector2Array:
	var duration := lerpf(0.03, 0.15, softness)
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var freq := lerpf(1200.0, 150.0, softness)
	var rc := 1.0 / (TWO_PI * freq)
	var dt := 1.0 / sample_rate
	var alpha := dt / (rc + dt)
	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		# Sharp exponential decay
		var env := exp(-t * lerpf(30.0, 12.0, softness)) * amplitude
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		var sample := lp_out * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a water splash — noise with falling pitch.
static func generate_splash(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.25
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var lp_out := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		# Sweep cutoff from bright to dull
		var freq := lerpf(3000.0, 200.0, t)
		var rc := 1.0 / (TWO_PI * freq)
		var dt := 1.0 / sample_rate
		var alpha := dt / (rc + dt)
		# Envelope: fast decay
		var env := (1.0 - t * t) * amplitude
		var noise := randf_range(-1.0, 1.0)
		lp_out += alpha * (noise - lp_out)
		var sample := lp_out * env
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a short UI click sound.
static func generate_click(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.02
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


## Generate a celebratory chime — used for hole-in-one, records.
static func generate_chime(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.6
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	# Two-note rising chime (C5 → E5)
	var freq1 := 523.0
	var freq2 := 659.0
	var phase1 := 0.0
	var phase2 := 0.0

	for i in sample_count:
		var t := float(i) / sample_count
		var env1 := maxf(0.0, 1.0 - t * 3.0) * amplitude
		var env2 := maxf(0.0, minf((t - 0.15) * 5.0, 1.0)) * (1.0 - t) * amplitude
		phase1 += TWO_PI * freq1 / sample_rate
		phase2 += TWO_PI * freq2 / sample_rate
		var sample := sin(phase1) * env1 + sin(phase2) * env2
		buffer[i] = Vector2(sample, sample)

	return buffer


## Generate a "ball in cup" sound — short metallic ping.
static func generate_cup_sound(sample_rate: int, amplitude: float) -> PackedVector2Array:
	var duration := 0.15
	var sample_count := int(sample_rate * duration)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)

	var phase := 0.0
	var freq := 2200.0  # High metallic ping
	for i in sample_count:
		var t := float(i) / sample_count
		var env := exp(-t * 25.0) * amplitude
		phase += TWO_PI * freq / sample_rate
		# Mix sine with a bit of noise for metallic character
		var sample := (sin(phase) * 0.7 + randf_range(-0.3, 0.3)) * env
		buffer[i] = Vector2(sample, sample)

	return buffer
