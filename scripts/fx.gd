class_name Fx
extends Node3D
## Visual effects for a battle: glowing sparks and porcelain shards (two pooled MultiMeshes
## driven from here), oil pools, expanding rings, lightning bolts, light beams, rising root
## spikes and floating "+mana" numbers. Everything fades or falls away by itself.

const MAX_SPARKS := 900
const MAX_SHARDS := 360
const MAX_POOLS := 48

var _spark_mm: MultiMesh
var _shard_mm: MultiMesh
var _pool_mm: MultiMesh
# per particle: position, velocity, life left, life total, colour, size
var _sp := []
var _sh := []
var _pools := []
var _temps := []   # [node, life, total, kind]
var low := false

static var _meshes := {}


func _ready() -> void:
	_spark_mm = _make_mm(_spark_mesh(), MAX_SPARKS, false)
	_shard_mm = _make_mm(_shard_mesh(), MAX_SHARDS, true)
	var disc := MeshKit.new()
	disc.cyl(Vector3.ZERO, Vector3(0, 0.01, 0), 1.0, 1.0, Color.WHITE, 16)
	var dm := disc.commit()
	dm.surface_set_material(0, Game.mat_oil)
	_pool_mm = _make_mm(dm, MAX_POOLS, true)


func _make_mm(mesh: Mesh, n: int, shadows: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 200.0
	add_child(mmi)
	return mm


static func _spark_mesh() -> Mesh:
	var m := MeshKit.new()
	m.sphere(Vector3.ZERO, Vector3(0.5, 0.5, 0.5), Color.WHITE, 6, 3, true)
	return m.commit()


static func _shard_mesh() -> Mesh:
	var m := MeshKit.new()
	m.gloss = true
	var a := Vector3(0, 0.6, 0)
	var pts: Array[Vector3] = [Vector3(-0.5, 0, -0.3), Vector3(0.5, 0, -0.4), Vector3(0.2, 0, 0.5)]
	for k in 3:
		m.tri(a, pts[(k + 1) % 3], pts[k], Color.WHITE)
	m.tri(pts[0], pts[1], pts[2], Color.WHITE)
	return m.commit()


func spark(p: Vector3, v: Vector3, col: Color, life := 0.5, size := 0.1) -> void:
	if _sp.size() >= MAX_SPARKS or (low and _sp.size() > MAX_SPARKS / 3):
		return
	_sp.append([p, v, life, life, col, size])


func burst(p: Vector3, col: Color, n := 12, speed := 3.0, life := 0.5, size := 0.12) -> void:
	if low:
		n = ceili(n * 0.4)
	for k in n:
		var d := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized()
		spark(p, d * speed * randf_range(0.4, 1.0), col.lerp(Color.WHITE, randf() * 0.3), life * randf_range(0.6, 1.2), size * randf_range(0.6, 1.3))


## A Phyrexian breaking apart: porcelain, sinew and oil fly off and bounce.
func shatter(p: Vector3, scale := 1.0, n := 10) -> void:
	if low:
		n = ceili(n * 0.5)
	for k in n:
		if _sh.size() >= MAX_SHARDS:
			_sh.pop_front()
		var col: Color = [Models.PORCELAIN, Models.PORCELAIN, Models.SINEW, Models.STEEL][k % 4]
		var v := Vector3(randf_range(-1, 1), randf_range(0.8, 2.0), randf_range(-1, 1)) * 2.4 * sqrt(scale)
		_sh.append([p + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.5), randf_range(-0.2, 0.2)) * scale, v, 1.6, 1.6, col, randf_range(0.08, 0.16) * scale, Vector3(randf(), randf(), randf()) * 10.0])


func pool(p: Vector3, r: float, life := 7.0) -> void:
	if _pools.size() >= MAX_POOLS:
		_pools.pop_front()
	_pools.append([Vector3(p.x, 0.03 + randf() * 0.01, p.z), r * randf_range(0.8, 1.2), life, life])


