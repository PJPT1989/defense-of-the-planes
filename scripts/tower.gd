class_name Tower
extends Node3D
## One hero on a build spot: picks a target in range, turns to face it and attacks with a
## swing of the arm. Can be upgraded four times (levels 4 and 5 add a glowing crown), sold, set to aim at the first, strongest or last
## Phyrexian, and frozen for a while by Phyrexian oil.

const MODES := ["First", "Strongest", "Last"]

var id := ""
var def: Dictionary
var level := 0
var pad := 0
var battle: Node
var spent := 0
var mode := 0
var cool := 0.5
var oiled := 0.0
var kills := 0
## Damage and speed bonus from a Warmarshal's banner nearby (set by Battle every step).
var buff := 0.0
var _base: MeshInstance3D
var _fig: Node3D
var _arm: Node3D
var _orbit: Node3D
var _crown: Node3D
var _oil: MeshInstance3D
var _model: Dictionary
var _swing := 0.0
var _aim_yaw := 0.0
var _idle := 0.0
var _build_t := 0.0

static var _oil_mesh: Mesh


func setup(tid: String, b: Node, pad_index: int) -> void:
	id = tid
	def = Data.TOWERS[tid]
	battle = b
	pad = pad_index
	spent = def.cost[0]
	_aim_yaw = randf() * TAU
	_idle = randf() * 10.0
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_model = Models.tower(id, level)
	_base = MeshInstance3D.new()
	_base.mesh = _model.base
	_base.position.y = 0.1
	add_child(_base)
	_fig = Node3D.new()
	_fig.position.y = _model.fig_y + 0.1
	_fig.rotation.y = _aim_yaw
	add_child(_fig)
	var f := MeshInstance3D.new()
	f.mesh = _model.figure
	_fig.add_child(f)
	_arm = Node3D.new()
	_arm.position = _model.arm_pivot
	_fig.add_child(_arm)
	var a := MeshInstance3D.new()
	a.mesh = _model.arm
	_arm.add_child(a)
	_orbit = null
	if _model.orbit:
		_orbit = Node3D.new()
		var o := MeshInstance3D.new()
		o.mesh = _model.orbit
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_orbit.add_child(o)
		_fig.add_child(_orbit)
	_crown = null
	if _model.get("crown"):
		_crown = Node3D.new()
		var c := MeshInstance3D.new()
		c.mesh = _model.crown
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_crown.add_child(c)
		add_child(_crown)
	if _oil_mesh == null:
		var m := MeshKit.new()
		for k in 9:
			var ang := TAU * k / 9.0
			m.cyl(Vector3(cos(ang) * 0.32, 1.2, sin(ang) * 0.3), Vector3(cos(ang) * 0.36, 0.2 + (k % 3) * 0.2, sin(ang) * 0.34), 0.07, 0.02, Color(1, 1, 1, 0.95), 5)
		m.sphere(Vector3(0, 1.25, 0), Vector3(0.36, 0.2, 0.34), Color(1, 1, 1, 0.95), 10, 5)
		_oil_mesh = m.commit()
		_oil_mesh.surface_set_material(0, Game.mat_oil)
	_oil = MeshInstance3D.new()
	_oil.mesh = _oil_mesh
	_oil.visible = false
	_fig.add_child(_oil)
	_build_t = 0.35
	scale = Vector3.ONE * Level.MODEL_SCALE * 0.9


func range_now() -> float:
	return def.range[level]


const MAX_LEVEL := 4


func can_upgrade() -> bool:
	return level < MAX_LEVEL


func upgrade_cost() -> int:
	return def.cost[level + 1] if level < MAX_LEVEL else 0


func sell_value() -> int:
	return int(spent * 0.7)


func upgrade() -> void:
	spent += upgrade_cost()
	level += 1
	_build()


func get_oiled(t: float) -> void:
	oiled = maxf(oiled, t * (0.6 if level >= 2 else 1.0) * (0.7 if level >= 4 else 1.0))


func step(dt: float) -> void:
	_idle += dt
	if _build_t > 0.0:
		_build_t = maxf(_build_t - dt, 0.0)
		var s := 1.0 - _build_t / 0.35
		scale = Vector3(1, 0.4 + 0.6 * s, 1) * (0.9 + 0.1 * s) * Level.MODEL_SCALE
	if _crown:
		_crown.rotation.y += dt * 0.6
		_crown.position.y = sin(_idle * 0.9) * 0.05
	if _orbit:
		_orbit.rotation.y += dt * _model.orbit_spin
		_orbit.position.y = sin(_idle * 1.3) * 0.04
	_oil.visible = oiled > 0.0
	if oiled > 0.0:
		oiled -= dt
		_fig.rotation.z = sin(_idle * 2.0) * 0.04
		return
	_fig.rotation.z = 0.0
	cool -= dt
	var target: Enemy = battle.pick_target(self)
	if target:
		var to := target.global_position - global_position
		var want := atan2(to.x, to.z) + PI
		_aim_yaw = lerp_angle(_aim_yaw, want, minf(1.0, dt * 10.0))
	else:
		_aim_yaw += sin(_idle * 0.4) * dt * 0.3
	_fig.rotation.y = _aim_yaw
	# arm swing: wind back, strike forward, settle
	if _swing > 0.0:
		_swing = maxf(_swing - dt * 3.5, 0.0)
		var t := 1.0 - _swing
		var ang := -1.6 * sin(t * PI) if t < 0.5 else -1.6 * sin(t * PI) * 0.6
		_arm.rotation.x = -ang if id != "dragon" else ang * 0.4
		if id == "grove":
			_arm.rotation.x = -1.2 * sin(t * PI)
	else:
		_arm.rotation.x = lerpf(_arm.rotation.x, sin(_idle * 1.5) * 0.06, dt * 4.0)
	if cool <= 0.0 and target:
		cool = 1.0 / (def.rate[level] * (1.0 + buff * 0.5))
		_swing = 1.0
		battle.tower_attack(self, target)


## Where shots leave from, in world space.
func muzzle() -> Vector3:
	return _fig.global_transform * Vector3(_model.muzzle)
