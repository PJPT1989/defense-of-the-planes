class_name Battle
extends Node3D
## One defense of one plane: the waves, mana and sanctum lives, heroes and their attacks,
## projectiles, the two spells, the camera, mouse picking and an autoplay bot (used by the
## title screen backdrop, the smoke test and the balance simulation).

signal finished(won: bool)

enum { PREP, RUNNING, WON, LOST }
const LIVES := 20
const WAVE_BREAK := 14.0
const SPELLS := [
	{"id": "halo", "name": "Halo Burst", "key": "Q", "cd": 35.0, "desc": "Call down a column of halo light: heavy damage in a small area. Click where."},
	{"id": "stasis", "name": "Stasis", "key": "E", "cd": 50.0, "desc": "Bend time over the whole field: every Phyrexian stops for 3 seconds."},
]

var plane := 0
var level: Level
var fx: Fx
var camera: Camera3D
var enemies: Array[Enemy] = []
var towers := {}
var state := PREP
var mana := 0
var lives := LIVES
var waves: Array = []
var wave_i := 0
var wave_timer := 0.0
var time := 0.0
var speed := 1
var paused := false
var autoplay := false
var demo := false
var selected := -1
var hover_pad := -1
var targeting := -1
var spell_cd: Array[float] = [0.0, 0.0]
var stats := {"kills": 0, "leaked": 0, "earned": 0, "built": 0}
var boss: Enemy = null
var hp_scale := 1.0
var _queue: Array = []   # [time, kind, road]
var _shots: Array = []   # projectile dictionaries
var _range_ring: MeshInstance3D
var _pad_ring: MeshInstance3D
var _cam_target := Vector3.ZERO
var _cam_zoom := 1.0
var _cam_fit := 40.0
var _drag := false
var _bot_t := 0.0
var _bot_order := 0
var _pitch := deg_to_rad(57.0)

static var _shot_meshes := {}


func setup(p: int) -> void:
	plane = p
	var d: Dictionary = Data.PLANES[p]
	hp_scale = d.hp
	mana = d.mana
	waves = Data.waves_for(p)
	level = Level.new()
	add_child(level)
	level.setup(p)
	fx = Fx.new()
	add_child(fx)
	fx.low = Game.quality == Game.LOW
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = 0.5
	camera.far = 200.0
	camera.environment = level.env
	add_child(camera)
	camera.current = true
	_range_ring = _ring_node(Color(1.0, 0.9, 0.6))
	_pad_ring = _ring_node(Color(0.6, 1.0, 0.9))
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)


func _ring_node(col: Color) -> MeshInstance3D:
	var m := MeshKit.new()
	m.ring(Vector3.ZERO, Vector3.UP, 1.0, 0.025, col, 64, 3, true)
	var mi := MeshInstance3D.new()
	mi.mesh = m.commit()
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func apply_quality() -> void:
	level.apply_quality()
	fx.low = Game.quality == Game.LOW


# --- camera ---------------------------------------------------------------------------------

## Finds the camera distance at which the whole field fits the screen.
func fit_camera() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 2.0:
		return
	var target := Vector3(0, 0, 0.6)
	var lo := 10.0
	var hi := 120.0
	for i in 24:
		var mid := (lo + hi) * 0.5
		_place_camera(target, mid)
		var ok := true
		var f := Level.FIELD
		for c in [Vector3(f.position.x, 0, f.position.y), Vector3(f.end.x, 0, f.position.y), Vector3(f.position.x, 0, f.end.y), Vector3(f.end.x, 0, f.end.y)]:
			if camera.is_position_behind(c):
				ok = false
				break
			var s := camera.unproject_position(c)
			if s.x < 0 or s.y < vp.y * 0.07 or s.x > vp.x or s.y > vp.y:
				ok = false
				break
		if ok:
			hi = mid
		else:
			lo = mid
	_cam_fit = hi
	_cam_target = target
	_update_camera()


func _place_camera(target: Vector3, d: float) -> void:
	camera.position = target + Vector3(0, sin(_pitch), cos(_pitch)) * d
	camera.look_at(target, Vector3.UP)


