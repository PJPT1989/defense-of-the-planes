extends Node3D
## Model check: every hero at all three levels and every Phyrexian in rows, screenshots in
## /tmp/dotp-lineup.   xvfb-run -a godot --path . --rendering-driver opengl3 -- --lineup

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	Game.set_gloss_sky(Data.PLANES[0])
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.4, 0.3)
	ground.material_override = gm
	add_child(ground)
	var x := 0.0
	for id in Data.TOWER_ORDER:
		for lv in 3:
			var m: Dictionary = Models.tower(id, lv)
			var root := Node3D.new()
			root.position = Vector3(x, 0, lv * 2.6)
			add_child(root)
			_mi(root, m.base, Vector3.ZERO)
			var fig := Node3D.new()
			fig.position = Vector3(0, m.fig_y, 0)
			fig.rotation.y = PI + 0.5
			root.add_child(fig)
			_mi(fig, m.figure, Vector3.ZERO)
			_mi(fig, m.arm, m.arm_pivot)
			if m.orbit:
				_mi(fig, m.orbit, Vector3.ZERO)
		x += 2.4
	var kinds := Data.ENEMIES.keys()
	x = 0.0
	for k in kinds:
		var e: Dictionary = Models.enemy(k)
		var root := Node3D.new()
		root.position = Vector3(x, e.fly, 9.0)
		root.rotation.y = PI + 0.6
		add_child(root)
		_mi(root, e.body, Vector3.ZERO)
		for l in e.limbs:
			_mi(root, l.mesh, l.pivot)
		x += 1.8 if not Data.ENEMIES[k].get("boss", false) else 3.0
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.environment = env
	var shots := "/tmp/dotp-lineup"
	DirAccess.make_dir_recursive_absolute(shots)
	await get_tree().process_frame
	var views := [[Vector3(4, 4.5, -3.5), Vector3(3.5, 1.0, 3)], [Vector3(13.5, 4.5, -3.5), Vector3(13, 1.0, 3)], [Vector3(6, 3.2, 3.5), Vector3(6, 0.6, 9)], [Vector3(16, 4.0, 3.0), Vector3(16, 1.0, 9)], [Vector3(8.5, 14, -6), Vector3(8.5, 0, 5)]]
	for i in views.size():
		cam.position = views[i][0]
		cam.look_at(views[i][1])
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/lineup%d.png" % [shots, i])
	print("LINEUP done")
	get_tree().quit()


func _mi(parent: Node3D, mesh: Mesh, at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
