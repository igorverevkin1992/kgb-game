class_name ArchiveView
## «Архив эпохи: 1985» — необязательный справочник: реальная техника, история и законы эпохи,
## а после первой фазы операции — эпилог «Факт и вымысел». Каждая запись помечена:
## факт, вымысел или «факт и вымысел» (где игра упрощает или додумывает).

const LEFT_W := 470.0
const RIGHT_X := 530.0
const RIGHT_W := 978.0
const TOP := 76.0
const H := 660.0
const STATUS_COLOR := {"fact": Color("#2f5f3a"), "fiction": Color("#8e2b22"), "mixed": Color("#7a5a1e")}


static func build() -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.archive.name"), T.t("archive.note")))
	var entries: Array = c.get("archive", [])
	var cur := Archive.entry_by_id(c, Game.archive_selected)
	if cur.is_empty() or not Archive.is_open(s, cur):
		cur = {}
		for e in entries:
			if Archive.is_open(s, e):
				cur = e
				break

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, TOP)
	scroll.size = Vector2(LEFT_W, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Style.vbox(6)
	list.name = "archive-list"
	list.custom_minimum_size.x = LEFT_W - 16
	for sec in Archive.SECTIONS:
		var items: Array = entries.filter(func(e): return e.section == sec)
		if items.is_empty():
			continue
		list.add_child(Style.label(T.t("archive.section." + sec).to_upper(), Style.form(true), 15, Color(Style.PAPER, 0.75)))
		for e in items:
			var open := Archive.is_open(s, e)
			var on: bool = not cur.is_empty() and e.id == cur.id
			var text := T.loc(e.title) if open else T.t("archive.lockedFinal" if String(e.get("unlock", "")).begins_with("ending:") else "archive.locked")
			var b := Style.button(text, "archive-entry-" + e.id, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.4), 14)
			b.custom_minimum_size.x = LEFT_W - 16
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.disabled = not open
			b.pressed.connect(Game.select_archive.bind(e.id))
			list.add_child(b)
	scroll.add_child(list)
	root.add_child(scroll)

	if cur.is_empty():
		var none := Style.label(T.t("archive.empty"), Style.mono(), 16, Color(Style.PAPER, 0.7))
		none.position = Vector2(RIGHT_X, TOP)
		root.add_child(none)
		return root
	var p := Style.panel(Color("#ece4cc"), 32)
	p.name = "archive-text"
	p.set_meta("entry", cur.id)
	p.set_meta("status", cur.status)
	p.position = Vector2(RIGHT_X, TOP)
	p.custom_minimum_size = Vector2(RIGHT_W, 0)
	var v := Style.vbox(14)
	var head := Style.hbox(16)
	var title := Style.para(T.loc(cur.title), RIGHT_W - 260, Style.serif(true), 26, Style.INK)
	head.add_child(title)
	head.add_child(Style.stamp(T.t("archive.status." + cur.status), STATUS_COLOR[cur.status], 15, -3))
	v.add_child(head)
	v.add_child(Style.label(T.t("archive.section." + cur.section), Style.form(), 14, Color(Style.INK, 0.6)))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	var body := Style.para(T.loc(cur.text), RIGHT_W - 64, Style.serif(), 19, Style.INK)
	body.add_theme_constant_override("line_spacing", 6)
	v.add_child(body)
	v.add_child(Style.para(T.t("archive.footer"), RIGHT_W - 64, Style.mono(), 12, Color(Style.INK, 0.55)))
	p.add_child(v)
	root.add_child(p)
	return root