func _update_camera() -> void:
	var lim := (1.0 - _cam_zoom) * Level.FIELD.end.x
	_cam_target.x = clampf(_cam_target.x, -lim, lim)
	_cam_target.z = clampf(_cam_target.z, -lim * 0.6 + 0.6, lim * 0.6 + 0.6)
	_place_camera(_cam_target, _cam_fit * _cam_zoom)


func zoom(by: float, at := Vector2(-1, -1)) -> void:
	var before := _cam_zoom
	_cam_zoom = clampf(_cam_zoom * by, 0.5, 1.0)
	if at.x >= 0.0 and _cam_zoom < before:
		var g := ground_at(at)
		_cam_target = _cam_target.lerp(Vector3(g.x, 0, g.z), 0.25)
	_update_camera()


func ground_at(screen: Vector2) -> Vector3:
	var o := camera.project_ray_origin(screen)
	var n := camera.project_ray_normal(screen)
	if absf(n.y) < 0.0001:
		return Vector3.ZERO
	var t := (0.1 - o.y) / n.y
	return o + n * t


# --- input -----------------------------------------------------------------------------------

func pad_at(screen: Vector2) -> int:
	var g := ground_at(screen)
	var best := -1
	var bd := 1.5
	for i in level.pads.size():
		var d := Vector2(g.x - level.pads[i].x, g.z - level.pads[i].z).length()
		# a tower is tall, so clicking its figure counts too
		if towers.has(i):
			var top := camera.unproject_position(level.pads[i] + Vector3(0, 2.2, 0))
			if screen.distance_to(top) < 40.0:
				d = minf(d, 0.5)
		if d < bd:
			bd = d
			best = i
	return best


func handle_click(screen: Vector2) -> void:
	if targeting >= 0:
		cast(targeting, ground_at(screen))
		return
	var p := pad_at(screen)
	if p >= 0:
		Game.play("click", -6.0)
	selected = p


func cancel() -> void:
	targeting = -1
	selected = -1


func _unhandled_input(e: InputEvent) -> void:
	if demo:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			handle_click(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if targeting >= 0 or selected >= 0:
				cancel()
			else:
				_drag = true
		elif not mb.pressed and mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.9, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 / 0.9)
	elif e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		hover_pad = pad_at(mm.position)
		if _drag:
			var scale_f := _cam_fit * _cam_zoom * 0.0016
			_cam_target -= Vector3(mm.relative.x, 0, mm.relative.y) * scale_f
			_update_camera()


# --- building --------------------------------------------------------------------------------

func can_build(tid: String) -> bool:
	return mana >= Data.TOWERS[tid].cost[0]


func build(pad: int, tid: String) -> bool:
	if pad < 0 or towers.has(pad) or not can_build(tid):
		return false
	var t := Tower.new()
	add_child(t)
	t.position = level.pads[pad]
	t.setup(tid, self, pad)
	towers[pad] = t
	mana -= Data.TOWERS[tid].cost[0]
	stats.built += 1
	fx.burst(level.pads[pad] + Vector3(0, 0.5, 0), Data.TOWERS[tid].color, 18, 3.0, 0.6)
	Game.play("build", -4.0)
	return true


func upgrade(pad: int) -> bool:
	var t: Tower = towers.get(pad)
	if t == null or not t.can_upgrade() or mana < t.upgrade_cost():
		return false
	mana -= t.upgrade_cost()
	t.upgrade()
	fx.burst(t.position + Vector3(0, 1.2, 0), t.def.color, 24, 3.5, 0.7)
	fx.ring(t.position, 1.4, Color(1.0, 0.85, 0.4), 0.6)
	Game.play("upgrade", -4.0)
	return true


func sell(pad: int) -> void:
	var t: Tower = towers.get(pad)
	if t == null:
		return
	mana += t.sell_value()
	fx.burst(t.position + Vector3(0, 0.8, 0), Color(1.0, 0.85, 0.4), 16, 2.5, 0.6)
	Game.play("coin", -4.0)
	towers.erase(pad)
	t.queue_free()
	if selected == pad:
		selected = -1


# --- waves ------------------------------------------------------------------------------------

func next_wave_preview() -> Dictionary:
	if wave_i >= waves.size():
		return {}
	var out := {}
	for g in waves[wave_i]:
		out[g.kind] = int(out.get(g.kind, 0)) + int(g.count)
	return out


