class_name Props
extends RefCounted
## Scenery for each plane, built with MeshKit: trees, rocks, houses, neon towers, hedrons,
## gothic buildings, graves, pines, Phyrexian spires, plus each plane's sanctum (the place the
## heroes defend) and the Realmbreaker root rifts the hordes come out of.
## scatter(theme) lists [mesh name, weight, min scale, max scale]; mesh(name, variant) builds one.

const SCATTER := {
	"dominaria": [["oak", 5, 0.8, 1.3], ["rock", 3, 0.6, 1.4], ["wheat", 3, 0.9, 1.3], ["bush", 4, 0.7, 1.2], ["cottage", 1, 0.9, 1.1], ["wall", 2, 0.9, 1.2]],
	"kamigawa": [["neon_tower", 4, 0.8, 1.4], ["sakura", 4, 0.8, 1.2], ["lantern", 3, 0.9, 1.1], ["rock", 1, 0.5, 0.9], ["torii", 1, 0.9, 1.1]],
	"zendikar": [["spire_rock", 4, 0.7, 1.5], ["rock", 4, 0.6, 1.6], ["hedron", 3, 0.8, 1.6], ["bush", 2, 0.6, 1.0], ["vine_tree", 2, 0.8, 1.2]],
	"ravnica": [["gothic", 6, 0.8, 1.3], ["lamp", 3, 0.9, 1.1], ["statue", 1, 0.9, 1.1], ["rock", 1, 0.4, 0.7]],
	"innistrad": [["dead_tree", 5, 0.8, 1.4], ["grave", 5, 0.8, 1.2], ["rock", 2, 0.5, 1.1], ["fence", 2, 0.9, 1.1], ["lamp", 1, 0.9, 1.0]],
	"kaldheim": [["pine", 7, 0.7, 1.4], ["ice", 3, 0.6, 1.4], ["rock", 3, 0.6, 1.3], ["runestone", 1, 0.9, 1.2]],
	"phyrexia": [["blade_spire", 5, 0.7, 1.5], ["rib_arch", 2, 0.8, 1.2], ["sinew_vine", 3, 0.8, 1.3], ["rock", 2, 0.6, 1.2], ["oil_vat", 1, 0.8, 1.1]],
}

const SANCTUM := {"dominaria": "chapel", "kamigawa": "shrine", "zendikar": "monument", "ravnica": "guildhall",
	"innistrad": "chapel_dark", "kaldheim": "longhall", "phyrexia": "beacon"}


