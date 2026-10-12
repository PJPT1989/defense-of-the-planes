class_name Portraits
extends Node
## Renders a portrait of every hero and every Phyrexian once at start-up (one off-screen
## render of all the models in a grid, then cut into pieces) for the build menu, the wave
## preview and the codex.

const CELL := 256
const COLS := 8

static var heroes := {}
static var foes := {}
static var done := false


static func generate(host: Node) -> void:
	if done:
		return
	var ids: Array = Data.TOWER_ORDER.duplicate()
	var kinds: Array = Data.ENEMIES.keys()
	var total := ids.size() + kinds.size()
	var rows := ceili(float(total) / COLS)
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL * COLS, CELL * rows)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.3
	root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -30, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.7, 0.8, 1.0)
	root.add_child(rim)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.environment = env
	root.add_child(cam)
	# each model sits in a 4-unit cell, seen from the front and a little above
	var spacing := 4.0
	cam.size = spacing * rows
	var w := spacing * COLS
	var h := spacing * rows
	var cells := []
	var n := 0
	for id in ids:
		var m: Dictionary = Models.tower(id, 1)
		var node := Node3D.new()
		var fig := Node3D.new()
		fig.rotation.y = 0.4
		node.add_child(fig)
		_mi(fig, m.figure, Vector3.ZERO)
		_mi(fig, m.arm, m.arm_pivot)
		if m.orbit:
			_mi(fig, m.orbit, Vector3.ZERO)
		cells.append([node, id, true, 1.45 if id != "grove" else 1.95])
	for k in kinds:
		var m: Dictionary = Models.enemy(k)
		var node := Node3D.new()
		var body := Node3D.new()
		body.rotation.y = -0.55
		node.add_child(body)
		_mi(body, m.body, Vector3(0, 0, 0))
		for l in m.limbs:
			_mi(body, l.mesh, l.pivot)
		var tall: float = {"mite": 0.5, "hound": 0.75, "drake": 0.6, "spitter": 0.75, "brood": 1.25, "colossus": 2.4, "walker": 2.0, "mother": 3.0}.get(k, 1.2)
		cells.append([node, k, false, tall])
	for c in cells:
		var node: Node3D = c[0]
		var col := n % COLS
		var row := n / COLS
		var s: float = 3.3 / c[3]
		node.scale = Vector3(s, s, s)
		node.rotation.x = deg_to_rad(-16)
		# x runs the other way because the camera looks back along +z
		node.position = Vector3(w * 0.5 - spacing * (col + 0.5), h * 0.5 - spacing * (row + 0.5) - c[3] * s * 0.5 + 0.1, 0)
		root.add_child(node)
		n += 1
	cam.position = Vector3(0, 0, -20)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	n = 0
	for c in cells:
		var col := n % COLS
		var row := n / COLS
		var piece := img.get_region(Rect2i(col * CELL, row * CELL, CELL, CELL))
		var tex := ImageTexture.create_from_image(piece)
		if c[2]:
			heroes[c[1]] = tex
		else:
			foes[c[1]] = tex
		n += 1
	vp.queue_free()
	done = true


static func _mi(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