func call_wave() -> void:
	if wave_i >= waves.size() or state in [WON, LOST]:
		return
	if state == RUNNING and wave_timer > 0.0:
		var bonus := int(wave_timer * 1.5)
		if bonus > 0:
			mana += bonus
			fx.text(level.rift_pos[0] + Vector3(0, 2.5, 0), "+%d" % bonus, Game.GOLD, 64)
			Game.play("coin", -4.0)
	state = RUNNING
	var span := 0.0
	var w: Array = waves[wave_i]
	for g in w:
		for k in g.count:
			var at: float = time + g.delay + k * g.gap
			_queue.append([at, g.kind, g.road % level.roads.size()])
			span = maxf(span, g.delay + k * g.gap)
	_queue.sort_custom(func(a, b): return a[0] < b[0])
	wave_i += 1
	wave_timer = span + WAVE_BREAK if wave_i < waves.size() else 0.0
	Game.play("horn", -6.0)


func _spawn(kind: String, road: int, at := Level.SPAWN_AT) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	var wave_scale := 1.0 + 0.045 * maxi(wave_i - 1, 0)
	e.setup(kind, self, road, at, hp_scale * (1.0 if Data.ENEMIES[kind].get("boss", false) else wave_scale))
	enemies.append(e)
	if e.boss:
		boss = e
		Game.play("boss", -2.0)
	fx.burst(e.center(), Color(1.0, 0.3, 0.2), 6, 2.0, 0.4)
	return e


func enemy_died(e: Enemy) -> void:
	var b: int = e.def.bounty
	mana += b
	stats.kills += 1
	stats.earned += b
	fx.shatter(e.center(), e.size, 8 + int(e.size * 6))
	fx.pool(e.global_position, 0.35 * e.size + 0.2)
	if b > 0:
		fx.text(e.center() + Vector3(0, 0.6, 0), "+%d" % b, Game.GOLD)
	Game.play("crunch", -8.0 if not e.boss else 0.0)
	if e.def.has("brood"):
		for k in e.def.brood:
			var m := _spawn("mite", e.road, maxf(e.dist - k * 0.25, 0.5))
			m.lane = clampf(e.lane + randf_range(-0.4, 0.4), -0.6, 0.6)
	if e.boss:
		fx.burst(e.center(), Color(1.0, 0.9, 0.7), 60, 6.0, 1.2, 0.2)
		fx.ring(e.global_position, 4.0, Color(1.0, 0.85, 0.5), 1.0)


func enemy_leaked(e: Enemy) -> void:
	lives = maxi(lives - int(e.def.leak), 0)
	stats.leaked += 1
	fx.burst(level.sanctum_pos + Vector3(0, 1.5, 0), Color(1.0, 0.2, 0.15), 20, 3.0, 0.6)
	Game.play("leak", -4.0)


func try_spit(e: Enemy) -> float:
	var reach := 4.6 if not e.boss else 5.5
	var victims := []
	for t in towers.values():
		var tw: Tower = t
		if tw.oiled <= 0.0 and Vector2(tw.position.x - e.position.x, tw.position.z - e.position.z).length() < reach:
			victims.append(tw)
	if victims.is_empty():
		return 1.0
	victims.sort_custom(func(a, b): return a.position.distance_to(e.position) < b.position.distance_to(e.position))
	var n := 3 if e.kind == "mother" else 1
	for k in mini(n, victims.size()):
		var tw: Tower = victims[k]
		_shots.append({"kind": "oil", "node": _shot_node("oil"), "from": e.center() + Vector3(0, 0.3, 0), "to": tw.position + Vector3(0, 1.4, 0),
			"t": 0.0, "dur": 0.8, "arc": 2.0, "tower": tw})
	Game.play("oil", -6.0)
	match e.kind:
		"spitter": return 7.5
		"walker": return 5.0
		_: return 6.0


func summon_husks(e: Enemy) -> void:
	for k in 4:
		var h := _spawn("husk", e.road, maxf(e.dist - 1.0 - k * 0.5, 0.5))
		h.lane = randf_range(-0.6, 0.6)
	fx.burst(e.center(), Color(1.0, 0.25, 0.2), 30, 4.0, 0.8)


# --- spells -------------------------------------------------------------------------------------

