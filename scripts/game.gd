extends Node
## Autoload `Game`: settings (graphics quality, sound, game speed), campaign progress (stars per
## plane), fonts, the shared materials and the generated sound effects.

signal quality_changed

enum { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["Low", "Medium", "High"]
const SETTINGS_PATH := "user://settings.cfg"
const PROGRESS_PATH := "user://progress.cfg"

const TITLE := "Defense of the Planes"
const TAGLINE := "The machines have come for every world. Hold the line."

const GOLD := Color(0.95, 0.78, 0.42)
const PALE := Color(0.95, 0.92, 0.84)
const BLOOD := Color(0.86, 0.12, 0.16)
const HALO := Color(0.55, 0.9, 1.0)

var quality := MEDIUM
var quality_chosen := false
var muted := false
var web := false
## Stars won on each plane (0 = not won yet). Plane i is open when plane i-1 is won.
var stars: Array[int] = []
var font_title: FontVariation
var font_title_bold: FontVariation
var font_body: Font
var font_bold: Font
var mat_solid: StandardMaterial3D
var mat_glow: ShaderMaterial
var mat_gloss: ShaderMaterial
var mat_oil: ShaderMaterial
var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played := {}


func _ready() -> void:
	web = OS.has_feature("web") or "--web" in OS.get_cmdline_user_args()
	quality = MEDIUM if web else HIGH
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		if cfg.has_section_key("video", "quality"):
			quality = clampi(int(cfg.get_value("video", "quality")), LOW, HIGH)
			quality_chosen = true
		muted = bool(cfg.get_value("audio", "muted", false))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			quality = clampi(int(a.get_slice("=", 1)), LOW, HIGH)
			quality_chosen = true
	_load_progress()
	font_title = _font("res://fonts/Cinzel.ttf", 700)
	font_title_bold = _font("res://fonts/Cinzel.ttf", 900)
	font_body = load("res://fonts/AlegreyaSans-Regular.ttf")
	font_bold = load("res://fonts/AlegreyaSans-Bold.ttf")
	mat_solid = StandardMaterial3D.new()
	mat_solid.vertex_color_use_as_albedo = true
	mat_solid.roughness = 0.72
	mat_solid.metallic_specular = 0.4
	mat_glow = ShaderMaterial.new()
	mat_glow.shader = load("res://shaders/glow.gdshader")
	mat_gloss = ShaderMaterial.new()
	mat_gloss.shader = load("res://shaders/gloss.gdshader")
	mat_oil = ShaderMaterial.new()
	mat_oil.shader = load("res://shaders/oil.gdshader")
	_setup_input()
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_sounds()
	AudioServer.set_bus_mute(0, muted)


func _setup_input() -> void:
	var keys := {
		"pause": [KEY_ESCAPE, KEY_P], "quality": [KEY_L], "mute": [KEY_M], "next_wave": [KEY_N, KEY_ENTER],
		"speed": [KEY_TAB, KEY_F], "spell1": [KEY_Q], "spell2": [KEY_E],
		"pan_left": [KEY_A, KEY_LEFT], "pan_right": [KEY_D, KEY_RIGHT], "pan_up": [KEY_W, KEY_UP], "pan_down": [KEY_S, KEY_DOWN],
		"upgrade": [KEY_U], "sell": [KEY_DELETE, KEY_BACKSPACE], "target": [KEY_T]}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for i in 8:
		var a := "build%d" % (i + 1)
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var e := InputEventKey.new()
		e.physical_keycode = KEY_1 + i
		InputMap.action_add_event(a, e)


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {"wght": weight}
	return f


## Points the porcelain and oil reflections at a plane's sky.
func set_gloss_sky(d: Dictionary) -> void:
	mat_gloss.set_shader_parameter("sky_top", d.sky_top)
	mat_gloss.set_shader_parameter("sky_horizon", d.sky_horizon)
	mat_gloss.set_shader_parameter("sky_ground", d.ground)


func set_quality(q: int, save := true) -> void:
	quality = clampi(q, LOW, HIGH)
	if save:
		quality_chosen = true
		_save()
	quality_changed.emit()


func cycle_quality() -> void:
	set_quality((quality + 1) % 3)


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_save()


func _testing() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--autotest" in args or "--bench" in args or "--simtest" in args


func _save() -> void:
	if _testing():
		return
	var cfg := ConfigFile.new()
	if quality_chosen:
		cfg.set_value("video", "quality", quality)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)


# --- campaign progress -------------------------------------------------------------

func _load_progress() -> void:
	stars.clear()
	for i in Data.PLANES.size():
		stars.append(0)
	if _testing():
		return
	var cfg := ConfigFile.new()
	if cfg.load(PROGRESS_PATH) == OK:
		for i in Data.PLANES.size():
			stars[i] = clampi(int(cfg.get_value("stars", Data.PLANES[i].id, 0)), 0, 3)


func record_win(plane: int, won_stars: int) -> void:
	stars[plane] = maxi(stars[plane], won_stars)
	if _testing():
		return
	var cfg := ConfigFile.new()
	for i in Data.PLANES.size():
		cfg.set_value("stars", Data.PLANES[i].id, stars[i])
	cfg.save(PROGRESS_PATH)


func plane_open(i: int) -> bool:
	return i == 0 or stars[i - 1] > 0


## Heroes that answer the call on plane i: the starting three plus one more per plane.
func heroes_for(plane: int) -> Array:
	var out := []
	for id in Data.TOWER_ORDER:
		if Data.TOWERS[id].plane <= plane:
			out.append(id)
	return out


# --- sound ---------------------------------------------------------------------------

