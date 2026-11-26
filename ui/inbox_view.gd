class_name InboxView
## Лоток входящих: утренняя почта резидента. Открытый документ отмечается прочитанным.


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("inbox.name"), T.t("inbox.hint")))

	var docs: Array = s.delivered_cables.map(func(id): return Campaign.cable_by_id(Game.content, id)).filter(func(c): return not c.is_empty() and c.kind != "directive")
	docs.reverse()  # свежие сверху

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 76)
	scroll.size = Vector2(440, 660)
	var list := Style.vbox(8)
	list.name = "inbox-list"
	list.custom_minimum_size.x = 420
	for d in docs:
		var unread: bool = not s.read_cables.has(d.cable_id)
		var cur: bool = d.cable_id == Game.inbox_selected
		var b := Button.new()
		b.name = "inbox-item-" + d.cable_id
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(420, 64)
		var bg := Color(Style.PAPER, 0.22 if cur else 0.08)
		var sb := Style.box(bg, Style.STAMP_RED if unread else Color(0, 0, 0, 0), 0, 0, 10)
		sb.border_width_left = 4
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate()
		hov.bg_color = Color(Style.PAPER, 0.16)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.pressed.connect(Game.select_document.bind(d.cable_id))
		var v := Style.vbox(2)
		v.position = Vector2(14, 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var left := Campaign.untaken_chunks(s, Game.content, d.cable_id).size()
		var meta := "%s · %s" % [T.t("doc.kind." + d.kind), T.t("calendar.week", {"week": d.week})]
		if left > 0:
			meta += " · " + T.t("inbox.chunks", {"n": left})
		v.add_child(Style.label(meta, Style.form(), 13, Color(Style.PAPER, 0.7)))
		var subj := Style.para(T.loc(d.subject), 390, Style.form(unread), 17, Style.PAPER)
		subj.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(subj)
		b.add_child(v)
		b.custom_minimum_size.y = maxf(64, v.get_combined_minimum_size().y + 16)
		list.add_child(b)
	scroll.add_child(list)
	root.add_child(scroll)

	var reader := ScrollContainer.new()
	reader.position = Vector2(500, 76)
	reader.size = Vector2(1010, 660)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(990, 0)
	var cur_doc := Campaign.cable_by_id(Game.content, Game.inbox_selected)
	if not cur_doc.is_empty() and s.delivered_cables.has(cur_doc.cable_id) and cur_doc.kind != "directive":
		center.add_child(DocumentView.build(cur_doc))
	else:
		var has_unread := not Cipher.unread_mail(s, Game.content).is_empty()
		center.add_child(Style.label(T.t("inbox.pick") if has_unread else T.t("inbox.allRead"), Style.mono(), 16, Color(Style.PAPER, 0.6)))
	reader.add_child(center)
	root.add_child(reader)
	return root