static func mesh(name: String, variant := 0) -> ArrayMesh:
	var m := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + variant * 977
	match name:
		"oak":
			m.cyl(Vector3.ZERO, Vector3(0.05, 1.1, 0), 0.16, 0.1, Color(0.3, 0.21, 0.13), 7)
			m.cyl(Vector3(0.03, 0.8, 0), Vector3(0.4, 1.3, 0.1), 0.07, 0.04, Color(0.3, 0.21, 0.13), 6)
			for k in 7:
				var a := TAU * k / 7.0 + rng.randf()
				var r := rng.randf_range(0.2, 0.55)
				var g := Color(0.2 + rng.randf() * 0.08, 0.38 + rng.randf() * 0.1, 0.12)
				m.sphere(Vector3(cos(a) * r, 1.35 + rng.randf_range(-0.2, 0.35), sin(a) * r), Vector3.ONE * rng.randf_range(0.42, 0.6), g, 9, 6)
		"bush":
			for k in 4:
				m.sphere(Vector3(rng.randf_range(-0.3, 0.3), 0.15, rng.randf_range(-0.3, 0.3)), Vector3(0.3, 0.25, 0.3) * rng.randf_range(0.7, 1.2), Color(0.2, 0.36 + rng.randf() * 0.1, 0.13), 8, 5)
		"rock":
			m.rock(Vector3(0, 0.1, 0), Vector3(0.5, 0.35, 0.42), Color(0.5, 0.48, 0.45), variant)
			m.rock(Vector3(0.4, 0.05, 0.2), Vector3(0.25, 0.18, 0.22), Color(0.46, 0.44, 0.42), variant + 7)
		"wheat":
			for k in 30:
				var p := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.6, 0.6))
				m.cyl(p, p + Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(0.35, 0.5), 0), 0.015, 0.01, Color(0.72, 0.6, 0.3), 3, false, false, false)
				m.sphere(p + Vector3(0, 0.48, 0), Vector3(0.03, 0.07, 0.03), Color(0.85, 0.7, 0.35), 4, 3)
		"cottage":
			m.box(Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 0.9), Color(0.86, 0.82, 0.72))
			for x in [-0.6, 0.6]:
				m.box(Vector3(x, 0.4, 0), Vector3(0.08, 0.82, 0.92), Color(0.35, 0.24, 0.15))
			m.taper(Vector3(0, 0.8, 0), Vector2(1.5, 1.1), Vector2(1.5, 0.08), 0.6, Color(0.62, 0.5, 0.3))
			m.box(Vector3(0.2, 0.3, -0.46), Vector3(0.25, 0.45, 0.02), Color(0.3, 0.2, 0.12))
			m.box(Vector3(-0.3, 0.5, -0.46), Vector3(0.2, 0.18, 0.02), Color(1.0, 0.85, 0.5), true)
			m.box(Vector3(0.45, 1.2, 0.2), Vector3(0.15, 0.5, 0.15), Color(0.5, 0.45, 0.4))
		"wall":
			for k in 5:
				m.rock(Vector3(-0.8 + k * 0.4, 0.15, 0), Vector3(0.24, 0.2, 0.2), Color(0.55, 0.52, 0.47), variant * 5 + k)
				m.rock(Vector3(-0.6 + k * 0.4, 0.4, 0), Vector3(0.2, 0.15, 0.18), Color(0.6, 0.57, 0.5), variant * 5 + k + 50)
		"neon_tower":
			var h := rng.randf_range(3.0, 6.5)
			var w := rng.randf_range(1.0, 1.8)
			m.box(Vector3(0, h * 0.5, 0), Vector3(w, h, w), Color(0.1, 0.1, 0.14))
			var c1: Color = [Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.7), Color(0.7, 0.4, 1.0)][variant % 3]
			for k in int(h / 0.45):
				var y := 0.4 + k * 0.45
				for s in 4:
					var a := s * PI * 0.5
					var d := Vector3(sin(a), 0, -cos(a)) * (w * 0.5 + 0.005)
					if rng.randf() < 0.55:
						m.box(d + Vector3(0, y, 0), Vector3(w * 0.7, 0.1, 0.02) if s % 2 == 0 else Vector3(0.02, 0.1, w * 0.7), Color(0.55, 0.45, 0.3) if rng.randf() < 0.7 else c1 * 0.6, true)
			m.box(Vector3(0, h + 0.03, 0), Vector3(w + 0.02, 0.06, w + 0.02), Color(0.12, 0.12, 0.16))
			for s2 in 4:
				var a2 := s2 * PI * 0.5
				m.box(Vector3(sin(a2), 0, -cos(a2)) * (w * 0.5 + 0.03) + Vector3(0, h + 0.03, 0), Vector3(w + 0.06, 0.05, 0.03) if s2 % 2 == 0 else Vector3(0.03, 0.05, w + 0.06), c1, true)
			m.box(Vector3(w * 0.5 + 0.05, h * 0.6, 0), Vector3(0.06, h * 0.5, 0.3), c1, true)
		"sakura":
			m.cyl(Vector3.ZERO, Vector3(0.1, 0.9, 0), 0.12, 0.07, Color(0.2, 0.12, 0.1), 6)
			m.cyl(Vector3(0.1, 0.7, 0), Vector3(-0.4, 1.1, 0.1), 0.06, 0.03, Color(0.2, 0.12, 0.1), 5)
			for k in 7:
				var a := TAU * k / 7.0
				m.sphere(Vector3(cos(a) * 0.45, 1.15 + rng.randf() * 0.3, sin(a) * 0.45), Vector3(0.38, 0.28, 0.38), Color(0.95, 0.55, 0.72).darkened(rng.randf() * 0.15), 8, 5)
		"lantern":
			m.cyl(Vector3.ZERO, Vector3(0, 0.12, 0), 0.22, 0.2, Color(0.45, 0.45, 0.45), 6)
			m.cyl(Vector3(0, 0.12, 0), Vector3(0, 0.6, 0), 0.07, 0.07, Color(0.5, 0.5, 0.5), 6)
			m.box(Vector3(0, 0.72, 0), Vector3(0.28, 0.22, 0.28), Color(1.0, 0.75, 0.4), true)
			m.taper(Vector3(0, 0.83, 0), Vector2(0.45, 0.45), Vector2(0.05, 0.05), 0.2, Color(0.4, 0.4, 0.42))
		"torii":
			for x in [-0.7, 0.7]:
				m.cyl(Vector3(x, 0, 0), Vector3(x, 1.6, 0), 0.08, 0.07, Color(0.75, 0.1, 0.08), 8)
			m.box(Vector3(0, 1.62, 0), Vector3(2.0, 0.12, 0.16), Color(0.12, 0.1, 0.1))
			m.box(Vector3(0, 1.35, 0), Vector3(1.6, 0.08, 0.1), Color(0.75, 0.1, 0.08))
		"spire_rock":
			var h := rng.randf_range(1.5, 3.5)
			m.cyl(Vector3.ZERO, Vector3(rng.randf_range(-0.2, 0.2), h, 0), rng.randf_range(0.5, 0.8), 0.2, Color(0.62, 0.45, 0.33), 7, false)
			for k in 3:
				m.box(Vector3(0, h * (0.25 + k * 0.25), 0), Vector3(0.9 - k * 0.2, 0.05, 0.9 - k * 0.2), Color(0.75, 0.55, 0.4), false, k * 0.7)
		"hedron":
			var c := Vector3(0, rng.randf_range(1.6, 3.2), 0)
			m.cyl(c - Vector3(0, 0.5, 0), c + Vector3(0, 0.5, 0), 0.32, 0.32, Color(0.55, 0.53, 0.5), 8, false, false, false)
			m.cyl(c + Vector3(0, 0.5, 0), c + Vector3(0, 0.95, 0), 0.32, 0.0, Color(0.6, 0.58, 0.55), 8, false, false, false)
			m.cyl(c - Vector3(0, 0.5, 0), c - Vector3(0, 0.95, 0), 0.32, 0.0, Color(0.5, 0.48, 0.45), 8, false, false, false)
			for k in 4:
				var a := TAU * k / 4.0 + 0.39
				m.box(c + Vector3(cos(a), 0, sin(a)) * 0.31, Vector3(0.03, 0.9, 0.03), Color(0.35, 1.0, 0.85), true, -a)
			m.sphere(Vector3(0, 0.02, 0), Vector3(0.35, 0.02, 0.35), Color(0.1, 0.1, 0.1), 8, 2)
		"vine_tree":
			m.cyl(Vector3.ZERO, Vector3(0.2, 1.5, 0), 0.15, 0.08, Color(0.35, 0.3, 0.22), 6)
			for k in 4:
				var a := TAU * k / 4.0
				m.cyl(Vector3(0.15, 1.2, 0), Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), 0.04, 0.02, Color(0.3, 0.42, 0.2), 5)
			m.sphere(Vector3(0.2, 1.6, 0), Vector3(0.6, 0.3, 0.6), Color(0.3, 0.45, 0.22), 9, 5)
		"gothic":
			var h := rng.randf_range(2.0, 4.0)
			var w := rng.randf_range(1.2, 2.0)
			var d := rng.randf_range(1.2, 1.8)
			var stone := Color(0.5, 0.47, 0.44).darkened(rng.randf() * 0.2)
			m.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), stone)
			m.taper(Vector3(0, h, 0), Vector2(w + 0.1, d + 0.1), Vector2(w * 0.1, d + 0.1), 0.9, Color(0.25, 0.27, 0.3))
			for k in int(h / 0.7):
				for x in [-0.3, 0.3]:
					var lit := rng.randf() < 0.5
					m.box(Vector3(x * w, 0.5 + k * 0.7, -d * 0.5 - 0.01), Vector3(0.18, 0.35, 0.02), Color(1.0, 0.8, 0.45) if lit else Color(0.1, 0.1, 0.12), lit)
			m.cyl(Vector3(w * 0.4, h, d * 0.3), Vector3(w * 0.4, h + 1.4, d * 0.3), 0.15, 0.0, Color(0.25, 0.27, 0.3), 6)
		"lamp":
			m.cyl(Vector3.ZERO, Vector3(0, 1.4, 0), 0.04, 0.03, Color(0.12, 0.12, 0.12), 6)
			m.cyl(Vector3(0, 1.4, 0), Vector3(0.25, 1.45, 0), 0.03, 0.02, Color(0.12, 0.12, 0.12), 5)
			m.sphere(Vector3(0.25, 1.35, 0), Vector3(0.09, 0.11, 0.09), Color(1.0, 0.8, 0.45), 8, 5, true)
		"statue":
			m.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), Color(0.45, 0.45, 0.45))
			m.cyl(Vector3(0, 0.6, 0), Vector3(0, 1.4, 0), 0.2, 0.15, Color(0.6, 0.62, 0.6), 8)
			m.sphere(Vector3(0, 1.55, 0), Vector3(0.14, 0.16, 0.14), Color(0.6, 0.62, 0.6), 8, 5)
			for s in [-1.0, 1.0]:
				m.cyl(Vector3(s * 0.15, 1.3, 0), Vector3(s * 0.7, 1.8, 0.2), 0.12, 0.02, Color(0.55, 0.58, 0.55), 5)
		"dead_tree":
			m.cyl(Vector3.ZERO, Vector3(0.1, 1.6, 0), 0.14, 0.04, Color(0.18, 0.16, 0.15), 6)
			for k in 5:
				var a := TAU * k / 5.0 + rng.randf()
				var y := rng.randf_range(0.7, 1.4)
				m.cyl(Vector3(0.05, y, 0), Vector3(cos(a) * 0.6, y + 0.4, sin(a) * 0.6), 0.04, 0.0, Color(0.16, 0.14, 0.13), 4)
		"grave":
			for k in 3:
				var p := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.5, 0.5))
				var yaw := rng.randf_range(-0.2, 0.2)
				m.box(p + Vector3(0, 0.25, 0), Vector3(0.32, 0.5, 0.08), Color(0.42, 0.42, 0.44), false, yaw)
				m.cyl(p + Vector3(0, 0.5, 0), p + Vector3(0, 0.5, 0.04), 0.16, 0.16, Color(0.42, 0.42, 0.44), 8)
				m.box(p + Vector3(0, 0.02, -0.25), Vector3(0.3, 0.05, 0.4), Color(0.2, 0.18, 0.15), false, yaw)
		"fence":
			for k in 6:
				m.box(Vector3(-0.9 + k * 0.36, 0.35, 0), Vector3(0.04, 0.7, 0.04), Color(0.1, 0.1, 0.11))
				m.cyl(Vector3(-0.9 + k * 0.36, 0.7, 0), Vector3(-0.9 + k * 0.36, 0.82, 0), 0.03, 0.0, Color(0.1, 0.1, 0.11), 4)
			m.box(Vector3(0, 0.6, 0), Vector3(1.9, 0.04, 0.03), Color(0.1, 0.1, 0.11))
			m.box(Vector3(0, 0.15, 0), Vector3(1.9, 0.04, 0.03), Color(0.1, 0.1, 0.11))
		"pine":
			m.cyl(Vector3.ZERO, Vector3(0, 0.5, 0), 0.1, 0.08, Color(0.3, 0.2, 0.14), 6)
			for k in 4:
				var y := 0.35 + k * 0.42
				var r := 0.75 - k * 0.15
				m.cyl(Vector3(0, y, 0), Vector3(0, y + 0.65, 0), r, 0.0, Color(0.12, 0.28, 0.2).lightened(k * 0.03), 8, false)
				m.cyl(Vector3(0, y + 0.18, 0), Vector3(0, y + 0.66, 0), r * 0.75, 0.0, Color(0.92, 0.95, 1.0), 8, false)
		"ice":
			for k in 4:
				var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
				m.cyl(p, p + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.6, 1.4), rng.randf_range(-0.3, 0.3)), rng.randf_range(0.12, 0.22), 0.0, Color(0.65, 0.85, 1.0), 6, false)
		"runestone":
			m.taper(Vector3.ZERO, Vector2(0.5, 0.25), Vector2(0.35, 0.18), 1.4, Color(0.45, 0.45, 0.47))
			for k in 4:
				m.box(Vector3(0, 0.3 + k * 0.25, -0.12), Vector3(0.18, 0.04, 0.01), Color(0.4, 0.8, 1.0), true, 0.0)
		"blade_spire":
			var h := rng.randf_range(1.5, 3.5)
			m.gloss = true
			m.cyl(Vector3.ZERO, Vector3(rng.randf_range(-0.4, 0.4), h, rng.randf_range(-0.4, 0.4)), 0.35, 0.0, Color(0.6, 0.6, 0.64), 5, false)
			for k in 3:
				var a := TAU * k / 3.0
				m.cyl(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), Vector3(cos(a) * 0.7, h * 0.5, sin(a) * 0.7), 0.12, 0.0, Color(0.92, 0.9, 0.85), 5, false)
			m.gloss = false
		"rib_arch":
			for k in 4:
				var z := -0.6 + k * 0.4
				var prev := Vector3(-1.0, 0, z)
				for j in 8:
					var t := (j + 1) / 8.0
					var p := Vector3(-1.0 + t * 2.0, sin(t * PI) * 1.8, z)
					m.gloss = true
					m.cyl(prev, p, 0.08, 0.08, Color(0.9, 0.88, 0.82), 6)
					m.gloss = false
					prev = p
		"sinew_vine":
			for k in 5:
				var a := TAU * k / 5.0
				var prev := Vector3.ZERO
				for j in 5:
					var p := Vector3(cos(a + j * 0.4) * (0.2 + j * 0.15), j * 0.25, sin(a + j * 0.4) * (0.2 + j * 0.15))
					m.cyl(prev, p, 0.06 - j * 0.01, 0.05 - j * 0.01, Color(0.45, 0.06, 0.08), 5)
					prev = p
			m.sphere(Vector3(0, 0.1, 0), Vector3(0.3, 0.15, 0.3), Color(0.35, 0.05, 0.06), 8, 4)
		"oil_vat":
			m.gloss = true
			m.cyl(Vector3.ZERO, Vector3(0, 0.9, 0), 0.5, 0.45, Color(0.14, 0.14, 0.16), 10)
			m.ring(Vector3(0, 0.9, 0), Vector3.UP, 0.45, 0.05, Color(0.8, 0.8, 0.82), 16, 4)
			m.cyl(Vector3(0, 0.85, 0), Vector3(0, 0.88, 0), 0.42, 0.42, Color(0.02, 0.02, 0.03), 12)
			m.gloss = false
			m.box(Vector3(0, 0.45, -0.48), Vector3(0.3, 0.4, 0.02), Color(1.0, 0.25, 0.15), true)
		_:
			m.box(Vector3(0, 0.5, 0), Vector3.ONE, Color.MAGENTA)
	return m.commit()


