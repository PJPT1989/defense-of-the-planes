class_name Hud
extends Control
## The battle HUD: lives, mana and wave counter, the "call next wave" button with a preview of
## what is coming, game speed and pause, the two spells, the hero build menu for an empty spot,
## the upgrade / sell panel for a hero, health bars over hurt Phyrexians, the boss bar and
## announcements. Keyboard: 1-8 build, U upgrade, Del sell, T target, N wave, Q/E spells,
## Tab speed, Esc pause.

signal pause_pressed

var battle: Battle
var _lives: Label
var _mana: Label
var _wave: Label
var _call: Button
var _call_note: Label
var _preview: HBoxContainer
var _speed: Button
var _spells: Array[Button] = []
var _spell_cd: Array = []
var _build: PanelContainer
var _build_buttons := {}
var _info: PanelContainer
var _info_box: VBoxContainer
var _tower: PanelContainer
var _tower_box: VBoxContainer
var _tower_for := -1
var _banner: Label
var _mid: VBoxContainer
var _right: HBoxContainer
var _spell_box: HBoxContainer
var _banner_t := 0.0
var _boss_seen := false
var _shown_for := -2
var _last_wave := -1
var _preview_for := -1
var _hover_hero := ""


func setup(b: Battle) -> void:
	battle = b
	theme = Ui.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_spells()
	_build = PanelContainer.new()
	_build.add_theme_stylebox_override("panel", Ui.panel_style())
	_build.visible = false
	add_child(_build)
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", Ui.panel_style(Color(0.04, 0.03, 0.04, 0.95)))
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box = VBoxContainer.new()
	_info.add_child(_info_box)
	add_child(_info)
	_tower = PanelContainer.new()
	_tower.add_theme_stylebox_override("panel", Ui.panel_style())
	_tower.visible = false
	_tower_box = VBoxContainer.new()
	_tower_box.add_theme_constant_override("separation", 6)
	_tower.add_child(_tower_box)
	add_child(_tower)
	_banner = Ui.title("", 46)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var d: Dictionary = Data.PLANES[battle.plane]
	announce("%s - %s" % [d.name, d.place], 3.5)


func _build_top() -> void:
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", Ui.panel_style(Ui.INK, Ui.EDGE, 8, 10))
	left.position = Vector2(12, 10)
	add_child(left)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	row.add_child(Ui.icon("heart", 24))
	_lives = Ui.label("20", 24, Game.PALE, Game.font_title_bold)
	row.add_child(_lives)
	row.add_child(_spacer(10))
	row.add_child(Ui.icon("mana", 24))
	_mana = Ui.label("0", 24, Color(0.7, 0.88, 1.0), Game.font_title_bold)
	row.add_child(_mana)
	row.add_child(_spacer(10))
	row.add_child(Ui.icon("wave", 24))
	_wave = Ui.label("", 22, Game.PALE, Game.font_title_bold)
	row.add_child(_wave)
	# the call-wave button and what is coming
	var mid := VBoxContainer.new()
	_mid = mid
	mid.custom_minimum_size = Vector2(300, 0)
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(mid)
	_call = Ui.button("CALL THE FIRST WAVE", func(): battle.call_wave(), 17)
	_call.tooltip_text = "Start the next wave now (N). Calling early earns bonus mana."
	mid.add_child(_call)
	_call_note = Ui.label("", 15, Color(0.85, 0.82, 0.75))
	_call_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_call_note)
	_preview = HBoxContainer.new()
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.add_theme_constant_override("separation", 4)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_preview)
	var right := HBoxContainer.new()
	_right = right
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	_speed = Ui.button("x1", func():
		battle.speed = battle.speed % 3 + 1, 18)
	_speed.tooltip_text = "Game speed (Tab)"
	_speed.custom_minimum_size = Vector2(64, 44)
	_speed.add_theme_font_override("font", Game.font_bold)
	_speed.add_theme_font_size_override("font_size", 20)
	right.add_child(_speed)
	var p := Ui.button("II", func(): pause_pressed.emit(), 18)
	p.tooltip_text = "Pause (Esc)"
	p.custom_minimum_size = Vector2(56, 44)
	right.add_child(p)


func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 1)
	return c


func _build_spells() -> void:
	var box := HBoxContainer.new()
	_spell_box = box
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for i in Battle.SPELLS.size():
		var s: Dictionary = Battle.SPELLS[i]
		var b := Ui.button("%s  %s" % [s.key, s.name.to_upper()], func(): battle.start_spell(i), 16)
		b.custom_minimum_size = Vector2(190, 58)
		b.tooltip_text = s.desc
		b.clip_contents = true
		var cd := Ui.icon("cooldown", 58)
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cd)
		box.add_child(b)
		_spells.append(b)
		_spell_cd.append(cd)


