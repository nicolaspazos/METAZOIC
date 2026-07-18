extends SceneTree
## Procedurally synthesizes every sound in METAZOIC — SFX, ambient loops, and the
## music track — as 22.05kHz mono 16-bit WAVs. Deterministic (fixed seed).
##
## Run from the repo root:
##   godot --headless --path . -s tools/asset_gen/generate_audio.gd
##
## Output goes to assets/audio/. Loops (music/wind/hum) are made seamless with a
## short crossfade; Sfx.gd sets their loop flags at runtime.

const SR := 22050
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 777
	DirAccess.make_dir_recursive_absolute(OUT)
	_sfx()
	_ambient()
	_music()
	print("[gen] all audio written to assets/audio/")
	quit(0)


# ---------------------------------------------------------------- plumbing

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * SR))
	return b


func _save(name: String, buf: PackedFloat32Array) -> void:
	var peak := 0.001
	for s in buf:
		peak = maxf(peak, absf(s))
	var k := 0.85 / peak
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * k, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = false
	wav.data = data
	wav.save_to_wav(OUT + name + ".wav")
	print("  wrote %s.wav (%.2fs)" % [name, buf.size() / float(SR)])


## Crossfade the tail into the head so the buffer loops seamlessly, then trim the tail.
func _loopify(buf: PackedFloat32Array, fade_sec: float) -> PackedFloat32Array:
	var fn := int(fade_sec * SR)
	var n := buf.size()
	for i in fn:
		var w := float(i) / fn
		buf[i] = buf[i] * w + buf[n - fn + i] * (1.0 - w)
	buf.resize(n - fn)
	return buf


## Additive tone: frequency glides f0→f1. type: 0 sine, 1 square, 2 saw, 3 triangle.
func _tone(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		amp: float, type := 0, vib := 0.0, attack := 0.005) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var p := float(i) / n
		var f := lerpf(f0, f1, p) * (1.0 + vib * sin(TAU * 6.0 * t))
		phase += f / SR
		var s: float
		match type:
			0: s = sin(TAU * phase)
			1: s = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
			2: s = 2.0 * fposmod(phase, 1.0) - 1.0
			_: s = 4.0 * absf(fposmod(phase, 1.0) - 0.5) - 1.0
		var env := minf(t / attack, 1.0) * pow(1.0 - p, 1.5)
		var j := i0 + i
		if j >= 0 and j < buf.size():
			buf[j] += s * amp * env


## Low-passed noise burst with a sweeping cutoff (0..1) and exponential decay.
func _burst(buf: PackedFloat32Array, start: float, dur: float, amp: float,
		c0 := 0.5, c1 := 0.1) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var y := 0.0
	for i in n:
		var p := float(i) / n
		var a := lerpf(c0, c1, p)
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var env := pow(1.0 - p, 1.6) * minf(float(i) / (0.004 * SR), 1.0)
		var j := i0 + i
		if j >= 0 and j < buf.size():
			buf[j] += y * amp * env


## Whoosh: low-passed noise with a bell envelope and rising cutoff.
func _whoosh(buf: PackedFloat32Array, start: float, dur: float, amp: float,
		c0 := 0.06, c1 := 0.45) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var y := 0.0
	for i in n:
		var p := float(i) / n
		var a := lerpf(c0, c1, p)
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		var env := pow(sin(PI * p), 1.3)
		var j := i0 + i
		if j >= 0 and j < buf.size():
			buf[j] += y * amp * env


## Beastly vocal: stacked detuned saws + sub sine with a pitch envelope, breath
## noise, fast growl modulation, all saturated through tanh — animal, not chiptune.
func _beast(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		amp: float, growl := 0.4, breath := 0.5) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	var y := 0.0
	for i in n:
		var t := float(i) / SR
		var p := float(i) / n
		var f := lerpf(f0, f1, p) * (1.0 + growl * 0.5 * sin(TAU * 27.0 * t))
		ph1 += f / SR
		ph2 += f * 1.007 / SR
		ph3 += f * 0.5 / SR
		var s := (2.0 * fposmod(ph1, 1.0) - 1.0) * 0.5 \
			+ (2.0 * fposmod(ph2, 1.0) - 1.0) * 0.35 + sin(TAU * ph3) * 0.6
		y += 0.12 * (rng.randf_range(-1.0, 1.0) - y)
		s += y * breath
		var env := minf(t / 0.03, 1.0) * pow(1.0 - p, 1.3)
		var j := i0 + i
		if j < buf.size():
			buf[j] += tanh(s * 2.2) * amp * env