func ring(p: Vector3, radius: float, col: Color, life := 0.5, thick := 0.06) -> void:
	var key := "ring%s" % col.to_html()
	if not _meshes.has(key):
		var m := MeshKit.new()
		m.ring(Vector3.ZERO, Vector3.UP, 1.0, 0.04, col, 40, 3, true)
		_meshes[key] = m.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.position = p + Vector3(0, 0.15, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("r", radius)
	mi.set_meta("thick", thick / 0.04)
	add_child(mi)
	_temps.append([mi, life, life, "ring"])


func beam(p: Vector3, col: Color, radius := 1.0, life := 0.8) -> void:
	var m := MeshKit.new()
	m.cyl(Vector3(0, 0, 0), Vector3(0, 30, 0), radius, radius * 0.4, col, 16, true, true, false)
	m.cyl(Vector3(0, 0, 0), Vector3(0, 30, 0), radius * 0.45, radius * 0.2, Color.WHITE, 12, true, true, false)
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	mi.position = p
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_temps.append([mi, life, life, "beam"])


## A jagged bolt through the given points, gone in a moment.
func bolt(points: Array, col: Color, life := 0.22) -> void:
	var m := MeshKit.new()
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var prev := a
		var n := maxi(2, int(a.distance_to(b) / 0.5))
		for j in n:
			var t := float(j + 1) / n
			var q := a.lerp(b, t)
			if j < n - 1:
				q += Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
			m.cyl(prev, q, 0.06, 0.06, col, 4, true, false, false)
			m.cyl(prev, q, 0.025, 0.025, Color.WHITE, 4, true, false, false)
			prev = q
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_temps.append([mi, life, life, "bolt"])


## Roots or stone spikes bursting out of the ground at p.
func spikes(p: Vector3, col: Color, tip: Color, life := 0.9) -> void:
	var key := "spikes%s" % col.to_html()
	if not _meshes.has(key):
		var m := MeshKit.new()
		for k in 5:
			var a := TAU * k / 5.0
			var b := Vector3(cos(a) * 0.3, -0.1, sin(a) * 0.3)
			var t := Vector3(cos(a) * 0.12, 0.7 + (k % 2) * 0.25, sin(a) * 0.12)
			m.cyl(b, t, 0.1, 0.0, col, 5)
			m.sphere(t * 0.9, Vector3(0.04, 0.04, 0.04), tip, 4, 3, true)
		_meshes[key] = m.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.position = p
	mi.rotation.y = randf() * TAU
	add_child(mi)
	_temps.append([mi, life, life, "spikes"])


func text(p: Vector3, s: String, col: Color, size := 48) -> void:
	if low:
		return
	var l := Label3D.new()
	l.text = s
	l.font = Game.font_title_bold
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = p
	add_child(l)
	_temps.append([l, 1.0, 1.0, "text"])


func step(dt: float) -> void:
	# sparks: drift up a little, slow down, shrink
	var n := 0
	var k := 0
	while k < _sp.size():
		var s: Array = _sp[k]
		s[2] -= dt
		if s[2] <= 0.0:
			_sp[k] = _sp[_sp.size() - 1]
			_sp.pop_back()
			continue
		s[1] *= 1.0 - 2.5 * dt
		s[1].y += 0.6 * dt
		s[0] += s[1] * dt
		var f: float = s[2] / s[3]
		var sz: float = s[5] * (0.3 + 0.7 * f)
		_spark_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(sz, sz, sz)), s[0]))
		var c: Color = s[4]
		_spark_mm.set_instance_color(n, Color(c.r * f + 0.05, c.g * f + 0.05, c.b * f + 0.05))
		n += 1
		k += 1
	_spark_mm.visible_instance_count = n
	# shards: gravity, bounce, tumble, sink away at the end
	n = 0
	k = 0
	while k < _sh.size():
		var s: Array = _sh[k]
		s[2] -= dt
		if s[2] <= 0.0:
			_sh[k] = _sh[_sh.size() - 1]
			_sh.pop_back()
			continue
		s[1].y -= 12.0 * dt
		s[0] += s[1] * dt
		if s[0].y < 0.03:
			s[0].y = 0.03
			s[1] = Vector3(s[1].x * 0.5, absf(s[1].y) * 0.3, s[1].z * 0.5)
			s[6] *= 0.5
		var spin: Vector3 = s[6] * (s[3] - s[2])
		var sz: float = s[5] * minf(1.0, s[2] * 2.0)
		_shard_mm.set_instance_transform(n, Transform3D(Basis.from_euler(spin).scaled(Vector3(sz, sz, sz)), s[0]))
		_shard_mm.set_instance_color(n, s[4])
		n += 1
		k += 1
	_shard_mm.visible_instance_count = n
	n = 0
	k = 0
	while k < _pools.size():
		var s: Array = _pools[k]
		s[2] -= dt
		if s[2] <= 0.0:
			_pools.remove_at(k)
			continue
		var grow := minf(1.0, (s[3] - s[2]) * 4.0)
		var r: float = s[1] * grow
		_pool_mm.set_instance_transform(n, Transform3D(Basis().scaled(Vector3(r, 1, r)), s[0]))
		_pool_mm.set_instance_color(n, Color(1, 1, 1, minf(0.92, s[2] / 2.0)))
		n += 1
		k += 1
	_pool_mm.visible_instance_count = n
	k = 0
	while k < _temps.size():
		var t: Array = _temps[k]
		t[1] -= dt
		var node: Node3D = t[0]
		if t[1] <= 0.0:
			node.queue_free()
			_temps.remove_at(k)
			continue
		var f: float = t[1] / t[2]
		match t[3]:
			"ring":
				var r: float = node.get_meta("r") * (1.0 - f * f * 0.7)
				var th: float = node.get_meta("thick") * f
				node.scale = Vector3(r, maxf(th, 0.05), r)
			"beam":
				node.scale = Vector3(f, 1.0, f)
			"bolt":
				node.visible = fmod(t[1] * 40.0, 2.0) > 0.4
			"spikes":
				var up := minf(1.0, (1.0 - f) * 8.0)
				node.scale = Vector3(1.0, up * minf(1.0, f * 3.0) + 0.01, 1.0)
			"text":
				node.position.y += dt * 1.2
				(node as Label3D).modulate.a = minf(1.0, f * 2.0)
				(node as Label3D).outline_modulate.a = minf(0.8, f * 1.6)
		k += 1
