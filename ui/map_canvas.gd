class_name MapCanvas
extends Control
## Оперативная карта (рисуется в _draw): Потомак, кольцевая, районы цветом, 25-мильная граница,
## маршрут и отметки наружки. Поверх булавок — прозрачные кнопки «site-<id>» для кликов и подсказок.

signal stop_clicked(site_id: String)

## Видимая часть карты в милях. Точки за краем (Лисберг) рисуются стрелкой на краю листа.
const VIEW := Rect2(5, 7, 36, 22)
const W := 1040.0
const DISTRICT_COLORS := [Color("#7a4f9e"), Color("#2f6f8f"), Color("#9a5a22"), Color("#4f7a3a"), Color("#a03b5a"), Color("#3b5a9e"), Color("#6f6f22"), Color("#555555")]

var route: Array = []
var target_id := ""
var selectable := false
## Сколько отрезков маршрута уже проехано на выезде (−1 — не едем).
var progress := -1
var marks := 0
var visited: Array = []
var k := W / VIEW.size.x


func _init(p_route: Array, p_target: String, p_selectable: bool, p_progress: int, p_marks: int, p_visited: Array) -> void:
	route = p_route
	target_id = p_target
	selectable = p_selectable
	progress = p_progress
	marks = p_marks
	visited = p_visited
	name = "map-canvas"
	clip_contents = true
	size = Vector2(W, VIEW.size.y * k)
	custom_minimum_size = size
	_add_pin_buttons()


static func district_color(district: String) -> Color:
	var i: int = Game.content.map.districts.keys().find(district)
	return DISTRICT_COLORS[maxi(i, 0) % DISTRICT_COLORS.size()]


func px(x: float, y: float) -> Vector2:
	return Vector2((x - VIEW.position.x) * k, (y - VIEW.position.y) * k)


func _clamped(s: Dictionary) -> Dictionary:
	var x: float = clampf(s.pos.x, VIEW.position.x + 0.5, VIEW.end.x - 0.5)
	var y: float = clampf(s.pos.y, VIEW.position.y + 0.5, VIEW.end.y - 0.5)
	return {"p": px(x, y), "clamped": x != s.pos.x or y != s.pos.y}


func _add_pin_buttons() -> void:
	for s in Game.content.map.sites:
		var c := _clamped(s)
		var b := Button.new()
		b.name = "site-" + s.site_id
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(32, 32)
		b.position = c.p - b.size / 2
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		var district := T.loc(Game.content.map.districts.get(s.district, {"ru": s.district}))
		b.tooltip_text = "%s · %s" % [T.loc(s.name), district]
		var clickable: bool = selectable and s.role == "stop"
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
		if clickable:
			b.pressed.connect(func(): stop_clicked.emit(s.site_id))
		add_child(b)