# ---------------------------------------------------------------- SFX

func _sfx() -> void:
	var b: PackedFloat32Array

	b = _buf(0.28)                     # club swing
	_whoosh(b, 0.0, 0.28, 1.0, 0.08, 0.5)
	_save("swing", b)

	b = _buf(0.2)                      # meaty impact
	_tone(b, 0.0, 0.16, 150, 55, 0.9)
	_burst(b, 0.0, 0.12, 0.6, 0.6, 0.2)
	_save("hit", b)

	b = _buf(0.24)                     # raptor bite — wet snap, no chirp
	_burst(b, 0.0, 0.05, 1.0, 0.85, 0.4)
	_beast(b, 0.02, 0.14, 150, 85, 0.7, 0.6, 0.6)
	_burst(b, 0.09, 0.06, 0.7, 0.8, 0.4)
	_save("bite", b)

	b = _buf(0.95)                     # aggro growl — low, throaty, sub-heavy
	_beast(b, 0.0, 0.9, 58, 36, 0.85, 0.55, 0.55)
	_save("growl", b)

	b = _buf(0.4)                      # raptor pain — harsh bark, not a whistle
	_beast(b, 0.0, 0.35, 340, 150, 0.8, 0.75, 0.8)
	_burst(b, 0.0, 0.15, 0.35, 0.75, 0.3)
	_save("raptor_hurt", b)

	b = _buf(1.35)                     # raptor death — long agonized bellow
	_beast(b, 0.0, 1.25, 280, 60, 0.85, 0.6, 0.7)
	_burst(b, 0.7, 0.6, 0.35, 0.25, 0.05)
	_save("raptor_die", b)

	b = _buf(0.32)                     # caveman grunt — human, chesty
	_beast(b, 0.0, 0.28, 155, 92, 0.65, 0.25, 0.65)
	_save("player_hurt", b)

	b = _buf(0.16)                     # jump
	_tone(b, 0.0, 0.15, 280, 520, 0.6)
	_save("jump", b)

	b = _buf(0.1)                      # footstep
	_burst(b, 0.0, 0.08, 0.6, 0.3, 0.05)
	_tone(b, 0.0, 0.07, 95, 60, 0.4)
	_save("step", b)

	b = _buf(1.1)                      # power absorbed — rising arpeggio + shimmer
	var notes := [329.6, 392.0, 493.9, 659.3]
	for i in notes.size():
		_tone(b, i * 0.12, 0.55, notes[i], notes[i], 0.45)
		_tone(b, i * 0.12, 0.55, notes[i] * 2.0, notes[i] * 2.0, 0.12)
	_tone(b, 0.4, 0.6, 1318.5, 1318.5, 0.1, 0, 0.3)
	for i in range(b.size() - 1, int(0.18 * SR), -1):  # cheap echo
		b[i] += b[i - int(0.18 * SR)] * 0.35
	_save("absorb", b)

	b = _buf(0.22)                     # shield block clank
	_tone(b, 0.0, 0.18, 620, 600, 0.5)
	_tone(b, 0.0, 0.15, 930, 900, 0.35)
	_tone(b, 0.0, 0.12, 1250, 1210, 0.25)
	_burst(b, 0.0, 0.04, 0.8, 0.9, 0.5)
	_save("block", b)

	b = _buf(0.38)                     # dash / charge whoosh
	_whoosh(b, 0.0, 0.38, 0.9, 0.04, 0.25)
	_tone(b, 0.0, 0.3, 95, 65, 0.35)
	_save("dash", b)

	b = _buf(0.34)                     # jaws chomp — bone-deep crunch
	_burst(b, 0.0, 0.07, 1.0, 0.9, 0.4)
	_beast(b, 0.0, 0.24, 95, 48, 1.0, 0.5, 0.5)
	_burst(b, 0.11, 0.08, 0.9, 0.9, 0.4)
	_save("chomp", b)

	b = _buf(0.5)                      # tail sweep — big wide whoosh
	_whoosh(b, 0.0, 0.5, 1.0, 0.05, 0.35)
	_tone(b, 0.05, 0.4, 120, 70, 0.3)
	_save("sweep", b)

	b = _buf(0.42)                     # heavy overhead swing — deeper, slower
	_whoosh(b, 0.0, 0.42, 1.0, 0.03, 0.22)
	_tone(b, 0.05, 0.3, 75, 50, 0.35)
	_save("heavy", b)

	b = _buf(0.16)                     # landing thud
	_burst(b, 0.0, 0.12, 0.8, 0.25, 0.05)
	_tone(b, 0.0, 0.1, 70, 45, 0.7)
	_save("land", b)

	b = _buf(0.4)                      # heartbeat — two low thumps
	_tone(b, 0.0, 0.1, 58, 48, 1.0)
	_tone(b, 0.2, 0.09, 52, 44, 0.75)
	_save("heartbeat", b)

	b = _buf(0.35)                     # bird call 1 — two descending chirps
	_tone(b, 0.0, 0.09, 2200, 1400, 0.5)
	_tone(b, 0.14, 0.1, 1800, 1100, 0.45)
	_save("bird1", b)

	b = _buf(0.4)                      # bird call 2 — trill
	for i in 5:
		_tone(b, i * 0.055, 0.05, 1600 if i % 2 == 0 else 1950, 1600 if i % 2 == 0 else 1950, 0.4)
	_save("bird2", b)

	b = _buf(0.42)                     # raptor idle chitter — fast clicks
	for i in 6:
		_burst(b, i * 0.055, 0.03, 0.7, 0.85, 0.5)
	_tone(b, 0.0, 0.35, 520, 430, 0.15, 3, 0.2)
	_save("chitter", b)

	b = _buf(2.2)                      # distant roar — something huge, far away
	_beast(b, 0.0, 1.9, 64, 30, 0.75, 0.45, 0.5)
	_burst(b, 0.2, 1.4, 0.3, 0.05, 0.02)
	for i in range(b.size() - 1, int(0.32 * SR), -1):  # cheap cavern echo
		b[i] += b[i - int(0.32 * SR)] * 0.42
	_save("distant_roar", b)


