class_name DocumentView
## Документ на столе. Визуальная дуальность (GDD, Блок 5): советские бумаги — серый бланк
## по ГОСТ, машинопись, гриф и штамп; американские — газетная вырезка; перехват — телетайпная лента.


static func build(cable: Dictionary) -> Control:
	match cable.kind:
		"press_clipping":
			return _clipping(cable)
		"intercept", "anonymous":
			return _intercept(cable)
		"letter":
			return _letter(cable)
		_:
			return _form(cable)


static func _wrap(p: PanelContainer, cable: Dictionary) -> PanelContainer:
	# Фактура бумаги под текстом: крапинки и волокна (детерминированно по документу).
	var grain := PaperGrain.new(hash(cable.cable_id))
	p.add_child(grain)
	p.move_child(grain, 0)
	p.name = "document"
	p.set_meta("kind", cable.kind)
	return p


## Текст документа с подсвеченными фрагментами-уликами (Orwell): клик снимает улику на доску.
## Снятые фрагменты остаются подчёркнутыми.
static func body(cable: Dictionary, width: float, font: Font, size: int, color: Color, upper := false, indent := "") -> RichTextLabel:
	var text: String = T.loc(cable.body)
	var marks: Array = []
	for clue in Game.content.clues:
		if clue.source.channel == "document" and clue.source.from == cable.cable_id and clue.has("chunk"):
			var at := text.find(clue.chunk)
			if at >= 0:
				marks.append({"at": at, "len": String(clue.chunk).length(), "id": clue.clue_id, "taken": Game.state.clues.has(clue.clue_id)})
	marks.sort_custom(func(a, b): return a.at < b.at)
	var out := indent
	var pos := 0
	for m in marks:
		out += _esc(text.substr(pos, m.at - pos), upper)
		var piece := _esc(text.substr(m.at, m.len), upper)
		if m.taken:
			out += "[u]%s[/u]" % piece
		else:
			out += "[url=%s][bgcolor=#e9c46a99]%s[/bgcolor][/url]" % [m.id, piece]
		pos = m.at + m.len
	out += _esc(text.substr(pos), upper)
	var r := RichTextLabel.new()
	r.name = "doc-body"
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = width
	r.add_theme_font_override("normal_font", font)
	r.add_theme_font_size_override("normal_font_size", Style.fs(size))
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("line_separation", 8)
	r.meta_underlined = false
	r.text = out
	r.meta_clicked.connect(func(meta): Game.take_clue(str(meta)))
	r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return r


static func _esc(t: String, upper: bool) -> String:
	return (t.to_upper() if upper else t).replace("[", "[lb]")


## «Интуиция» (Roottrees): сколько улик в документе ещё не снято.
static func intuition(cable: Dictionary, width: float, color: Color) -> Label:
	var n := Campaign.untaken_chunks(Game.state, Game.content, cable.cable_id).size()
	var total: int = Game.content.clues.filter(func(c): return c.source.channel == "document" and c.source.from == cable.cable_id).size()
	var text := T.t("doc.intuition", {"n": n}) if n > 0 else (T.t("doc.intuitionDone") if total > 0 else T.t("doc.intuitionNone"))
	var l := Style.para(text, width, Style.form(), 14, color)
	l.name = "intuition"
	return l


static func _form(cable: Dictionary) -> Control:
	var w := 720.0
	var sb := Style.box(Style.PAPER, Color(0, 0, 0, 0), 0, 0, 0)
	sb.content_margin_left = 80
	sb.content_margin_right = 56
	sb.content_margin_top = 40
	sb.content_margin_bottom = 64
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(10)
	v.custom_minimum_size.x = w - 136
	var head := Style.hbox(18)
	head.alignment = BoxContainer.ALIGNMENT_END
	head.add_child(Style.label(T.t("doc.secret").to_upper(), Style.form(), 15, Style.STAMP_RED))
	head.add_child(Style.label(T.t("doc.copy").to_upper(), Style.form(), 15, Style.INK))
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	var number := "№ %d/%d-КР" % [cable.week, String(cable.cable_id).length() * 7 + int(cable.week)]
	for row in [[T.t("doc.from"), T.loc(cable.sender)], [T.t("doc.number"), number], [T.t("doc.kind"), T.t("doc.kind." + cable.kind)]]:
		grid.add_child(Style.label(row[0], Style.form(), 15, Color(Style.INK, 0.65)))
		grid.add_child(Style.label(row[1], Style.form(), 15, Style.INK))
	v.add_child(grid)
	v.add_child(Style.hline(Color("#8a8578")))
	var subject := Style.para(T.loc(cable.subject), w - 136, Style.mono(), 18, Style.INK)
	subject.add_theme_constant_override("line_spacing", 4)
	v.add_child(subject)
	v.add_child(body(cable, w - 136, Style.mono(), 17, Style.INK, false, "      "))
	v.add_child(intuition(cable, w - 136, Color(Style.INK, 0.6)))
	var stamp_row := Style.hbox()
	stamp_row.alignment = BoxContainer.ALIGNMENT_END
	var st := Style.stamp(T.t("doc.stamp"), Color(0.18, 0.29, 0.55, 0.8), 15, -7)
	stamp_row.add_child(st)
	v.add_child(stamp_row)
	p.add_child(v)
	return _wrap(p, cable)


