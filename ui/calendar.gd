class_name Calendar
## Настольный календарь: неделя, дата, фаза, кнопка перехода. Ночью — выбор донесения в Центр.


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.name = "calendar"
	root.position = Vector2(1190, 330)
	root.size = Vector2(380, 230)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Отрывной лист.
	var sheet := Style.panel(Style.PAPER_LIGHT, 12)
	sheet.position = Vector2(0, 0)
	sheet.custom_minimum_size = Vector2(160, 0)
	sheet.add_theme_stylebox_override("panel", _sheet_box())
	var v := Style.vbox(2)
	var week := Style.label(T.t("calendar.week", {"week": s.week}), Style.form(true), 22, Style.INK, false)
	week.name = "calendar-week"
	v.add_child(week)
	v.add_child(Style.label(Fmt.date(Campaign.week_date(Game.content, s.act, s.week)), Style.form(), 14, Color(Style.INK, 0.75), false))
	var phase := Style.label(T.t("phase." + s.phase).to_upper(), Style.form(true), 20, Style.STAMP_RED, false)
	phase.name = "calendar-phase"
	v.add_child(phase)
	var def := Campaign.current_act_def(s, Game.content)
	if not def.is_empty():
		v.add_child(Style.label("%s · %s" % [T.t("desk.act", {"act": s.act}), T.loc(def.title)], Style.form(), 14, Color(Style.INK, 0.75), false))
	sheet.add_child(v)
	root.add_child(sheet)

	# Управление.
	var c := Style.vbox(6)
	c.position = Vector2(172, 0)
	c.custom_minimum_size = Vector2(208, 0)
	c.add_child(Style.para(T.t("phase.%s.hint" % s.phase), 208, Style.mono(), 12, Color(Style.PAPER, 0.75)))
	if s.phase == "night":
		for r in ["truth", "embellished", "silence"]:
			var b := Style.button(T.t("report." + r), "report-" + r, Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.55), 13)
			b.tooltip_text = T.t("report.%s.hint" % r)
			b.pressed.connect(Game.dispatch.bind({"type": "submit_report", "report": r}))
			c.add_child(b)
	else:
		var nb := Style.button(T.t("calendar.next"), "advance-phase", Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.55), 13)
		nb.pressed.connect(Game.dispatch.bind({"type": "advance_phase"}))
		c.add_child(nb)
	var ab := Style.button(T.t("analyst.open"), "analyst-toggle", Color(Style.PAPER, 0.85), Color(0, 0, 0, 0.15), Color(Style.PAPER, 0.35), 13)
	ab.pressed.connect(Game.toggle_analyst)
	c.add_child(ab)
	if Game.saved_at > 0:
		var saved := Style.label(T.t("saves.saved").to_upper(), Style.form(true), 12, Color("#a9c89c"), false)
		saved.name = "save-indicator"
		c.add_child(saved)
		# Штамп «Сохранено» бледнеет через пару секунд.
		var tw := saved.create_tween()
		tw.tween_interval(1.6)
		tw.tween_property(saved, "modulate:a", 0.35, 0.8)
	if Game.last_error != "":
		var err := Style.para(Game.last_error, 208, Style.mono(), 12, Color("#e2826f"))
		err.name = "engine-error"
		c.add_child(err)
	root.add_child(c)
	return root


static func _sheet_box() -> StyleBoxFlat:
	var sb := Style.box(Style.PAPER_LIGHT, Style.STAMP_RED, 0, 0, 12)
	sb.border_width_top = 10
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	return sb
