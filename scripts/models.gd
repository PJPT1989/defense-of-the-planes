class_name Models
extends RefCounted
## Every hero tower and every Phyrexian, modelled in code with MeshKit. Models face -Z.
##
## tower(id, level) returns {base: Mesh, figure: Mesh, arm: Mesh, arm_pivot, fig_y, orbit: Mesh or
## null, muzzle} : the base stands on the pad, the figure turns towards its target and the arm
## (pivoting at the shoulder) swings when it attacks. orbit spins slowly around the figure.
## enemy(kind) returns {body: Mesh, limbs: [{mesh, pivot, kind}], fly}: limbs are legs ("leg",
## swing about X), wings ("wing", flap about Z) and the like, animated by Enemy.

const PORCELAIN := Color(0.93, 0.91, 0.86)
const PORCELAIN_SHADE := Color(0.78, 0.76, 0.72)
const SINEW := Color(0.42, 0.06, 0.07)
const SINEW_DARK := Color(0.24, 0.03, 0.04)
const STEEL := Color(0.13, 0.13, 0.15)
const OIL := Color(0.025, 0.025, 0.03)
const CHROME := Color(0.6, 0.62, 0.66)
const EYE := Color(1.0, 0.95, 0.85)
const RED_GLOW := Color(1.0, 0.18, 0.12)
const GOLD := Color(0.86, 0.66, 0.26)
const SILVER := Color(0.78, 0.8, 0.85)
const MARBLE := Color(0.88, 0.86, 0.82)
const COPPER := Color(0.72, 0.4, 0.2)
const BRASS := Color(0.8, 0.62, 0.3)

static var _towers := {}
static var _enemies := {}


# --- shared shapes ----------------------------------------------------------------------

