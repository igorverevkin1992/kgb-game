class_name EvidenceView
## Сейф с вещественными доказательствами: слева — предметы, справа — выбранный предмет. Его
## можно перевернуть (стороны) и указать деталь, которая кажется важной. Верная деталь даёт
## сведения на доску мотивов или продвигает сюжетную линию; неверная — пометка, без штрафа.

const LEFT_W := 420.0
const RIGHT_X := 480.0
const RIGHT_W := 1020.0
const TOP := 76.0
const H := 660.0


static func build() -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.evidence.name"), T.t("evidence.note")))
	var items: Array = Evidence.arrived(s, c)
	items.reverse()  # свежие сверху
	var cur := Evidence.by_id(c, Game.evidence_selected)
	if cur.is_empty() or not items.has(cur):
		cur = items[0] if not items.is_empty() else {}

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, TOP)
	scroll.size = Vector2(LEFT_W + 16, H)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Style.vbox(8)
	list.name = "evidence-list"
	list.custom_minimum_size.x = LEFT_W
	if items.is_empty():
		list.add_child(Style.para(T.t("evidence.empty"), LEFT_W, Style.mono(), 14, Color(Style.PAPER, 0.6)))
	for it in items:
		var r := Evidence.record(s, it.item_id)
		var left := _left_to_find(it, r)
		var on: bool = not cur.is_empty() and it.item_id == cur.item_id
		var b := Style.button("%s\n%s" % [T.loc(it.title), T.t("evidence.left", {"n": left}) if left > 0 else T.t("evidence.done")],
			"evidence-item-" + it.item_id, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Style.OCHRE if left > 0 else Color(Style.PAPER, 0.4), 14)
		b.custom_minimum_size.x = LEFT_W
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(Game.select_evidence.bind(it.item_id))
		list.add_child(b)
	scroll.add_child(list)
	root.add_child(scroll)
	if not cur.is_empty():
		root.add_child(_item(s, cur))
	return root


static func _left_to_find(it: Dictionary, r: Dictionary) -> int:
	var n := 0
	for side in it.sides:
		for d in side.details:
			if d.correct and not r.found.has(d.detail_id):
				n += 1
	return n


static func _item(s: Dictionary, it: Dictionary) -> Control:
	var r := Evidence.record(s, it.item_id)
	var side_i := clampi(Game.evidence_side, 0, it.sides.size() - 1)
	var side: Dictionary = it.sides[side_i]
	var sc := ScrollContainer.new()
	sc.set_meta("scroll_key", "evidence-" + it.item_id)
	sc.position = Vector2(RIGHT_X, TOP)
	sc.size = Vector2(RIGHT_W + 16, H)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := Style.vbox(12)
	v.name = "evidence-card"
	v.custom_minimum_size.x = RIGHT_W
	v.add_child(Style.label(T.t("evidence.kind." + it.kind).to_upper() + " · " + T.loc(it.source), Style.form(), 14, Color(Style.PAPER, 0.7)))
	v.add_child(Style.label(T.loc(it.title), Style.form(true), 26, Style.PAPER_LIGHT))
	# Стороны предмета: перевернуть.
	var tabs := Style.hbox(8)
	for i in it.sides.size():
		var on: bool = i == side_i
		var tb := Style.button(T.loc(it.sides[i].title), "evidence-side-%d" % i, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 14)
		tb.pressed.connect(Game.set_evidence_side.bind(i))
		tabs.add_child(tb)
	v.add_child(tabs)
	# Сам предмет — карточка «бумаги» с текстом стороны.
	var paper := Style.panel(Color("#ece4cf") if it.kind != "photo" else Color("#cfc8b6"), 28, Color(Style.INK, 0.4), 1)
	var pt := Style.para(T.loc(side.text), RIGHT_W - 80, Style.serif(false, it.kind in ["card", "note", "book"]), 19, Style.INK)
	pt.add_theme_constant_override("line_spacing", 5)
	paper.add_child(pt)
	v.add_child(paper)
	v.add_child(Style.label(T.t("evidence.pick"), Style.form(true), 15, Color(Style.PAPER, 0.85)))
	for d in side.details:
		var tried: bool = r.tried.has(d.detail_id)
		var found: bool = r.found.has(d.detail_id)
		var mark := T.t("evidence.found") if found else (T.t("evidence.nothing") if tried else "")
		var b := Style.button(T.loc(d.label) + mark, "evidence-detail-" + d.detail_id,
			Style.INK if found else Style.PAPER, Color("#e9c46a") if found else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 15)
		b.disabled = tried
		# Осмотренная деталь неактивна, но читается: найденная — тёмным по жёлтому.
		b.add_theme_color_override("font_disabled_color", Style.INK if found else Color(Style.PAPER, 0.55))
		if found:
			b.add_theme_stylebox_override("disabled", Style.box(Color("#e9c46a"), Color(Style.PAPER, 0.5), 1, 0, 8))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = RIGHT_W
		b.pressed.connect(Game.dispatch.bind({"type": "inspect_detail", "item_id": it.item_id, "detail_id": d.detail_id}))
		v.add_child(b)
		if tried:
			var note := Style.para(T.loc(d.note), RIGHT_W - 20, Style.serif(false, true), 15, Color("#f0d9a0") if found else Color(Style.PAPER, 0.65))
			note.name = "evidence-note-" + d.detail_id
			v.add_child(note)
	sc.add_child(v)
	return sc