## The place the heroes defend at the end of the road; faces -x (the road comes from the west).
static func sanctum(theme: String) -> ArrayMesh:
	var m := MeshKit.new()
	match SANCTUM[theme]:
		"chapel", "chapel_dark":
			var dark: bool = SANCTUM[theme] == "chapel_dark"
			var stone := Color(0.5, 0.48, 0.47) if dark else Color(0.88, 0.85, 0.78)
			m.box(Vector3(0.8, 1.1, 0), Vector3(2.6, 2.2, 2.4), stone)
			m.taper(Vector3(0.8, 2.2, 0), Vector2(2.8, 2.6), Vector2(2.8, 0.1), 1.2, Color(0.3, 0.25, 0.3) if dark else Color(0.55, 0.25, 0.15))
			m.box(Vector3(-0.6, 1.8, 0), Vector3(1.0, 3.6, 1.0), stone.darkened(0.05))
			m.taper(Vector3(-0.6, 3.6, 0), Vector2(1.1, 1.1), Vector2(0.05, 0.05), 1.6, Color(0.3, 0.25, 0.3) if dark else Color(0.85, 0.65, 0.3))
			m.box(Vector3(-1.11, 0.8, 0), Vector3(0.02, 1.4, 0.8), Color(0.25, 0.15, 0.1))
			m.cyl(Vector3(-1.12, 2.6, 0), Vector3(-1.14, 2.6, 0), 0.3, 0.3, Color(1.0, 0.8, 0.45) if not dark else Color(0.7, 0.75, 1.0), 16, true)
			for z in [-1.21, 1.21]:
				for x in [0.0, 1.0, 1.8]:
					m.box(Vector3(x, 1.3, z), Vector3(0.3, 0.8, 0.02), Color(1.0, 0.8, 0.45), true)
		"shrine":
			m.box(Vector3(0.6, 0.3, 0), Vector3(3.0, 0.6, 3.0), Color(0.3, 0.3, 0.32))
			for t in 3:
				var w := 2.2 - t * 0.5
				var y := 0.6 + t * 1.0
				m.box(Vector3(0.6, y + 0.35, 0), Vector3(w, 0.7, w), Color(0.35, 0.1, 0.08))
				m.taper(Vector3(0.6, y + 0.7, 0), Vector2(w + 0.8, w + 0.8), Vector2(w * 0.4, w * 0.4), 0.3, Color(0.1, 0.1, 0.14))
				m.box(Vector3(0.6, y + 0.71, 0), Vector3(w + 0.82, 0.04, w + 0.82), Color(0.3, 0.9, 1.0), true)
			m.cyl(Vector3(0.6, 3.6, 0), Vector3(0.6, 4.6, 0), 0.05, 0.02, Color(0.8, 0.65, 0.3), 6)
			for z in [-1.0, 1.0]:
				m.cyl(Vector3(-1.4, 0, z), Vector3(-1.4, 1.9, z), 0.1, 0.09, Color(0.8, 0.12, 0.1), 8)
			m.box(Vector3(-1.4, 1.95, 0), Vector3(0.2, 0.14, 2.8), Color(0.1, 0.1, 0.1))
			m.box(Vector3(-1.4, 1.6, 0), Vector3(0.12, 0.1, 2.2), Color(0.8, 0.12, 0.1))
		"monument":
			m.rock(Vector3(0.5, 0.2, 0), Vector3(2.0, 0.6, 2.0), Color(0.6, 0.48, 0.38), 3)
			for k in 4:
				var a := TAU * k / 4.0
				var c := Vector3(0.5 + cos(a) * 1.2, 2.0 + k * 0.2, sin(a) * 1.2)
				m.cyl(c - Vector3(0, 0.8, 0), c + Vector3(0, 0.8, 0), 0.35, 0.35, Color(0.58, 0.56, 0.52), 8, false, false, false)
				m.cyl(c + Vector3(0, 0.8, 0), c + Vector3(0, 1.3, 0), 0.35, 0.0, Color(0.62, 0.6, 0.56), 8, false, false, false)
				m.cyl(c - Vector3(0, 0.8, 0), c - Vector3(0, 1.3, 0), 0.35, 0.0, Color(0.5, 0.48, 0.45), 8, false, false, false)
				for j in 4:
					var b := TAU * j / 4.0 + 0.39
					m.box(c + Vector3(cos(b), 0, sin(b)) * 0.34, Vector3(0.04, 1.5, 0.04), Color(0.35, 1.0, 0.85), true, -b)
			m.sphere(Vector3(0.5, 3.0, 0), Vector3(0.4, 0.4, 0.4), Color(0.4, 1.0, 0.85), 10, 6, true)
		"guildhall":
			m.box(Vector3(1.0, 1.6, 0), Vector3(2.4, 3.2, 3.2), Color(0.55, 0.52, 0.5))
			for z in [-1.2, 0.0, 1.2]:
				m.cyl(Vector3(-0.3, 0, z), Vector3(-0.3, 2.6, z), 0.15, 0.15, Color(0.75, 0.72, 0.68), 10)
			m.taper(Vector3(0.5, 2.6, 0), Vector2(1.6, 3.4), Vector2(0.1, 3.4), 0.8, Color(0.6, 0.57, 0.53))
			m.cyl(Vector3(1.4, 3.2, 0), Vector3(1.4, 6.0, 0), 0.5, 0.0, Color(0.3, 0.32, 0.36), 8, false)
			m.cyl(Vector3(-0.32, 1.8, 0), Vector3(-0.35, 1.8, 0), 0.4, 0.4, Color(1.0, 0.8, 0.45), 16, true)
		"longhall":
			m.box(Vector3(0.8, 0.8, 0), Vector3(3.2, 1.6, 2.2), Color(0.4, 0.28, 0.18))
			m.taper(Vector3(0.8, 1.6, 0), Vector2(3.6, 2.8), Vector2(3.6, 0.1), 1.4, Color(0.9, 0.92, 0.96))
			for x in [-0.95, 2.55]:
				m.cyl(Vector3(x, 2.6, 0), Vector3(x - 0.4 * signf(x - 0.8), 3.4, 0), 0.1, 0.05, Color(0.4, 0.28, 0.18), 6)
			m.box(Vector3(-0.81, 0.6, 0), Vector3(0.02, 1.0, 0.8), Color(1.0, 0.7, 0.35), true)
		"beacon":
			m.cyl(Vector3(0.5, 0, 0), Vector3(0.5, 0.5, 0), 1.6, 1.4, Color(0.85, 0.82, 0.75), 12)
			for k in 6:
				var a := TAU * k / 6.0
				m.cyl(Vector3(0.5 + cos(a) * 1.2, 0.5, sin(a) * 1.2), Vector3(0.5 + cos(a) * 0.5, 3.0, sin(a) * 0.5), 0.12, 0.05, Color(0.9, 0.88, 0.8), 6)
			m.sphere(Vector3(0.5, 3.4, 0), Vector3(0.5, 0.5, 0.5), Color(0.6, 0.95, 1.0), 12, 8, true)
			m.ring(Vector3(0.5, 3.4, 0), Vector3(0.3, 1, 0), 0.9, 0.04, Color(1.0, 0.9, 0.6), 24, 4, true)
	return m.commit()


