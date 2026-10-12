class_name Level
extends Node3D
## One plane's battlefield: sky and light, the ground with its roads, the build spots, the
## scenery, the Realmbreaker rifts the horde comes out of and the sanctum it wants to reach.
## Also answers questions about the roads (where is distance d along road r, how far is a point
## from any road).

const ROAD_HALF := 1.15
const CORNER := 1.9
const STEP := 0.25
## Road coordinates in Data are multiplied by this.
const ROAD_SCALE := 0.85
## The playable field; the camera frames this.
const FIELD := Rect2(-18.7, -11.05, 37.4, 22.1)
## Heroes and Phyrexians are drawn this much bigger than modelled.
const MODEL_SCALE := 1.3
const SPAWN_AT := 2.2
const COBBLE := {"dominaria": 0.55, "kamigawa": 1.0, "zendikar": 0.0, "ravnica": 1.0, "innistrad": 0.6, "kaldheim": 0.7, "phyrexia": 1.0}
const ACCENT := {"dominaria": Color(1.0, 0.85, 0.45), "kamigawa": Color(0.3, 0.9, 1.0), "zendikar": Color(0.35, 1.0, 0.85),
	"ravnica": Color(1.0, 0.75, 0.4), "innistrad": Color(0.7, 0.75, 1.0), "kaldheim": Color(0.45, 0.85, 1.0), "phyrexia": Color(0.6, 0.95, 1.0)}

var def: Dictionary
var index := 0
var theme := ""
var env: Environment
var sun: DirectionalLight3D
## Dense points of each road (Vector3, y = 0) and the distance along it at each point.
var roads: Array[PackedVector3Array] = []
var road_dist: Array[PackedFloat32Array] = []
var road_len: Array[float] = []
var pads: Array[Vector3] = []
var sanctum_pos := Vector3.ZERO
var rift_pos: Array[Vector3] = []
var _dist: PackedFloat32Array
var _heights: PackedFloat32Array
const GRID_MIN := Vector2(-38, -26)
const GRID_RES := 0.5
const GRID_N := Vector2i(153, 105)
const DIST_RES := 0.25
const DIST_N := Vector2i(305, 209)
var _noise := FastNoiseLite.new()


func setup(i: int) -> void:
	index = i
	def = Data.PLANES[i]
	theme = def.theme
	_noise.seed = 1000 + i * 17
	_noise.frequency = 0.07
	_noise.fractal_octaves = 3
	for r in def.roads:
		_build_road(r)
	_build_distance()
	_pick_pads()
	_build_environment()
	_build_ground()
	_build_pads()
	_build_rifts_and_sanctum()
	_scatter()
	apply_quality()


# --- roads -------------------------------------------------------------------------------

func _build_road(pts: Array) -> void:
	# corners become arcs, then the line is resampled every STEP units
	var sp: Array[Vector2] = []
	for p in pts:
		sp.append(p * ROAD_SCALE)
	pts = sp
	var line: Array[Vector2] = [pts[0]]
	for k in range(1, pts.size() - 1):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var c: Vector2 = pts[k + 1]
		var r := minf(CORNER, minf(a.distance_to(b), b.distance_to(c)) * 0.45)
		var d0 := (b - a).normalized()
		var d1 := (c - b).normalized()
		var p0 := b - d0 * r
		var p1 := b + d1 * r
		for s in 9:
			var t := s / 8.0
			line.append(p0.lerp(b, t).lerp(b.lerp(p1, t), t))
	line.append(pts[pts.size() - 1])
	var out := PackedVector3Array()
	var dists := PackedFloat32Array()
	var acc := 0.0
	out.append(Vector3(line[0].x, 0, line[0].y))
	dists.append(0.0)
	var carry := 0.0
	for k in range(1, line.size()):
		var a := line[k - 1]
		var b := line[k]
		var seg := a.distance_to(b)
		var t := STEP - carry
		while t <= seg:
			var p := a.lerp(b, t / seg)
			out.append(Vector3(p.x, 0, p.y))
			acc += STEP
			dists.append(acc)
			t += STEP
		carry = seg - (t - STEP)
	roads.append(out)
	road_dist.append(dists)
	road_len.append(acc)


## Position on road r at distance d (clamped), with a sideways offset `lane`.
func road_point(r: int, d: float, lane := 0.0) -> Vector3:
	var pts := roads[r]
	var f := clampf(d / STEP, 0.0, pts.size() - 1.001)
	var k := int(f)
	var p := pts[k].lerp(pts[k + 1], f - k)
	if lane != 0.0:
		var dir := (pts[k + 1] - pts[k]).normalized()
		p += Vector3(-dir.z, 0, dir.x) * lane
	return p