func _draw() -> void:
	var c: Dictionary = Game.content
	var paper := Color("#d8d6bc")
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	for gx in range(int(VIEW.position.x), int(VIEW.end.x) + 1, 2):
		draw_line(px(gx, VIEW.position.y), px(gx, VIEW.end.y), Color("#b9b79d"), 0.6)
	for gy in range(int(VIEW.position.y), int(VIEW.end.y) + 1, 2):
		draw_line(px(VIEW.position.x, gy), px(VIEW.end.x, gy), Color("#b9b79d"), 0.6)
	# Парки: Рок-Крик и Фокстон.
	_poly([[34.2, 10], [34.8, 12], [34.6, 14.5], [33.8, 17.2]], Color("#a9b88f", 0.8), k * 0.9)
	draw_set_transform(px(19.6, 17.6), 0, Vector2(1.6, 1.0))
	draw_circle(Vector2.ZERO, k, Color("#a9b88f", 0.7))
	draw_set_transform(Vector2.ZERO)
	# Потомак.
	_poly([[0, 9], [8, 8], [14, 9], [20, 10.5], [26, 13], [29, 15.5], [31.5, 17.6], [32.8, 18.4], [33.8, 21], [33.9, 24], [34.5, 30], [35, 32]], Color("#86a6b8"), k * 0.55)
	# Кольцевая I-495 и шоссе.
	var ring: Array = []
	for i in 65:
		var a := TAU * i / 64.0
		ring.append([31 + 9.5 * cos(a), 16.5 + 8.8 * sin(a)])
	_poly(ring, Color("#c49a5a", 0.85), 3)
	_poly([[0, 21], [15, 21], [24, 19.5], [31, 18.8]], Color("#c49a5a", 0.85), 3)
	_poly([[3, 11.5], [12, 13], [20, 16.5], [28, 20]], Color("#b7b59a"), 2.2)
	_poly([[31.4, 9], [32.9, 18.2]], Color("#b7b59a"), 2.2)

	# 25-мильная зона вокруг посольства.
	var embassy = MapGeo.site(c, c.balance.sdr.embassy_site)
	if embassy != null:
		var center := px(embassy.pos.x, embassy.pos.y)
		var r: float = k * float(c.balance.sdr.zone_radius_miles)
		var n := 240
		for i in n:
			if i % 2 == 0:
				var a0 := TAU * i / n
				var a1 := TAU * (i + 1) / n
				draw_line(center + Vector2(cos(a0), sin(a0)) * r, center + Vector2(cos(a1), sin(a1)) * r, Color("#8e2b22"), 2.5)
		var lx: float = center.x - r + 22
		draw_set_transform(Vector2(lx, center.y), -PI / 2)
		draw_string(Style.form(), Vector2(-80, 0), T.t("sdr.zoneLabel"), HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color("#8e2b22"))
		draw_set_transform(Vector2.ZERO)

	# Маршрут: посольство → 1 → 2 → 3 → цель. Пройденная часть — сплошной линией.
	var chain: Array = []
	if embassy != null:
		chain.append(embassy)
	for id in route:
		var s = MapGeo.site(c, id)
		if s != null:
			chain.append(s)
	var target = MapGeo.site(c, target_id) if target_id != "" else null
	if target != null:
		chain.append(target)
	for i in range(1, chain.size()):
		var a: Vector2 = _clamped(chain[i - 1]).p
		var b: Vector2 = _clamped(chain[i]).p
		var driven := i <= progress
		if driven:
			draw_line(a, b, Style.INK, 4)
		else:
			draw_dashed_line(a, b, Style.STAMP_RED if chain[i] == target else Color("#4a4436"), 2.5, 7)

	# Точки: остановки, цели, ориентиры.
	for role in ["stop", "target", "landmark"]:
		for s in c.map.sites:
			if s.role != role:
				continue
			var cl := _clamped(s)
			var p: Vector2 = cl.p
			var label := T.loc(s.name)
			match role:
				"landmark":
					var col := Style.STAMP_RED if s.kind == "embassy" else Style.US_BLUE
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -11), p + Vector2(11, 0), p + Vector2(0, 11), p + Vector2(-11, 0)]), col)
					_text(p + Vector2(13, 4), label.get_slice(",", 0), 13)
				"target":
					var active: bool = s.site_id == target_id
					draw_circle(p, 13 if active else 9, Color("#c9a227") if active else Color("#b59a4a"))
					draw_arc(p, 13 if active else 9, 0, TAU, 32, Style.INK, 2)
					if active:
						_text(p + Vector2(17, 5), label, 16, true)
				"stop":
					var order := route.find(s.site_id)
					var outside := embassy != null and not MapGeo.within_zone(c, s)
					var col := district_color(s.district)
					if cl.clamped:
						draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 0), p + Vector2(-4, -9), p + Vector2(-4, 9)]), col)
						_text(p + Vector2(14, -12), "« " + T.loc(c.map.districts.get(s.district, {"ru": s.district})), 13)
					var rad := 12.0 if order >= 0 else 8.0
					draw_circle(p, rad, Style.INK if order >= 0 else col)
					draw_arc(p, rad, 0, TAU, 32, Style.STAMP_RED if outside else Color("#f2eee2"), 3 if outside else 2)
					if order >= 0:
						draw_string(Style.form(true), p + Vector2(-5, 5), str(order + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Style.PAPER_LIGHT)

	# Отметки наружки ФБР — у мест, где резидент уже бывал, иначе у посольства.
	var anchors: Array = visited.map(func(id): return MapGeo.site(c, id)).filter(func(x): return x != null)
	if embassy != null:
		anchors.append(embassy)
	for i in marks:
		if anchors.is_empty():
			break
		var a: Vector2 = _clamped(anchors[i % anchors.size()]).p + Vector2(16 + (i % 2) * 10, -14 - (i / 2) * 9)
		draw_line(a - Vector2(7, 7), a + Vector2(7, 7), Color("#c0281c"), 3.5)
		draw_line(a + Vector2(7, -7), a + Vector2(-7, 7), Color("#c0281c"), 3.5)


func _poly(pts: Array, color: Color, width: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(px(p[0], p[1]))
	draw_polyline(out, color, width, true)


func _text(p: Vector2, text: String, size_px: int, bold := false) -> void:
	var f := Style.form(bold)
	# Обводка цветом бумаги, чтобы подпись читалась поверх линий.
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 4, Color("#d8d6bc"))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Style.INK)