# ---------------------------------------------------------------- ambient loops

func _ambient() -> void:
	# Wind: a deep 24s moan, heavily filtered (no rain-like hiss), with two slow
	# breathing cycles that both complete whole periods → the loop never pops
	# and takes far longer to feel repetitive.
	var b := _buf(24.0)
	var y := 0.0
	var y2 := 0.0
	for i in b.size():
		var t := float(i) / SR
		var cutoff := 0.008 + 0.006 * sin(TAU * t / 12.0) + 0.004 * sin(TAU * t / 8.0)
		y += cutoff * (rng.randf_range(-1.0, 1.0) - y)
		y2 += 0.02 * (y - y2)  # second pole — kills the hiss entirely
		b[i] = y2 * (0.55 + 0.3 * sin(TAU * t / 24.0) + 0.15 * sin(TAU * t / 6.0))
	_save("wind", _loopify(b, 0.5))

	# Crash-site hum: alien drone from the meteor shards. 4s, seamless.
	b = _buf(4.0)
	for i in b.size():
		var t := float(i) / SR
		var trem := 0.75 + 0.25 * sin(TAU * t / 1.0)
		b[i] = (sin(TAU * 55.0 * t) * 0.6 + sin(TAU * 82.5 * t) * 0.3
			+ sin(TAU * 220.4 * t) * 0.08) * trem
	_save("hum", _loopify(b, 0.1))


# ---------------------------------------------------------------- music

func _music() -> void:
	_music_dark()


