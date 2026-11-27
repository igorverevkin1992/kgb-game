class_name InboxView
## Лоток входящих: утренняя почта резидента. Открытый документ отмечается прочитанным.


## Ящики входящих: id → виды документов (пусто — особое правило в in_folder).
const FOLDERS := ["all", "new", "decisions", "reports", "notes", "press", "letters"]
const FOLDER_KINDS := {
	"reports": ["agent_report", "intercept", "anonymous"],
	"notes": ["vgu_note", "personnel_file"],
	"press": ["press_clipping"],
	"letters": ["letter"],
}


static func in_folder(folder: String, d: Dictionary, s: Dictionary) -> bool:
	match folder:
		"all":
			return true
		"new":
			return not s.read_cables.has(d.cable_id)
		"decisions":
			return false
	return FOLDER_KINDS.get(folder, []).has(d.kind)


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("inbox.name"), T.t("inbox.hint")))

	var all_docs: Array = s.delivered_cables.map(func(id): return Campaign.cable_by_id(Game.content, id)).filter(func(c): return not c.is_empty() and c.kind != "directive")
	all_docs.reverse()  # свежие сверху
	var folder: String = Game.inbox_folder
	var docs: Array = all_docs.filter(func(d): return in_folder(folder, d, s))
	var show_decisions := folder in ["all", "new", "decisions"]

	# Ящики по темам: число — непрочитанные (и решения, которые ждут ответа).
	var tabs := HFlowContainer.new()
	tabs.name = "inbox-folders"
	tabs.position = Vector2(28, 76)
	tabs.size = Vector2(440, 0)
	tabs.custom_minimum_size.x = 440
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	for f in FOLDERS:
		var n: int = all_docs.filter(func(d): return in_folder(f, d, s) and not s.read_cables.has(d.cable_id)).size()
		if f in ["all", "new", "decisions"]:
			n += Decisions.arrived(s, Game.content).filter(func(x): return not s.decisions.has(x.decision_id)).size()
		var on: bool = f == folder
		var label := T.t("inbox.folder." + f) + (" · %d" % n if n > 0 else "")
		var tb := Style.button(label, "inbox-folder-" + f, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 13)
		tb.pressed.connect(Game.set_inbox_folder.bind(f))
		tabs.add_child(tb)
	root.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.set_meta("scroll_key", "inbox-list-" + folder)
	scroll.position = Vector2(28, 160)
	scroll.size = Vector2(440, 576)
	var list := Style.vbox(8)
	list.name = "inbox-list"
	list.custom_minimum_size.x = 420
	# Пробный пакет «крота» — самым первым, пока ждёт решения.
	if s.get("package") != null and show_decisions and (folder != "new" or Dangle.open(s)):
		var open := Dangle.open(s)
		var pb := Button.new()
		pb.name = "package-item"
		pb.focus_mode = Control.FOCUS_NONE
		var psb := Style.box(Color(Style.STAMP_RED, 0.25 if Game.inbox_selected == PackageView.ITEM else 0.14), Style.STAMP_RED if open else Color(0, 0, 0, 0), 0, 0, 10)
		psb.border_width_left = 4
		for st in ["normal", "hover", "pressed"]:
			pb.add_theme_stylebox_override(st, psb)
		pb.pressed.connect(Game.select_document.bind(PackageView.ITEM))
		var pv := Style.vbox(2)
		pv.position = Vector2(14, 8)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.add_child(Style.label(T.t("package.waiting") if open else T.t("decision.done"), Style.form(), 13, Color(Style.PAPER, 0.75)))
		pv.add_child(Style.para(T.loc(Dangle.config(Game.content).title), 390, Style.form(open), 17, Style.PAPER))
		pb.add_child(pv)
		pb.custom_minimum_size = Vector2(420, 64)
		list.add_child(pb)
	# Решения резидента — первыми: ждущие решения отмечены красным.
	for dec in (Decisions.arrived(s, Game.content) if show_decisions else []):
		var waiting: bool = not s.decisions.has(dec.decision_id)
		if folder == "new" and not waiting:
			continue
		var on: bool = dec.decision_id == Game.inbox_selected
		var db := Button.new()
		db.name = "decision-item-" + dec.decision_id
		db.focus_mode = Control.FOCUS_NONE
		var dsb := Style.box(Color(Style.STAMP_RED, 0.25 if on else 0.14), Style.STAMP_RED if waiting else Color(0, 0, 0, 0), 0, 0, 10)
		dsb.border_width_left = 4
		db.add_theme_stylebox_override("normal", dsb)
		db.add_theme_stylebox_override("hover", dsb)
		db.add_theme_stylebox_override("pressed", dsb)
		db.pressed.connect(Game.select_document.bind(dec.decision_id))
		var dv := Style.vbox(2)
		dv.position = Vector2(14, 8)
		dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dv.add_child(Style.label(T.t("decision.waiting") if waiting else T.t("decision.done"), Style.form(), 13, Color(Style.PAPER, 0.75)))
		dv.add_child(Style.para(T.loc(dec.title), 390, Style.form(waiting), 17, Style.PAPER))
		db.add_child(dv)
		db.custom_minimum_size = Vector2(420, 64)
		list.add_child(db)
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
		# Высота по реальному числу строк темы (перенос по ширине 390).
		var subj_h := Style.form(unread).get_multiline_string_size(T.loc(d.subject), HORIZONTAL_ALIGNMENT_LEFT, 390, Style.fs(17)).y
		b.custom_minimum_size.y = maxf(64, subj_h + Style.fs(13) + 30)
		list.add_child(b)
	scroll.add_child(list)
	root.add_child(scroll)

	var reader := ScrollContainer.new()
	reader.set_meta("scroll_key", "inbox-reader-" + Game.inbox_selected)  # новый документ — сверху
	reader.position = Vector2(500, 76)
	reader.size = Vector2(1010, 660)
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(990, 0)
	var cur_doc := Campaign.cable_by_id(Game.content, Game.inbox_selected)
	var cur_dec := Decisions.by_id(Game.content, Game.inbox_selected)
	if Game.inbox_selected == PackageView.ITEM and s.get("package") != null:
		center.add_child(PackageView.build())
	elif not cur_dec.is_empty() and Decisions.arrived(s, Game.content).has(cur_dec):
		center.add_child(DecisionView.build(cur_dec))
	elif not cur_doc.is_empty() and s.delivered_cables.has(cur_doc.cable_id) and cur_doc.kind != "directive":
		center.add_child(DocumentView.build(cur_doc))
	else:
		var has_unread := not Cipher.unread_mail(s, Game.content).is_empty()
		center.add_child(Style.label(T.t("inbox.pick") if has_unread else T.t("inbox.allRead"), Style.mono(), 16, Color(Style.PAPER, 0.6)))
	reader.add_child(center)
	root.add_child(reader)
	return root