## A ring of points around centre c (an ellipse rx by rz), for lofting.
static func _ring(c: Vector3, rx: float, rz: float, n := 12, wob := 0.0, seed := 0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n:
		var a := TAU * k / n
		var w := 1.0 + (sin(a * 3.0 + seed) * 0.5 + sin(a * 5.0 + seed * 2.0) * 0.5) * wob
		out.append(c + Vector3(cos(a) * rx * w, 0.0, sin(a) * rz * w))
	return out


## Smooth body of revolution: profile is [[y, rx, rz, dz], ...] from bottom to top.
static func _body(mk: MeshKit, profile: Array, col: Variant, n := 12, x := 0.0) -> void:
	var rows := []
	for p in profile:
		rows.append(_ring(Vector3(x, p[0], p[3] if p.size() > 3 else 0.0), p[1], p[2], n))
	mk.loft(rows, col)


## Horizontal body (for beasts): profile is [[z, rx, ry, dy], ...] from back (+z) to front (-z).
static func _hbody(mk: MeshKit, profile: Array, y: float, col: Variant, n := 12) -> void:
	var rows := []
	for p in profile:
		var row := PackedVector3Array()
		for k in n:
			var a := TAU * k / n
			row.append(Vector3(cos(a) * p[1], y + (p[3] if p.size() > 3 else 0.0) + sin(a) * p[2], p[0]))
		rows.append(row)
	mk.loft(rows, col)


## A cloth sheet hanging from a line of points, swept along `drop`, flaring out by `flare` at the
## hem and folded in soft waves. Drawn from both sides.
static func _cloth(mk: MeshKit, top: Array, drop: Vector3, flare: float, col: Color, rows := 6) -> void:
	var cols := 9
	var line: Array[Vector3] = []
	for i in cols:
		var u := float(i) / (cols - 1) * (top.size() - 1)
		var k := mini(int(u), top.size() - 2)
		line.append((top[k] as Vector3).lerp(top[k + 1], u - k))
	var across: Vector3 = (line[cols - 1] - line[0]).normalized()
	var fold := drop.normalized().cross(across).normalized()
	var grid := []
	for r in rows:
		var t := float(r) / (rows - 1)
		var row: Array[Vector3] = []
		for i in cols:
			var side := (float(i) / (cols - 1) - 0.5) * 2.0
			var wave := sin(i * 1.9 + t * 1.3) * (0.015 + 0.05 * t)
			row.append(line[i] + drop * t + across * side * flare * t + fold * wave)
		grid.append(row)
	for r in rows - 1:
		for i in cols - 1:
			var a: Vector3 = grid[r][i]
			var b: Vector3 = grid[r][i + 1]
			var c: Vector3 = grid[r + 1][i + 1]
			var d: Vector3 = grid[r + 1][i]
			var shade := col.darkened(0.1 * float(r) / rows + (0.12 if i % 2 else 0.0))
			mk.quad(a, b, c, d, shade)
			mk.quad(a, d, c, b, shade.darkened(0.3))


## Octahedron stretched along y (hedrons, crystals, spear heads).
static func _gem(mk: MeshKit, c: Vector3, r: float, h: float, col: Color, glow := false, yaw := 0.0) -> void:
	var top := c + Vector3(0, h, 0)
	var bot := c - Vector3(0, h, 0)
	var pts: Array[Vector3] = []
	for k in 4:
		var a := yaw + TAU * k / 4.0
		pts.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
	for k in 4:
		var n := (k + 1) % 4
		mk.tri(top, pts[n], pts[k], col, glow)
		mk.tri(bot, pts[k], pts[n], col.darkened(0.2), glow)


## Hedron: a long eight-sided stone with glowing seams.
static func _hedron(mk: MeshKit, c: Vector3, r: float, h: float, yaw: float, stone: Color, line: Color) -> void:
	mk.cyl(c - Vector3(0, h * 0.5, 0), c + Vector3(0, h * 0.5, 0), r, r, stone, 8, false, false, false)
	mk.cyl(c + Vector3(0, h * 0.5, 0), c + Vector3(0, h * 0.5 + r * 1.3, 0), r, 0.0, stone.lightened(0.05), 8, false, false, false)
	mk.cyl(c - Vector3(0, h * 0.5, 0), c - Vector3(0, h * 0.5 + r * 1.3, 0), r, 0.0, stone.darkened(0.1), 8, false, false, false)
	for k in 4:
		var a := yaw + TAU * k / 4.0 + 0.39
		var d := Vector3(cos(a), 0, sin(a)) * (r * 0.93)
		mk.box(c + d * 1.02, Vector3(0.025, h * 0.9, 0.025), line, true, -a)


static func _head(mk: MeshKit, c: Vector3, r: float, skin: Color) -> void:
	mk.sphere(c, Vector3(r * 0.9, r * 1.05, r * 0.95), skin, 12, 8)
	# nose and brow give the face a direction even from above
	mk.sphere(c + Vector3(0, -r * 0.05, -r * 0.88), Vector3(r * 0.16, r * 0.22, r * 0.18), skin.darkened(0.05), 6, 4)
	mk.box(c + Vector3(0, r * 0.22, -r * 0.78), Vector3(r * 1.1, r * 0.14, r * 0.25), skin.darkened(0.15))


static func _legs(mk: MeshKit, hip: float, spread: float, thick: float, col: Color, boot: Color) -> void:
	for s in [-1.0, 1.0]:
		mk.cyl(Vector3(s * spread, hip, 0), Vector3(s * spread * 0.9, hip * 0.5, -0.01), thick, thick * 0.8, col, 8)
		mk.cyl(Vector3(s * spread * 0.9, hip * 0.5, -0.01), Vector3(s * spread * 0.85, 0.06, 0), thick * 0.82, thick * 0.9, boot, 8)
		mk.box(Vector3(s * spread * 0.85, 0.04, -0.05), Vector3(thick * 1.8, 0.08, thick * 3.0), boot.darkened(0.2))


## An arm in its own pivot space: shoulder at the origin, hanging down and slightly forward.
static func _arm(mk: MeshKit, len: float, thick: float, sleeve: Color, hand: Color) -> Vector3:
	var elbow := Vector3(0, -len * 0.48, -0.03)
	var wrist := Vector3(0, -len * 0.82, -len * 0.25)
	mk.sphere(Vector3.ZERO, Vector3(thick * 1.25, thick * 1.25, thick * 1.25), sleeve, 8, 5)
	mk.cyl(Vector3.ZERO, elbow, thick, thick * 0.85, sleeve, 8)
	mk.cyl(elbow, wrist, thick * 0.85, thick * 0.7, sleeve.darkened(0.08), 8)
	mk.sphere(wrist + Vector3(0, -0.03, -0.02), Vector3(thick * 0.9, thick, thick * 0.9), hand, 8, 5)
	return wrist + Vector3(0, -0.04, -0.03)


static func _flame(mk: MeshKit, c: Vector3, s: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf() * 0.4
		var r := s * rng.randf_range(0.2, 0.5)
		var b := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var tip := b + Vector3(cos(a) * s * 0.2, s * rng.randf_range(0.9, 1.6), sin(a) * s * 0.2)
		var col := Color(1.0, 0.35 + rng.randf() * 0.35, 0.08)
		mk.cyl(b, tip, s * 0.22, 0.0, col, 5, true)
	mk.cyl(c, c + Vector3(0, s * 1.9, 0), s * 0.18, 0.0, Color(1.0, 0.9, 0.5), 5, true)


static func _banner(mk: MeshKit, at: Vector3, out: Vector3, h: float, cloth: Color, mark: Color) -> void:
	# a pole sticking out of the wall with a hanging cloth and a glowing emblem
	mk.cyl(at, at + out * 0.25, 0.02, 0.02, GOLD, 5)
	var side := Vector3(out.z, 0, -out.x) * 0.16
	var top := at + out * 0.2
	_cloth(mk, [top - side, top, top + side], Vector3(0, -h, 0) + out * 0.04, 0.0, cloth, 4)
	mk.sphere(top + Vector3(0, -h * 0.4, 0) + out * 0.03, Vector3(0.07, 0.07, 0.07), mark, 6, 4, true)


static func _crenels(mk: MeshKit, y: float, r: float, n: int, col: Color, s := 0.16) -> void:
	for k in n:
		var a := TAU * (k + 0.5) / n
		mk.box(Vector3(cos(a) * r, y + s * 0.5, sin(a) * r), Vector3(s, s, s * 0.8), col, false, -a)


# --- hero towers -------------------------------------------------------------------------

static func tower(id: String, level: int) -> Dictionary:
	var key := "%s%d" % [id, level]
	if not _towers.has(key):
		var d: Dictionary
		match id:
			"champion": d = _t_champion(level)
			"ember": d = _t_ember(level)
			"sage": d = _t_sage(level)
			"ninja": d = _t_ninja(level)
			"litho": d = _t_litho(level)
			"dragon": d = _t_dragon(level)
			"ghost": d = _t_ghost(level)
			_: d = _t_grove(level)
		_towers[key] = d
	return _towers[key]


static func _t_champion(lv: int) -> Dictionary:
	# base: white marble keep with gold bands, sun banners and battlements
	var b := MeshKit.new()
	var h := 0.9 + lv * 0.18
	b.cyl(Vector3.ZERO, Vector3(0, 0.18, 0), 0.95, 0.92, MARBLE.darkened(0.2), 8, false, false)
	b.cyl(Vector3(0, 0.18, 0), Vector3(0, h, 0), 0.82, 0.72, MARBLE, 8, false, false)
	b.cyl(Vector3(0, h, 0), Vector3(0, h + 0.1, 0), 0.82, 0.82, MARBLE.lightened(0.05), 8, false)
	b.ring(Vector3(0, h * 0.55, 0), Vector3.UP, 0.79, 0.035, GOLD, 16, 4)
	_crenels(b, h + 0.1, 0.74, 8, MARBLE)
	b.box(Vector3(0, 0.35, -0.78), Vector3(0.32, 0.5, 0.1), Color(0.18, 0.13, 0.1))
	b.cyl(Vector3(0, 0.6, -0.78), Vector3(0, 0.6, -0.84), 0.16, 0.16, Color(0.18, 0.13, 0.1), 8)
	for a in [PI * 0.5, PI * 1.5] if lv < 2 else [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var d := Vector3(cos(a), 0, sin(a))
		_banner(b, d * 0.75 + Vector3(0, h - 0.05, 0), d, 0.5 + lv * 0.06, Color(0.95, 0.94, 0.9), Color(1.0, 0.8, 0.3))
	if lv >= 1:
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			b.ring(Vector3(cos(a) * 0.8, h * 0.8, sin(a) * 0.8), Vector3(cos(a), 0, sin(a)), 0.12, 0.025, GOLD, 12, 4)
			b.sphere(Vector3(cos(a) * 0.81, h * 0.8, sin(a) * 0.81), Vector3(0.06, 0.06, 0.06), Color(1.0, 0.85, 0.4), 6, 4, true)
	# figure: silver plate armour, white cape, sun shield
	var f := MeshKit.new()
	f.gloss = true
	_legs(f, 0.5, 0.09, 0.07, SILVER, SILVER.darkened(0.2))
	_body(f, [[0.44, 0.17, 0.13], [0.55, 0.19, 0.14], [0.72, 0.2, 0.15], [0.88, 0.24, 0.16], [0.97, 0.18, 0.13], [1.02, 0.07, 0.07]], SILVER, 14)
	f.gloss = false
	_body(f, [[0.28, 0.2, 0.16], [0.47, 0.17, 0.13]], GOLD.darkened(0.1), 10)
	f.ring(Vector3(0, 0.56, 0), Vector3.UP, 0.19, 0.025, GOLD, 14, 4)
	f.sphere(Vector3(0, 0.8, -0.155), Vector3(0.07, 0.07, 0.02), Color(1.0, 0.85, 0.35), 8, 4, true)
	for s in [-1.0, 1.0]:
		f.gloss = true
		f.sphere(Vector3(s * 0.25, 0.94, 0), Vector3(0.12, 0.09, 0.12), SILVER, 10, 6)
		f.gloss = false
		f.ring(Vector3(s * 0.25, 0.92, 0), Vector3.UP, 0.11, 0.018, GOLD, 12, 4)
	_head(f, Vector3(0, 1.13, 0), 0.115, Color(0.95, 0.78, 0.66))
	# short golden hair
	f.sphere(Vector3(0, 1.18, 0.02), Vector3(0.115, 0.08, 0.115), Color(0.95, 0.8, 0.45), 10, 6)
	f.sphere(Vector3(0, 1.1, 0.07), Vector3(0.1, 0.1, 0.07), Color(0.92, 0.76, 0.4), 8, 5)
	_cloth(f, [Vector3(-0.22, 0.97, 0.12), Vector3(0, 0.99, 0.16), Vector3(0.22, 0.97, 0.12)], Vector3(0, -0.85, 0.22), 0.18, Color(0.96, 0.95, 0.92))
	# left arm with the sun shield
	f.cyl(Vector3(-0.27, 0.92, 0), Vector3(-0.3, 0.68, -0.12), 0.055, 0.05, SILVER, 8)
	f.cyl(Vector3(-0.32, 0.72, -0.24), Vector3(-0.32, 0.72, -0.28), 0.24, 0.24, SILVER.lightened(0.05), 16)
	f.ring(Vector3(-0.32, 0.72, -0.285), Vector3(0, 0, 1), 0.24, 0.025, GOLD, 18, 4)
	f.sphere(Vector3(-0.32, 0.72, -0.29), Vector3(0.09, 0.09, 0.02), Color(1.0, 0.82, 0.3), 10, 4, true)
	for k in 8:
		var a := TAU * k / 8.0
		f.box(Vector3(-0.32 + cos(a) * 0.15, 0.72 + sin(a) * 0.15, -0.29), Vector3(0.03, 0.03, 0.01), Color(1.0, 0.85, 0.4), true)
	# right arm with the spear of light
	var a := MeshKit.new()
	a.gloss = true
	var hand := _arm(a, 0.42, 0.055, SILVER, SILVER.darkened(0.1))
	a.gloss = false
	a.cyl(hand + Vector3(0, -0.35, 0.12), hand + Vector3(0, 0.75, -0.3), 0.022, 0.022, GOLD, 6)
	_gem(a, hand + Vector3(0, 0.86, -0.34), 0.05, 0.14, Color(1.0, 0.92, 0.6), true)
	var orbit: Mesh = null
	if lv >= 2:
		var o := MeshKit.new()
		o.ring(Vector3(0, 1.15, 0.28), Vector3(0, 0, 1), 0.32, 0.02, Color(1.0, 0.85, 0.4), 24, 4, true)
		for k in 12:
			var ang := TAU * k / 12.0
			o.box(Vector3(cos(ang) * 0.42, 1.15 + sin(ang) * 0.42, 0.28), Vector3(0.025, 0.12, 0.01), Color(1.0, 0.8, 0.35), true, 0.0)
		orbit = o.commit()
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.27, 0.93, 0),
		"fig_y": h + 0.1, "orbit": orbit, "orbit_spin": 0.0, "muzzle": Vector3(0.3, 1.5, -0.3)}


static func _t_ember(lv: int) -> Dictionary:
	# base: copper and brass tower of the inventors' city with teal glass and fire braziers
	var b := MeshKit.new()
	var h := 0.85 + lv * 0.18
	b.cyl(Vector3.ZERO, Vector3(0, 0.15, 0), 0.92, 0.9, Color(0.35, 0.25, 0.2), 10, false, false)
	b.gloss = true
	b.cyl(Vector3(0, 0.15, 0), Vector3(0, h, 0), 0.72, 0.62, COPPER, 12)
	b.gloss = false
	for k in 3 + lv:
		b.ring(Vector3(0, 0.25 + k * (h - 0.3) / (2 + lv), 0), Vector3.UP, 0.72 - k * 0.03, 0.03, BRASS, 18, 4)
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		b.box(d * 0.66 + Vector3(0, h * 0.55, 0), Vector3(0.18, h * 0.35, 0.04), Color(0.15, 0.75, 0.7), true, -a + PI * 0.5)
		b.ring(d * 0.69 + Vector3(0, h * 0.55, 0), d, 0.13, 0.015, BRASS, 10, 3)
	b.cyl(Vector3(0, h, 0), Vector3(0, h + 0.08, 0), 0.8, 0.8, BRASS, 16)
	for k in (2 if lv == 0 else 4):
		var a := TAU * k / (2 if lv == 0 else 4) + 0.6
		var p := Vector3(cos(a) * 0.68, h + 0.08, sin(a) * 0.68)
		b.cyl(p, p + Vector3(0, 0.14, 0), 0.07, 0.11, BRASS.darkened(0.2), 8)
		_flame(b, p + Vector3(0, 0.14, 0), 0.12, k * 13 + lv)
	# figure: red jacket, goggles, hair of living flame
	var f := MeshKit.new()
	_legs(f, 0.5, 0.085, 0.06, Color(0.22, 0.16, 0.14), Color(0.35, 0.2, 0.12))
	_body(f, [[0.45, 0.16, 0.12], [0.6, 0.17, 0.12], [0.78, 0.19, 0.13], [0.92, 0.21, 0.14], [1.0, 0.13, 0.1], [1.03, 0.06, 0.06]], Color(0.78, 0.18, 0.1), 14)
	_body(f, [[0.38, 0.17, 0.14], [0.5, 0.165, 0.13]], Color(0.25, 0.16, 0.12), 12)
	f.ring(Vector3(0, 0.6, 0), Vector3.UP, 0.17, 0.02, BRASS, 14, 4)
	f.box(Vector3(0, 0.8, -0.13), Vector3(0.09, 0.22, 0.02), Color(0.95, 0.75, 0.3))
	_head(f, Vector3(0, 1.14, 0), 0.11, Color(0.96, 0.78, 0.64))
	f.ring(Vector3(0, 1.21, -0.02), Vector3(0, 1, 0.25), 0.105, 0.02, Color(0.3, 0.2, 0.12), 14, 4)
	for s in [-1.0, 1.0]:
		f.cyl(Vector3(s * 0.045, 1.22, -0.1), Vector3(s * 0.045, 1.23, -0.12), 0.035, 0.035, BRASS, 8)
		f.sphere(Vector3(s * 0.045, 1.23, -0.125), Vector3(0.028, 0.028, 0.01), Color(0.4, 0.95, 0.9), 6, 3, true)
	f.sphere(Vector3(0, 1.17, 0.03), Vector3(0.12, 0.09, 0.12), Color(0.85, 0.22, 0.06), 10, 6)
	_flame(f, Vector3(0, 1.2, 0.04), 0.16, 4)
	# left hand on fire too
	f.cyl(Vector3(-0.24, 0.94, 0), Vector3(-0.3, 0.7, -0.08), 0.05, 0.045, Color(0.78, 0.18, 0.1), 8)
	f.sphere(Vector3(-0.31, 0.66, -0.1), Vector3(0.05, 0.05, 0.05), Color(0.96, 0.78, 0.64), 8, 5)
	_flame(f, Vector3(-0.31, 0.68, -0.1), 0.08, 9)
	var a := MeshKit.new()
	var hand := _arm(a, 0.4, 0.05, Color(0.78, 0.18, 0.1), Color(0.96, 0.78, 0.64))
	a.sphere(hand + Vector3(0, -0.02, -0.05), Vector3(0.09, 0.09, 0.09), Color(1.0, 0.55, 0.12), 10, 6, true)
	a.sphere(hand + Vector3(0, -0.02, -0.05), Vector3(0.05, 0.05, 0.05), Color(1.0, 0.95, 0.6), 8, 5, true)
	var orbit: Mesh = null
	if lv >= 2:
		var o := MeshKit.new()
		for k in 10:
			var ang := TAU * k / 10.0
			_flame(o, Vector3(cos(ang) * 0.55, 0.45, sin(ang) * 0.55), 0.09, k)
		o.ring(Vector3(0, 0.45, 0), Vector3.UP, 0.55, 0.02, Color(1.0, 0.5, 0.1), 32, 3, true)
		orbit = o.commit()
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.24, 0.95, 0),
		"fig_y": h + 0.08, "orbit": orbit, "orbit_spin": 1.2, "muzzle": Vector3(0.3, 0.6, -0.3)}