func road_dir(r: int, d: float) -> Vector3:
	var pts := roads[r]
	var k := clampi(int(d / STEP), 0, pts.size() - 2)
	var k2 := mini(k + 3, pts.size() - 1)
	return (pts[k2] - pts[maxi(k - 1, 0)]).normalized()


func _build_distance() -> void:
	_dist = PackedFloat32Array()
	_dist.resize(DIST_N.x * DIST_N.y)
	_dist.fill(99.0)
	var reach := 7.0
	for pts in roads:
		for k in range(0, pts.size() - 1, 4):
			var a := Vector2(pts[k].x, pts[k].z)
			var kb := mini(k + 4, pts.size() - 1)
			var b := Vector2(pts[kb].x, pts[kb].z)
			var lo := (Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach) - GRID_MIN) / DIST_RES
			var hi := (Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach) - GRID_MIN) / DIST_RES
			for gz in range(maxi(0, int(lo.y)), mini(DIST_N.y, int(hi.y) + 1)):
				for gx in range(maxi(0, int(lo.x)), mini(DIST_N.x, int(hi.x) + 1)):
					var p := GRID_MIN + Vector2(gx, gz) * DIST_RES
					var ab := b - a
					var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
					var dd := p.distance_to(a + ab * t)
					var i := gz * DIST_N.x + gx
					if dd < _dist[i]:
						_dist[i] = dd


## Distance from (x, z) to the nearest road centre line.
func road_distance(x: float, z: float) -> float:
	var f := (Vector2(x, z) - GRID_MIN) / DIST_RES
	var gx := clampi(int(f.x), 0, DIST_N.x - 2)
	var gz := clampi(int(f.y), 0, DIST_N.y - 2)
	var tx := clampf(f.x - gx, 0.0, 1.0)
	var tz := clampf(f.y - gz, 0.0, 1.0)
	var a := lerpf(_dist[gz * DIST_N.x + gx], _dist[gz * DIST_N.x + gx + 1], tx)
	var b := lerpf(_dist[(gz + 1) * DIST_N.x + gx], _dist[(gz + 1) * DIST_N.x + gx + 1], tx)
	return lerpf(a, b, tz)


func _pick_pads() -> void:
	# Build spots: points 2.2-3.3 units off the road, ranked by how much road they cover,
	# chosen greedily with room between them.
	var samples: Array[Vector2] = []
	for pts in roads:
		for k in range(0, pts.size(), 4):
			var p := Vector2(pts[k].x, pts[k].z)
			if FIELD.grow(-0.5).has_point(p):
				samples.append(p)
	var ends: Array[Vector2] = []
	for r in roads.size():
		var a := road_point(r, SPAWN_AT)
		ends.append(Vector2(a.x, a.z))
	var e := road_point(0, road_len[0])
	ends.append(Vector2(e.x, e.z))
	var cands := []
	var x := FIELD.position.x + 1.6
	while x < FIELD.end.x - 1.5:
		var z := FIELD.position.y + 1.6
		while z < FIELD.end.y - 1.3:
			var d := road_distance(x, z)
			if d > 2.5 and d < 3.5:
				var ok := true
				for q in ends:
					if q.distance_to(Vector2(x, z)) < 4.0:
						ok = false
				if ok:
					var score := 0.0
					for s in samples:
						var dd := s.distance_to(Vector2(x, z))
						if dd < 4.6:
							score += 1.0 - dd / 6.0
					cands.append([score, Vector2(x, z)])
			z += 0.5
		x += 0.5
	cands.sort_custom(func(p, q): return p[0] > q[0])
	var want := 14 + roads.size() * 2
	for c in cands:
		var p: Vector2 = c[1]
		var ok := true
		for q in pads:
			if Vector2(q.x, q.z).distance_to(p) < 3.3:
				ok = false
				break
		if ok:
			pads.append(Vector3(p.x, 0, p.y))
			if pads.size() >= want:
				break