func start_spell(i: int) -> void:
	if spell_cd[i] > 0.0 or state in [WON, LOST]:
		return
	if SPELLS[i].id == "stasis":
		cast(i, Vector3.ZERO)
	else:
		targeting = i if targeting != i else -1
		selected = -1


func cast(i: int, at: Vector3) -> void:
	targeting = -1
	if spell_cd[i] > 0.0:
		return
	spell_cd[i] = SPELLS[i].cd
	match SPELLS[i].id:
		"halo":
			fx.beam(at, Color(0.55, 0.9, 1.0), 1.2, 0.9)
			fx.ring(at, 2.6, Color(0.7, 0.95, 1.0), 0.7)
			fx.burst(at + Vector3(0, 0.5, 0), Color(0.7, 0.95, 1.0), 40, 6.0, 0.9, 0.18)
			Game.play("burst", -2.0)
			for e in enemies.duplicate():
				if e.alive and Vector2(e.position.x - at.x, e.position.z - at.z).length() < 2.6:
					e.damage(260.0 * hp_scale, "true")
		"stasis":
			Game.play("stasis", -2.0)
			for e in enemies:
				e.freeze_t = 1.5 if e.boss else 3.0
				fx.ring(e.global_position, 0.8, Color(0.5, 0.85, 1.0), 0.8)


# --- heroes attacking --------------------------------------------------------------------------

func _in_range(t: Tower, e: Enemy) -> bool:
	if not e.alive or (e.flying and not t.def.air):
		return false
	var r := t.range_now()
	return Vector2(e.position.x - t.position.x, e.position.z - t.position.z).length_squared() <= r * r


func pick_target(t: Tower, skip: Enemy = null) -> Enemy:
	var best: Enemy = null
	var score := INF
	for e in enemies:
		if e == skip or not _in_range(t, e):
			continue
		var s := 0.0
		match t.mode:
			0: s = e.remaining()
			1: s = -e.hp
			2: s = -e.remaining()
		if s < score:
			score = s
			best = e
	return best


func tower_attack(t: Tower, target: Enemy) -> void:
	var lv := t.level
	var dmg: float = t.def.dmg[lv]
	var from := t.muzzle()
	match t.id:
		"champion":
			_shots.append({"kind": "spear", "node": _shot_node("spear"), "pos": from, "target": target, "speed": 17.0,
				"dmg": dmg, "type": "phys", "boss_bonus": t.def.boss_bonus[lv]})
			Game.play("spear", -10.0)
		"ember":
			var to := target.predict(0.55)
			_shots.append({"kind": "fireball", "node": _shot_node("fireball"), "from": from, "to": to, "t": 0.0, "dur": 0.55, "arc": 1.6,
				"dmg": dmg, "type": "magic", "splash": t.def.splash[lv], "burn": t.def.burn[lv], "air": true})
			Game.play("fire", -12.0)
		"sage":
			fx.ring(t.position, t.range_now(), Color(0.5, 0.85, 1.0), 0.6, 0.08)
			for e in enemies.duplicate():
				if _in_range(t, e):
					e.apply_slow(t.def.slow[lv], t.def.slow_time[lv])
					e.damage(dmg, "magic")
					fx.spark(e.center(), Vector3(0, 0.8, 0), Color(0.5, 0.85, 1.0), 0.6, 0.18)
			Game.play("chime", -14.0)
		"ninja":
			var targets: Array = [target]
			if t.def.multi[lv] > 1:
				var other := pick_target(t, target)
				if other:
					targets.append(other)
			for tg in targets:
				_shots.append({"kind": "shuriken", "node": _shot_node("shuriken"), "pos": from, "target": tg, "speed": 19.0, "dmg": dmg, "type": "phys"})
			Game.play("shuriken", -14.0)
		"litho":
			var to := target.predict(0.75)
			to.y = 0.0
			_shots.append({"kind": "hedron", "node": _shot_node("hedron"), "from": to + Vector3(randf_range(-1, 1), 9.0, -2.0), "to": to, "t": 0.0, "dur": 0.75, "arc": 0.0,
				"dmg": dmg, "type": "phys", "splash": t.def.splash[lv], "air": false})
		"dragon":
			var pts: Array = [from]
			var hit: Array = []
			var cur: Enemy = target
			var d := dmg
			for k in t.def.chain[lv]:
				if cur == null:
					break
				hit.append(cur)
				pts.append(cur.center())
				cur.damage(d, "magic")
				fx.burst(cur.center(), Color(0.5, 0.85, 1.0), 5, 2.0, 0.3, 0.08)
				d *= 0.8
				var nxt: Enemy = null
				var nd := 2.8
				for e in enemies:
					if e.alive and not hit.has(e):
						var dd := e.position.distance_to(pts[pts.size() - 1])
						if dd < nd:
							nd = dd
							nxt = e
				cur = nxt
			fx.bolt(pts, Color(0.45, 0.75, 1.0))
			Game.play("zap", -10.0)
		"ghost":
			_shots.append({"kind": "dagger", "node": _shot_node("dagger"), "pos": from, "target": target, "speed": 20.0, "dmg": dmg, "type": "true",
				"execute": t.def.execute[lv]})
			Game.play("ghost", -12.0)
		"grove":
			fx.ring(t.position, t.range_now(), Color(0.55, 1.0, 0.4), 0.6, 0.1)
			var n := 0
			for e in enemies.duplicate():
				if _in_range(t, e):
					e.apply_root(t.def.root[lv])
					if n < 8:
						fx.spikes(e.position, Color(0.32, 0.22, 0.14), Color(0.6, 1.0, 0.4))
					n += 1
					e.damage(dmg, "magic")
			Game.play("roots", -10.0)