static func _t_sage(lv: int) -> Dictionary:
	# base: sandstone steps with a blue time glyph band and a clock face
	var b := MeshKit.new()
	var sand := Color(0.82, 0.7, 0.5)
	var h := 0.75 + lv * 0.15
	b.cyl(Vector3.ZERO, Vector3(0, 0.2, 0), 0.95, 0.95, sand.darkened(0.15), 12, false)
	b.cyl(Vector3(0, 0.2, 0), Vector3(0, 0.4, 0), 0.82, 0.82, sand.darkened(0.05), 12, false)
	b.cyl(Vector3(0, 0.4, 0), Vector3(0, h, 0), 0.66, 0.62, sand, 12, false)
	b.ring(Vector3(0, h - 0.12, 0), Vector3.UP, 0.645, 0.03, Color(0.35, 0.75, 1.0), 24, 4, true)
	b.cyl(Vector3(0, h, 0), Vector3(0, h + 0.08, 0), 0.74, 0.74, sand.lightened(0.08), 16)
	b.ring(Vector3(0, h * 0.62, -0.66), Vector3(0, 0, 1), 0.2, 0.025, GOLD, 18, 4)
	b.box(Vector3(0, h * 0.62 + 0.07, -0.68), Vector3(0.025, 0.14, 0.01), GOLD)
	b.box(Vector3(0.05, h * 0.62, -0.68), Vector3(0.1, 0.025, 0.01), GOLD)
	for k in 12:
		var a := TAU * k / 12.0
		b.box(Vector3(cos(a) * 0.17, h * 0.62 + sin(a) * 0.17, -0.68), Vector3(0.02, 0.02, 0.01), Color(0.5, 0.85, 1.0), true)
	if lv >= 1:
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			b.rock(Vector3(cos(a) * 1.0, h + 0.3 + k * 0.08, sin(a) * 1.0), Vector3(0.14, 0.1, 0.14), sand, k + 3)
	# figure: long white and blue robes, staff with an hourglass
	var f := MeshKit.new()
	var skin := Color(0.38, 0.24, 0.16)
	_body(f, [[0.0, 0.3, 0.27], [0.3, 0.24, 0.21], [0.6, 0.19, 0.15], [0.8, 0.21, 0.15], [0.95, 0.24, 0.16], [1.02, 0.12, 0.1], [1.05, 0.06, 0.06]], func(t, a, _c, _n): return Color(0.92, 0.92, 0.95) if fmod(a * 8.0, 1.0) > 0.18 or t > 0.6 else Color(0.2, 0.42, 0.75), 16)
	f.ring(Vector3(0, 0.6, 0), Vector3.UP, 0.18, 0.03, Color(0.2, 0.42, 0.75), 14, 4)
	_cloth(f, [Vector3(-0.2, 1.0, -0.12), Vector3(0, 0.96, -0.16), Vector3(0.2, 1.0, -0.12)], Vector3(0, -0.5, -0.02), 0.06, Color(0.2, 0.42, 0.75), 4)
	for s in [-1.0, 1.0]:
		f.sphere(Vector3(s * 0.23, 0.97, 0), Vector3(0.1, 0.08, 0.1), Color(0.2, 0.42, 0.75), 10, 6)
	_head(f, Vector3(0, 1.15, 0), 0.11, skin)
	f.sphere(Vector3(0, 1.2, 0.01), Vector3(0.11, 0.07, 0.11), Color(0.12, 0.1, 0.1), 10, 5)
	f.sphere(Vector3(0, 1.07, -0.07), Vector3(0.07, 0.06, 0.05), Color(0.85, 0.85, 0.85), 8, 5)
	# left hand holds the staff
	f.cyl(Vector3(-0.25, 0.95, 0), Vector3(-0.3, 0.72, -0.1), 0.05, 0.045, Color(0.92, 0.92, 0.95), 8)
	f.cyl(Vector3(-0.32, 0.05, -0.12), Vector3(-0.32, 1.35, -0.12), 0.025, 0.02, Color(0.4, 0.28, 0.16), 6)
	f.ring(Vector3(-0.32, 1.42, -0.12), Vector3(0, 0, 1), 0.08, 0.015, GOLD, 12, 3)
	f.cyl(Vector3(-0.32, 1.36, -0.12), Vector3(-0.32, 1.42, -0.12), 0.045, 0.0, Color(0.5, 0.9, 1.0), 8, true)
	f.cyl(Vector3(-0.32, 1.48, -0.12), Vector3(-0.32, 1.42, -0.12), 0.045, 0.0, Color(0.5, 0.9, 1.0), 8, true)
	var a := MeshKit.new()
	var hand := _arm(a, 0.4, 0.05, Color(0.92, 0.92, 0.95), skin)
	a.sphere(hand + Vector3(0, 0.0, -0.06), Vector3(0.06, 0.06, 0.06), Color(0.45, 0.85, 1.0), 8, 5, true)
	# floating time rings around him
	var o := MeshKit.new()
	for k in 1 + lv:
		var tilt := Vector3(sin(k * 1.3) * 0.5, 1.0, cos(k * 1.7) * 0.4).normalized()
		o.ring(Vector3(0, 0.75, 0), tilt, 0.42 + k * 0.08, 0.012, Color(1.0, 0.82, 0.4), 32, 3, true)
		for m in 4:
			var ang := TAU * m / 4.0
			var side := tilt.cross(Vector3.FORWARD).normalized()
			var fwd := side.cross(tilt)
			o.sphere(Vector3(0, 0.75, 0) + (side * cos(ang) + fwd * sin(ang)) * (0.42 + k * 0.08), Vector3(0.025, 0.025, 0.025), Color(0.5, 0.9, 1.0), 6, 3, true)
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.24, 0.96, 0),
		"fig_y": h + 0.08, "orbit": o.commit(), "orbit_spin": 0.7, "muzzle": Vector3(0, 0.8, 0)}


static func _t_ninja(lv: int) -> Dictionary:
	# base: a dark pagoda with curved roofs and neon trim
	var b := MeshKit.new()
	var wood := Color(0.18, 0.1, 0.1)
	var roof := Color(0.12, 0.12, 0.16)
	var tiers := 2 + mini(lv, 1)
	var y := 0.0
	b.box(Vector3(0, 0.08, 0), Vector3(1.7, 0.16, 1.7), Color(0.3, 0.3, 0.32))
	y = 0.16
	for t in tiers:
		var w := 1.15 - t * 0.18
		var th := 0.42 - t * 0.06
		b.box(Vector3(0, y + th * 0.5, 0), Vector3(w, th, w), wood)
		for s in [-1.0, 1.0]:
			b.box(Vector3(s * w * 0.3, y + th * 0.5, -w * 0.5 - 0.005), Vector3(w * 0.25, th * 0.7, 0.01), Color(1.0, 0.85, 0.6), true)
		y += th
		b.taper(Vector3(0, y, 0), Vector2(w + 0.5, w + 0.5), Vector2(w * 0.5, w * 0.5), 0.18, roof)
		b.box(Vector3(0, y + 0.01, 0), Vector3(w + 0.52, 0.03, w + 0.52), Color(0.95, 0.2, 0.6), true)
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			b.cyl(Vector3(cos(a) * (w + 0.5) * 0.7, y, sin(a) * (w + 0.5) * 0.7), Vector3(cos(a) * (w + 0.5) * 0.78, y + 0.12, sin(a) * (w + 0.5) * 0.78), 0.03, 0.01, roof, 5)
		y += 0.18
	b.box(Vector3(0, y + 0.04, 0), Vector3(0.62, 0.08, 0.62), Color(0.22, 0.2, 0.22))
	for s in [-1.0, 1.0]:
		var p := Vector3(s * 0.72, 0.16, -0.72)
		b.cyl(p, p + Vector3(0, 0.6, 0), 0.025, 0.025, wood, 5)
		b.sphere(p + Vector3(0, 0.66, 0), Vector3(0.08, 0.1, 0.08), Color(0.3, 0.95, 1.0) if s < 0 else Color(1.0, 0.3, 0.7), 8, 5, true)
	# figure: navy suit, mask, white scarf, katana on the back, a little drone
	var f := MeshKit.new()
	var suit := Color(0.12, 0.14, 0.26)
	_legs(f, 0.48, 0.09, 0.06, suit, Color(0.08, 0.08, 0.1))
	_body(f, [[0.44, 0.15, 0.12], [0.6, 0.15, 0.11], [0.78, 0.18, 0.12], [0.92, 0.2, 0.13], [1.0, 0.12, 0.1], [1.03, 0.06, 0.06]], suit, 14)
	f.ring(Vector3(0, 0.58, 0), Vector3.UP, 0.155, 0.02, Color(0.6, 0.12, 0.15), 14, 4)
	_head(f, Vector3(0, 1.12, 0), 0.105, Color(0.85, 0.7, 0.58))
	f.sphere(Vector3(0, 1.12, 0.005), Vector3(0.11, 0.12, 0.11), Color(0.08, 0.08, 0.12), 10, 7)
	f.box(Vector3(0, 1.14, -0.1), Vector3(0.14, 0.03, 0.02), Color(0.85, 0.7, 0.58))
	f.box(Vector3(0, 1.14, -0.105), Vector3(0.12, 0.012, 0.012), Color(0.3, 0.9, 1.0), true)
	_cloth(f, [Vector3(-0.1, 1.0, 0.06), Vector3(0, 1.0, 0.1), Vector3(0.1, 1.0, 0.06)], Vector3(0.12, -0.4, 0.45), 0.02, Color(0.95, 0.95, 0.97), 5)
	f.ring(Vector3(0, 1.0, 0), Vector3.UP, 0.1, 0.035, Color(0.95, 0.95, 0.97), 12, 4)
	f.cyl(Vector3(-0.2, 0.55, 0.16), Vector3(0.22, 1.2, 0.16), 0.02, 0.018, Color(0.05, 0.05, 0.06), 6)
	f.box(Vector3(-0.1, 0.71, 0.16), Vector3(0.1, 0.02, 0.06), GOLD, false, 0.0)
	for s in [-1.0, 1.0]:
		f.sphere(Vector3(s * 0.22, 0.95, 0), Vector3(0.08, 0.07, 0.08), suit.lightened(0.1), 8, 5)
	f.cyl(Vector3(-0.22, 0.94, 0), Vector3(-0.28, 0.7, -0.06), 0.045, 0.04, suit, 8)
	var a := MeshKit.new()
	var hand := _arm(a, 0.4, 0.045, suit, Color(0.08, 0.08, 0.1))
	for k in 4:
		var ang := TAU * k / 4.0
		a.tri(hand + Vector3(0, 0, -0.05), hand + Vector3(cos(ang) * 0.09, sin(ang) * 0.09, -0.05), hand + Vector3(cos(ang + 0.5) * 0.03, sin(ang + 0.5) * 0.03, -0.05), Color(0.75, 0.9, 1.0), true)
		a.tri(hand + Vector3(0, 0, -0.05), hand + Vector3(cos(ang + 0.5) * 0.03, sin(ang + 0.5) * 0.03, -0.05), hand + Vector3(cos(ang) * 0.09, sin(ang) * 0.09, -0.05), Color(0.75, 0.9, 1.0), true)
	var o := MeshKit.new()
	o.gloss = true
	o.sphere(Vector3(0.5, 1.25, 0), Vector3(0.08, 0.065, 0.08), Color(0.85, 0.88, 0.92), 10, 6)
	o.gloss = false
	o.sphere(Vector3(0.5, 1.25, -0.07), Vector3(0.03, 0.03, 0.02), Color(0.3, 0.95, 1.0), 6, 4, true)
	o.ring(Vector3(0.5, 1.25, 0), Vector3.UP, 0.1, 0.012, Color(1.0, 0.35, 0.75), 14, 3, true)
	if lv >= 2:
		o.gloss = true
		o.sphere(Vector3(-0.5, 1.2, 0), Vector3(0.07, 0.055, 0.07), Color(0.85, 0.88, 0.92), 10, 6)
		o.gloss = false
		o.sphere(Vector3(-0.5, 1.2, -0.06), Vector3(0.025, 0.025, 0.02), Color(1.0, 0.35, 0.75), 6, 4, true)
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.22, 0.95, 0),
		"fig_y": y + 0.08, "orbit": o.commit(), "orbit_spin": 1.5, "muzzle": Vector3(0.25, 0.6, -0.3)}