## A Realmbreaker root punching down out of the sky into a rift in the ground.
static func rift() -> ArrayMesh:
	var m := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	m.gloss = true
	var prev := Vector3(0, 0.2, 0)
	for k in 9:
		var p := Vector3(sin(k * 0.8) * 0.4 + k * 0.05, 0.2 + (k + 1) * 1.3, cos(k * 0.6) * 0.3 + k * 0.35)
		m.cyl(prev, p, 0.55 + k * 0.08, 0.6 + k * 0.08, Color(0.16, 0.15, 0.17), 9)
		prev = p
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf() * 0.4
		var tip := Vector3(cos(a) * rng.randf_range(1.6, 2.4), -0.05, sin(a) * rng.randf_range(1.6, 2.4))
		m.cyl(Vector3(0, 0.6, 0), tip, 0.2, 0.03, Color(0.18, 0.17, 0.2), 6)
		m.cyl(Vector3(cos(a) * 0.4, 1.4 + k * 0.2, sin(a) * 0.4), Vector3(cos(a) * 1.0, 2.4 + k * 0.25, sin(a) * 1.0), 0.07, 0.0, Color(0.9, 0.88, 0.82), 5)
	m.gloss = false
	m.ring(Vector3(0, 0.05, 0), Vector3.UP, 1.4, 0.08, Color(1.0, 0.25, 0.15), 28, 4, true)
	m.ring(Vector3(0, 0.05, 0), Vector3.UP, 1.0, 0.05, Color(1.0, 0.85, 0.75), 24, 4, true)
	m.cyl(Vector3(0, 0.0, 0), Vector3(0, 0.03, 0), 1.35, 1.35, Color(0.04, 0.02, 0.03), 24)
	for k in 5:
		var a := TAU * k / 5.0
		m.box(Vector3(cos(a) * 0.4, 1.0 + k * 0.4, sin(a) * 0.4), Vector3(0.05, 0.35, 0.05), Color(1.0, 0.3, 0.2), true, a)
	return m.commit()


## A build spot: round stone platform with a faint ring of runes in the plane's accent colour.
static func pad(stone: Color, accent: Color) -> ArrayMesh:
	var m := MeshKit.new()
	m.cyl(Vector3(0, -0.1, 0), Vector3(0, 0.08, 0), 1.0, 0.95, stone, 16)
	m.cyl(Vector3(0, 0.08, 0), Vector3(0, 0.1, 0), 0.82, 0.82, stone.lightened(0.08), 16)
	m.ring(Vector3(0, 0.1, 0), Vector3.UP, 0.88, 0.02, accent, 32, 3, true)
	for k in 8:
		var a := TAU * k / 8.0
		m.box(Vector3(cos(a) * 0.95, 0.04, sin(a) * 0.95), Vector3(0.1, 0.12, 0.2), stone.darkened(0.2), false, -a)
	return m.commit()
