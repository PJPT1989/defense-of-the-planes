class_name Enemy
extends Node3D
## One Phyrexian: walks (or flies) along its road, takes damage after armour or resistance,
## can be slowed, rooted and set burning, and animates its legs, wings and body as it goes.
## Spitters, the Compleated Walker and the Porcelain Mother oil nearby heroes; the Mother also
## calls up husks; Broodmothers burst into mites.

var kind := ""
var def: Dictionary
var battle: Node
var hp := 1.0
var max_hp := 1.0
var armor := 0.0
var resist := 0.0
var speed := 1.0
var road := 0
var dist := 0.0
var lane := 0.0
var flying := false
var fly_h := 0.0
var boss := false
var alive := true
var size := 1.0
var slow := 0.0
var slow_t := 0.0
var root_t := 0.0
var freeze_t := 0.0
var burn := 0.0
var burn_t := 0.0
var spit_cd := 0.0
var summon_cd := 8.0
var anim := 0.0
var _body: MeshInstance3D
var _limbs: Array[Node3D] = []
var _limb_defs: Array = []
var _hit_flash := 0.0


func setup(k: String, b: Node, r: int, start_dist: float, hp_scale: float) -> void:
	kind = k
	def = Data.ENEMIES[k]
	battle = b
	road = r
	dist = start_dist
	max_hp = def.hp * hp_scale
	hp = max_hp
	armor = def.armor
	resist = def.resist
	speed = def.speed * randf_range(0.95, 1.05)
	flying = def.get("fly", false)
	boss = def.get("boss", false)
	size = def.size * Level.MODEL_SCALE
	lane = randf_range(-0.55, 0.55) if not boss else 0.0
	spit_cd = randf_range(2.0, 5.0)
	anim = randf() * 10.0
	var m: Dictionary = Models.enemy(k)
	fly_h = m.fly
	var scale_all := Level.MODEL_SCALE
	_body = MeshInstance3D.new()
	_body.mesh = m.body
	add_child(_body)
	for l in m.limbs:
		var piv := Node3D.new()
		piv.position = l.pivot
		var mi := MeshInstance3D.new()
		mi.mesh = l.mesh
		piv.add_child(mi)
		add_child(piv)
		_limbs.append(piv)
		_limb_defs.append(l)
	scale = Vector3.ONE * scale_all
	_place(0.0)


## Where the enemy will be in t seconds at its current speed (for lobbed shots).
func predict(t: float) -> Vector3:
	var d := dist + _cur_speed() * t
	var p: Vector3 = battle.level.road_point(road, d, lane)
	return p + Vector3(0, fly_h + size * 0.5, 0)


func center() -> Vector3:
	return global_position + Vector3(0, size * 0.5 + (0.0 if flying else 0.0), 0)


func _cur_speed() -> float:
	if root_t > 0.0 or freeze_t > 0.0:
		return 0.0
	return speed * (1.0 - slow)


## How far it still has to go: lower means more dangerous (used for "first" targeting).
func remaining() -> float:
	return battle.level.road_len[road] - dist


func damage(amount: float, type: String, from_boss_bonus := 0.0) -> void:
	if not alive:
		return
	var mul := 1.0
	match type:
		"phys": mul = 1.0 - armor
		"magic": mul = 1.0 - resist
	if boss:
		mul *= 1.0 + from_boss_bonus
	hp -= amount * mul
	_hit_flash = 0.12
	if hp <= 0.0:
		alive = false
		battle.enemy_died(self)


func apply_slow(amount: float, t: float) -> void:
	if boss:
		amount *= 0.5
	if amount >= slow or slow_t <= 0.0:
		slow = amount
	slow_t = maxf(slow_t, t)


func apply_root(t: float) -> void:
	if flying:
		return
	root_t = maxf(root_t, t * (0.35 if boss else 1.0))


func apply_burn(dps: float, t: float) -> void:
	burn = maxf(burn, dps)
	burn_t = maxf(burn_t, t)


func step(dt: float) -> void:
	if not alive:
		return
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow = 0.0
	root_t = maxf(root_t - dt, 0.0)
	freeze_t = maxf(freeze_t - dt, 0.0)
	if burn_t > 0.0:
		burn_t -= dt
		hp -= burn * dt * (1.0 - resist)
		if randf() < dt * 10.0:
			battle.fx.spark(center() + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)) * size, Vector3(0, 1.2, 0), Color(1.0, 0.45, 0.1), 0.45, 0.1)
		if hp <= 0.0:
			alive = false
			battle.enemy_died(self)
			return
	var v := _cur_speed()
	dist += v * dt
	if dist >= battle.level.road_len[road] - 0.4:
		alive = false
		battle.enemy_leaked(self)
		return
	if def.get("spit", false):
		spit_cd -= dt
		if spit_cd <= 0.0 and freeze_t <= 0.0:
			spit_cd = battle.try_spit(self)
	if def.get("summon", false):
		summon_cd -= dt
		if summon_cd <= 0.0:
			summon_cd = 9.0
			battle.summon_husks(self)
	anim += dt * (v / maxf(speed, 0.1)) * (6.0 if size < 1.0 else 4.0)
	_place(dt)


func _place(dt: float) -> void:
	var p: Vector3 = battle.level.road_point(road, dist, lane)
	var dir: Vector3 = battle.level.road_dir(road, dist)
	var y := fly_h
	if flying:
		y += sin(anim * 0.7) * 0.12
	elif fly_h > 0.0:
		y += sin(anim * 0.5) * 0.06
	position = p + Vector3(0, y, 0)
	var yaw := atan2(dir.x, dir.z) + PI
	rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, dt * 8.0)) if dt > 0.0 else yaw
	var moving := _cur_speed() > 0.0
	# body bob and limb swing
	var bob := absf(sin(anim)) * 0.04 * size if moving and not flying else 0.0
	_body.position.y = bob
	if _hit_flash > 0.0:
		_hit_flash -= dt
	for k in _limbs.size():
		var l: Dictionary = _limb_defs[k]
		var ph: float = l.phase
		var amp: float = l.amp
		if l.kind == "wing":
			var side := signf(l.pivot.x)
			_limbs[k].rotation.z = side * sin(anim * 1.6) * amp
		else:
			_limbs[k].rotation.x = sin(anim + ph) * amp if moving else 0.0
	if freeze_t > 0.0:
		_body.position.y = 0.0