func announce(text: String, t := 2.5) -> void:
	_banner.text = text
	_banner_t = t


# --- every frame -------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if battle == null:
		return
	size = get_viewport_rect().size
	_mid.position = Vector2(size.x * 0.5 - _mid.size.x * 0.5, 8)
	_right.position = Vector2(size.x - _right.size.x - 12, 12)
	_spell_box.position = Vector2(14, size.y - _spell_box.size.y - 14)
	_banner.position = Vector2(0, size.y * 0.22)
	_banner.size = Vector2(size.x, 60)
	_lives.text = str(battle.lives)
	_lives.add_theme_color_override("font_color", Game.PALE if battle.lives > 8 else Color(1.0, 0.4, 0.35))
	_mana.text = str(battle.mana)
	_wave.text = "Wave %d / %d" % [battle.wave_i, battle.waves.size()]
	_speed.text = "x%d" % battle.speed
	var left := battle.waves.size() - battle.wave_i
	if left > 0 and battle.state != Battle.WON and battle.state != Battle.LOST:
		_call.visible = true
		if battle.state == Battle.PREP:
			_call.text = "CALL THE FIRST WAVE"
			_call_note.text = "Build heroes on the glowing spots, then press N"
		else:
			_call.text = "CALL WAVE %d" % (battle.wave_i + 1)
			_call_note.text = "in %ds  -  early: +%d mana" % [ceili(battle.wave_timer), int(battle.wave_timer * 1.5)]
		if _preview_for != battle.wave_i:
			_preview_for = battle.wave_i
			_fill_preview()
	else:
		_call.visible = false
		_call_note.text = ""
		_preview_for = -1
		for c in _preview.get_children():
			c.queue_free()
	if battle.wave_i != _last_wave:
		if battle.wave_i > 0:
			var last := battle.wave_i == battle.waves.size()
			announce("Final wave" if last else "Wave %d" % battle.wave_i, 2.0)
		_last_wave = battle.wave_i
	if battle.boss and not _boss_seen:
		_boss_seen = true
		announce(battle.boss.def.name, 3.0)
	for i in _spells.size():
		var cd: float = battle.spell_cd[i]
		var g: Ui.Glyph = _spell_cd[i]
		g.fill = 1.0 - cd / Battle.SPELLS[i].cd
		g.queue_redraw()
		_spells[i].disabled = cd > 0.0
		_spells[i].modulate = Color(1.3, 1.2, 0.9) if battle.targeting == i else Color.WHITE
	_banner_t -= dt
	_banner.modulate.a = clampf(_banner_t, 0.0, 1.0)
	_update_panels()
	queue_redraw()