func _shot_node(kind: String) -> Node3D:
	if not _shot_meshes.has(kind):
		var m := MeshKit.new()
		match kind:
			"spear":
				m.cyl(Vector3(0, 0, 0.5), Vector3(0, 0, -0.3), 0.02, 0.02, Color(1.0, 0.85, 0.4), 5, true)
				m.cyl(Vector3(0, 0, -0.3), Vector3(0, 0, -0.6), 0.06, 0.0, Color(1.0, 0.95, 0.7), 5, true)
			"fireball":
				m.sphere(Vector3.ZERO, Vector3(0.18, 0.18, 0.18), Color(1.0, 0.5, 0.1), 10, 6, true)
				m.sphere(Vector3.ZERO, Vector3(0.1, 0.1, 0.1), Color(1.0, 0.95, 0.6), 8, 5, true)
			"shuriken":
				for k in 4:
					var a := TAU * k / 4.0
					var p := Vector3(cos(a), 0, sin(a)) * 0.15
					var q := Vector3(cos(a + 0.6), 0, sin(a + 0.6)) * 0.05
					m.tri(Vector3.ZERO, q, p, Color(0.8, 0.9, 1.0), true)
					m.tri(Vector3.ZERO, p, q, Color(0.8, 0.9, 1.0), true)
			"hedron":
				Models._hedron(m, Vector3.ZERO, 0.22, 0.5, 0.0, Color(0.58, 0.56, 0.52), Color(0.35, 1.0, 0.85))
			"dagger":
				m.cyl(Vector3(0, 0, 0.15), Vector3(0, 0, -0.35), 0.05, 0.0, Color(0.8, 0.55, 1.0), 6, true)
			"oil":
				m.sphere(Vector3.ZERO, Vector3(0.16, 0.14, 0.16), Color(1, 1, 1, 0.95), 8, 5)
		var mesh := m.commit()
		if kind == "oil":
			mesh.surface_set_material(0, Game.mat_oil)
		_shot_meshes[kind] = mesh
	var mi := MeshInstance3D.new()
	mi.mesh = _shot_meshes[kind]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _splash(at: Vector3, radius: float, dmg: float, type: String, air: bool, burn := 0.0) -> void:
	for e in enemies.duplicate():
		if not e.alive or (e.flying and not air):
			continue
		var d := Vector2(e.position.x - at.x, e.position.z - at.z).length()
		if d <= radius:
			var f := 1.0 if d < radius * 0.5 else 0.6
			if burn > 0.0:
				e.apply_burn(burn, 2.5)
			e.damage(dmg * f, type)


