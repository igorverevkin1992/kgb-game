class_name TutorialView
## Записка наставника (заместителя резидента) с текущим шагом обучения, подсветка нужного
## предмета и карточка «Памятки» модуля. Шаги и памятки — content/tutorial/, content/help/.

const NOTE_W := 500.0


## Записка: на столе — внизу слева, в модуле — внизу справа над кромкой. Свернуть можно.
static func note(step: Dictionary) -> Control:
	var p := Style.panel(Color("#efe6c8"), 14, Style.STAMP_RED, 2)
	p.name = "tutorial-note"
	var v := Style.vbox(6)
	var head := Style.hbox(10)
	var pr := Tutorial.progress(Game.content, step)
	head.add_child(Style.label(T.t("tutorial.head", {"n": pr[0], "of": pr[1]}), Style.form(true), 14, Style.STAMP_RED, false))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var fold := Style.button(T.t("tutorial.unfold") if Game.tutorial_folded else T.t("tutorial.fold"), "tutorial-fold", Style.INK, Color(0, 0, 0, 0), Color(Style.INK, 0.4), 12)
	fold.pressed.connect(Game.toggle_tutorial_fold)
	head.add_child(fold)
	v.add_child(head)
	if not Game.tutorial_folded:
		var text := Style.para(T.loc(step.text), NOTE_W - 28, Style.serif(), 16, Style.INK)
		text.name = "tutorial-text"
		v.add_child(text)
		var row := Style.hbox(8)
		if step.done == "ack":
			var ok := Style.paper_button(T.t("tutorial.ack"), "tutorial-ack")
			ok.pressed.connect(Game.ack_tutorial.bind(step.step_id))
			row.add_child(ok)
		else:
			var skip := Style.button(T.t("tutorial.skip"), "tutorial-skip", Color(Style.INK, 0.7), Color(0, 0, 0, 0), Color(Style.INK, 0.3), 12)
			skip.pressed.connect(Game.ack_tutorial.bind(step.step_id))
			row.add_child(skip)
		var off := Style.button(T.t("tutorial.off"), "tutorial-off", Color(Style.INK, 0.7), Color(0, 0, 0, 0), Color(Style.INK, 0.3), 12)
		off.pressed.connect(Game.set_setting.bind("tutorial", false))
		row.add_child(off)
		v.add_child(row)
	p.add_child(v)
	p.custom_minimum_size.x = NOTE_W
	# Нижний край записки прижат к низу: высоту текста с переносами узнаём после раскладки.
	var bottom := 890.0 if Game.view == "" else 790.0
	p.position = Vector2(40 if Game.view == "" else 1600 - 40 - NOTE_W, bottom - p.get_combined_minimum_size().y)
	p.resized.connect(func(): p.position.y = bottom - p.size.y)
	return p


## Пульсирующая красная рамка вокруг узла (предмет на столе, кнопка календаря).
static func highlight(target: Control) -> Control:
	var r := target.get_global_rect().grow(6)
	var frame := Panel.new()
	frame.name = "tutorial-highlight"
	frame.position = r.position
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Style.THREAD_RED
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	var tw := frame.create_tween().set_loops()
	tw.tween_property(frame, "modulate:a", 0.25, 0.7)
	tw.tween_property(frame, "modulate:a", 1.0, 0.7)
	return frame


## Карточка памятки модуля поверх него.
static func help_card(view: String) -> Control:
	var h := Tutorial.help_for(Game.content, view)
	var root := Control.new()
	root.name = "help-card"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(Style.rect(Color(0, 0, 0, 0.55), Rect2(0, 0, 1600, 900)))
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(blocker)
	var p := Style.panel(Style.PAPER_LIGHT, 32, Style.INK, 1)
	var v := Style.vbox(14)
	v.add_child(Style.label(T.t("help.head").to_upper(), Style.mono(), 14, Style.STAMP_RED, false))
	v.add_child(Style.label(T.loc(h.get("title", {"ru": ""})), Style.form(true), 28, Style.INK, false))
	var text := Style.para(T.loc(h.get("text", {"ru": ""})), 720, Style.serif(), 18, Style.INK)
	text.add_theme_constant_override("line_spacing", 5)
	v.add_child(text)
	var ok := Style.paper_button(T.t("help.ok"), "help-ok")
	ok.pressed.connect(Game.close_help)
	v.add_child(ok)
	p.add_child(v)
	p.position = Vector2(800, 450) - p.get_combined_minimum_size() / 2
	p.resized.connect(func(): p.position = Vector2(800, 450) - p.size / 2)  # по центру после раскладки
	root.add_child(p)
	return root
