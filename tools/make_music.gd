extends SceneTree
## Renders the game's ambient music loops. Nothing is sampled; it's all synthesis:
## a low drone, slow chord pads, wind, and distant bells through a reverb.
## Every part repeats exactly over the loop (whole-cycle frequencies, cyclic envelopes,
## filters warmed up on the loop's own tail), so the tracks loop without a seam.
##
## Run:  godot --headless --path . -s res://tools/make_music.gd -- --out=/tmp/music
## Then: for f in /tmp/music/*.wav; do ffmpeg -y -i "$f" -c:a libvorbis -q:a 4 "audio/$(basename "${f%.wav}").ogg"; done
## Replace the .ogg files with composed music any time; nothing else needs to change.

const RATE := 22050
const LOOP_SECONDS := 64
const CHORD_SECONDS := 16.0
const CHORD_FADE := 4.0

# Bell partials: frequency ratio (inharmonic, like a real bell), amplitude, decay seconds.
const BELL_RATIOS: Array[float] = [1.0, 2.76, 5.4, 8.93]
const BELL_AMPS: Array[float] = [1.0, 0.45, 0.25, 0.12]
const BELL_DECAYS: Array[float] = [3.5, 1.6, 0.8, 0.4]

# Freeverb-style reverb, delay lengths scaled for 22.05 kHz.
const COMBS: Array[int] = [558, 594, 638, 678]
const ALLPASSES: Array[int] = [278, 220]
const STEREO_SPREAD := 12
const FEEDBACK := 0.92
const DAMP := 0.3

# Notes are MIDI numbers. Chords change every 16 s with 4 s crossfades.
# "mix" is each layer's loudness (RMS) before the final normalisation.
const TRACKS := {
	# D minor: Dm - Bb - Gm - A. Low and uneasy, with sparse far-off bells.
	"forgotten_city": {
		"drone": 38,
		"chords": [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52]],
		"brightness": 0.2,
		"bells": [[3.0, 74, 1.0], [11.0, 69, 0.7], [19.5, 77, 0.85], [26.0, 76, 0.6],
				[35.0, 74, 0.9], [41.0, 72, 0.6], [50.0, 69, 0.85], [57.5, 76, 0.7]],
		"mix": {"drone": 0.11, "pad": 0.045, "wet": 0.085, "bells": 0.012, "wind": 0.035},
	},
	# D major: D - G - Bm - A. Same room, but warmer, with more frequent, higher bells.
	"lamps_lit": {
		"drone": 38,
		"chords": [[50, 54, 57], [43, 47, 50, 55], [47, 50, 54], [45, 49, 52]],
		"brightness": 0.45,
		"bells": [[2.0, 74, 0.8], [6.0, 78, 0.6], [10.0, 81, 0.7], [14.0, 76, 0.6],
				[18.0, 74, 0.8], [22.0, 79, 0.6], [26.0, 83, 0.7], [30.0, 78, 0.6],
				[34.0, 74, 0.8], [38.0, 81, 0.6], [42.0, 78, 0.7], [46.0, 76, 0.6],
				[50.0, 73, 0.8], [54.0, 76, 0.6], [58.0, 81, 0.7], [62.0, 76, 0.5]],
		"mix": {"drone": 0.06, "pad": 0.06, "wet": 0.1, "bells": 0.025, "wind": 0.015},
	},
}


func _initialize() -> void:
	var out_dir := OS.get_user_data_dir().path_join("music")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for track_name in TRACKS:
		var started := Time.get_ticks_msec()
		var stereo := _render(TRACKS[track_name])
		var path := out_dir.path_join(track_name + ".wav")
		_save_wav(stereo[0], stereo[1], path)
		print("%s -> %s (%.1f s)" % [track_name, path, (Time.get_ticks_msec() - started) / 1000.0])
	quit()


