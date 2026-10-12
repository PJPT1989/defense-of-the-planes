class_name Ui
extends RefCounted
## Shared look for menus and HUD: the theme (dark obsidian panels with gold edges), label and
## button helpers, and small vector icons (heart, mana crystal, star, wave horn) drawn in code
## because the web fonts have no symbols.

const INK := Color(0.05, 0.04, 0.05, 0.9)
const EDGE := Color(0.95, 0.78, 0.42, 0.55)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = Game.font_body
	t.default_font_size = 18
	var normal := _box(Color(0.09, 0.07, 0.08, 0.92), EDGE, 2, 6)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.2, 0.14, 0.1, 0.95)
	hover.border_color = Game.GOLD
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.35, 0.08, 0.08, 0.95)
	pressed.border_color = Color(1.0, 0.5, 0.4)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.06, 0.05, 0.05, 0.75)
	disabled.border_color = Color(0.4, 0.35, 0.3, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_font("font", "Button", Game.font_title_bold)
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Button", Color(0.96, 0.92, 0.82))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	var panel := _box(INK, Color(EDGE, 0.4), 1, 8)
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_color("font_color", "Label", Game.PALE)
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s


static func panel_style(bg := INK, border := EDGE, radius := 8, pad := 14) -> StyleBoxFlat:
	var s := _box(bg, border, 1, radius)
	s.set_content_margin_all(pad)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func label(text: String, size := 18, col := Game.PALE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func wrap(text: String, size := 17, col := Game.PALE, width := 360.0) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func title(text: String, size := 40) -> Label:
	var l := label(text, size, Game.GOLD, Game.font_title_bold)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func button(text: String, cb: Callable, size := 16) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Game.play("click", -6.0)
		cb.call())
	return b


static func icon(kind: String, size := 22.0, col := Color.WHITE) -> Glyph:
	var g := Glyph.new()
	g.kind = kind
	g.col = col
	g.custom_minimum_size = Vector2(size, size)
	return g


## Draws small icons with polygons.
class Glyph extends Control:
	var kind := "heart"
	var col := Color.WHITE
	var fill := 1.0

	func _draw() -> void:
		var s := size
		var c := s * 0.5
		var r := minf(s.x, s.y) * 0.5
		match kind:
			"heart":
				var pts := PackedVector2Array()
				for i in 32:
					var t := TAU * i / 32.0
					var x := 16.0 * pow(sin(t), 3)
					var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
					pts.append(c + Vector2(x, y) * r / 17.0)
				draw_colored_polygon(pts, Color(0.85, 0.12, 0.15))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 0.6, 0.55, 0.8), 1.2, true)
			"mana":
				var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.62, -r * 0.2), c + Vector2(0, r), c + Vector2(-r * 0.62, -r * 0.2)])
				draw_colored_polygon(pts, Color(0.3, 0.6, 1.0))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.62, -r * 0.2), c + Vector2(0, -r * 0.05)]), Color(0.7, 0.9, 1.0))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 0.95, 1.0), 1.2, true)
			"star", "star_empty":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI * 0.5 + TAU * i / 10.0
					pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
				if kind == "star":
					draw_colored_polygon(pts, Game.GOLD)
				else:
					draw_colored_polygon(pts, Color(0.2, 0.18, 0.16, 0.8))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 0.9, 0.6, 0.9) if kind == "star" else Color(0.6, 0.55, 0.45, 0.7), 1.3, true)
			"wave":
				# a Phyrexian sigil: a circle split by a vertical line
				draw_arc(c, r * 0.72, 0, TAU, 32, Color(0.95, 0.9, 0.85), 2.5, true)
				draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(0.95, 0.9, 0.85), 2.5, true)
				draw_circle(c, r * 0.18, Color(0.9, 0.15, 0.15))
			"pause":
				draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.4, r * 1.4)), col)
				draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.7), Vector2(r * 0.4, r * 1.4)), col)
			"play":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.7), c + Vector2(r * 0.7, 0), c + Vector2(-r * 0.5, r * 0.7)]), col)
			"lock":
				draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.1), Vector2(r * 1.2, r * 0.9)), Color(0.6, 0.55, 0.5))
				draw_arc(c + Vector2(0, -r * 0.1), r * 0.4, PI, TAU, 16, Color(0.6, 0.55, 0.5), 3.0, true)
			"cooldown":
				if fill < 1.0:
					var pts := PackedVector2Array([c])
					var steps := 40
					for i in steps + 1:
						var a := -PI * 0.5 + TAU * (fill + (1.0 - fill) * i / steps)
						pts.append(c + Vector2(cos(a), sin(a)) * r * 1.5)
					draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