static func _t_litho(lv: int) -> Dictionary:
	# base: three great hedrons standing in a ring, holding up a carved platform
	var b := MeshKit.new()
	var stone := Color(0.55, 0.53, 0.5)
	var line := Color(0.35, 1.0, 0.85)
	var h := 0.85 + lv * 0.16
	b.rock(Vector3(0, 0.0, 0), Vector3(0.95, 0.3, 0.95), Color(0.48, 0.42, 0.36), 11)
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		_hedron(b, Vector3(cos(a) * 0.5, h * 0.48, sin(a) * 0.5), 0.17, h * 0.55, a, stone, line)
	b.cyl(Vector3(0, h, 0), Vector3(0, h + 0.12, 0), 0.72, 0.68, stone.lightened(0.05), 8, false)
	b.ring(Vector3(0, h + 0.06, 0), Vector3.UP, 0.7, 0.02, line, 16, 3, true)
	if lv >= 1:
		for k in 3:
			var a := TAU * k / 3.0 + 1.35
			_hedron(b, Vector3(cos(a) * 0.82, h * 0.35, sin(a) * 0.82), 0.1, h * 0.3, a, stone.darkened(0.05), line)
	# figure: kor stoneshaper, pale grey skin, white hair, bronze and teal armour, a stone blade
	var f := MeshKit.new()
	var skin := Color(0.72, 0.74, 0.78)
	var armour := Color(0.62, 0.48, 0.3)
	_legs(f, 0.5, 0.085, 0.06, Color(0.25, 0.3, 0.32), armour.darkened(0.2))
	_body(f, [[0.32, 0.2, 0.16], [0.45, 0.17, 0.13], [0.6, 0.16, 0.12], [0.78, 0.19, 0.13], [0.92, 0.22, 0.14], [1.0, 0.13, 0.1], [1.03, 0.06, 0.06]], func(t, a, _c, _n): return armour if t > 0.35 else Color(0.2, 0.55, 0.52), 14)
	f.ring(Vector3(0, 0.82, 0), Vector3(0, 1, 0.2), 0.18, 0.02, line, 14, 3, true)
	for s in [-1.0, 1.0]:
		f.gloss = true
		f.sphere(Vector3(s * 0.24, 0.95, 0), Vector3(0.1, 0.08, 0.1), armour, 10, 6)
		f.gloss = false
		_gem(f, Vector3(s * 0.3, 1.02, 0), 0.03, 0.08, line, true)
	_head(f, Vector3(0, 1.14, 0), 0.105, skin)
	for k in 3:
		f.box(Vector3(-0.04 + k * 0.04, 1.2, -0.08), Vector3(0.012, 0.03, 0.01), line, true)
	f.sphere(Vector3(0, 1.17, 0.03), Vector3(0.115, 0.09, 0.115), Color(0.95, 0.95, 0.95), 10, 6)
	_cloth(f, [Vector3(-0.08, 1.15, 0.08), Vector3(0, 1.17, 0.11), Vector3(0.08, 1.15, 0.08)], Vector3(0, -0.45, 0.1), 0.06, Color(0.92, 0.92, 0.94), 5)
	f.cyl(Vector3(-0.25, 0.94, 0), Vector3(-0.3, 0.7, -0.08), 0.048, 0.042, armour, 8)
	f.box(Vector3(-0.31, 0.95, -0.15), Vector3(0.06, 0.6, 0.02), Color(0.7, 0.68, 0.62), false, 0.0)
	f.box(Vector3(-0.31, 0.95, -0.161), Vector3(0.012, 0.55, 0.01), line, true)
	var a := MeshKit.new()
	_arm(a, 0.4, 0.048, armour, skin)
	var o := MeshKit.new()
	for k in 2 + lv:
		var ang := TAU * k / (2 + lv)
		_hedron(o, Vector3(cos(ang) * 0.55, 1.0 + (k % 2) * 0.15, sin(ang) * 0.55), 0.05, 0.14, ang, stone, line)
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.24, 0.96, 0),
		"fig_y": h + 0.12, "orbit": o.commit(), "orbit_spin": 0.9, "muzzle": Vector3(0, 2.0, 0)}


static func _t_dragon(lv: int) -> Dictionary:
	# base: a copper and red spire of the guild of mad inventors, crackling coils on top
	var b := MeshKit.new()
	var red := Color(0.55, 0.1, 0.08)
	var h := 1.0 + lv * 0.18
	b.cyl(Vector3.ZERO, Vector3(0, 0.2, 0), 0.92, 0.88, Color(0.25, 0.2, 0.2), 10, false)
	b.cyl(Vector3(0, 0.2, 0), Vector3(0, h, 0), 0.62, 0.5, red, 10, false)
	b.gloss = true
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		b.cyl(d * 0.66 + Vector3(0, 0.2, 0), d * 0.55 + Vector3(0, h, 0), 0.06, 0.05, COPPER, 8)
	b.gloss = false
	for k in 3:
		b.ring(Vector3(0, 0.35 + k * (h - 0.35) / 3.0, 0), Vector3.UP, 0.62 - k * 0.04, 0.03, COPPER, 16, 4)
	b.cyl(Vector3(0, h, 0), Vector3(0, h + 0.12, 0), 0.75, 0.7, Color(0.3, 0.25, 0.25), 10)
	for k in (2 if lv < 2 else 3):
		var a := TAU * k / (2 if lv < 2 else 3) + 2.0
		var p := Vector3(cos(a) * 0.62, h + 0.12, sin(a) * 0.62)
		for m in 4:
			b.ring(p + Vector3(0, 0.06 + m * 0.07, 0), Vector3.UP, 0.06, 0.015, COPPER, 10, 3)
		b.cyl(p, p + Vector3(0, 0.35, 0), 0.02, 0.02, COPPER, 5)
		b.sphere(p + Vector3(0, 0.4, 0), Vector3(0.07, 0.07, 0.07), Color(0.45, 0.8, 1.0), 8, 5, true)
	# figure: a red dragon perched on the spire, wings half open, blue fire in its ridges
	var f := MeshKit.new()
	var scale_c := Color(0.68, 0.1, 0.07)
	var belly := Color(0.85, 0.55, 0.3)
	_hbody(f, [[0.55, 0.0, 0.0, 0.0], [0.4, 0.14, 0.13, 0.0], [0.15, 0.22, 0.2, 0.02], [-0.1, 0.2, 0.2, 0.06], [-0.25, 0.12, 0.13, 0.15]], 0.38, func(_t, a, _c, _n): return belly if a > 0.6 and a < 0.9 else scale_c, 12)
	# neck and head (the neck is part of the "arm" so it can strike)
	for k in 6:
		var t := k / 5.0
		f.cyl(Vector3(0, 0.38 + t * 0.02, 0.55 + t * 0.35), Vector3(0, 0.38 + (t + 0.2) * 0.02, 0.55 + (t + 0.2) * 0.35), 0.1 * (1.0 - t * 0.8), 0.1 * (1.0 - (t + 0.2) * 0.8), scale_c, 8)
	for k in 7:
		var z := 0.4 - k * 0.12
		f.cyl(Vector3(0, 0.55 + sin(k * 0.6) * 0.02, z), Vector3(0, 0.66, z - 0.04), 0.035, 0.0, Color(0.35, 0.75, 1.0), 4, true)
	for s in [-1.0, 1.0]:
		f.cyl(Vector3(s * 0.15, 0.32, 0.25), Vector3(s * 0.2, 0.08, 0.3), 0.06, 0.04, scale_c, 8)
		f.cyl(Vector3(s * 0.13, 0.32, -0.12), Vector3(s * 0.18, 0.08, -0.2), 0.05, 0.035, scale_c, 8)
		for c in 3:
			f.cyl(Vector3(s * (0.18 + c * 0.03), 0.06, -0.2), Vector3(s * (0.18 + c * 0.05), 0.02, -0.28), 0.015, 0.0, Color(0.9, 0.85, 0.75), 4)
		# wings: a few long finger bones with red membrane between them
		var root := Vector3(s * 0.15, 0.55, 0.05)
		var tips: Array[Vector3] = [root + Vector3(s * 0.9, 0.55, 0.15), root + Vector3(s * 1.0, 0.25, 0.35), root + Vector3(s * 0.8, 0.0, 0.5), root + Vector3(s * 0.4, -0.1, 0.45)]
		var elbow := root + Vector3(s * 0.45, 0.45, 0.0)
		f.cyl(root, elbow, 0.04, 0.03, scale_c, 6)
		for k in tips.size():
			f.cyl(elbow, tips[k], 0.02, 0.008, scale_c.darkened(0.2), 5)
		for k in tips.size() - 1:
			f.tri(elbow, tips[k], tips[k + 1], Color(0.75, 0.2, 0.12))
			f.tri(elbow, tips[k + 1], tips[k], Color(0.55, 0.12, 0.08))
		f.tri(root, elbow, tips[3], Color(0.7, 0.18, 0.1))
		f.tri(root, tips[3], elbow, Color(0.5, 0.1, 0.08))
	# tail curling round the spire top
	var prev := Vector3(0, 0.38, 0.55)
	for k in 10:
		var ang := k * 0.3
		var p := Vector3(sin(ang) * 0.35, 0.3 - k * 0.012, 0.55 + cos(ang) * 0.25 - k * 0.02)
		f.cyl(prev, p, 0.08 * (1.0 - k * 0.09), 0.08 * (1.0 - (k + 1) * 0.09), scale_c, 6)
		prev = p
	var a := MeshKit.new()
	# neck and head in pivot space (pivot at the base of the neck, pointing forward)
	a.cyl(Vector3.ZERO, Vector3(0, 0.25, -0.2), 0.11, 0.08, scale_c, 10)
	a.cyl(Vector3(0, 0.25, -0.2), Vector3(0, 0.35, -0.38), 0.08, 0.075, scale_c, 10)
	a.sphere(Vector3(0, 0.37, -0.45), Vector3(0.09, 0.08, 0.12), scale_c, 10, 6)
	a.taper(Vector3(0, 0.31, -0.5), Vector2(0.11, 0.1), Vector2(0.06, 0.05), 0.07, scale_c, false, 0.0, Vector3(0, -0.01, -0.14))
	a.box(Vector3(0, 0.3, -0.58), Vector3(0.09, 0.03, 0.18), belly)
	for s in [-1.0, 1.0]:
		a.sphere(Vector3(s * 0.05, 0.41, -0.52), Vector3(0.02, 0.015, 0.02), Color(0.4, 0.85, 1.0), 6, 3, true)
		a.cyl(Vector3(s * 0.05, 0.43, -0.4), Vector3(s * 0.12, 0.52, -0.25), 0.025, 0.0, Color(0.95, 0.9, 0.8), 5)
		a.cyl(Vector3(s * 0.07, 0.4, -0.38), Vector3(s * 0.16, 0.42, -0.25), 0.018, 0.0, Color(0.95, 0.9, 0.8), 5)
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0, 0.42, -0.25),
		"fig_y": h + 0.12, "orbit": null, "orbit_spin": 0.0, "muzzle": Vector3(0, 0.75, -0.95)}