func _render(spec: Dictionary) -> Array:
	var n := RATE * LOOP_SECONDS
	var drone := _drone(spec, n)
	var pad := _pad(spec, n)
	var bells := _bells(spec, n)
	var wind := _wind(n)

	# The reverb hears the pads softly and the bells loudly, which makes the bells sound far away.
	var send := PackedFloat32Array()
	send.resize(n)
	var pad_gain := 0.5 / maxf(_rms(pad), 1e-6)
	var bell_gain := 2.0 / maxf(_peak(bells), 1e-6)
	for i in n:
		send[i] = pad[i] * pad_gain + bells[i] * bell_gain
	var wet := _reverb(send, n)

	var mix: Dictionary = spec.mix
	var buses := [
		[drone[0], drone[1], mix.drone],
		[pad, pad, mix.pad],
		[wet[0], wet[1], mix.wet],
		[bells, bells, mix.bells],
		[wind[0], wind[1], mix.wind],
	]
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(n)
	right.resize(n)
	for bus in buses:
		var bus_l: PackedFloat32Array = bus[0]
		var bus_r: PackedFloat32Array = bus[1]
		var gain: float = bus[2] / maxf(sqrt((_rms(bus_l) ** 2 + _rms(bus_r) ** 2) / 2.0), 1e-6)
		for i in n:
			left[i] += bus_l[i] * gain
			right[i] += bus_r[i] * gain

	var scale := 0.9 / maxf(maxf(_peak(left), _peak(right)), 1e-6)
	for i in n:
		left[i] *= scale
		right[i] *= scale
	return [left, right]


# Snaps a frequency so it completes a whole number of cycles in the loop.
static func _snap(freq: float) -> float:
	return maxf(1.0, round(freq * LOOP_SECONDS)) / LOOP_SECONDS


static func _note(midi: float) -> float:
	return _snap(440.0 * pow(2.0, (midi - 69.0) / 12.0))


func _drone(spec: Dictionary, n: int) -> Array:
	var root := _note(spec.drone)
	var root_right := _snap(root * 1.004)  # slight detune between ears makes it slowly beat
	var fifth := _note(spec.drone + 7)
	var octave := root * 2.0
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	l.resize(n)
	r.resize(n)
	for i in n:
		var t := float(i) / RATE
		var swell := 0.7 + 0.3 * sin(TAU * t / 16.0)
		var shimmer := 0.5 + 0.5 * sin(TAU * t / 32.0 + 1.0)
		var common := 0.35 * sin(TAU * octave * t) * shimmer + 0.25 * sin(TAU * fifth * t)
		l[i] = (sin(TAU * root * t) + common) * swell
		r[i] = (sin(TAU * root_right * t) + common) * swell
	return [l, r]


func _pad(spec: Dictionary, n: int) -> PackedFloat32Array:
	var chords: Array = spec.chords
	var freqs: Array = []
	for chord in chords:
		var chord_freqs := PackedFloat32Array()
		for note in chord:
			chord_freqs.append(_note(note))
		freqs.append(chord_freqs)
	var bright: float = spec.brightness
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for c in chords.size():
			var env := _chord_envelope(t, c)
			if env <= 0.0:
				continue
			var chord_freqs: PackedFloat32Array = freqs[c]
			var s := 0.0
			for f in chord_freqs:
				var phase := TAU * f * t
				s += sin(phase) + bright * sin(2.0 * phase)
			v += s * env
		out[i] = v
	return out


# Each chord fades in over CHORD_FADE seconds centred on its start, and out the same way,
# wrapping around the loop so the last chord crossfades into the first.
func _chord_envelope(t: float, chord_index: int) -> float:
	var u := fposmod(t - chord_index * CHORD_SECONDS + CHORD_FADE / 2.0, float(LOOP_SECONDS))
	if u < CHORD_FADE:
		return 0.5 - 0.5 * cos(PI * u / CHORD_FADE)
	if u < CHORD_SECONDS:
		return 1.0
	if u < CHORD_SECONDS + CHORD_FADE:
		return 0.5 + 0.5 * cos(PI * (u - CHORD_SECONDS) / CHORD_FADE)
	return 0.0