# --- look ---------------------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = def.ambient
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.fog_enabled = true
	env.fog_light_color = def.fog
	env.fog_density = def.fog_density * 0.35
	env.fog_sky_affect = 0.2
	env.glow_enabled = true
	env.glow_intensity = 0.55 if def.time in ["day", "overcast", "dusk"] else 0.8
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.5)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	sun = DirectionalLight3D.new()
	var sd: Vector3 = def.sun_dir.normalized()
	sun.look_at_from_position(Vector3.ZERO, sd, Vector3.UP if absf(sd.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = def.sun
	sun.light_energy = def.sun_energy
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	sm.set_shader_parameter("top_color", def.sky_top)
	sm.set_shader_parameter("horizon_color", def.sky_horizon)
	sm.set_shader_parameter("ground_color", def.ground)
	sm.set_shader_parameter("sun_dir", -sd)
	sm.set_shader_parameter("sun_color", def.sun)
	var night: bool = def.time in ["night", "moon", "aurora", "phyrexia"]
	sm.set_shader_parameter("sun_disc", 0.0 if night else 1.0)
	sm.set_shader_parameter("stars", 1.0 if night else 0.0)
	match def.time:
		"aurora": sm.set_shader_parameter("aurora", Vector4(0.3, 1.0, 0.6, 0.9))
		"night": sm.set_shader_parameter("aurora", Vector4(1.0, 0.3, 0.8, 0.35))
		"phyrexia": sm.set_shader_parameter("aurora", Vector4(1.0, 0.3, 0.2, 0.5))
	if def.time == "moon":
		sm.set_shader_parameter("moon_dir", -sd)
		sm.set_shader_parameter("moon_color", Color(1.0, 0.75, 0.65))
	Game.set_gloss_sky(def)


func apply_quality() -> void:
	sun.shadow_enabled = Game.quality != Game.LOW
	env.glow_enabled = Game.quality != Game.LOW
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if Game.quality == Game.HIGH else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS


func height_at(x: float, z: float) -> float:
	var f := (Vector2(x, z) - GRID_MIN) / GRID_RES
	var gx := clampi(int(f.x), 0, GRID_N.x - 2)
	var gz := clampi(int(f.y), 0, GRID_N.y - 2)
	var tx := clampf(f.x - gx, 0.0, 1.0)
	var tz := clampf(f.y - gz, 0.0, 1.0)
	var a := lerpf(_heights[gz * GRID_N.x + gx], _heights[gz * GRID_N.x + gx + 1], tx)
	var b := lerpf(_heights[(gz + 1) * GRID_N.x + gx], _heights[(gz + 1) * GRID_N.x + gx + 1], tx)
	return lerpf(a, b, tz)


func _raw_height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 0.55
	# hills (or canyon walls) rise outside the field so the edges frame it
	var out := maxf(absf(x) - FIELD.end.x - 0.6, 0.0) + maxf(absf(z) - FIELD.end.y - 0.4, 0.0) * 1.4
	var wall := 1.6 if theme == "zendikar" else (0.9 if theme in ["kaldheim", "dominaria"] else 0.45)
	h += minf(out * wall, 6.0) * (0.7 + 0.6 * _noise.get_noise_2d(x * 2.0, z * 2.0 + 50.0))
	var d := road_distance(x, z)
	h *= smoothstep(ROAD_HALF + 0.3, 3.2, d)
	for p in pads:
		var pd := Vector2(x - p.x, z - p.z).length()
		if pd < 2.0:
			h *= smoothstep(1.1, 2.0, pd)
	return h - 0.05 * (1.0 - smoothstep(ROAD_HALF - 0.2, ROAD_HALF + 0.2, d))


func _build_ground() -> void:
	_heights = PackedFloat32Array()
	_heights.resize(GRID_N.x * GRID_N.y)
	for gz in GRID_N.y:
		for gx in GRID_N.x:
			var p := GRID_MIN + Vector2(gx, gz) * GRID_RES
			_heights[gz * GRID_N.x + gx] = _raw_height(p.x, p.y)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var g1: Color = def.grass
	var g2: Color = def.grass2
	var rc: Color = def.road
	var edge := rc.lerp(g1, 0.35).darkened(0.2)
	for gz in GRID_N.y:
		for gx in GRID_N.x:
			var p := GRID_MIN + Vector2(gx, gz) * GRID_RES
			var h := _heights[gz * GRID_N.x + gx]
			verts.append(Vector3(p.x, h, p.y))
			var hx := _heights[gz * GRID_N.x + mini(gx + 1, GRID_N.x - 1)] - _heights[gz * GRID_N.x + maxi(gx - 1, 0)]
			var hz := _heights[mini(gz + 1, GRID_N.y - 1) * GRID_N.x + gx] - _heights[maxi(gz - 1, 0) * GRID_N.x + gx]
			norms.append(Vector3(-hx, 2.0 * GRID_RES, -hz).normalized())
			var d := road_distance(p.x, p.y)
			var road := 1.0 - smoothstep(ROAD_HALF - 0.15, ROAD_HALF + 0.15, d)
			var verge := 1.0 - smoothstep(ROAD_HALF, ROAD_HALF + 0.7, d)
			var n := _noise.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.5 + 0.5
			var c := g1.lerp(g2, smoothstep(0.35, 0.75, n))
			# slopes show bare rock
			var slope := 1.0 - norms[norms.size() - 1].y
			c = c.lerp(Color(0.42, 0.4, 0.38) if theme != "kaldheim" else Color(0.55, 0.6, 0.68), clampf(slope * 3.0, 0.0, 0.8))
			c = c.lerp(edge, verge * 0.8)
			c = c.lerp(rc.darkened(n * 0.12), road)
			cols.append(c)
			uvs.append(Vector2(road, 0))
	var idx := PackedInt32Array()
	for gz in GRID_N.y - 1:
		for gx in GRID_N.x - 1:
			var i := gz * GRID_N.x + gx
			idx.append_array([i, i + 1, i + GRID_N.x, i + 1, i + GRID_N.x + 1, i + GRID_N.x])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("cobble", COBBLE[theme])
	mat.set_shader_parameter("cobble_dark", rc.darkened(0.55))
	mat.set_shader_parameter("detail", 1.0)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_pads() -> void:
	var stone := Color(0.55, 0.53, 0.5)
	match theme:
		"kamigawa", "innistrad": stone = Color(0.35, 0.34, 0.36)
		"zendikar": stone = Color(0.6, 0.5, 0.42)
		"kaldheim": stone = Color(0.5, 0.52, 0.56)
		"phyrexia": stone = Color(0.82, 0.8, 0.75)
	var mesh := Props.pad(stone.darkened(0.3), ACCENT[theme])
	for p in pads:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = p
		mi.scale = Vector3(1.25, 1.0, 1.25)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _build_rifts_and_sanctum() -> void:
	var rmesh := Props.rift()
	for r in roads.size():
		var p := road_point(r, SPAWN_AT)
		# two roads can share a rift
		var dup := false
		for q in rift_pos:
			if q.distance_to(p) < 1.0:
				dup = true
		if dup:
			continue
		rift_pos.append(p)
		var mi := MeshInstance3D.new()
		mi.mesh = rmesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(0, 0.02, 0)
		mi.rotation.y = atan2(-road_dir(r, SPAWN_AT).z, road_dir(r, SPAWN_AT).x)
		add_child(mi)
	var d := road_dir(0, road_len[0])
	sanctum_pos = road_point(0, road_len[0]) + d * 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = Props.sanctum(theme)
	mi.position = sanctum_pos + Vector3(0, height_at(sanctum_pos.x, sanctum_pos.z), 0)
	mi.rotation.y = atan2(-d.z, d.x)
	add_child(mi)


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + index
	var kinds: Array = Props.SCATTER[theme]
	var total := 0.0
	for k in kinds:
		total += k[1]
	var groups := {}
	var count := 420
	var tries := 0
	var placed := 0
	var spots: Array[Vector3] = []
	while placed < count and tries < count * 8:
		tries += 1
		var x := rng.randf_range(-36.0, 36.0)
		var z := rng.randf_range(-25.0, 25.0)
		var inside := absf(x) < FIELD.end.x + 0.8 and absf(z) < FIELD.end.y + 0.5
		if inside and rng.randf() < 0.45:
			continue
		var pick := rng.randf() * total
		var kind: Array = kinds[0]
		for k in kinds:
			pick -= k[1]
			if pick <= 0.0:
				kind = k
				break
		var big: bool = kind[0] in ["neon_tower", "gothic", "cottage", "spire_rock", "rib_arch", "oil_vat"]
		var clear := 3.0 if big else 2.1
		if road_distance(x, z) < clear:
			continue
		var ok := true
		for p in pads:
			if Vector2(x - p.x, z - p.z).length() < (2.4 if big else 1.6):
				ok = false
				break
		for p in rift_pos:
			if Vector2(x - p.x, z - p.z).length() < 3.0:
				ok = false
		if Vector2(x - sanctum_pos.x, z - sanctum_pos.z).length() < 3.6:
			ok = false
		for s in spots:
			if Vector2(x - s.x, z - s.z).length() < (1.4 if big else 0.8):
				ok = false
				break
		if not ok:
			continue
		# tall things stay out of the field so they never hide the road or the heroes
		if big and inside:
			continue
		spots.append(Vector3(x, 0, z))
		var key := "%s:%d" % [kind[0], rng.randi_range(0, 2)]
		if not groups.has(key):
			groups[key] = []
		var s := rng.randf_range(kind[2], kind[3])
		var yaw := rng.randf() * TAU
		if big and theme in ["ravnica", "kamigawa"]:
			yaw = roundf(yaw / (PI * 0.5)) * PI * 0.5
		groups[key].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x, height_at(x, z) - 0.03, z)))
		placed += 1
	for key in groups:
		var parts: PackedStringArray = key.split(":")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.mesh(parts[0], int(parts[1]))
		var list: Array = groups[key]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.set_meta("prop", parts[0])
		add_child(mmi)