## Dark-fantasy score — slow ritual taiko, an abyssal tritone drone, tolling
## phrygian bells, and a distant detuned choir. Prehistoric dark souls.
func _music_dark() -> void:
	var spb := 60.0 / 70.0            # 70 BPM — a funeral pace
	var bar := spb * 4.0
	var bars := 16
	var len := bar * bars             # ≈ 54.9s
	var b := _buf(len + 0.1)

	# Abyssal drone: E1 root + Bb1 (the tritone — the devil's interval) + E2.
	for i in int(len * SR):
		var t := float(i) / SR
		var sw := 0.7 + 0.3 * sin(TAU * t / (len / 4.0))
		b[i] += (sin(TAU * 41.2 * t) * 0.15 + sin(TAU * 58.27 * t) * 0.06
			+ sin(TAU * 82.41 * t) * 0.05) * sw

	# Ritual taiko — huge, slow, sparse.
	for bi in bars:
		var t0 := bi * bar
		_tone(b, t0, 0.5, 110, 32, 1.0)
		_burst(b, t0, 0.35, 0.3, 0.18, 0.03)
		if bi % 2 == 1:
			_tone(b, t0 + 2.5 * spb, 0.4, 95, 30, 0.7)
		if bi % 4 == 3:
			_tone(b, t0 + 3.5 * spb, 0.35, 120, 35, 0.85)
			_tone(b, t0 + 3.75 * spb, 0.3, 110, 33, 0.6)

	# Tolling bells — E phrygian (E F G Bb), long decays, from bar 4.
	var bells := [
		[4.0, 164.81], [5.5, 174.61], [7.0, 164.81], [8.0, 233.08],
		[9.5, 196.0], [11.0, 174.61], [12.5, 164.81], [14.0, 155.56],
	]
	for bell in bells:
		var t: float = bell[0] * bar
		var f: float = bell[1]
		_tone(b, t, 2.8, f, f, 0.28, 0, 0.0, 0.01)
		_tone(b, t, 2.2, f * 2.76, f * 2.76, 0.05, 0, 0.0, 0.01)  # bell partial

	# Distant choir swell across the back half — detuned cluster, barely there.
	var choir_start := 8.0 * bar
	for i in range(int(choir_start * SR), int(len * SR)):
		var t := float(i) / SR
		var p := (t - choir_start) / (len - choir_start)
		var env := pow(sin(PI * p), 1.6) * 0.05
		b[i] += (sin(TAU * 219.0 * t) + sin(TAU * 221.5 * t)
			+ sin(TAU * 329.6 * t) * 0.6 + sin(TAU * 466.2 * t) * 0.3) * env

	b.resize(int(len * SR))
	_save("music", _loopify(b, 0.05))


