extends Node
## Smoke test (tools/smoke_test.sh): title, campaign map and codex, then a defense of every plane
## with the autoplay bot (build menu and hero panel on the first, the full eleven-hero menu and a
## Legendary hero on the last), a fast-forward to the bosses, an Endless run and a full win with the
## results screen. Saves screenshots.

var main: Node
var shots := "/tmp/dotp-shots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(shots)
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
	print("AUTOTEST shot ", name, " fps ", Engine.get_frames_per_second())


func _ff(seconds: float) -> void:
	var b: Battle = main.battle
	for i in int(seconds * 30.0):
		if b.state == Battle.WON or b.state == Battle.LOST:
			break
		b.simulate(1.0 / 30.0)


func _run() -> void:
	await _wait(30)
	await _shot("00_title")
	main.show_campaign()
	await _wait(5)
	await _shot("01_campaign")
	main.show_codex(0)
	await _wait(5)
	await _shot("02_codex_heroes")
	main.show_codex(1)
	await _wait(5)
	await _shot("03_codex_horde")
	main.show_campaign()
	await _wait(5)
	await _shot("04_campaign_modes")
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plane="):
			only = int(a.get_slice("=", 1))
	for p in Data.PLANES.size():
		if only >= 0 and p != only:
			continue
		main.start_battle(p)
		await _wait(3)
		var b: Battle = main.battle
		await _shot("p%d_start" % p)
		if p == 0:
			b.selected = 0
			await _wait(3)
			await _shot("p0_build_menu")
			b.build(0, "champion")
			b.build(1, "ember")
			b.build(2, "sage")
			b.selected = 1
			await _wait(3)
			await _shot("p0_hero_panel")
			b.selected = -1
		if p == Data.PLANES.size() - 1:
			b.selected = 0
			await _wait(3)
			await _shot("p6_build_menu")
			b.mana += 6000
			b.build(0, "marshal")
			b.build(1, "raptor")
			b.build(2, "tide")
			for k in 4:
				b.upgrade(1)
				b.upgrade(2)
			b.upgrade(0)
			b.selected = 1
			await _wait(3)
			await _shot("p6_hero_panel_legendary")
			b.selected = -1
			b.mana -= 6000
		b.autoplay = true
		b.mana += 400
		_ff(70.0 + p * 10.0)
		await _wait(20)
		await _shot("p%d_battle" % p)
		print("AUTOTEST plane %d wave %d lives %d towers %d enemies %d" % [p, b.wave_i, b.lives, b.towers.size(), b.enemies.size()])
		if p == Data.PLANES.size() - 1 or p == 1:
			# jump to the boss wave
			b.mana += 3000
			while b.wave_i < b.waves.size() and b.state != Battle.LOST:
				_ff(10.0)
				b.call_wave()
			_ff(25.0)
			b._cam_zoom = 0.65
			if b.boss:
				b._cam_target = b.boss.position
			b._update_camera()
			await _wait(10)
			await _shot("p%d_boss" % p)
			print("AUTOTEST boss %s alive %s lives %d" % [Data.PLANES[p].boss, b.boss != null, b.lives])
	# Endless on Kamigawa: past the campaign's length to the first Endless boss
	main.start_battle(1, Data.ENDLESS)
	await _wait(3)
	var be: Battle = main.battle
	be.autoplay = true
	be.mana += 3000
	while be.wave_i < 22 and be.state != Battle.LOST:
		_ff(10.0)
		be.call_wave()
	_ff(30.0)
	if be.boss:
		be._cam_zoom = 0.7
		be._cam_target = be.boss.position
		be._update_camera()
	await _wait(10)
	await _shot("95_endless")
	print("AUTOTEST endless wave %d lives %d towers %d boss %s" % [be.wave_i, be.lives, be.towers.size(), be.boss.kind if be.boss else "none"])
	be.lives = 0
	_ff(1.0)
	await get_tree().create_timer(2.5).timeout
	await _wait(5)
	await _shot("96_endless_results")
	# pause menu and a full win on the first plane
	main.start_battle(0)
	await _wait(3)
	main._pause()
	await _wait(3)
	await _shot("90_pause")
	main._resume()
	var b: Battle = main.battle
	b.autoplay = true
	b.mana += 2000
	_ff(900.0)
	print("AUTOTEST full run state %d lives %d" % [b.state, b.lives])
	await get_tree().create_timer(2.5).timeout
	await _wait(5)
	await _shot("91_results")
	print("AUTOTEST done")
	get_tree().quit()
