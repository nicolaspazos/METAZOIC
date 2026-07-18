extends SceneTree
## Procedurally generates all of METAZOIC's PS2-style textures (128x128 PNGs,
## quantized to a 16-level palette per channel). Deterministic — fixed seeds.
##
## Run from the repo root:
##   godot --headless --path . -s tools/asset_gen/generate_textures.gd
##
## Output goes to assets/textures/. Textures tile seamlessly (4-corner blend).

const S := 128
const OUT := "res://assets/textures/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 1337
	DirAccess.make_dir_recursive_absolute(OUT)
	_grass()
	_dirt()
	_rock()
	_bark()
	_leaves()
	_fern()
	_skin()
	_fur()
	_scales()
	_crystal()
	_face()
	_water()
	_cloud()
	_sun()
	print("[gen] all textures written to assets/textures/")
	quit(0)


# ---------------------------------------------------------------- helpers

func _noise(seed_: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Seamlessly tiling noise in -1..1 (blends 4 shifted samples across the tile).
func _tiled(n: FastNoiseLite, x: int, y: int) -> float:
	var u := float(x) / S
	var v := float(y) / S
	var a := n.get_noise_2d(x, y)
	var b := n.get_noise_2d(x - S, y)
	var c := n.get_noise_2d(x, y - S)
	var d := n.get_noise_2d(x - S, y - S)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _t01(n: FastNoiseLite, x: int, y: int) -> float:
	return _tiled(n, x, y) * 0.5 + 0.5


## Quantize to 16 levels/channel — the PS2 palette feel. Alpha becomes hard 0/1.
func _q(c: Color) -> Color:
	return Color(
		floorf(c.r * 15.0 + 0.5) / 15.0,
		floorf(c.g * 15.0 + 0.5) / 15.0,
		floorf(c.b * 15.0 + 0.5) / 15.0,
		1.0 if c.a > 0.5 else 0.0)


func _paint(name: String, fn: Callable) -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			img.set_pixel(x, y, _q(fn.call(x, y)))
	img.save_png(OUT + name + ".png")
	print("  wrote ", name, ".png")


# ---------------------------------------------------------------- textures

func _grass() -> void:
	var base := _noise(10, 0.05, 3)
	var patch := _noise(11, 0.025, 2)
	var speck := _noise(12, 0.35, 1)
	_paint("grass", func(x, y):
		var c := Color(0.23, 0.34, 0.13).lerp(Color(0.37, 0.48, 0.18), _t01(base, x, y))
		if _tiled(patch, x, y) > 0.25:
			c *= 0.8
		if _tiled(speck, x, y) > 0.62:
			c *= 1.2
		return c)


func _dirt() -> void:
	var base := _noise(20, 0.06, 3)
	var pebble := _noise(21, 0.3, 1)
	_paint("dirt", func(x, y):
		var c := Color(0.3, 0.21, 0.12).lerp(Color(0.46, 0.34, 0.2), _t01(base, x, y))
		if _tiled(pebble, x, y) > 0.55:
			c *= 1.22
		return c)


func _rock() -> void:
	var base := _noise(30, 0.045, 4)
	var crack := _noise(31, 0.08, 2)
	_paint("rock", func(x, y):
		var c := Color(0.33, 0.32, 0.3).lerp(Color(0.56, 0.54, 0.52), _t01(base, x, y))
		if 1.0 - absf(_tiled(crack, x, y)) > 0.9:
			c *= 0.55
		return c)


func _bark() -> void:
	var wob := _noise(40, 0.06, 2)
	var grain := _noise(41, 0.2, 2)
	_paint("bark", func(x, y):
		# Vertical bands (tile in x for cylinder wrap), wobbled by noise.
		var band := 0.5 + 0.5 * sin(TAU * (float(x) / S * 6.0 + _tiled(wob, x, y) * 0.7))
		var c := Color(0.24, 0.15, 0.08).lerp(Color(0.42, 0.28, 0.15), band)
		c *= 0.9 + 0.2 * _t01(grain, x, y)
		return c)


func _leaves() -> void:
	var clump := _noise(50, 0.07, 3)
	var hole := _noise(51, 0.18, 2)
	_paint("leaves", func(x, y):
		var c := Color(0.09, 0.24, 0.1).lerp(Color(0.24, 0.42, 0.14), _t01(clump, x, y))
		if _tiled(hole, x, y) > 0.45:
			c *= 0.55
		return c)


## Fan of tapered blades with hard alpha — used on crossed foliage quads.
func _fern() -> void:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blades := 14
	for b in blades:
		var spread := lerpf(-1.15, 1.15, float(b) / float(blades - 1))
		var length := rng.randf_range(48.0, 60.0)
		var cx := S * 0.5
		var cy := S - 4.0
		for st in 110:
			var t := float(st) / 109.0
			var px := cx + sin(spread) * length * t + signf(sin(spread)) * 9.0 * t * t
			var py := cy - cos(spread) * length * t
			var w := lerpf(3.0, 0.6, t)
			var col := Color(0.14, 0.3, 0.1).lerp(Color(0.3, 0.5, 0.18), t)
			var wi := int(ceilf(w))
			for dx in range(-wi, wi + 1):
				for dy in range(-wi, wi + 1):
					if dx * dx + dy * dy <= w * w:
						var ix := int(px) + dx
						var iy := int(py) + dy
						if ix >= 0 and ix < S and iy >= 0 and iy < S:
							img.set_pixel(ix, iy, _q(Color(col.r, col.g, col.b, 1.0)))
	img.save_png(OUT + "fern.png")
	print("  wrote fern.png")


func _skin() -> void:
	var base := _noise(60, 0.08, 3)
	var blotch := _noise(61, 0.04, 2)
	_paint("skin", func(x, y):
		var c := Color(0.72, 0.49, 0.33).lerp(Color(0.82, 0.58, 0.4), _t01(base, x, y))
		if _tiled(blotch, x, y) > 0.4:
			c = c.lerp(Color(0.62, 0.38, 0.26), 0.35)
		return c)


func _fur() -> void:
	var streak := _noise(70, 0.05, 2)
	_paint("fur", func(x, y):
		# Vertically stretched streaks read as hair strands.
		var v := streak.get_noise_2d(x * 3.0, y * 0.6) * 0.5 + 0.5
		var u := float(x) / S
		v = lerpf(v, streak.get_noise_2d((x - S) * 3.0, y * 0.6) * 0.5 + 0.5, u)
		return Color(0.24, 0.15, 0.08).lerp(Color(0.42, 0.28, 0.14), v))


func _scales() -> void:
	var bump := _noise(80, 0.22, 2)
	var stripe := _noise(81, 0.03, 2)
	_paint("scales", func(x, y):
		var c := Color(0.2, 0.4, 0.15) * (0.85 + 0.35 * _t01(bump, x, y))
		# Broken vertical striping — classic movie-raptor markings.
		var s := 0.5 + 0.5 * sin(TAU * (float(x) / S * 3.0)) + _tiled(stripe, x, y) * 0.9
		if s > 1.05:
			c *= 0.55
		return c)


## The caveman's face, painted PS2-style onto a quad: heavy brow, eyes, nostrils,
## mouth, stubble. 64x64 so the features stay chunky.
func _face() -> void:
	var fs := 64
	var img := Image.create(fs, fs, false, Image.FORMAT_RGBA8)
	var n := _noise(65, 0.15, 2)
	for y in fs:
		for x in fs:
			var c := Color(0.74, 0.5, 0.34) * (0.94 + 0.12 * (n.get_noise_2d(x, y) * 0.5 + 0.5))
			# Heavy brow shadow band.
			if y >= 10 and y <= 19:
				c *= 0.55
			# Eye whites (two ovals under the brow).
			var in_left := x >= 15 and x <= 26 and y >= 21 and y <= 28
			var in_right := x >= 37 and x <= 48 and y >= 21 and y <= 28
			if in_left or in_right:
				c = Color(0.85, 0.82, 0.72)
				# Pupils.
				if (absi(x - 21) <= 1 or absi(x - 42) <= 1) and y >= 23 and y <= 27:
					c = Color(0.1, 0.07, 0.05)
			# Nose shadow + nostrils.
			if y >= 34 and y <= 38 and absi(x - 32) <= 3:
				c *= 0.8
			if y >= 37 and y <= 39 and (absi(x - 29) <= 1 or absi(x - 35) <= 1):
				c = Color(0.25, 0.15, 0.1)
			# Mouth line.
			if y >= 46 and y <= 48 and x >= 21 and x <= 43:
				c = Color(0.3, 0.16, 0.12)
			# Stubble.
			if y >= 50 and n.get_noise_2d(x * 4, y * 4) > 0.15:
				c *= 0.7
			img.set_pixel(x, y, _q(c))
	img.save_png(OUT + "face.png")
	print("  wrote face.png")


func _water() -> void:
	var wave := _noise(100, 0.06, 3)
	var glint := _noise(101, 0.2, 1)
	_paint("water", func(x, y):
		var c := Color(0.1, 0.28, 0.3).lerp(Color(0.16, 0.4, 0.42), _t01(wave, x, y))
		# Bright caustic ripple lines.
		var v := sin(TAU * (float(y) / S * 4.0 + _tiled(wave, x, y) * 1.2))
		if v > 0.82:
			c = c.lerp(Color(0.55, 0.8, 0.75), 0.7)
		if _tiled(glint, x, y) > 0.62:
			c *= 1.2
		return c)


## Soft-alpha cloud blob for billboard quads (alpha stays smooth — no hard cut).
func _cloud() -> void:
	var cs := 64
	var img := Image.create(cs, cs, false, Image.FORMAT_RGBA8)
	var n := _noise(110, 0.08, 3)
	for y in cs:
		for x in cs:
			var dx := (x - cs / 2.0) / (cs / 2.0)
			var dy := (y - cs / 2.0) / (cs / 2.0) * 1.8  # squashed ellipse
			var falloff := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			var a := clampf(falloff * 1.6 * (0.55 + 0.45 * (n.get_noise_2d(x * 2, y * 2) * 0.5 + 0.5)) - 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.98, 0.9, 0.85, a))
	img.save_png(OUT + "cloud.png")
	print("  wrote cloud.png")


## Soft radial glow for the sun billboard.
func _sun() -> void:
	var ss := 64
	var img := Image.create(ss, ss, false, Image.FORMAT_RGBA8)
	for y in ss:
		for x in ss:
			var dx := (x - ss / 2.0) / (ss / 2.0)
			var dy := (y - ss / 2.0) / (ss / 2.0)
			var d := sqrt(dx * dx + dy * dy)
			var core := clampf(1.0 - d * 3.2, 0.0, 1.0)
			var halo := clampf(1.0 - d, 0.0, 1.0)
			var a := clampf(core + halo * halo * 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 0.9, 0.7, a))
	img.save_png(OUT + "sun.png")
	print("  wrote sun.png")


func _crystal() -> void:
	var vein := _noise(90, 0.06, 3)
	var star := _noise(91, 0.4, 1)
	_paint("crystal", func(x, y):
		var c := Color(0.03, 0.09, 0.05)
		var v := 1.0 - absf(_tiled(vein, x, y))
		if v > 0.82:
			c = c.lerp(Color(0.35, 1.0, 0.5), (v - 0.82) / 0.18)
		if _tiled(star, x, y) > 0.68:
			c = c.lerp(Color(0.6, 1.0, 0.7), 0.6)
		return c)