func _step_shots(dt: float) -> void:
	var k := 0
	while k < _shots.size():
		var s: Dictionary = _shots[k]
		var node: Node3D = s.node
		var done := false
		if s.has("target"):
			var tg = s.target
			var aim: Vector3 = tg.center() if is_instance_valid(tg) and tg.alive else s.get("last", s.pos)
			if is_instance_valid(tg) and tg.alive:
				s.last = aim
			var to: Vector3 = aim - s.pos
			var step: float = s.speed * dt
			if to.length() <= step + 0.15:
				done = true
				if is_instance_valid(tg) and tg.alive:
					match s.kind:
						"dagger":
							if not tg.boss and s.execute > 0.0 and tg.hp - s.dmg < tg.max_hp * s.execute:
								tg.damage(tg.hp + 1.0, "true")
							else:
								tg.damage(s.dmg, "true")
							fx.burst(aim, Color(0.75, 0.5, 1.0), 6, 2.0, 0.35, 0.08)
						"spear":
							tg.damage(s.dmg, s.type, s.boss_bonus)
							fx.burst(aim, Color(1.0, 0.9, 0.5), 6, 2.0, 0.3, 0.08)
						_:
							tg.damage(s.dmg, s.type)
							fx.spark(aim, Vector3.ZERO, Color(0.8, 0.9, 1.0), 0.15, 0.12)
			else:
				s.pos += to.normalized() * step
				node.position = s.pos
				if s.kind == "shuriken":
					node.rotation.y += dt * 25.0
				else:
					node.look_at(s.pos + to, Vector3.UP if absf(to.normalized().y) < 0.99 else Vector3.RIGHT)
				if s.kind == "dagger" and randf() < 0.5:
					fx.spark(s.pos, Vector3.ZERO, Color(0.6, 0.4, 0.9), 0.25, 0.06)
		else:
			s.t += dt / s.dur
			var t: float = minf(s.t, 1.0)
			var p: Vector3 = (s.from as Vector3).lerp(s.to, t) + Vector3(0, s.arc * 4.0 * t * (1.0 - t), 0)
			node.position = p
			if s.kind == "hedron":
				node.rotation.y += dt * 4.0
			if s.kind == "fireball" and randf() < 0.8:
				fx.spark(p, Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3)), Color(1.0, 0.5, 0.1), 0.35, 0.12)
			if t >= 1.0:
				done = true
				match s.kind:
					"fireball":
						_splash(s.to, s.splash, s.dmg, "magic", true, s.burn)
						fx.burst(s.to, Color(1.0, 0.5, 0.1), 16, 3.5, 0.5, 0.16)
						fx.ring(Vector3(s.to.x, 0, s.to.z), s.splash, Color(1.0, 0.55, 0.15), 0.35, 0.06)
					"hedron":
						_splash(s.to, s.splash, s.dmg, "phys", false)
						fx.burst(s.to + Vector3(0, 0.2, 0), Color(0.6, 0.55, 0.45), 14, 3.0, 0.6, 0.14)
						fx.burst(s.to + Vector3(0, 0.3, 0), Color(0.35, 1.0, 0.85), 8, 2.5, 0.4, 0.1)
						fx.ring(Vector3(s.to.x, 0, s.to.z), s.splash, Color(0.4, 1.0, 0.85), 0.4, 0.08)
						Game.play("rock", -8.0)
					"oil":
						var tw = s.tower
						if is_instance_valid(tw):
							tw.get_oiled(3.5)
							fx.burst(s.to, Color(0.15, 0.15, 0.2), 10, 2.0, 0.6, 0.12)
						Game.play("splat", -8.0)
		if done:
			node.queue_free()
			_shots.remove_at(k)
		else:
			k += 1


# --- the main loop -----------------------------------------------------------------------------

func _process(dt: float) -> void:
	if paused:
		return
	dt = minf(dt, 0.05)
	for i in speed:
		simulate(dt)
	_update_rings()