func _music_old_hunt() -> void:
	# (Kept for reference — the brighter 95 BPM hunt loop from earlier builds.)
	var spb := 60.0 / 95.0            # seconds per beat
	var bar := spb * 4.0
	var bars := 24
	var len := bar * bars
	var b := _buf(len + 0.1)

	# Drone bed — E2 + B2 with a slow swell (period divides the loop → seamless).
	var swell := len / 6.0
	for i in int(len * SR):
		var t := float(i) / SR
		var sw := 0.75 + 0.25 * sin(TAU * t / swell)
		b[i] += (sin(TAU * 82.41 * t) * 0.1 + sin(TAU * 123.47 * t) * 0.06) * sw

	# Drums — tribal kicks and toms; section B doubles the shaker and adds rims.
	for bi in bars:
		var t0 := bi * bar
		var section_b := bi >= 16
		_tone(b, t0, 0.24, 160, 45, 1.0)                    # kick on 1
		_tone(b, t0 + 2.0 * spb, 0.24, 160, 45, 0.9)        # kick on 3
		_tone(b, t0 + 1.0 * spb, 0.2, 190, 115, 0.55)       # tom hi
		_tone(b, t0 + 3.0 * spb, 0.2, 145, 90, 0.6)         # tom lo
		if section_b:
			_tone(b, t0 + 1.5 * spb, 0.15, 210, 140, 0.45)  # extra syncopation
			_tone(b, t0 + 3.5 * spb, 0.15, 165, 100, 0.5)
		if bi % 4 == 3:
			_tone(b, t0 + 3.5 * spb, 0.18, 200, 120, 0.6)   # fill
		var shaker_steps := 16 if section_b else 8
		for k in shaker_steps:
			var step := spb * (4.0 / shaker_steps)
			var amp := 0.15 if k % 2 == 1 else 0.08
			_burst(b, t0 + k * step, 0.045, amp, 0.85, 0.5)
		if section_b and bi % 2 == 1:
			_tone(b, t0 + 2.5 * spb, 0.05, 1900, 1700, 0.18)  # rim click

	# Bass pulse from bar 4 — eighth notes on the bar's root.
	var roots := [82.41, 82.41, 82.41, 82.41, 98.0, 98.0, 110.0, 110.0,
		82.41, 82.41, 98.0, 98.0, 73.42, 110.0, 82.41, 82.41,
		82.41, 82.41, 98.0, 110.0, 73.42, 73.42, 82.41, 82.41]
	for bi in range(4, bars):
		var t0 := bi * bar
		var f: float = roots[bi]
		for k in 8:
			var amp := 0.5 if k % 4 == 0 else 0.32
			_tone(b, t0 + k * spb * 0.5, spb * 0.42, f, f, amp, 3)
			_tone(b, t0 + k * spb * 0.5, spb * 0.42, f * 0.5, f * 0.5, amp * 0.6)

	# Melody — sparse bone-flute phrases (E minor pentatonic).
	const E4 := 329.63
	const G4 := 392.0
	const A4 := 440.0
	const B4 := 493.88
	const D5 := 587.33
	const E5 := 659.26
	const G5 := 783.99
	const A5 := 880.0
	# Phrase A: bars 8-15 (beats relative to bar 8).
	var phrase_a := [
		[0.0, E4, 1.5], [2.0, G4, 1.0], [3.0, A4, 1.0], [4.0, B4, 2.0],
		[6.5, A4, 0.5], [7.0, G4, 1.0], [8.0, E4, 2.0], [10.0, A4, 1.5],
		[12.0, B4, 1.0], [13.5, D5, 1.5], [15.0, B4, 1.0], [16.0, E5, 2.0],
		[18.0, D5, 1.0], [19.0, B4, 1.0], [20.0, A4, 2.0], [22.0, G4, 1.0],
		[23.0, A4, 1.0], [24.0, E4, 1.5], [26.0, G4, 1.0], [27.0, A4, 1.0],
		[28.0, E4, 3.0],
	]
	# Phrase B: bars 16-23 — higher, more urgent (the hunt closes in).
	var phrase_b := [
		[0.0, E5, 1.0], [1.0, D5, 0.5], [1.5, B4, 0.5], [2.0, D5, 1.0],
		[3.0, E5, 1.0], [4.0, G5, 1.5], [5.5, E5, 0.5], [6.0, D5, 1.0],
		[7.0, B4, 1.0], [8.0, A5, 1.5], [10.0, G5, 1.0], [11.0, E5, 1.0],
		[12.0, D5, 1.5], [13.5, B4, 0.5], [14.0, D5, 1.0], [15.0, E5, 1.0],
		[16.0, G5, 2.0], [18.0, E5, 1.0], [19.0, D5, 1.0], [20.0, B4, 2.0],
		[22.0, A4, 1.0], [23.0, B4, 1.0], [24.0, E5, 1.5], [26.0, D5, 1.0],
		[27.0, B4, 1.0], [28.0, A4, 1.5], [30.0, G4, 1.0], [31.0, E4, 1.0],
	]
	for note in phrase_a:
		var t: float = 8.0 * bar + note[0] * spb
		var dur: float = note[2] * spb * 0.95
		var freq: float = note[1]
		_tone(b, t, dur, freq, freq, 0.3, 0, 0.12, 0.03)
		_tone(b, t, dur, freq * 2.0, freq * 2.0, 0.07, 0, 0.12, 0.03)
	for note in phrase_b:
		var t: float = 16.0 * bar + note[0] * spb
		var dur: float = note[2] * spb * 0.95
		var freq: float = note[1]
		_tone(b, t, dur, freq, freq, 0.26, 0, 0.14, 0.03)
		_tone(b, t, dur, freq * 0.5, freq * 0.5, 0.08, 0, 0.14, 0.03)

	b.resize(int(len * SR))
	_save("music", _loopify(b, 0.04))
