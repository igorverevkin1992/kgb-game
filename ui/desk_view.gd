class_name DeskView
## Кабинет на сцене 1600×900: стена (0–300) и стол (300–900). Предметы — кнопки:
## клик открывает модуль. Координаты — в пикселях сцены (окончательная раскладка, арт — шаг 9).

## Прямоугольники предметов: name → [x, y, w, h, поворот°, svg].
const OBJECTS := {
	"mice": [380, 26, 680, 260, 0.0, "corkboard"],
	"counterintel": [1110, 30, 250, 250, 0.0, "console"],
	"map": [50, 360, 520, 416, -2.5, "map"],
	"cipher": [620, 330, 300, 290, 0.0, "fialka"],
	"inbox": [610, 650, 290, 222, 0.0, "inbox"],
	"finance": [950, 560, 230, 280, 5.0, "ledger"],
	"dialog": [1230, 590, 320, 260, 0.0, "recorder"],
}


static func build() -> Control:
	var room := Control.new()
	room.name = "room"
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(Style.gradient(Style.WALL, Style.WALL_DARK, Rect2(0, 0, 1600, 300)))
	room.add_child(Style.gradient(Style.VENEER_LIGHT, Style.VENEER_DARK, Rect2(0, 300, 1600, 600)))
	room.add_child(Style.rect(Color("#6b4f35"), Rect2(0, 300, 1600, 6)))
	room.add_child(Style.art("window", Rect2(1400, 30, 170, 230)))
	room.add_child(Style.art("lamp", Rect2(1000, 322, 150, 190)))
	room.add_child(_plaque())
	for v in OBJECTS:
		room.add_child(_object(v))
	room.add_child(_lamp_light())
	room.add_child(Calendar.build())
	return room


static func _plaque() -> Control:
	var b := Button.new()
	b.name = "plaque"
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(40, 40)
	b.size = Vector2(300, 112)
	b.tooltip_text = T.t("service.title")
	var sb := Style.box(Color("#7d6a40"), Color("#5e4e2c"), 2, 0, 14)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb if s != "hover" else Style.box(Color("#8f7a4a"), Color("#5e4e2c"), 2, 0, 14))
	b.pressed.connect(Game.open_service)
	var v := Style.vbox(2)
	v.position = Vector2(16, 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(Style.label(T.t("game.title").to_upper(), Style.form(true), 22, Color("#1f1a0f"), false))
	var act := Style.label("%s · %s" % [T.t("game.subtitle"), T.t("desk.act", {"act": Game.act()})], Style.form(), 14, Color("#1f1a0f"), false)
	act.name = "act"
	v.add_child(act)
	v.add_child(Style.label("%s  [Esc]" % T.t("service.title"), Style.form(), 13, Color(0.12, 0.1, 0.06, 0.7), false))
	b.add_child(v)
	return b


static func _object(v: String) -> Control:
	var o: Array = OBJECTS[v]
	var unlocked := Game.is_unlocked(v)
	var b := Button.new()
	b.name = "desk-object-" + v
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(o[0], o[1])
	b.size = Vector2(o[2], o[3])
	b.rotation_degrees = o[4]
	b.pivot_offset = b.size / 2
	b.disabled = not unlocked
	b.tooltip_text = T.t(_key(v, "object"))
	b.flat = true
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.pressed.connect(Game.open.bind(v))
	var tex := Style.art(o[5] if not (v == "inbox" and Cipher.unread_mail(Game.state, Game.content).size() > 0) else "inbox_full", Rect2(Vector2.ZERO, b.size))
	if not unlocked:
		tex.modulate = Color(0.45, 0.45, 0.42)
	b.add_child(tex)
	b.mouse_entered.connect(func(): if not b.disabled: tex.modulate = Color(1.12, 1.12, 1.1))
	b.mouse_exited.connect(func(): if not b.disabled: tex.modulate = Color.WHITE)
	if v == "map":
		b.add_child(SogMarks.new(Signals.sog_marks(Game.state.risks.sog_heat), b.size))
	if v == "mice":
		var cork := Shells.CorkTexture.new(b.size - Vector2(24, 24))
		cork.position = Vector2(12, 12)
		b.add_child(cork)
		b.add_child(CorkCards.new(Game.state.targets.values().filter(func(t): return t.unlocked).size(), b.size))
	if v == "mice":
		var fresh := Campaign.unpinned_clues(Game.state, Game.content).size()
		if fresh > 0:
			var nb := Style.panel(Style.STAMP_RED, 6)
			nb.name = "board-new"
			nb.position = Vector2(b.size.x - 60, 24)
			nb.add_child(Style.label(str(fresh), Style.form(true), 20, Style.PAPER_LIGHT, false))
			nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(nb)
	if v == "cipher" and unlocked:
		var pending := Cipher.pending_directives(Game.state, Game.content).size()
		if pending > 0:
			var cb := Style.panel(Style.STAMP_RED, 6)
			cb.name = "cipher-pending"
			cb.position = Vector2(b.size.x - 52, 20)
			cb.add_child(Style.label(str(pending), Style.form(true), 20, Style.PAPER_LIGHT, false))
			cb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cb)
	if v == "dialog" and unlocked:
		var ready: int = Game.content.targets.filter(func(t): return Meeting.meet_error(Game.state, Game.content, t.target_id) == "").size()
		if ready > 0 or Game.state.meeting != null:
			var db := Style.panel(Style.STAMP_RED, 6)
			db.name = "dialog-ready"
			db.position = Vector2(b.size.x - 60, 20)
			db.add_child(Style.label(T.t("dialog.recording") if Game.state.meeting != null else str(ready), Style.form(true), 18, Style.PAPER_LIGHT, false))
			db.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(db)
	if v == "inbox":
		var unread := Cipher.unread_mail(Game.state, Game.content).size()
		if unread > 0:
			var badge := Style.panel(Style.STAMP_RED, 6)
			badge.name = "inbox-unread"
			badge.position = Vector2(b.size.x - 44, 66)
			badge.add_child(Style.label(str(unread), Style.form(true), 20, Style.PAPER_LIGHT, false))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(badge)
	# Бумажный ярлык с названием и клавишей.
	var tag := Style.panel(Style.PAPER_LIGHT, 4)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Style.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Style.label(T.t(_key(v, "name")), Style.form(), 15, Style.INK, false))
	h.add_child(Style.label("[%d]" % Modules.hotkey(v) if unlocked else T.t("desk.locked", {"act": Modules.unlock_act(v)}), Style.form(), 13, Color(Style.INK, 0.7), false))
	tag.add_child(h)
	b.add_child(tag)
	tag.position = Vector2((b.size.x - tag.get_combined_minimum_size().x) / 2, b.size.y - 16)
	return b


