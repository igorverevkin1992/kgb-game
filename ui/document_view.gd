class_name DocumentView
## Документ на столе. Визуальная дуальность (GDD, Блок 5): советские бумаги — серый бланк
## по ГОСТ, машинопись, гриф и штамп; американские — газетная вырезка; перехват — телетайпная лента.


static func build(cable: Dictionary) -> Control:
	match cable.kind:
		"press_clipping":
			return _clipping(cable)
		"intercept":
			return _intercept(cable)
		_:
			return _form(cable)


static func _wrap(p: PanelContainer, cable: Dictionary) -> PanelContainer:
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
