extends Node3D
## Close look at some heroes at levels 1, 3 and 5 from the game's camera angle, from the front
## and from behind. Screenshots in /tmp/dotp-heroes.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --heroes=tide,marshal,raptor

func _ready() -> void:
	var ids := ["tide", "marshal", "raptor"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--heroes="):
			ids = Array(a.get_slice("=", 1).split(","))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.26, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 160, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	Game.set_gloss_sky(Data.PLANES[3])
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.36, 0.3)
	ground.material_override = gm
	add_child(ground)
	var figs := []
	for i in ids.size():
		for j in 3:
			var lv: int = [0, 2, 4][j]
			var m: Dictionary = Models.tower(ids[i], lv)
			var root := Node3D.new()
			root.position = Vector3(j * 3.0, 0, i * 3.2)
			root.scale = Vector3.ONE * Level.MODEL_SCALE
			add_child(root)
			_mi(root, m.base, Vector3(0, 0.1, 0))
			if m.get("crown"):
				_mi(root, m.crown, Vector3.ZERO)
			var fig := Node3D.new()
			fig.position = Vector3(0, m.fig_y + 0.1, 0)
			root.add_child(fig)
			_mi(fig, m.figure, Vector3.ZERO)
			_mi(fig, m.arm, m.arm_pivot)
			if m.orbit:
				_mi(fig, m.orbit, Vector3.ZERO)
			figs.append(fig)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34
	cam.environment = env
	var shots := "/tmp/dotp-heroes"
	DirAccess.make_dir_recursive_absolute(shots)
	var mid := Vector3(3.0, 1.0, (ids.size() - 1) * 1.6)
	var dist := 6.5 + ids.size() * 3.2
	for v in 2:
		for f in figs:
			f.rotation.y = 0.0 if v == 0 else PI
		var pitch := deg_to_rad(50.0)
		cam.position = mid + Vector3(0, sin(pitch), -cos(pitch)) * dist
		cam.look_at(mid)
		for k in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/heroes%d.png" % [shots, v])
	print("HEROES done")
	get_tree().quit()


func _mi(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