func play(name: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not sounds.has(name):
		return
	# the same sound at most every 40 ms, so a volley does not stack into one loud click
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 40:
		return
	_last_played[name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = sounds[name]
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


func make_wav(dur: float, gen: Callable, rate := 22050) -> AudioStreamWAV:
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var p := float(i) / n
		var env := pow(1.0 - p, 1.6) * minf(1.0, i / 60.0)
		var v: float = gen.call(float(i) / rate, p) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


func _noise(cut: float) -> Callable:
	var st := [0.0]
	return func(_t: float, _p: float) -> float:
		st[0] += (randf() * 2.0 - 1.0 - st[0]) * cut
		return st[0] / sqrt(cut) * 0.5


func _build_sounds() -> void:
	if "--simtest" in OS.get_cmdline_user_args():
		return
	var n1 := _noise(0.3)
	sounds["spear"] = make_wav(0.35, func(t, p): return sin(TAU * (1400.0 - 900.0 * p) * t) * 0.25 + n1.call(t, p) * 0.12)
	var n2 := _noise(0.12)
	sounds["fire"] = make_wav(0.5, func(t, p): return n2.call(t, p) * 0.9 + sin(TAU * (180.0 - 80.0 * p) * t) * 0.2)
	sounds["chime"] = make_wav(0.6, func(t, _p): return (sin(TAU * 880.0 * t) + sin(TAU * 1318.5 * t) * 0.6 + sin(TAU * 1760.0 * t) * 0.3) * 0.16)
	var n3 := _noise(0.6)
	sounds["shuriken"] = make_wav(0.12, func(t, p): return n3.call(t, p) * 0.4 + sin(TAU * 2200.0 * t) * 0.08)
	var n4 := _noise(0.04)
	sounds["rock"] = make_wav(0.45, func(t, p): return n4.call(t, p) * 1.6 + sin(TAU * (90.0 - 40.0 * p) * t) * 0.5)
	var n5 := _noise(0.9)
	sounds["zap"] = make_wav(0.35, func(t, p): return (n5.call(t, p) * 0.5 + signf(sin(TAU * 120.0 * t)) * 0.12) * (0.6 + 0.4 * sin(TAU * 31.0 * t)))
	sounds["ghost"] = make_wav(0.45, func(t, p): return sin(TAU * (520.0 + 160.0 * sin(TAU * 7.0 * t)) * t) * 0.2 * (1.0 - p))
	var n6 := _noise(0.03)
	sounds["roots"] = make_wav(0.7, func(t, p): return n6.call(t, p) * 1.5 + sin(TAU * 55.0 * t) * 0.4)
	var n7 := _noise(0.25)
	sounds["crunch"] = make_wav(0.28, func(t, p): return n7.call(t, p) * 0.8 * (1.0 if fposmod(t * 40.0, 1.0) < 0.6 else 0.3))
	var n8 := _noise(0.08)
	sounds["splat"] = make_wav(0.3, func(t, p): return n8.call(t, p) * 0.9 + sin(TAU * (140.0 - 60.0 * p) * t) * 0.3)
	sounds["leak"] = make_wav(0.6, func(t, p): return signf(sin(TAU * (220.0 if p < 0.5 else 165.0) * t)) * 0.18)
	sounds["horn"] = make_wav(1.6, func(t, p): return (sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 165.0 * t) * 0.3 + sin(TAU * 220.0 * t) * 0.15) * minf(1.0, p * 6.0) * 0.8)
	var n9 := _noise(0.5)
	sounds["build"] = make_wav(0.4, func(t, p): return n9.call(t, p) * (1.0 if fposmod(t * 9.0, 1.0) < 0.25 else 0.1) * 0.8 + sin(TAU * 300.0 * t) * 0.1)
	sounds["upgrade"] = make_wav(0.7, func(t, p): return sin(TAU * (523.3 if p < 0.33 else (659.3 if p < 0.66 else 784.0)) * t) * 0.25)
	sounds["coin"] = make_wav(0.3, func(t, p): return sin(TAU * (1568.0 if p < 0.3 else 2093.0) * t) * 0.18)
	sounds["click"] = make_wav(0.06, func(t, _p): return sin(TAU * 1200.0 * t) * 0.25)
	var n10 := _noise(0.02)
	sounds["burst"] = make_wav(1.2, func(t, p): return n10.call(t, p) * 1.8 + sin(TAU * (60.0 + 200.0 * (1.0 - p)) * t) * 0.35)
	sounds["stasis"] = make_wav(1.0, func(t, p): return sin(TAU * (1200.0 - 900.0 * p) * t) * 0.15 + sin(TAU * (600.0 - 450.0 * p) * t) * 0.15)
	sounds["oil"] = make_wav(0.4, func(t, p): return sin(TAU * (300.0 - 200.0 * p) * t) * 0.3 * (0.5 + 0.5 * sin(TAU * 25.0 * t)))
	sounds["boss"] = make_wav(2.0, func(t, p): return (sin(TAU * 55.0 * t) * 0.6 + sin(TAU * 58.0 * t) * 0.4 + n10.call(t, p) * 0.5) * minf(1.0, p * 4.0))
	sounds["win"] = make_wav(1.8, func(t, p): return (sin(TAU * [392.0, 523.3, 659.3, 784.0][mini(int(p * 5.0), 3)] * t) * 0.3 + sin(TAU * 196.0 * t) * 0.1))
	sounds["lose"] = make_wav(1.8, func(t, p): return (sin(TAU * [220.0, 207.7, 196.0, 146.8][mini(int(p * 4.0), 3)] * t) * 0.3))