func simulate(dt: float) -> void:
	if state == WON or state == LOST:
		fx.step(dt)
		for t in towers.values():
			(t as Tower).step(dt)
		return
	time += dt
	for i in 2:
		spell_cd[i] = maxf(spell_cd[i] - dt, 0.0)
	if state == RUNNING:
		while not _queue.is_empty() and _queue[0][0] <= time:
			var q: Array = _queue.pop_front()
			_spawn(q[1], q[2])
		if wave_timer > 0.0:
			wave_timer -= dt
			if wave_timer <= 0.0:
				wave_timer = 0.0
				call_wave()
	for e in enemies:
		e.step(dt)
	var k := 0
	while k < enemies.size():
		if not enemies[k].alive:
			if enemies[k] == boss:
				boss = null
			enemies[k].queue_free()
			enemies.remove_at(k)
		else:
			k += 1
	for t in towers.values():
		(t as Tower).step(dt)
	_step_shots(dt)
	fx.step(dt)
	if autoplay:
		_bot(dt)
	if lives <= 0 and state != LOST:
		state = LOST
		Game.play("lose")
		finished.emit(false)
	elif state == RUNNING and wave_i >= waves.size() and _queue.is_empty() and enemies.is_empty():
		state = WON
		Game.play("win")
		finished.emit(true)


func stars_won() -> int:
	if lives >= 18:
		return 3
	if lives >= 10:
		return 2
	return 1


func _update_rings() -> void:
	var show := selected if selected >= 0 else -1
	if show >= 0 and towers.has(show):
		var t: Tower = towers[show]
		_range_ring.visible = true
		_range_ring.position = t.position + Vector3(0, 0.14, 0)
		var r := t.range_now()
		_range_ring.scale = Vector3(r, 1, r)
	else:
		_range_ring.visible = false
	var hp := hover_pad if hover_pad >= 0 else selected
	if hp >= 0 and not towers.has(hp):
		_pad_ring.visible = true
		_pad_ring.position = level.pads[hp] + Vector3(0, 0.14, 0)
		var s := 1.05 + sin(time * 4.0) * 0.04
		_pad_ring.scale = Vector3(s, 1, s)
	else:
		_pad_ring.visible = false


## Shows the range a hero would have on the selected spot (while the build menu hovers it).
func preview_range(tid: String) -> void:
	if selected < 0 or tid == "":
		if selected < 0 or not towers.has(selected):
			_range_ring.visible = false
		return
	var r: float = Data.TOWERS[tid].range[0]
	_range_ring.visible = true
	_range_ring.position = level.pads[selected] + Vector3(0, 0.14, 0)
	_range_ring.scale = Vector3(r, 1, r)


# --- autoplay bot ----------------------------------------------------------------------------------

func _bot(dt: float) -> void:
	_bot_t -= dt
	if _bot_t > 0.0:
		return
	_bot_t = 0.4
	if state == PREP and time > 2.0:
		call_wave()
	var heroes: Array = Game.heroes_for(plane)
	# a mix that covers everything: damage first, then support and specialists
	var order := ["champion", "ember", "ninja", "litho", "champion", "sage", "dragon", "ghost", "grove", "ember", "ninja", "ghost", "dragon", "litho", "champion", "ember", "grove", "ninja"]
	var free := -1
	for i in level.pads.size():
		if not towers.has(i):
			free = i
			break
	var want := ""
	var tries := 0
	while tries < order.size():
		var cand: String = order[(_bot_order + tries) % order.size()]
		if cand in heroes:
			want = cand
			break
		tries += 1
	var upgrades := []
	for t in towers.values():
		if (t as Tower).can_upgrade():
			upgrades.append(t)
	upgrades.sort_custom(func(a, b): return a.upgrade_cost() < b.upgrade_cost())
	var prefer_upgrade := towers.size() >= 5 and not upgrades.is_empty() and (_bot_order % 3 != 0 or free < 0)
	if free >= 0 and want != "" and not prefer_upgrade:
		if build(free, want):
			_bot_order += tries + 1
	elif not upgrades.is_empty():
		if upgrade((upgrades[0] as Tower).pad):
			_bot_order += 1
	# spells when there is something worth hitting
	if spell_cd[1] <= 0.0 and (boss != null and boss.remaining() < 15.0 or enemies.size() > 25):
		cast(1, Vector3.ZERO)
	if spell_cd[0] <= 0.0 and enemies.size() > 6:
		var best: Enemy = null
		var bn := 0
		for e in enemies:
			var n := 0
			for o in enemies:
				if o.position.distance_to(e.position) < 2.4:
					n += 1
			if n > bn:
				bn = n
				best = e
		if best and bn >= 5:
			cast(0, best.position)