static func _lamp_light() -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.9, 0.67, 0.14))
	g.set_color(1, Color(1, 0.9, 0.67, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.22)
	gt.fill_to = Vector2(1.0, 0.22)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.position = Vector2(640, 300)
	tr.size = Vector2(760, 600)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _key(v: String, part: String) -> String:
	return ("inbox.%s" % part) if v == "inbox" else ("module.%s.%s" % [v, part])


## Красные отметки наружки поверх карты на столе.
class SogMarks extends Control:
	var count := 0
	func _init(n: int, sz: Vector2) -> void:
		count = n
		size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var pts := [Vector2(0.6, 0.3), Vector2(0.42, 0.57), Vector2(0.72, 0.62), Vector2(0.3, 0.35), Vector2(0.8, 0.42)]
		for i in count:
			var p: Vector2 = pts[i] * size
			draw_line(p - Vector2(9, 9), p + Vector2(9, 9), Color("#c0281c"), 4)
			draw_line(p + Vector2(9, -9), p + Vector2(-9, 9), Color("#c0281c"), 4)


## Приколотые карточки досье на пробковой доске (по числу установленных целей).
class CorkCards extends Control:
	var count := 0
	func _init(n: int, sz: Vector2) -> void:
		count = n
		size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var slots := [Vector2(70, 60), Vector2(250, 40), Vector2(440, 70), Vector2(150, 150), Vector2(360, 160), Vector2(530, 140)]
		var shown := slots.slice(0, count)
		for i in range(1, shown.size()):
			draw_line(shown[i - 1] + Vector2(45, 10), shown[i] + Vector2(45, 10), Style.THREAD_RED, 2)
		for p in shown:
			draw_rect(Rect2(p, Vector2(90, 62)), Style.PAPER_LIGHT)
			for k in 3:
				draw_line(p + Vector2(10, 22 + k * 12), p + Vector2(78 - k * 9, 22 + k * 12), Color("#8a8578"), 1)
			draw_circle(p + Vector2(45, 8), 5, Style.THREAD_RED)
