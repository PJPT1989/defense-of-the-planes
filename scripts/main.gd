extends Node
## Runs the game: title screen over a battle the computer plays by itself, the campaign map of
## the seven planes, the codex of heroes and Phyrexians, how to play, the battle with its HUD,
## pause menu and results. Applies the graphics quality and hands over to the smoke test
## (--autotest), the balance simulation (--simtest) or the model lineup (--lineup).

var ui: CanvasLayer
var screen: Control
var battle: Battle
var hud: Hud
var plane := 0
var mode := Data.CAMPAIGN
var _fps_watch := -1.0
var _fps_frames := 0
var _demo_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	Game.quality_changed.connect(_apply_quality)
	get_tree().root.size_changed.connect(_apply_quality)
	_apply_quality()
	var args := OS.get_cmdline_user_args()
	if "--waves" in args:
		add_child(load("res://tools/waves.gd").new())
		return
	for a in args:
		if a.begins_with("--heroes"):
			add_child(load("res://tools/hero_check.gd").new())
			return
	if "--lineup" in args:
		add_child(load("res://tools/lineup.gd").new())
		return
	if "--simtest" in args:
		_simtest.call_deferred()
		return
	_start.call_deferred()


func _start() -> void:
	var cover := ColorRect.new()
	cover.color = Color(0.03, 0.02, 0.03)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(cover)
	var l := Ui.title("Defense of the Planes", 44)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(-300, -30)
	l.size = Vector2(600, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(l)
	await get_tree().process_frame
	await Portraits.generate(self)
	cover.queue_free()
	show_title()
	if "--autotest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(load("res://scripts/autotest.gd"))
		t.set("main", self)
		add_child(t)


# --- quality ------------------------------------------------------------------------------------

func _apply_quality() -> void:
	# Menus and HUD always draw at the window's own resolution so text stays sharp. The 3D view
	# draws at full resolution on High, up to 1080 lines on Medium and up to 720 on Low.
	var root := get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280, 720)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var lines := float(maxi(root.size.y, 1))
	match Game.quality:
		Game.HIGH:
			root.scaling_3d_scale = 1.0
			root.msaa_3d = Viewport.MSAA_4X
		Game.MEDIUM:
			root.scaling_3d_scale = minf(1.0, 1080.0 / lines)
			root.msaa_3d = Viewport.MSAA_2X
		_:
			root.scaling_3d_scale = minf(1.0, 720.0 / lines)
			root.msaa_3d = Viewport.MSAA_DISABLED
	if battle:
		battle.apply_quality()
	if screen and screen.has_meta("quality_button"):
		var b: Button = screen.get_meta("quality_button")
		if is_instance_valid(b):
			b.text = "GRAPHICS: " + Game.QUALITY_NAMES[Game.quality].to_upper()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("quality"):
		Game.cycle_quality()
		if hud:
			hud.announce("Graphics: " + Game.QUALITY_NAMES[Game.quality], 1.5)
	elif e.is_action_pressed("mute"):
		Game.toggle_mute()
	elif e.is_action_pressed("pause") and battle and not battle.demo and battle.state != Battle.WON and battle.state != Battle.LOST:
		if battle.targeting >= 0 or battle.selected >= 0:
			battle.cancel()
		elif battle.paused:
			_resume()
		else:
			_pause()


func _process(dt: float) -> void:
	if battle and battle.demo:
		# the title backdrop drifts slowly over the field
		_demo_t += dt
		battle._cam_zoom = 0.62
		battle._cam_target = Vector3(sin(_demo_t * 0.05) * 7.0, 0, 0.8 + cos(_demo_t * 0.04) * 2.5)
		battle._update_camera()
		if battle.state == Battle.WON or battle.state == Battle.LOST or battle.time > 600.0:
			_start_demo()
	# In the browser, drop to Low once if the first defense runs slowly.
	if battle and not battle.demo and battle.state == Battle.RUNNING and Game.web and not Game.quality_chosen and Game.quality != Game.LOW:
		if _fps_watch < 0.0:
			_fps_watch = 0.0
			_fps_frames = 0
		_fps_watch += dt
		_fps_frames += 1
		if _fps_watch > 6.0:
			if _fps_frames / _fps_watch < 24.0:
				Game.set_quality(Game.LOW, false)
				if hud:
					hud.announce("Low graphics for speed - L to change", 4.0)
			Game.quality_chosen = true


# --- screens ------------------------------------------------------------------------------------

