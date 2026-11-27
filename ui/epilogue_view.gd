class_name EpilogueView
## Документальный эпилог после финала операции: хроника дела Эймса по листам — как офицер
## линии КР вашингтонской резидентуры привёл к одному из крупнейших успехов советской разведки
## и чем это обернулось. Тексты — в content/archive (раздел «epilogue»); те же листы потом
## лежат в «Архиве 1985».

const W := 980.0


static func build() -> Control:
	var pages := Archive.epilogue(Game.state, Game.content)
	var root := Control.new()
	root.name = "epilogue-overlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := Style.rect(Color(0.02, 0.015, 0.01, 0.88), Rect2(0, 0, 1600, 900))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	if pages.is_empty():
		return root
	var i := clampi(Game.epilogue_page, 0, pages.size() - 1)
	var e: Dictionary = pages[i]
	var p := Style.panel(Color("#ece4cc"), 48)
	p.name = "epilogue"
	p.set_meta("page", i)
	p.set_meta("entry", e.id)
	p.custom_minimum_size = Vector2(W, 0)
	var v := Style.vbox(16)
	var head := Style.hbox(16)
	var kicker := Style.label(T.t("epilogue.kicker").to_upper(), Style.form(true), 15, Color(Style.INK, 0.65))
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kicker)
	head.add_child(Style.stamp(T.t("archive.status." + e.status), ArchiveView.STATUS_COLOR[e.status], 14, -3))
	v.add_child(head)
	v.add_child(Style.para(T.loc(e.title), W - 96, Style.serif(true), 30, Style.INK))
	v.add_child(Style.hline(Color(Style.INK, 0.35)))
	var body := Style.para(T.loc(e.text), W - 96, Style.serif(), 20, Style.INK)
	body.name = "epilogue-text"
	body.add_theme_constant_override("line_spacing", 7)
	v.add_child(body)
	var foot := Style.hbox(12)
	var count := Style.label(T.t("epilogue.page", {"n": i + 1, "of": pages.size()}), Style.mono(), 13, Color(Style.INK, 0.6))
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(count)
	if i > 0:
		var prev := Style.paper_button(T.t("epilogue.prev"), "epilogue-prev")
		prev.pressed.connect(Game.set_epilogue_page.bind(i - 1))
		foot.add_child(prev)
	if i < pages.size() - 1:
		var nxt := Style.paper_button(T.t("epilogue.next"), "epilogue-next")
		nxt.pressed.connect(Game.set_epilogue_page.bind(i + 1))
		foot.add_child(nxt)
	else:
		var arc := Style.paper_button(T.t("epilogue.toArchive"), "epilogue-archive")
		arc.pressed.connect(func():
			Game.epilogue_page = -1
			Game.open_archive("arc_epilogue_fiction"))
		foot.add_child(arc)
	var close := Style.paper_button(T.t("epilogue.close"), "epilogue-close")
	close.pressed.connect(Game.set_epilogue_page.bind(-1))
	foot.add_child(close)
	v.add_child(foot)
	p.add_child(v)
	# Длинный лист прокручивается; кнопки листания — внизу листа.
	var sc := ScrollContainer.new()
	sc.name = "epilogue-scroll"
	sc.position = Vector2((1600 - W) / 2, 60)
	sc.size = Vector2(W + 16, 780)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(p)
	root.add_child(sc)
	return root