func _bells(spec: Dictionary, n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var length := int(RATE * 6.0)
	for bell in spec.bells:
		var start := int(float(bell[0]) * RATE)
		var freq := 440.0 * pow(2.0, (float(bell[1]) - 69.0) / 12.0)
		var amp := float(bell[2])
		for k in length:
			var tt := float(k) / RATE
			var v := 0.0
			for p in BELL_RATIOS.size():
				v += BELL_AMPS[p] * exp(-tt / BELL_DECAYS[p]) * sin(TAU * freq * BELL_RATIOS[p] * tt)
			var idx := (start + k) % n  # tails wrap around to the start of the loop
			out[idx] += v * amp * minf(1.0, tt / 0.004)
	return out


func _wind(n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var result := []
	var warm := RATE * 3
	for channel in 2:
		var noise := PackedFloat32Array()
		noise.resize(n)
		for i in n:
			noise[i] = rng.randf_range(-1.0, 1.0)
		var out := PackedFloat32Array()
		out.resize(n)
		var low := 0.0
		var rumble := 0.0
		for j in range(-warm, n):
			var i := posmod(j, n)
			var t := float(i) / RATE
			var cutoff := 380.0 + 260.0 * sin(TAU * t / 32.0 + channel * 2.0) + 120.0 * sin(TAU * t / 8.0 + channel)
			low += (1.0 - exp(-TAU * cutoff / RATE)) * (noise[i] - low)
			rumble += 0.004 * (low - rumble)
			if j >= 0:
				var gust := 0.6 + 0.4 * sin(TAU * t * 3.0 / LOOP_SECONDS + channel)
				out[i] = (low - rumble) * gust
		result.append(out)
	return result


func _reverb(input: PackedFloat32Array, n: int) -> Array:
	var result := []
	var warm := RATE * 6
	for channel in 2:
		var spread := channel * STEREO_SPREAD
		var comb_sizes := PackedInt32Array()
		var comb_offsets := PackedInt32Array()
		var total := 0
		for size in COMBS:
			comb_offsets.append(total)
			comb_sizes.append(size + spread)
			total += size + spread
		var comb_buf := PackedFloat32Array()
		comb_buf.resize(total)
		var comb_pos := PackedInt32Array()
		comb_pos.resize(COMBS.size())
		var comb_store := PackedFloat32Array()
		comb_store.resize(COMBS.size())

		var ap_sizes := PackedInt32Array()
		var ap_offsets := PackedInt32Array()
		total = 0
		for size in ALLPASSES:
			ap_offsets.append(total)
			ap_sizes.append(size + spread)
			total += size + spread
		var ap_buf := PackedFloat32Array()
		ap_buf.resize(total)
		var ap_pos := PackedInt32Array()
		ap_pos.resize(ALLPASSES.size())

		var out := PackedFloat32Array()
		out.resize(n)
		for j in range(-warm, n):
			var i := posmod(j, n)
			var x := input[i] * 0.03
			var acc := 0.0
			for c in comb_sizes.size():
				var idx := comb_offsets[c] + comb_pos[c]
				var y := comb_buf[idx]
				comb_store[c] = y * (1.0 - DAMP) + comb_store[c] * DAMP
				comb_buf[idx] = x + comb_store[c] * FEEDBACK
				comb_pos[c] = (comb_pos[c] + 1) % comb_sizes[c]
				acc += y
			for a in ap_sizes.size():
				var idx := ap_offsets[a] + ap_pos[a]
				var b := ap_buf[idx]
				ap_buf[idx] = acc + b * 0.5
				ap_pos[a] = (ap_pos[a] + 1) % ap_sizes[a]
				acc = b - acc
			if j >= 0:
				out[i] = acc
		result.append(out)
	return result


static func _rms(samples: PackedFloat32Array) -> float:
	var sum := 0.0
	for s in samples:
		sum += s * s
	return sqrt(sum / maxf(samples.size(), 1))


static func _peak(samples: PackedFloat32Array) -> float:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	return peak


func _save_wav(left: PackedFloat32Array, right: PackedFloat32Array, path: String) -> void:
	var bytes := PackedByteArray()
	bytes.resize(left.size() * 4)
	for i in left.size():
		bytes.encode_s16(i * 4, int(clampf(left[i], -1.0, 1.0) * 32767.0))
		bytes.encode_s16(i * 4 + 2, int(clampf(right[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = RATE
	wav.data = bytes
	wav.save_to_wav(path)