static func _t_ghost(lv: int) -> Dictionary:
	# base: black stone shrine with gold trim, spectral candles and a stained glass window
	var b := MeshKit.new()
	var black := Color(0.12, 0.11, 0.13)
	var h := 0.9 + lv * 0.17
	b.taper(Vector3.ZERO, Vector2(1.7, 1.7), Vector2(1.5, 1.5), 0.2, black.lightened(0.05))
	b.taper(Vector3(0, 0.2, 0), Vector2(1.2, 1.2), Vector2(1.02, 1.02), h - 0.2, black)
	b.box(Vector3(0, h + 0.04, 0), Vector3(1.22, 0.08, 1.22), GOLD.darkened(0.15))
	for s in [-1.0, 1.0]:
		for t in [-1.0, 1.0]:
			b.cyl(Vector3(s * 0.56, 0.2, t * 0.56), Vector3(s * 0.52, h, t * 0.52), 0.06, 0.05, GOLD.darkened(0.2), 8)
	b.taper(Vector3(0, h * 0.35, -0.56), Vector2(0.3, 0.02), Vector2(0.02, 0.02), h * 0.5, Color(0.7, 0.4, 1.0), true)
	for k in (4 if lv < 2 else 8):
		var a := TAU * k / (4 if lv < 2 else 8) + PI * 0.25
		var p := Vector3(cos(a) * 0.95, 0.2, sin(a) * 0.95)
		b.cyl(p, p + Vector3(0, 0.15 + (k % 3) * 0.05, 0), 0.03, 0.03, Color(0.9, 0.88, 0.8), 6)
		b.cyl(p + Vector3(0, 0.15 + (k % 3) * 0.05, 0), p + Vector3(0, 0.27 + (k % 3) * 0.05, 0), 0.025, 0.0, Color(0.75, 0.45, 1.0), 5, true)
	# figure: assassin in violet and white, long braids, two ghostly daggers
	var f := MeshKit.new()
	var skin := Color(0.5, 0.32, 0.22)
	var robe := Color(0.35, 0.18, 0.45)
	_legs(f, 0.5, 0.085, 0.058, Color(0.15, 0.12, 0.18), Color(0.12, 0.1, 0.12))
	_body(f, [[0.25, 0.2, 0.15], [0.45, 0.16, 0.12], [0.6, 0.15, 0.11], [0.78, 0.18, 0.12], [0.92, 0.2, 0.13], [1.0, 0.12, 0.1], [1.03, 0.06, 0.06]], func(t, a, _c, _n): return Color(0.92, 0.9, 0.95) if (a > 0.7 and a < 0.8) else robe, 14)
	f.ring(Vector3(0, 0.6, 0), Vector3.UP, 0.155, 0.02, GOLD, 14, 4)
	f.sphere(Vector3(0, 0.82, -0.13), Vector3(0.04, 0.04, 0.015), Color(0.8, 0.5, 1.0), 6, 4, true)
	for s in [-1.0, 1.0]:
		f.sphere(Vector3(s * 0.22, 0.95, 0), Vector3(0.09, 0.07, 0.09), robe.lightened(0.1), 8, 5)
	_head(f, Vector3(0, 1.13, 0), 0.105, skin)
	f.sphere(Vector3(0, 1.17, 0.02), Vector3(0.11, 0.09, 0.11), Color(0.08, 0.06, 0.06), 10, 6)
	for s in [-1.0, 1.0]:
		var prev := Vector3(s * 0.08, 1.12, 0.06)
		for k in 5:
			var p := prev + Vector3(s * 0.01, -0.11, 0.04)
			f.cyl(prev, p, 0.03, 0.026, Color(0.1, 0.07, 0.06), 6)
			prev = p
	f.cyl(Vector3(-0.22, 0.94, 0), Vector3(-0.28, 0.7, -0.08), 0.045, 0.04, robe, 8)
	f.cyl(Vector3(-0.29, 0.68, -0.1), Vector3(-0.29, 0.66, -0.4), 0.03, 0.0, Color(0.8, 0.55, 1.0), 6, true)
	var a := MeshKit.new()
	var hand := _arm(a, 0.4, 0.045, robe, skin)
	a.cyl(hand + Vector3(0, -0.01, -0.02), hand + Vector3(0, -0.02, -0.34), 0.032, 0.0, Color(0.8, 0.55, 1.0), 6, true)
	var o: Mesh = null
	if lv >= 1:
		var om := MeshKit.new()
		for k in lv * 2:
			var ang := TAU * k / (lv * 2)
			var p := Vector3(cos(ang) * 0.5, 0.8, sin(ang) * 0.5)
			om.sphere(p, Vector3(0.06, 0.08, 0.06), Color(0.7, 0.5, 1.0), 8, 5, true)
			om.cyl(p, p + Vector3(0, -0.2, 0), 0.05, 0.0, Color(0.55, 0.35, 0.85), 6, true)
		o = om.commit()
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.22, 0.95, 0),
		"fig_y": h + 0.08, "orbit": o, "orbit_spin": -0.8, "muzzle": Vector3(0.25, 0.6, -0.35)}


static func _t_grove(lv: int) -> Dictionary:
	# base: a mound of roots and mossy stones
	var b := MeshKit.new()
	var bark := Color(0.32, 0.22, 0.15)
	var moss := Color(0.25, 0.42, 0.18)
	b.rock(Vector3(0, -0.05, 0), Vector3(1.0, 0.32, 1.0), moss.darkened(0.2), 21)
	for k in 7:
		var a := TAU * k / 7.0 + 0.2
		var d := Vector3(cos(a), 0, sin(a))
		b.cyl(d * 0.25 + Vector3(0, 0.25, 0), d * 1.0 + Vector3(0, 0.0, 0), 0.12, 0.04, bark, 6)
	for k in 4:
		var a := TAU * k / 4.0 + 0.9
		b.rock(Vector3(cos(a) * 0.85, 0.05, sin(a) * 0.85), Vector3(0.16, 0.12, 0.16), Color(0.55, 0.55, 0.52), k + 40)
	if lv >= 1:
		for k in 5 + lv * 3:
			var a := TAU * k / (5 + lv * 3)
			b.sphere(Vector3(cos(a) * 0.75, 0.2, sin(a) * 0.75), Vector3(0.04, 0.04, 0.04), Color(0.7, 1.0, 0.4), 6, 3, true)
	# figure: a treefolk giant with a dryad on its shoulder
	var f := MeshKit.new()
	var s := 1.0 + lv * 0.08
	_body(f, [[0.0, 0.32 * s, 0.28 * s], [0.25 * s, 0.24 * s, 0.22 * s], [0.6 * s, 0.22 * s, 0.2 * s], [0.95 * s, 0.28 * s, 0.24 * s], [1.15 * s, 0.24 * s, 0.2 * s], [1.3 * s, 0.1 * s, 0.1 * s]], func(t, a, _c, _n): return bark.darkened(0.15 * sin(a * 40.0) * sin(a * 40.0)) if t < 0.9 else moss, 14)
	for k in 5:
		var a := TAU * k / 5.0
		f.cyl(Vector3(cos(a) * 0.2, 0.15, sin(a) * 0.2), Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45), 0.09, 0.03, bark, 6)
	# face: hollow eyes glowing green
	for e in [-1.0, 1.0]:
		f.sphere(Vector3(e * 0.08 * s, 1.0 * s, -0.21 * s), Vector3(0.035, 0.025, 0.02), Color(0.6, 1.0, 0.35), 6, 4, true)
	f.box(Vector3(0, 0.88 * s, -0.22 * s), Vector3(0.14, 0.03, 0.03), Color(0.12, 0.08, 0.05))
	# leafy crown and shoulder canopy
	var leaves := [Vector3(0, 1.38, 0), Vector3(-0.25, 1.28, 0.05), Vector3(0.22, 1.32, 0.08), Vector3(0, 1.3, 0.22), Vector3(-0.1, 1.5, 0.05), Vector3(0.15, 1.48, -0.05)]
	for k in leaves.size():
		f.sphere(leaves[k] * s, Vector3(0.22, 0.17, 0.22) * s, Color(0.2 + k * 0.02, 0.45 + (k % 3) * 0.05, 0.15), 10, 6)
	if lv >= 2:
		for k in 8:
			var ang := TAU * k / 8.0
			f.sphere(Vector3(cos(ang) * 0.3, 1.45, sin(ang) * 0.3) * s, Vector3(0.035, 0.035, 0.035), Color(1.0, 0.6, 0.8), 6, 3, true)
	# left branch arm
	f.cyl(Vector3(-0.28, 1.0, 0) * s, Vector3(-0.5, 0.6, -0.12) * s, 0.09, 0.06, bark, 7)
	for k in 3:
		f.cyl(Vector3(-0.5, 0.6, -0.12) * s, Vector3(-0.55 - k * 0.04, 0.42, -0.2 + k * 0.08) * s, 0.04, 0.0, bark, 5)
	# the dryad on the right shoulder: green skin, leaf hair
	var d := Vector3(0.24, 1.22, 0.1) * s
	f.sphere(d + Vector3(0, 0.12, 0), Vector3(0.06, 0.1, 0.05), Color(0.45, 0.7, 0.35), 8, 5)
	f.sphere(d + Vector3(0, 0.27, 0), Vector3(0.05, 0.055, 0.05), Color(0.55, 0.8, 0.45), 8, 5)
	f.sphere(d + Vector3(0, 0.3, 0.02), Vector3(0.07, 0.05, 0.07), Color(0.95, 0.75, 0.2), 8, 5)
	f.cyl(d + Vector3(0, 0.05, 0), d + Vector3(0.05, -0.08, -0.08), 0.025, 0.02, Color(0.45, 0.7, 0.35), 6)
	var a := MeshKit.new()
	a.cyl(Vector3.ZERO, Vector3(0.1, -0.35, -0.1) * s, 0.1, 0.075, bark, 7)
	a.cyl(Vector3(0.1, -0.35, -0.1) * s, Vector3(0.12, -0.55, -0.3) * s, 0.075, 0.06, bark, 7)
	for k in 4:
		a.cyl(Vector3(0.12, -0.55, -0.3) * s, Vector3(0.08 + k * 0.03, -0.7, -0.4 - (k % 2) * 0.05) * s, 0.04, 0.0, bark.darkened(0.1), 5)
	a.sphere(Vector3(0.12, -0.3, -0.12) * s, Vector3(0.1, 0.07, 0.1), moss, 8, 5)
	return {"base": b.commit(), "figure": f.commit(), "arm": a.commit(), "arm_pivot": Vector3(0.3, 1.0, 0) * s,
		"fig_y": 0.22, "orbit": null, "orbit_spin": 0.0, "muzzle": Vector3(0, 0.3, 0)}