func _fill_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	var p := battle.next_wave_preview()
	for k in p:
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", -6)
		var tr := TextureRect.new()
		tr.texture = Portraits.foes.get(k)
		tr.custom_minimum_size = Vector2(46, 46)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.tooltip_text = Data.ENEMIES[k].name + ": " + Data.ENEMIES[k].desc
		tr.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(tr)
		var l := Ui.label("x%d" % p[k], 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		_preview.add_child(box)


func _update_panels() -> void:
	var sel := battle.selected
	var has_tower := sel >= 0 and battle.towers.has(sel)
	var key: int = sel * 10 + (1 if has_tower else 0) + (0 if not has_tower else battle.towers[sel].level * 2 + 2)
	if key != _shown_for:
		_shown_for = key
		_build.visible = false
		_tower.visible = false
		_info.visible = false
		_hover_hero = ""
		if sel >= 0 and not has_tower:
			_open_build(sel)
		elif has_tower:
			_open_tower(sel)
	if _build.visible:
		for id in _build_buttons:
			var b: Button = _build_buttons[id]
			b.disabled = not battle.can_build(id)
		_place_near(_build, battle.level.pads[sel])
		if _info.visible:
			_info.position = _build.position + Vector2(_build.size.x + 8, 0)
			if _info.position.x + _info.size.x > size.x - 8:
				_info.position.x = _build.position.x - _info.size.x - 8
	if _tower.visible and has_tower:
		_place_near(_tower, battle.level.pads[sel])
		_refresh_tower()


func _place_near(c: Control, world: Vector3) -> void:
	var s := battle.camera.unproject_position(world + Vector3(0, 0.5, 0))
	var p := s + Vector2(60, -c.size.y * 0.5)
	if p.x + c.size.x > size.x - 10:
		p.x = s.x - 60 - c.size.x
	p.y = clampf(p.y, 110, size.y - c.size.y - 90)
	c.position = p


func _open_build(pad: int) -> void:
	for c in _build.get_children():
		c.queue_free()
	_build_buttons.clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_build.add_child(v)
	v.add_child(Ui.label("Call a hero", 20, Game.GOLD, Game.font_title_bold))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var n := 0
	for id in Game.heroes_for(battle.plane):
		n += 1
		var d: Dictionary = Data.TOWERS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 112)
		b.clip_contents = true
		b.tooltip_text = ""
		var key := n
		b.pressed.connect(func():
			if battle.build(pad, id):
				battle.selected = -1)
		b.mouse_entered.connect(func(): _show_info(id))
		b.mouse_exited.connect(func():
			if _hover_hero == id:
				_info.visible = false
				_hover_hero = ""
				battle.preview_range(""))
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 0)
		b.add_child(col)
		var tr := TextureRect.new()
		tr.texture = Portraits.heroes.get(id)
		tr.custom_minimum_size = Vector2(92, 76)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tr)
		var cost := HBoxContainer.new()
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Ui.icon("mana", 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.add_child(ic)
		var cl := Ui.label(str(d.cost[0]), 16, Color(0.75, 0.9, 1.0), Game.font_title_bold)
		cost.add_child(cl)
		col.add_child(cost)
		var kl := Ui.label(str(key), 12, Color(0.7, 0.65, 0.55))
		kl.position = Vector2(6, 2)
		b.add_child(kl)
		grid.add_child(b)
		_build_buttons[id] = b
	_build.visible = true
	_build.reset_size()


func _show_info(id: String) -> void:
	_hover_hero = id
	battle.preview_range(id)
	var d: Dictionary = Data.TOWERS[id]
	for c in _info_box.get_children():
		c.queue_free()
	_info_box.add_child(Ui.label(d.name, 22, Game.GOLD, Game.font_title_bold))
	_info_box.add_child(Ui.label(d.title, 15, Color(0.8, 0.75, 0.65)))
	_info_box.add_child(Ui.wrap(d.desc, 16, Game.PALE, 300))
	_info_box.add_child(Ui.wrap(_stat_line(d, 0), 15, Color(0.75, 0.9, 1.0), 300))
	_info_box.add_child(Ui.wrap(d.lore, 15, Color(0.75, 0.7, 0.62), 300))
	_info.visible = true
	_info.reset_size()


func _stat_line(d: Dictionary, lv: int) -> String:
	var t: String = {"phys": "physical", "magic": "magic", "true": "spirit (ignores armour)"}[d.type]
	var s := "Damage %d %s, %.1f per second, range %.1f" % [d.dmg[lv], t, d.rate[lv], d.range[lv]]
	if d.has("splash"):
		s += ", splash %.1f" % d.splash[lv]
	if d.has("slow"):
		s += ", slows %d%%" % int(d.slow[lv] * 100)
	if d.has("chain"):
		s += ", jumps to %d foes" % d.chain[lv]
	if d.has("root"):
		s += ", roots %.1fs" % d.root[lv]
	if d.has("multi") and d.multi[lv] > 1:
		s += ", two targets"
	if d.has("execute") and d.execute[lv] > 0.0:
		s += ", finishes foes under %d%%" % int(d.execute[lv] * 100)
	if d.has("burn"):
		s += ", burns %d/s" % int(d.burn[lv])
	if d.has("boss_bonus"):
		s += ", +%d%% vs champions" % int(d.boss_bonus[lv] * 100)
	if not d.air:
		s += ". Cannot hit flyers"
	return s + "."


func _open_tower(pad: int) -> void:
	_tower_for = pad
	for c in _tower_box.get_children():
		c.queue_free()
	var t: Tower = battle.towers[pad]
	var head := HBoxContainer.new()
	var tr := TextureRect.new()
	tr.texture = Portraits.heroes.get(t.id)
	tr.custom_minimum_size = Vector2(64, 64)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(tr)
	var names := VBoxContainer.new()
	names.add_child(Ui.label(t.def.name, 20, Game.GOLD, Game.font_title_bold))
	var stars := HBoxContainer.new()
	for i in 3:
		stars.add_child(Ui.icon("star" if i <= t.level else "star_empty", 18))
	names.add_child(stars)
	head.add_child(names)
	_tower_box.add_child(head)
	_tower_box.add_child(Ui.wrap(_stat_line(t.def, t.level), 15, Color(0.75, 0.9, 1.0), 290))
	if t.can_upgrade():
		var up := Ui.button("UPGRADE  (%d)" % t.upgrade_cost(), func(): battle.upgrade(pad), 15)
		up.name = "Upgrade"
		up.tooltip_text = "Level %d: %s (U)" % [t.level + 2, _stat_line(t.def, t.level + 1)]
		_tower_box.add_child(up)
	else:
		_tower_box.add_child(Ui.label("Fully upgraded", 15, Game.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tgt := Ui.button("AIM: " + Tower.MODES[t.mode].to_upper(), func():
		t.mode = (t.mode + 1) % Tower.MODES.size()
		_shown_for = -2, 14)
	tgt.name = "Target"
	tgt.tooltip_text = "Which Phyrexian to attack first (T)"
	row.add_child(tgt)
	var sell := Ui.button("SELL  +%d" % t.sell_value(), func(): battle.sell(pad), 14)
	sell.tooltip_text = "Send the hero home for 70% of the mana spent (Del)"
	row.add_child(sell)
	_tower_box.add_child(row)
	_tower.visible = true
	_tower.reset_size()


func _refresh_tower() -> void:
	var t: Tower = battle.towers.get(_tower_for)
	if t == null:
		return
	var up := _tower_box.get_node_or_null("Upgrade") as Button
	if up:
		up.disabled = battle.mana < t.upgrade_cost()


# --- keys --------------------------------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if battle == null or battle.paused or battle.demo:
		return
	if e.is_action_pressed("next_wave"):
		battle.call_wave()
	elif e.is_action_pressed("speed"):
		battle.speed = battle.speed % 3 + 1
	elif e.is_action_pressed("spell1"):
		battle.start_spell(0)
	elif e.is_action_pressed("spell2"):
		battle.start_spell(1)
	elif e.is_action_pressed("upgrade") and battle.selected >= 0:
		battle.upgrade(battle.selected)
	elif e.is_action_pressed("sell") and battle.selected >= 0:
		battle.sell(battle.selected)
	elif e.is_action_pressed("target") and battle.towers.has(battle.selected):
		var t: Tower = battle.towers[battle.selected]
		t.mode = (t.mode + 1) % Tower.MODES.size()
		_shown_for = -2
	else:
		for i in 8:
			if e.is_action_pressed("build%d" % (i + 1)) and battle.selected >= 0 and not battle.towers.has(battle.selected):
				var heroes := Game.heroes_for(battle.plane)
				if i < heroes.size() and battle.build(battle.selected, heroes[i]):
					battle.selected = -1


# --- health bars --------------------------------------------------------------------------------

func _draw() -> void:
	if battle == null:
		return
	var cam := battle.camera
	for e in battle.enemies:
		if not e.alive or e.boss:
			continue
		var top := e.global_position + Vector3(0, e.size * 1.25 + 0.15, 0)
		if cam.is_position_behind(top):
			continue
		var s := cam.unproject_position(top)
		var w := 22.0 + e.size * 16.0
		var f := clampf(e.hp / e.max_hp, 0.0, 1.0)
		if f >= 0.999 and e.slow_t <= 0.0 and e.root_t <= 0.0:
			continue
		draw_rect(Rect2(s.x - w * 0.5 - 1, s.y - 1, w + 2, 6), Color(0, 0, 0, 0.75))
		var col := Color(0.9, 0.15, 0.12).lerp(Color(0.95, 0.85, 0.3), f)
		if e.root_t > 0.0:
			col = Color(0.5, 0.95, 0.35)
		elif e.slow_t > 0.0:
			col = Color(0.45, 0.8, 1.0)
		draw_rect(Rect2(s.x - w * 0.5, s.y, w * f, 4), col)
	if battle.boss and battle.boss.alive:
		var b := battle.boss
		var w := 460.0
		var x := size.x * 0.5 - w * 0.5
		var y := size.y - 52.0
		draw_rect(Rect2(x - 3, y - 3, w + 6, 20), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x, y, w * clampf(b.hp / b.max_hp, 0, 1), 14), Color(0.85, 0.1, 0.12))
		draw_rect(Rect2(x - 3, y - 3, w + 6, 20), Game.GOLD, false, 1.5)
		var f := Game.font_title_bold
		var label: String = b.def.name
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string_outline(f, Vector2(size.x * 0.5 - tw * 0.5, y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(size.x * 0.5 - tw * 0.5, y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Game.GOLD)
	if battle.targeting >= 0:
		var m := get_local_mouse_position()
		draw_arc(m, 34, 0, TAU, 40, Color(0.6, 0.9, 1.0, 0.8), 2.0, true)