static func _clipping(cable: Dictionary) -> Control:
	var sb := Style.box(Style.NEWSPRINT, Color(0, 0, 0, 0), 0, 0, 34)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(10)
	v.custom_minimum_size.x = 470
	var mast := Style.label(T.loc(cable.sender), Style.serif(false, true), 16, Style.INK)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mast)
	v.add_child(Style.hline(Style.INK, 3))
	v.add_child(Style.para(T.loc(cable.subject), 470, Style.serif(true), 26, Style.INK))
	v.add_child(body(cable, 470, Style.serif(), 18, Style.INK))
	v.add_child(intuition(cable, 470, Color(Style.INK, 0.6)))
	p.add_child(v)
	p.rotation_degrees = -0.8
	return _wrap(p, cable)


## Письмо из дома: тетрадный лист в линейку, синяя шариковая ручка.
static func _letter(cable: Dictionary) -> Control:
	var sb := Style.box(Color("#f3ecd8"), Color(0, 0, 0, 0), 0, 0, 0)
	sb.content_margin_left = 64
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 44
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var ink := Color("#2c3e66")
	var v := Style.vbox(12)
	v.custom_minimum_size.x = 560
	var head := Style.label(T.t("doc.letterFrom", {"from": T.loc(cable.sender), "date": Fmt.date(Campaign.week_date(Game.content, cable.act, cable.week))}), Style.serif(false, true), 14, Color(ink, 0.7))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(head)
	v.add_child(body(cable, 560, Style.serif(false, true), 19, ink))
	# Линейки — под строками текста: шаг = высота строки шрифта плюс межстрочный интервал.
	var font := Style.serif(false, true)
	var line_h := font.get_height(Style.fs(19)) + 8
	var first := head.get_combined_minimum_size().y + 12 + font.get_ascent(Style.fs(19)) + font.get_descent(Style.fs(19)) + 2
	var lines := LinedPaper.new(first, line_h)
	p.add_child(lines)
	p.move_child(lines, 0)
	p.add_child(v)
	p.rotation_degrees = 0.6
	if cable.get("reply") == null:
		return _wrap(p, cable)
	# Ответ домой: под письмом — варианты с последствиями для «Отношений с семьёй».
	var col := Style.vbox(14)
	col.add_child(_wrap(p, cable))
	col.add_child(reply_block(cable))
	return col


## Блок ответа на письмо семьи: шкала отношений, срок, варианты или отправленный ответ.
static func reply_block(cable: Dictionary) -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var box := Style.panel(Color(0, 0, 0, 0.22), 18, Color(Style.PAPER, 0.35), 1)
	box.name = "letter-reply"
	var v := Style.vbox(8)
	v.custom_minimum_size.x = 640
	var fam := int(s.get("family", Family.cfg(c).start))
	var head := Style.label(T.t("family.scale", {"n": fam}), Style.form(true), 16, Style.PAPER_LIGHT, false)
	head.name = "family-scale"
	head.set_meta("value", fam)
	v.add_child(head)
	var done: String = s.get("replies", {}).get(cable.cable_id, "")
	if done == "":
		v.add_child(Style.para(T.t("family.due", {"week": Family.due_week(c, cable), "n": absi(int(Family.cfg(c).no_reply))}), 640, Style.mono(), 13, Color(Style.PAPER, 0.75)))
		for o in cable.reply.options:
			var fx := T.t("family.fx", {"d": ("+%d" % int(o.family)) if int(o.family) > 0 else str(int(o.family))})
			if int(o.get("centre_trust", 0)) != 0:
				fx += T.t("family.fxTrust", {"d": int(o.centre_trust)})
			var b := Style.button("%s — %s" % [T.loc(o.label), fx], "reply-" + o.option_id, Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 14)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 640
			b.pressed.connect(Game.dispatch.bind({"type": "reply_letter", "cable_id": cable.cable_id, "option_id": o.option_id}))
			v.add_child(b)
	else:
		var o := Family.option(cable, done)
		var text := T.t("family.sent", {"text": T.loc(o.label)}) if not o.is_empty() else T.t("family." + done)
		var sent := Style.para(text, 640, Style.serif(false, true), 15, Color("#f0d9a0"))
		sent.name = "letter-replied"
		v.add_child(sent)
	box.add_child(v)
	return box


## Линейки тетрадного листа и красное поле.
class LinedPaper extends Control:
	var first := 30.0
	var step := 30.0
	func _init(f: float, st: float) -> void:
		first = f
		step = st
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := first
		while y < size.y + 20:
			draw_line(Vector2(-40, y), Vector2(size.x + 30, y), Color(0.45, 0.6, 0.8, 0.35), 1)
			y += step
		draw_line(Vector2(-18, -36), Vector2(-18, size.y + 44), Color(0.8, 0.3, 0.3, 0.45), 1)


static func _intercept(cable: Dictionary) -> Control:
	var sb := Style.box(Color("#f1ecdc"), Color("#2a2119"), 0, 0, 30)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(10)
	v.custom_minimum_size.x = 640
	v.add_child(Style.para("%s · %s" % [T.loc(cable.sender).to_upper(), T.loc(cable.subject).to_upper()], 640, Style.mono(), 14, Color(Style.INK, 0.7)))
	v.add_child(body(cable, 640, Style.mono(), 17, Style.INK, true))
	v.add_child(intuition(cable, 640, Color(Style.INK, 0.6)))
	p.add_child(v)
	return _wrap(p, cable)



## Фактура бумаги: редкие крапинки и короткие волокна, одинаковые от запуска к запуску.
class PaperGrain extends Control:
	var seed_value := 0
	func _init(sd: int) -> void:
		seed_value = sd
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var n := int(size.x * size.y / 900.0)
		for i in n:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(0.4, 1.1), Color(0.3, 0.25, 0.15, rng.randf_range(0.05, 0.16)))
		for i in n / 8:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var d := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4, 12)
			draw_line(p, p + d, Color(0.35, 0.3, 0.2, 0.08), 1)