func _new_screen(dim := 0.0) -> Control:
	if screen:
		screen.queue_free()
	screen = Control.new()
	screen.theme = Ui.theme()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(screen)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.01, 0.02, dim)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.add_child(shade)
	return screen


func _clear_battle() -> void:
	if hud:
		hud.queue_free()
		hud = null
	if battle:
		battle.queue_free()
		battle = null
	get_tree().paused = false


func _start_demo() -> void:
	_clear_battle()
	battle = Battle.new()
	battle.demo = true
	battle.autoplay = true
	add_child(battle)
	battle.setup(randi_range(0, Data.PLANES.size() - 1) if _demo_t > 0.0 else 1)
	battle.mana += 600
	battle.speed = 1
	_demo_t = 0.01


func show_title() -> void:
	if battle == null or not battle.demo:
		_start_demo()
	var s := _new_screen()
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.01, 0.02, 0.85))
	g.set_color(1, Color(0.02, 0.01, 0.02, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.75, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	s.add_child(grad)
	var v := VBoxContainer.new()
	v.position = Vector2(70, 90)
	v.add_theme_constant_override("separation", 12)
	s.add_child(v)
	var t1 := Ui.title("DEFENSE", 64)
	v.add_child(t1)
	var t2 := Ui.title("OF THE PLANES", 40)
	v.add_child(t2)
	v.add_child(Ui.wrap(Game.TAGLINE, 20, Game.PALE, 440))
	v.add_child(_gap(18))
	var buttons := [["CAMPAIGN", show_campaign], ["HEROES AND FOES", show_codex], ["HOW TO PLAY", show_howto]]
	for b in buttons:
		var btn := Ui.button(b[0], b[1], 20)
		btn.custom_minimum_size = Vector2(300, 52)
		v.add_child(btn)
	var q := Ui.button("GRAPHICS: " + Game.QUALITY_NAMES[Game.quality].to_upper(), func(): Game.cycle_quality(), 16)
	q.custom_minimum_size = Vector2(300, 44)
	s.set_meta("quality_button", q)
	v.add_child(q)
	var m := Ui.button("SOUND: " + ("OFF" if Game.muted else "ON"), func(): pass, 16)
	m.pressed.connect(func():
		Game.toggle_mute()
		m.text = "SOUND: " + ("OFF" if Game.muted else "ON"))
	m.custom_minimum_size = Vector2(300, 44)
	v.add_child(m)
	var foot := Ui.label("A fan-made game inspired by the March of the Machine story. Characters, art and text are original.", 14, Color(0.75, 0.7, 0.62))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(70, -40)
	s.add_child(foot)


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(1, h)
	return c


func show_campaign() -> void:
	if battle == null or not battle.demo:
		_start_demo()
	var s := _new_screen(0.55)
	var top := HBoxContainer.new()
	top.position = Vector2(40, 26)
	s.add_child(top)
	top.add_child(Ui.title("The Invasion", 40))
	var h := HBoxContainer.new()
	h.position = Vector2(40, 100)
	h.add_theme_constant_override("separation", 26)
	s.add_child(h)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	h.add_child(list)
	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(560, 520)
	h.add_child(detail)
	var first := 0
	for i in Data.PLANES.size():
		if Game.plane_open(i):
			first = i
	for i in Data.PLANES.size():
		var d: Dictionary = Data.PLANES[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(380, 62)
		b.disabled = not Game.plane_open(i)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  %d.  %s" % [i + 1, d.name.to_upper()]
		b.add_theme_font_size_override("font_size", 19)
		var stars := HBoxContainer.new()
		stars.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		stars.position = Vector2(-100, -11)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if Game.plane_open(i):
			for k in 3:
				var st := Ui.icon("star" if k < Game.stars[i] else "star_empty", 22)
				st.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stars.add_child(st)
		else:
			var lk := Ui.icon("lock", 22)
			lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stars.add_child(lk)
		b.add_child(stars)
		var idx := i
		b.pressed.connect(func():
			Game.play("click", -6.0)
			_fill_plane(detail, idx))
		list.add_child(b)
	var back := Ui.button("BACK", show_title, 16)
	back.custom_minimum_size = Vector2(380, 44)
	list.add_child(_gap(6))
	list.add_child(back)
	_fill_plane(detail, first)


func _fill_plane(detail: PanelContainer, i: int) -> void:
	for c in detail.get_children():
		c.queue_free()
	var d: Dictionary = Data.PLANES[i]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	detail.add_child(v)
	v.add_child(Ui.title(d.name, 36))
	v.add_child(Ui.label(d.place, 20, Color(0.85, 0.8, 0.7), Game.font_title))
	v.add_child(Ui.wrap(d.intro, 19, Game.PALE, 520))
	v.add_child(Ui.wrap(d.new, 17, Color(0.7, 0.88, 1.0), 520))
	v.add_child(Ui.label("Heroes", 18, Game.GOLD, Game.font_title_bold))
	var hrow := HBoxContainer.new()
	var heroes := Game.heroes_for(i)
	for id in heroes:
		var tr := _portrait(Portraits.heroes.get(id), 60 if heroes.size() <= 8 else 48)
		tr.tooltip_text = Data.TOWERS[id].name
		hrow.add_child(tr)
	v.add_child(hrow)
	v.add_child(Ui.label("The horde", 18, Color(1.0, 0.5, 0.45), Game.font_title_bold))
	var frow := HBoxContainer.new()
	for k in d.roster + [d.boss]:
		var tr := _portrait(Portraits.foes.get(k), 60)
		tr.tooltip_text = Data.ENEMIES[k].name
		frow.add_child(tr)
	v.add_child(frow)
	v.add_child(Ui.label("%d waves.  Starting mana %d." % [d.waves, d.mana], 16, Color(0.8, 0.76, 0.68)))
	var go := Ui.button("DEFEND " + d.name.to_upper(), func(): start_battle(i), 20)
	go.custom_minimum_size = Vector2(320, 54)
	go.disabled = not Game.plane_open(i)
	v.add_child(go)
	# the longer games for a bigger late game
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var long := Ui.button("LONG SIEGE: %d WAVES" % Data.wave_count(i, Data.LONG), func(): start_battle(i, Data.LONG), 16)
	long.tooltip_text = "Twice the waves, a boss halfway and a much stronger one at the end. Every foe joins in."
	long.custom_minimum_size = Vector2(255, 44)
	long.disabled = not Game.plane_open(i)
	row.add_child(long)
	var endless := Ui.button("ENDLESS", func(): start_battle(i, Data.ENDLESS), 16)
	endless.tooltip_text = "The horde never stops, and a boss comes every ten waves. How long can you hold?"
	endless.custom_minimum_size = Vector2(255, 44)
	endless.disabled = not Game.plane_open(i)
	row.add_child(endless)
	v.add_child(row)
	var rec := []
	if Game.long_won[i]:
		rec.append("Long Siege won")
	if Game.endless_best[i] > 0:
		rec.append("Endless record: %d waves" % Game.endless_best[i])
	if not rec.is_empty():
		v.add_child(Ui.label(".  ".join(rec) + ".", 15, Game.GOLD))


func _portrait(tex: Texture2D, s: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(s, s)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func show_codex(page := 0) -> void:
	if battle == null or not battle.demo:
		_start_demo()
	var s := _new_screen(0.7)
	s.add_child(_at(Ui.title("Heroes" if page == 0 else "The Phyrexian Horde", 38), Vector2(40, 22)))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 84)
	scroll.size = Vector2(1200, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var items: Array = Data.TOWER_ORDER if page == 0 else Data.ENEMIES.keys()
	for id in items:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(580, 150)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		h.add_child(_portrait(Portraits.heroes.get(id) if page == 0 else Portraits.foes.get(id), 120))
		var v := VBoxContainer.new()
		h.add_child(v)
		if page == 0:
			var d: Dictionary = Data.TOWERS[id]
			v.add_child(Ui.label(d.name, 22, Game.GOLD, Game.font_title_bold))
			v.add_child(Ui.label("%s.  Joins on %s." % [d.title, Data.PLANES[d.plane].name], 15, Color(0.8, 0.75, 0.65)))
			v.add_child(Ui.wrap(d.desc, 16, Game.PALE, 410))
			v.add_child(Ui.wrap(d.lore, 15, Color(0.75, 0.7, 0.62), 410))
		else:
			var d: Dictionary = Data.ENEMIES[id]
			v.add_child(Ui.label(d.name, 22, Color(1.0, 0.55, 0.5), Game.font_title_bold))
			var tags := "Life %d, speed %.1f" % [d.hp, d.speed]
			if d.armor >= 0.3:
				tags += ", heavy armour"
			if d.resist >= 0.3:
				tags += ", warded against magic"
			if d.get("fly", false):
				tags += ", flies"
			v.add_child(Ui.label(tags, 15, Color(0.8, 0.75, 0.65)))
			v.add_child(Ui.wrap(d.desc, 16, Game.PALE, 410))
		grid.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(Ui.button("HEROES", func(): show_codex(0), 16))
	row.add_child(Ui.button("THE HORDE", func(): show_codex(1), 16))
	row.add_child(Ui.button("BACK", show_title, 16))
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.position = Vector2(-420, 30)
	s.add_child(row)


func _at(c: Control, p: Vector2) -> Control:
	c.position = p
	return c


func show_howto() -> void:
	var s := _new_screen(0.72)
	var p := PanelContainer.new()
	p.position = Vector2(60, 50)
	p.custom_minimum_size = Vector2(760, 0)
	s.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Ui.title("How to play", 36))
	var lines := [
		"The Phyrexians pour out of the Realmbreaker's roots and march along the road to the sanctum. Every one that gets through costs lives. Lose all 20 and the plane falls.",
		"Click a glowing build spot and call a hero onto it. Heroes attack on their own. Click a hero to upgrade it (four times: the Exalted and Legendary levels are costly), change who it aims at, or sell it.",
		"Defeated Phyrexians give mana. Call the next wave early (N) for bonus mana.",
		"Armoured foes shrug off physical attacks (spears, shuriken, stones); warded knights resist magic (fire, time, lightning, roots). Spirit daggers ignore both. Flyers can only be hit by heroes that reach the sky.",
		"Oil Spitters freeze nearby heroes in glistening oil for a few seconds. Kill them first.",
		"Spells: Q Halo Burst (click a spot), E Stasis (stops every Phyrexian). Each has a cooldown.",
		"Keys: 1-9, 0 and - build on the selected spot, U upgrade, Del sell, T aim, Tab game speed, Esc pause, L graphics quality, M sound. Mouse wheel zooms, right-drag pans.",
		"Win a plane to open the next. Keep 18 or more lives for three stars. For a bigger late game, try the Long Siege (twice the waves) or Endless (a boss every ten waves) on any open plane.",
	]
	for l in lines:
		v.add_child(Ui.wrap(l, 18, Game.PALE, 720))
	v.add_child(Ui.button("BACK", show_title, 16))


# --- battle -------------------------------------------------------------------------------------

func start_battle(i: int, m := Data.CAMPAIGN) -> void:
	_clear_battle()
	plane = i
	mode = m
	if screen:
		screen.queue_free()
		screen = null
	battle = Battle.new()
	add_child(battle)
	battle.setup(i, m)
	battle.finished.connect(_on_finished)
	hud = Hud.new()
	ui.add_child(hud)
	hud.setup(battle)
	hud.pause_pressed.connect(_pause)
	_fps_watch = -1.0


func _pause() -> void:
	if battle == null:
		return
	battle.paused = true
	var s := _new_screen(0.6)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-160, -190)
	v.custom_minimum_size = Vector2(320, 0)
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	var t := Ui.title("Paused", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(Ui.button("RESUME", _resume, 18))
	v.add_child(Ui.button("RESTART", func(): start_battle(plane, mode), 18))
	var q := Ui.button("GRAPHICS: " + Game.QUALITY_NAMES[Game.quality].to_upper(), func(): Game.cycle_quality(), 16)
	s.set_meta("quality_button", q)
	v.add_child(q)
	var m := Ui.button("SOUND: " + ("OFF" if Game.muted else "ON"), func(): pass, 16)
	m.pressed.connect(func():
		Game.toggle_mute()
		m.text = "SOUND: " + ("OFF" if Game.muted else "ON"))
	v.add_child(m)
	v.add_child(Ui.button("LEAVE TO THE MAP", func():
		_clear_battle()
		show_campaign(), 16))


func _resume() -> void:
	if screen:
		screen.queue_free()
		screen = null
	if battle:
		battle.paused = false


func _on_finished(won: bool) -> void:
	await get_tree().create_timer(2.0).timeout
	if battle == null:
		return
	var stars := battle.stars_won() if won else 0
	var held := maxi(battle.wave_i - 1, 0)
	var record := false
	if won and mode == Data.CAMPAIGN:
		Game.record_win(plane, stars)
	elif won and mode == Data.LONG:
		Game.record_long(plane)
	elif mode == Data.ENDLESS:
		record = Game.record_endless(plane, held)
	var s := _new_screen(0.55)
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-320, -230)
	p.custom_minimum_size = Vector2(640, 0)
	s.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var final := won and mode == Data.CAMPAIGN and plane == Data.PLANES.size() - 1
	var title := ("The Mother Falls" if final else "%s Holds" % Data.PLANES[plane].name) if won else "%s Has Fallen" % Data.PLANES[plane].name
	if mode == Data.ENDLESS:
		title = "%d Waves Held" % held
	var t := Ui.title(title, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if won and mode == Data.CAMPAIGN:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for k in 3:
			row.add_child(Ui.icon("star" if k < stars else "star_empty", 54))
		v.add_child(row)
	var text := ""
	if mode == Data.ENDLESS:
		text = "%s held for %d waves against the endless horde. %d Phyrexians fell." % [Data.PLANES[plane].name, held, battle.stats.kills]
		text += " A new record!" if record else " Your record here: %d waves." % Game.endless_best[plane]
	elif won and mode == Data.LONG:
		text = "The Long Siege is broken. %d Phyrexians fell, %d got through." % [battle.stats.kills, battle.stats.leaked]
	elif final:
		text = "The Porcelain Mother breaks apart at the Realmbreaker's root, and the great tree withers on every plane at once. Where its roots tore through, new paths between the worlds are left glowing. The planes are free, and for the first time they are all connected."
	elif won:
		text = "The sanctum stands. %d Phyrexians fell, %d got through." % [battle.stats.kills, battle.stats.leaked]
	else:
		text = "The oil reached the sanctum. Try a different mix of heroes: armour, wards and flyers each need an answer."
	var tl := Ui.wrap(text, 19, Game.PALE, 600)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tl)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 10)
	if won and mode == Data.CAMPAIGN and plane < Data.PLANES.size() - 1:
		row2.add_child(Ui.button("NEXT: " + Data.PLANES[plane + 1].name.to_upper(), func(): start_battle(plane + 1), 17))
	row2.add_child(Ui.button("PLAY AGAIN" if won else "TRY AGAIN", func(): start_battle(plane, mode), 17))
	row2.add_child(Ui.button("MAP", func():
		_clear_battle()
		show_campaign(), 17))
	v.add_child(row2)


# --- balance simulation (headless) ---------------------------------------------------------------

func _simtest() -> void:
	var only := -1
	var mode := Data.CAMPAIGN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plane="):
			only = int(a.get_slice("=", 1))
		if a.begins_with("--mode="):
			mode = int(a.get_slice("=", 1))
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	for p in Data.PLANES.size():
		if only >= 0 and p != only:
			continue
		var b := Battle.new()
		add_child(b)
		b.setup(p, mode)
		var t1 := Time.get_ticks_msec()
		b.paused = true
		b.autoplay = true
		var steps := 0
		var last_w := 0
		while b.state != Battle.WON and b.state != Battle.LOST and steps < 4 * 60 * 60 * 30 and b.wave_i < 120:
			b.simulate(1.0 / 30.0)
			steps += 1
			if verbose and b.boss and steps % 300 == 0:
				print("    boss hp %d / %d dist %.1f / %.1f lives %d alive %d" % [b.boss.hp, b.boss.max_hp, b.boss.dist, b.level.road_len[b.boss.road], b.lives, b.enemies.size()])
			if verbose and b.wave_i != last_w:
				last_w = b.wave_i
				var tl := []
				for t in b.towers.values():
					tl.append("%s%d" % [t.id, t.level])
				print("  t=%4.0f wave %d lives %d mana %d alive %d towers %s" % [b.time, b.wave_i, b.lives, b.mana, b.enemies.size(), tl])
		var levels := [0, 0, 0, 0, 0]
		var kinds := {}
		for t in b.towers.values():
			levels[t.level] += 1
			kinds[t.id] = int(kinds.get(t.id, 0)) + 1
		print("SIM %s plane %d %-13s %s lives %2d waves %d/%d time %4.0fs towers %d (lv %s) mana left %d kills %d pads %d  sim %dms" % [Data.MODE_NAMES[mode], p, Data.PLANES[p].name,
			"WON " if b.state == Battle.WON else "LOST", b.lives, b.wave_i, b.waves.size(), b.time, b.towers.size(), levels, b.mana, b.stats.kills, b.level.pads.size(), Time.get_ticks_msec() - t1])
		print("    heroes %s" % [kinds])
		b.queue_free()
		await get_tree().process_frame
	get_tree().quit()