# --- Phyrexians --------------------------------------------------------------------------

static func enemy(kind: String) -> Dictionary:
	if not _enemies.has(kind):
		var d: Dictionary
		match kind:
			"mite": d = _e_mite()
			"husk": d = _e_husk()
			"hound": d = _e_hound()
			"brute": d = _e_brute()
			"drake": d = _e_drake()
			"spitter": d = _e_spitter()
			"knight": d = _e_knight()
			"brood": d = _e_brood()
			"colossus": d = _e_colossus()
			"walker": d = _e_walker()
			_: d = _e_mother()
		_enemies[kind] = d
	return _enemies[kind]


static func _limb(mk: MeshKit, pivot: Vector3, kind := "leg", phase := 0.0, amp := 0.6) -> Dictionary:
	return {"mesh": mk.commit(), "pivot": pivot, "kind": kind, "phase": phase, "amp": amp}


## A thin jointed leg in pivot space: hip at origin, knee out to the side, foot on the ground.
static func _spider_leg(side: float, len: float, h: float, col: Color, joint: Color) -> MeshKit:
	var m := MeshKit.new()
	var knee := Vector3(side * len * 0.55, h * 0.55, 0)
	var foot := Vector3(side * len, -h, 0)
	m.gloss = true
	m.cyl(Vector3.ZERO, knee, 0.035, 0.03, col, 6)
	m.cyl(knee, foot, 0.03, 0.006, col.darkened(0.1), 6)
	m.gloss = false
	m.sphere(knee, Vector3(0.04, 0.04, 0.04), joint, 6, 4)
	return m


## A biped leg in pivot space: hip at origin, digitigrade (knee forward, ankle back).
static func _bi_leg(hip_h: float, thick: float, plate: Color, flesh: Color, claw := true) -> MeshKit:
	var m := MeshKit.new()
	var knee := Vector3(0, -hip_h * 0.45, -0.12 * hip_h)
	var ankle := Vector3(0, -hip_h * 0.82, 0.1 * hip_h)
	var foot := Vector3(0, -hip_h + 0.03, -0.05 * hip_h)
	m.cyl(Vector3.ZERO, knee, thick, thick * 0.8, flesh, 8)
	m.gloss = true
	m.cyl(Vector3(0, -0.02, -thick * 0.6), knee + Vector3(0, 0.02, -thick * 0.7), thick * 0.7, thick * 0.55, plate, 6)
	m.cyl(knee, ankle, thick * 0.75, thick * 0.5, plate, 7)
	m.gloss = false
	m.cyl(ankle, foot, thick * 0.5, thick * 0.35, STEEL, 6)
	if claw:
		for k in 3:
			m.cyl(foot, foot + Vector3((k - 1) * thick * 0.7, -0.02, -thick * 2.2), thick * 0.25, 0.0, STEEL, 4)
	return m


static func _e_mite() -> Dictionary:
	var b := MeshKit.new()
	b.gloss = true
	b.sphere(Vector3(0, 0.22, 0.04), Vector3(0.2, 0.12, 0.24), PORCELAIN, 12, 7)
	b.gloss = false
	b.sphere(Vector3(0, 0.17, 0.04), Vector3(0.18, 0.08, 0.22), SINEW, 10, 5)
	for k in 3:
		b.box(Vector3(0, 0.32, -0.08 + k * 0.1), Vector3(0.22 - k * 0.03, 0.02, 0.04), PORCELAIN_SHADE)
	b.sphere(Vector3(0, 0.2, -0.2), Vector3(0.09, 0.07, 0.08), STEEL, 8, 5)
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.04, 0.22, -0.27), Vector3(0.02, 0.02, 0.02), RED_GLOW, 6, 3, true)
		b.cyl(Vector3(s * 0.04, 0.17, -0.25), Vector3(s * 0.02, 0.12, -0.35), 0.015, 0.0, PORCELAIN, 4)
	var limbs := []
	for k in 3:
		for s in [-1.0, 1.0]:
			var piv := Vector3(s * 0.14, 0.2, -0.1 + k * 0.12)
			limbs.append(_limb(_spider_leg(s, 0.3, 0.2, STEEL, SINEW), piv, "leg", k * 2.1 + (0.0 if s < 0 else PI), 0.5))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_husk() -> Dictionary:
	var b := MeshKit.new()
	var hip := 0.42
	# pelvis, exposed spine and ribs, porcelain chest plates, a faceless mask
	b.sphere(Vector3(0, hip, 0), Vector3(0.12, 0.08, 0.09), SINEW_DARK, 8, 5)
	for k in 5:
		b.sphere(Vector3(0, hip + 0.08 + k * 0.07, 0.04 + k * 0.012), Vector3(0.035, 0.03, 0.035), PORCELAIN, 6, 4)
	_body(b, [[hip + 0.12, 0.08, 0.06, 0.03], [hip + 0.25, 0.14, 0.1, 0.0], [hip + 0.38, 0.17, 0.12, -0.03], [hip + 0.45, 0.12, 0.09, -0.05]], func(t, a, _c, _n): return SINEW if fmod(t * 6.0, 1.0) < 0.5 else SINEW_DARK, 10)
	b.gloss = true
	b.taper(Vector3(0, hip + 0.22, -0.08), Vector2(0.24, 0.06), Vector2(0.3, 0.08), 0.22, PORCELAIN, false, 0.0, Vector3(0, 0, -0.03))
	b.sphere(Vector3(0, hip + 0.56, -0.08), Vector3(0.075, 0.1, 0.085), PORCELAIN, 10, 6)
	b.cyl(Vector3(0, hip + 0.62, -0.06), Vector3(0, hip + 0.75, 0.02), 0.04, 0.0, PORCELAIN_SHADE, 6)
	b.gloss = false
	b.box(Vector3(0, hip + 0.55, -0.16), Vector3(0.09, 0.012, 0.01), EYE, true)
	# left arm: a long porcelain blade
	b.cyl(Vector3(-0.17, hip + 0.4, -0.02), Vector3(-0.22, hip + 0.18, -0.12), 0.035, 0.03, SINEW, 6)
	b.gloss = true
	b.taper(Vector3(-0.22, hip + 0.18, -0.12), Vector2(0.05, 0.02), Vector2(0.005, 0.005), 0.42, PORCELAIN, false, 0.0, Vector3(-0.04, 0, -0.32))
	b.gloss = false
	# right arm: claw
	b.cyl(Vector3(0.17, hip + 0.4, -0.02), Vector3(0.2, hip + 0.15, -0.08), 0.035, 0.03, SINEW, 6)
	for k in 3:
		b.cyl(Vector3(0.2, hip + 0.15, -0.08), Vector3(0.18 + k * 0.03, hip + 0.04, -0.14), 0.015, 0.0, STEEL, 4)
	var limbs := []
	for s in [-1.0, 1.0]:
		limbs.append(_limb(_bi_leg(hip, 0.045, PORCELAIN, SINEW), Vector3(s * 0.08, hip, 0), "leg", 0.0 if s < 0 else PI, 0.55))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_hound() -> Dictionary:
	var b := MeshKit.new()
	var y := 0.42
	_hbody(b, [[0.42, 0.02, 0.02, 0.02], [0.32, 0.1, 0.1], [0.1, 0.14, 0.13, 0.01], [-0.15, 0.15, 0.15, 0.03], [-0.3, 0.11, 0.1, 0.06]], y, func(_t, a, _c, _n): return SINEW if a > 0.5 else SINEW_DARK, 10)
	b.gloss = true
	for k in 6:
		var z := 0.3 - k * 0.11
		b.taper(Vector3(0, y + 0.09, z), Vector2(0.22 - abs(k - 3) * 0.02, 0.09), Vector2(0.04, 0.04), 0.08, PORCELAIN, false, 0.0, Vector3(0, 0, 0.03))
	# long jaw head
	b.sphere(Vector3(0, y + 0.1, -0.42), Vector3(0.08, 0.08, 0.1), PORCELAIN, 8, 5)
	b.taper(Vector3(0, y + 0.03, -0.46), Vector2(0.12, 0.1), Vector2(0.05, 0.04), 0.06, PORCELAIN, false, 0.0, Vector3(0, -0.02, -0.18))
	b.gloss = false
	b.box(Vector3(0, y + 0.0, -0.55), Vector3(0.08, 0.02, 0.16), SINEW_DARK)
	for k in 4:
		b.cyl(Vector3(-0.03 + k * 0.02, y + 0.01, -0.5 - k * 0.025), Vector3(-0.03 + k * 0.02, y - 0.04, -0.5 - k * 0.025), 0.008, 0.0, Color.WHITE, 3)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.05, y + 0.13, -0.5), Vector3(0.03, 0.01, 0.03), EYE, true)
	b.cyl(Vector3(0, y + 0.03, 0.42), Vector3(0, y + 0.12, 0.75), 0.03, 0.005, STEEL, 5)
	var limbs := []
	var phases := [0.0, PI, PI, 0.0]
	var k := 0
	for z in [-0.22, 0.25]:
		for s in [-1.0, 1.0]:
			var m := MeshKit.new()
			m.cyl(Vector3.ZERO, Vector3(0, -y * 0.5, z * 0.15), 0.045, 0.035, SINEW, 6)
			m.gloss = true
			m.cyl(Vector3(0, -y * 0.5, z * 0.15), Vector3(0, -y + 0.03, -0.03), 0.035, 0.02, PORCELAIN, 6)
			m.gloss = false
			m.cyl(Vector3(0, -y + 0.03, -0.03), Vector3(0, -y + 0.01, -0.1), 0.015, 0.0, STEEL, 4)
			limbs.append(_limb(m, Vector3(s * 0.1, y, z), "leg", phases[k], 0.8))
			k += 1
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_brute() -> Dictionary:
	var b := MeshKit.new()
	var hip := 0.5
	b.sphere(Vector3(0, hip, 0), Vector3(0.22, 0.13, 0.17), SINEW_DARK, 10, 6)
	_body(b, [[hip + 0.05, 0.22, 0.16], [hip + 0.25, 0.3, 0.2, -0.04], [hip + 0.45, 0.42, 0.26, -0.08], [hip + 0.62, 0.38, 0.22, -0.06], [hip + 0.7, 0.15, 0.12, -0.1]], SINEW, 12)
	b.gloss = true
	# big black shoulder plates and chest plate, dripping oil
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.38, hip + 0.62, -0.04), Vector3(0.2, 0.15, 0.22), STEEL, 10, 6)
		for k in 3:
			b.cyl(Vector3(s * (0.3 + k * 0.06), hip + 0.74, -0.04 + k * 0.03), Vector3(s * (0.36 + k * 0.08), hip + 0.92, 0.0 + k * 0.03), 0.04, 0.0, STEEL, 5)
	b.taper(Vector3(0, hip + 0.2, -0.2), Vector2(0.44, 0.08), Vector2(0.58, 0.1), 0.42, STEEL, false, 0.0, Vector3(0, 0, -0.04))
	b.sphere(Vector3(0, hip + 0.68, -0.22), Vector3(0.1, 0.1, 0.1), PORCELAIN, 8, 5)
	for k in 5:
		b.cyl(Vector3(-0.2 + k * 0.1, hip + 0.25, -0.26), Vector3(-0.2 + k * 0.1, hip + 0.05 - (k % 2) * 0.06, -0.26), 0.02, 0.008, OIL, 5)
	b.gloss = false
	b.box(Vector3(0, hip + 0.68, -0.31), Vector3(0.1, 0.015, 0.01), RED_GLOW, true)
	# long arms down to the knuckles
	for s in [-1.0, 1.0]:
		b.cyl(Vector3(s * 0.45, hip + 0.55, -0.06), Vector3(s * 0.52, hip + 0.15, -0.14), 0.1, 0.08, SINEW, 8)
		b.gloss = true
		b.cyl(Vector3(s * 0.52, hip + 0.15, -0.14), Vector3(s * 0.5, 0.12, -0.2), 0.1, 0.12, STEEL, 8)
		b.gloss = false
		b.sphere(Vector3(s * 0.5, 0.1, -0.22), Vector3(0.13, 0.1, 0.13), STEEL.lightened(0.05), 8, 5)
	var limbs := []
	for s in [-1.0, 1.0]:
		limbs.append(_limb(_bi_leg(hip, 0.09, STEEL, SINEW), Vector3(s * 0.15, hip, 0.02), "leg", 0.0 if s < 0 else PI, 0.4))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_drake() -> Dictionary:
	var b := MeshKit.new()
	var y := 0.0
	_hbody(b, [[0.5, 0.01, 0.01], [0.3, 0.07, 0.07], [0.05, 0.13, 0.11], [-0.2, 0.11, 0.1, 0.02], [-0.32, 0.06, 0.06, 0.05]], y, SINEW, 10)
	b.gloss = true
	for k in 5:
		b.taper(Vector3(0, y + 0.07, 0.25 - k * 0.1), Vector2(0.14, 0.07), Vector2(0.02, 0.02), 0.06, PORCELAIN, false, 0.0, Vector3(0, 0, 0.04))
	b.sphere(Vector3(0, y + 0.06, -0.42), Vector3(0.07, 0.06, 0.1), PORCELAIN, 8, 5)
	b.taper(Vector3(0, y + 0.03, -0.48), Vector2(0.08, 0.06), Vector2(0.01, 0.01), 0.04, PORCELAIN_SHADE, false, 0.0, Vector3(0, -0.02, -0.2))
	b.cyl(Vector3(0, y + 0.1, -0.4), Vector3(0, y + 0.18, -0.3), 0.03, 0.0, PORCELAIN_SHADE, 5)
	b.gloss = false
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.04, y + 0.08, -0.5), Vector3(0.02, 0.01, 0.02), RED_GLOW, true)
	b.cyl(Vector3(0, y, 0.5), Vector3(0, y - 0.05, 0.85), 0.02, 0.0, STEEL, 4)
	var limbs := []
	for s in [-1.0, 1.0]:
		var m := MeshKit.new()
		var tips: Array[Vector3] = [Vector3(s * 0.75, 0.05, -0.1), Vector3(s * 0.9, 0.0, 0.15), Vector3(s * 0.7, 0.0, 0.38), Vector3(s * 0.35, 0.0, 0.35)]
		var el := Vector3(s * 0.35, 0.06, -0.05)
		m.gloss = true
		m.cyl(Vector3.ZERO, el, 0.035, 0.03, PORCELAIN, 6)
		for t in tips:
			m.cyl(el, t, 0.018, 0.006, PORCELAIN_SHADE, 5)
		m.gloss = false
		for k in tips.size() - 1:
			m.tri(el, tips[k], tips[k + 1], Color(0.55, 0.08, 0.1))
			m.tri(el, tips[k + 1], tips[k], Color(0.45, 0.05, 0.08))
		m.tri(Vector3.ZERO, el, tips[3], Color(0.5, 0.07, 0.09))
		m.tri(Vector3.ZERO, tips[3], el, Color(0.4, 0.05, 0.07))
		limbs.append(_limb(m, Vector3(s * 0.08, y + 0.04, -0.05), "wing", 0.0, 0.6))
	return {"body": b.commit(), "limbs": limbs, "fly": 2.0}


