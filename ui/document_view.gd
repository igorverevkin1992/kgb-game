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
	var body := Style.para("      " + T.loc(cable.body), w - 136, Style.mono(), 17, Style.INK)
	body.add_theme_constant_override("line_spacing", 10)
	v.add_child(body)
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
	var body := Style.para(T.loc(cable.body), 470, Style.serif(), 18, Style.INK)
	body.add_theme_constant_override("line_spacing", 6)
	v.add_child(body)
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
	var body := Style.para(T.loc(cable.body).to_upper(), 640, Style.mono(), 17, Style.INK)
	body.add_theme_constant_override("line_spacing", 8)
	v.add_child(body)
	p.add_child(v)
	return _wrap(p, cable)