static func _e_spitter() -> Dictionary:
	var b := MeshKit.new()
	var y := 0.3
	_hbody(b, [[0.3, 0.05, 0.05], [0.15, 0.17, 0.12], [-0.1, 0.16, 0.12], [-0.25, 0.08, 0.08]], y, SINEW, 10)
	b.gloss = true
	# the oil sac, swollen and shiny
	b.sphere(Vector3(0, y + 0.2, 0.08), Vector3(0.24, 0.2, 0.27), OIL, 12, 8)
	b.ring(Vector3(0, y + 0.2, 0.08), Vector3(0, 0, 1), 0.23, 0.02, PORCELAIN, 16, 4)
	b.ring(Vector3(0, y + 0.2, 0.08), Vector3(1, 0, 0), 0.24, 0.02, PORCELAIN, 16, 4)
	b.sphere(Vector3(0, y + 0.02, -0.27), Vector3(0.09, 0.08, 0.09), PORCELAIN, 8, 5)
	b.cyl(Vector3(0, y + 0.03, -0.32), Vector3(0, y + 0.1, -0.5), 0.045, 0.035, STEEL, 8)
	b.gloss = false
	b.ring(Vector3(0, y + 0.1, -0.5), Vector3(0, 0.35, -1), 0.035, 0.012, Color(0.5, 0.95, 0.4), 10, 3, true)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.05, y + 0.06, -0.35), Vector3(0.02, 0.01, 0.02), EYE, true)
	var limbs := []
	var phases := [0.0, PI, PI, 0.0]
	var k := 0
	for z in [-0.15, 0.18]:
		for s in [-1.0, 1.0]:
			limbs.append(_limb(_spider_leg(s, 0.32, y - 0.05, STEEL, SINEW), Vector3(s * 0.13, y, z), "leg", phases[k], 0.6))
			k += 1
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_knight() -> Dictionary:
	var b := MeshKit.new()
	var hip := 0.55
	b.gloss = true
	_body(b, [[hip - 0.08, 0.17, 0.13], [hip + 0.08, 0.15, 0.11], [hip + 0.25, 0.18, 0.13], [hip + 0.42, 0.24, 0.15], [hip + 0.5, 0.16, 0.12], [hip + 0.53, 0.06, 0.06]], func(t, a, _c, _n): return GOLD if fmod(t * 5.0, 1.0) < 0.12 else PORCELAIN, 14)
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.25, hip + 0.45, 0), Vector3(0.12, 0.08, 0.12), PORCELAIN, 10, 6)
		b.cyl(Vector3(s * 0.25, hip + 0.5, 0), Vector3(s * 0.33, hip + 0.68, 0.05), 0.05, 0.0, GOLD, 5)
	# tall crested helm
	b.sphere(Vector3(0, hip + 0.66, -0.01), Vector3(0.09, 0.12, 0.1), PORCELAIN, 10, 6)
	b.taper(Vector3(0, hip + 0.7, 0.02), Vector2(0.03, 0.16), Vector2(0.01, 0.05), 0.28, GOLD, false, 0.0, Vector3(0, 0, 0.1))
	b.gloss = false
	b.box(Vector3(0, hip + 0.66, -0.1), Vector3(0.1, 0.012, 0.01), EYE, true)
	for k in 4:
		b.box(Vector3(0, hip + 0.1 + k * 0.08, -0.13), Vector3(0.05, 0.03, 0.02), SINEW)
	_cloth(b, [Vector3(-0.2, hip + 0.48, 0.1), Vector3(0, hip + 0.5, 0.13), Vector3(0.2, hip + 0.48, 0.1)], Vector3(0, -hip - 0.35, 0.18), 0.12, OIL.lightened(0.05))
	# shield on the left, halberd on the right
	b.cyl(Vector3(-0.25, hip + 0.42, 0), Vector3(-0.3, hip + 0.18, -0.1), 0.045, 0.04, SINEW, 6)
	b.gloss = true
	b.taper(Vector3(-0.32, hip - 0.15, -0.18), Vector2(0.06, 0.03), Vector2(0.3, 0.035), 0.55, PORCELAIN, false, 0.0, Vector3(0, 0, 0))
	b.gloss = false
	b.box(Vector3(-0.32, hip + 0.2, -0.2), Vector3(0.03, 0.4, 0.01), GOLD)
	b.cyl(Vector3(0.25, hip + 0.42, 0), Vector3(0.3, hip + 0.18, -0.12), 0.045, 0.04, SINEW, 6)
	b.cyl(Vector3(0.31, 0.05, -0.15), Vector3(0.31, hip + 0.9, -0.15), 0.02, 0.02, STEEL, 5)
	b.gloss = true
	b.taper(Vector3(0.31, hip + 0.72, -0.15), Vector2(0.02, 0.18), Vector2(0.005, 0.02), 0.25, PORCELAIN_SHADE, false, PI * 0.5, Vector3(0, 0, -0.04))
	b.gloss = false
	var limbs := []
	for s in [-1.0, 1.0]:
		var m := MeshKit.new()
		m.gloss = true
		m.cyl(Vector3.ZERO, Vector3(0, -hip * 0.5, -0.02), 0.06, 0.05, PORCELAIN, 8)
		m.cyl(Vector3(0, -hip * 0.5, -0.02), Vector3(0, -hip + 0.05, 0), 0.05, 0.045, PORCELAIN_SHADE, 8)
		m.gloss = false
		m.sphere(Vector3(0, -hip * 0.5, -0.04), Vector3(0.05, 0.04, 0.04), GOLD, 6, 4)
		m.box(Vector3(0, -hip + 0.03, -0.05), Vector3(0.08, 0.06, 0.18), STEEL)
		limbs.append(_limb(m, Vector3(s * 0.09, hip, 0), "leg", 0.0 if s < 0 else PI, 0.4))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_brood() -> Dictionary:
	var b := MeshKit.new()
	var y := 0.55
	b.gloss = true
	b.cyl(Vector3(0, y - 0.25, 0), Vector3(0, y + 0.35, 0), 0.36, 0.33, STEEL, 14)
	b.sphere(Vector3(0, y + 0.37, 0), Vector3(0.33, 0.18, 0.33), PORCELAIN, 14, 6)
	b.sphere(Vector3(0, y - 0.25, 0), Vector3(0.36, 0.12, 0.36), STEEL.darkened(0.2), 12, 5)
	for k in 3:
		b.ring(Vector3(0, y - 0.15 + k * 0.2, 0), Vector3.UP, 0.37, 0.025, CHROME, 20, 4)
	b.gloss = false
	# glowing window into the vat: mites swimming in red fluid
	for k in 3:
		var a := -PI * 0.5 + (k - 1) * 0.6
		b.box(Vector3(cos(a) * 0.35, y + 0.05, sin(a) * 0.35), Vector3(0.18, 0.3, 0.02), Color(1.0, 0.25, 0.15), true, -a + PI * 0.5)
	for k in 5:
		b.cyl(Vector3(-0.15 + k * 0.075, y + 0.5, 0.05), Vector3(-0.2 + k * 0.1, y + 0.75, 0.15), 0.03, 0.015, SINEW, 5)
	b.sphere(Vector3(0, y + 0.3, -0.3), Vector3(0.1, 0.08, 0.08), PORCELAIN, 8, 5)
	b.box(Vector3(0, y + 0.3, -0.38), Vector3(0.08, 0.015, 0.01), EYE, true)
	var limbs := []
	for k in 3:
		for s in [-1.0, 1.0]:
			limbs.append(_limb(_spider_leg(s, 0.55, y - 0.05, STEEL, SINEW), Vector3(s * 0.28, y - 0.1, -0.2 + k * 0.2), "leg", k * 2.1 + (0.0 if s < 0 else PI), 0.35))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_colossus() -> Dictionary:
	var b := MeshKit.new()
	var hip := 1.0
	var bark := Color(0.16, 0.15, 0.17)
	b.gloss = true
	_body(b, [[hip - 0.15, 0.3, 0.24], [hip + 0.1, 0.35, 0.26], [hip + 0.45, 0.5, 0.32, -0.05], [hip + 0.8, 0.62, 0.36, -0.08], [hip + 1.0, 0.45, 0.3, -0.06], [hip + 1.08, 0.18, 0.15, -0.1]], func(t, a, _c, _n): return bark.lightened(0.1 * sin(a * 30.0) * sin(a * 30.0)), 16)
	# porcelain plates over the steel bark and a red core
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.62, hip + 0.88, -0.05), Vector3(0.32, 0.22, 0.32), PORCELAIN, 12, 7)
		for k in 4:
			b.cyl(Vector3(s * (0.5 + k * 0.1), hip + 1.0, -0.1 + k * 0.06), Vector3(s * (0.6 + k * 0.15), hip + 1.4 - k * 0.05, -0.05 + k * 0.08), 0.06, 0.0, PORCELAIN_SHADE, 5)
	b.taper(Vector3(0, hip + 0.85, -0.25), Vector2(0.25, 0.2), Vector2(0.16, 0.12), 0.3, PORCELAIN, false, 0.0, Vector3(0, 0, -0.05))
	b.gloss = false
	b.sphere(Vector3(0, hip + 0.5, -0.33), Vector3(0.15, 0.18, 0.06), RED_GLOW, 10, 6, true)
	b.ring(Vector3(0, hip + 0.5, -0.33), Vector3(0, 0, 1), 0.18, 0.03, CHROME, 16, 4)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.06, hip + 1.0, -0.38), Vector3(0.06, 0.02, 0.01), EYE, true)
	# huge arms
	for s in [-1.0, 1.0]:
		b.cyl(Vector3(s * 0.7, hip + 0.8, -0.05), Vector3(s * 0.85, hip + 0.25, -0.2), 0.16, 0.13, SINEW, 8)
		b.gloss = true
		b.cyl(Vector3(s * 0.85, hip + 0.25, -0.2), Vector3(s * 0.85, hip - 0.4, -0.35), 0.16, 0.22, bark, 8)
		b.gloss = false
		for k in 3:
			b.cyl(Vector3(s * 0.85, hip - 0.4, -0.35), Vector3(s * (0.75 + k * 0.1), hip - 0.7, -0.55), 0.06, 0.0, PORCELAIN, 5)
	var limbs := []
	for s in [-1.0, 1.0]:
		limbs.append(_limb(_bi_leg(hip, 0.16, bark, SINEW), Vector3(s * 0.28, hip, 0), "leg", 0.0 if s < 0 else PI, 0.35))
	return {"body": b.commit(), "limbs": limbs, "fly": 0.0}


static func _e_walker() -> Dictionary:
	# a planeswalker taken by the oil: tall, robed, a halo of blades, floats a little
	var b := MeshKit.new()
	_body(b, [[0.0, 0.42, 0.38], [0.3, 0.33, 0.3], [0.7, 0.24, 0.2], [1.0, 0.22, 0.17], [1.25, 0.3, 0.2], [1.38, 0.18, 0.14], [1.42, 0.07, 0.07]], func(t, a, _c, _n): return OIL.lightened(0.08) if t < 0.55 else (SINEW if fmod(a * 6.0, 1.0) < 0.3 else Color(0.3, 0.42, 0.25)), 16)
	b.gloss = true
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.3, 1.32, 0), Vector3(0.14, 0.1, 0.14), PORCELAIN, 10, 6)
	b.sphere(Vector3(0, 1.58, -0.02), Vector3(0.12, 0.15, 0.13), PORCELAIN, 12, 7)
	b.gloss = false
	b.box(Vector3(0, 1.58, -0.14), Vector3(0.14, 0.015, 0.01), EYE, true)
	for k in 6:
		b.cyl(Vector3(-0.1 + k * 0.04, 1.5, -0.12), Vector3(-0.1 + k * 0.04, 1.3 - (k % 3) * 0.08, -0.14), 0.012, 0.004, OIL, 4)
	for k in 12:
		var a := TAU * k / 12.0
		var p := Vector3(cos(a) * 0.32, 1.62 + sin(a) * 0.32, 0.12)
		b.gloss = true
		b.taper(p, Vector2(0.04, 0.015), Vector2(0.005, 0.005), 0.16, PORCELAIN_SHADE, false, 0.0, Vector3(cos(a) * 0.1, 0, 0))
		b.gloss = false
	b.ring(Vector3(0, 1.62, 0.12), Vector3(0, 0, 1), 0.3, 0.02, RED_GLOW, 24, 4, true)
	_cloth(b, [Vector3(-0.32, 1.35, 0.1), Vector3(0, 1.38, 0.18), Vector3(0.32, 1.35, 0.1)], Vector3(0, -1.25, 0.3), 0.16, Color(0.3, 0.04, 0.06))
	for s in [-1.0, 1.0]:
		b.cyl(Vector3(s * 0.3, 1.3, 0), Vector3(s * 0.42, 0.85, -0.15), 0.06, 0.05, SINEW, 8)
		b.cyl(Vector3(s * 0.42, 0.85, -0.15), Vector3(s * 0.45, 0.65, -0.3), 0.05, 0.0, PORCELAIN, 6)
	return {"body": b.commit(), "limbs": [], "fly": 0.25}


static func _e_mother() -> Dictionary:
	# the Mother of Machines: pale porcelain, a towering crest, a cloak of red and white, blade wings
	var b := MeshKit.new()
	b.gloss = true
	_body(b, [[0.0, 0.55, 0.5], [0.4, 0.42, 0.38], [0.9, 0.28, 0.24], [1.3, 0.24, 0.18], [1.6, 0.32, 0.2], [1.75, 0.2, 0.15], [1.8, 0.08, 0.08]], func(t, a, _c, _n): return PORCELAIN if fmod(a * 8.0 + t * 2.0, 1.0) > 0.12 else GOLD, 18)
	for s in [-1.0, 1.0]:
		b.sphere(Vector3(s * 0.34, 1.68, 0), Vector3(0.16, 0.12, 0.16), PORCELAIN, 12, 7)
		b.cyl(Vector3(s * 0.34, 1.75, 0), Vector3(s * 0.5, 2.05, 0.05), 0.06, 0.0, PORCELAIN_SHADE, 6)
	b.sphere(Vector3(0, 1.98, -0.02), Vector3(0.12, 0.16, 0.14), PORCELAIN, 12, 7)
	# the tall crest
	var crest := []
	for k in 8:
		var t := k / 7.0
		crest.append(_ring(Vector3(0, 2.05 + t * 0.9, 0.05 + t * t * 0.45), 0.11 * (1.0 - t * 0.85), 0.14 * (1.0 - t * 0.7), 10))
	b.loft(crest, PORCELAIN)
	b.gloss = false
	b.box(Vector3(0, 1.97, -0.15), Vector3(0.12, 0.012, 0.01), EYE, true)
	b.ring(Vector3(0, 2.02, 0), Vector3(0, 1, 0.15), 0.15, 0.02, GOLD, 16, 4)
	# ribbed red sinew in the torso
	for k in 5:
		b.ring(Vector3(0, 1.0 + k * 0.1, 0), Vector3.UP, 0.27 - abs(k - 2) * 0.01, 0.02, SINEW, 16, 4)
	# cloak spreading behind her
	_cloth(b, [Vector3(-0.38, 1.7, 0.12), Vector3(-0.15, 1.72, 0.2), Vector3(0.15, 1.72, 0.2), Vector3(0.38, 1.7, 0.12)], Vector3(0, -1.65, 0.45), 0.35, Color(0.5, 0.05, 0.07))
	# blade wings
	for s in [-1.0, 1.0]:
		for k in 5:
			var base := Vector3(s * 0.2, 1.6 - k * 0.12, 0.25)
			var tip := base + Vector3(s * (1.0 - k * 0.12), 0.6 - k * 0.2, 0.35)
			b.gloss = true
			b.cyl(base, tip, 0.05, 0.0, PORCELAIN_SHADE if k % 2 else PORCELAIN, 5)
			b.gloss = false
		b.cyl(Vector3(s * 0.34, 1.64, 0), Vector3(s * 0.5, 1.1, -0.2), 0.07, 0.06, PORCELAIN, 8)
		b.cyl(Vector3(s * 0.5, 1.1, -0.2), Vector3(s * 0.52, 0.85, -0.35), 0.06, 0.0, GOLD, 6)
	b.ring(Vector3(0, 0.02, 0), Vector3.UP, 0.6, 0.04, RED_GLOW, 24, 4, true)
	return {"body": b.commit(), "limbs": [], "fly": 0.3}
