class_name BoardView
## Доска мотивов (GDD, модуль 2 + практики Obra Dinn / Roottrees / Golden Idol / Orwell):
## стопка «Новые улики» → улики прикалывают к ячейкам мотивов Д/И/К/С или в общее поле досье
## (клик: выбрать улику → клик по ячейке; или перетащить). Три улики на мотиве — «подтверждено»:
## открывается истинная цифра уязвимости и «красная линия». Заключение тройкой: ведущий мотив,
## доступ, канал → штамп «В разработку». Подсказки: намёк → документ → ответ.

const AXES := ["money", "ideology", "compromise", "ego"]
const CHANNELS := ["false_flag", "true_flag", "contactless", "indirect"]
## Давление на мотив с таким риском обратного эффекта — «красная линия» (GDD: шантаж «Кроноса»).
const RED_LINE := 0.5


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.mice.name"), T.t("board.hint")))
	var cork := Panel.new()
	cork.position = Vector2(24, 66)
	cork.size = Vector2(1488, 672)
	cork.add_theme_stylebox_override("panel", Style.box(Color("#a37c4f"), Color("#5a3f27"), 12))
	cork.add_child(Shells.CorkTexture.new(cork.size))
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cork)
	root.add_child(_stack())
	root.add_child(_dossiers())
	if Game.last_error != "" and Game.view == "mice":
		var msg := Style.panel(Color(Style.STAMP_RED, 0.9), 8)
		msg.name = "board-message"
		msg.position = Vector2(400, 690)
		msg.add_child(Style.label(Game.last_error, Style.mono(), 14, Style.PAPER_LIGHT))
		root.add_child(msg)
	if Game.board_analysis != "" and s.targets.has(Game.board_analysis):
		root.add_child(_analysis_panel(Game.board_analysis))
	return root


# ——— Стопка новых улик ———

static func _stack() -> Control:
	var col := Style.vbox(8)
	col.name = "new-clues"
	col.position = Vector2(48, 88)
	col.custom_minimum_size.x = 320
	col.add_child(Style.label(T.t("board.newClues").to_upper(), Style.form(true), 18, Style.PAPER_LIGHT))
	var clues := Campaign.unpinned_clues(Game.state, Game.content)
	if clues.is_empty():
		col.add_child(Style.para(T.t("board.noNew"), 320, Style.mono(), 13, Color(Style.PAPER_LIGHT, 0.85)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Style.vbox(10)
	for clue in clues:
		list.add_child(ClueCard.new(clue, Game.board_selected == clue.clue_id))
	scroll.add_child(list)
	col.add_child(scroll)
	return col


## Карточка улики: клик — выбрать, перетаскивание — на ячейку досье.
class ClueCard extends PanelContainer:
	var clue_id := ""
	var title := ""

	func _init(clue: Dictionary, selected: bool) -> void:
		clue_id = clue.clue_id
		title = T.loc(clue.title)
		name = "clue-" + clue.clue_id
		custom_minimum_size.x = 310
		var sb := Style.box(Style.PAPER_LIGHT, Style.THREAD_RED if selected else Color("#8a8578"), 3 if selected else 1, 0, 10)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		add_theme_stylebox_override("panel", sb)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = T.t("board.cardTip")
		var v := Style.vbox(4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var src := Style.label(T.t("board.source." + clue.source.channel), Style.form(), 12, Color(Style.INK, 0.6))
		v.add_child(src)
		v.add_child(Style.para(T.loc(clue.title), 284, Style.form(true), 16, Style.INK))
		v.add_child(Style.para(T.loc(clue.text), 284, Style.mono(), 12, Style.INK))
		add_child(v)
		for c in v.get_children():
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			Game.select_board_clue(clue_id)

	func _get_drag_data(_at: Vector2) -> Variant:
		var preview := Style.panel(Style.PAPER_LIGHT, 8)
		preview.add_child(Style.label(title, Style.form(), 14, Style.INK))
		set_drag_preview(preview)
		return {"clue_id": clue_id}


## Ячейка досье: принимает выбранную или перетащенную улику.
class DropZone extends PanelContainer:
	var target_id := ""
	var axis := ""

	func _init(p_target: String, p_axis: String) -> void:
		target_id = p_target
		axis = p_axis
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and Game.board_selected != "":
			Game.pin_clue(Game.board_selected, target_id, axis)

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.has("clue_id")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		Game.pin_clue(data.clue_id, target_id, axis)


# ——— Досье ———

static func _dossiers() -> Control:
	var s: Dictionary = Game.state
	var flow := HFlowContainer.new()
	flow.name = "dossiers"
	flow.position = Vector2(420, 88)
	flow.size = Vector2(1080, 640)
	flow.add_theme_constant_override("h_separation", 28)
	flow.add_theme_constant_override("v_separation", 24)
	var hidden := 0
	for t in Game.content.targets:
		var ts: Dictionary = s.targets[t.target_id]
		if ts.unlocked:
			flow.add_child(_dossier(t, ts))
		elif t.act <= s.act:
			hidden += 1
	if hidden > 0:
		var note := Style.para(T.t("mice.hidden", {"count": hidden}), 500, Style.mono(), 14, Style.PAPER_LIGHT)
		note.name = "dossiers-hidden"
		flow.add_child(note)
	return flow


static func _dossier(t: Dictionary, ts: Dictionary) -> Control:
	var s: Dictionary = Game.state
	var an := Campaign.analysis_state(s, t.target_id)
	var p := Style.panel(Style.PAPER_LIGHT, 16)
	p.name = "dossier-" + t.target_id
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	p.custom_minimum_size = Vector2(520, 0)
	var v := Style.vbox(8)
	var head := Style.hbox(8)
	head.add_child(Style.label(T.loc(t.name), Style.form(true), 22, Style.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if ts.recruited or ts.lost:
		head.add_child(Style.stamp(T.t("mice.recruited" if ts.recruited else "mice.lost"), Style.STAMP_RED, 14, -6))
	elif an.approved:
		var st := Style.stamp(T.t("board.approved"), Color("#2f4a8c"), 14, -6)
		st.name = "stamp-approved"
		head.add_child(st)
	v.add_child(head)
	v.add_child(Style.para(T.loc(t.role), 488, Style.mono(), 13, Style.INK))

	# Ячейки мотивов Д/И/К/С.
	var row := Style.hbox(6)
	for axis in AXES:
		row.add_child(_axis_cell(t, axis))
	v.add_child(row)

	# Общее поле досье: улики, которые устанавливают цель, но не говорят о мотиве.
	var general := DropZone.new(t.target_id, "")
	general.name = "drop-%s-general" % t.target_id
	general.add_theme_stylebox_override("panel", Style.box(Color(0, 0, 0, 0.04), Color("#8a8578"), 1, 0, 8))
	var gv := Style.vbox(4)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(Style.label(T.t("board.general"), Style.form(true), 13, Color(Style.INK, 0.7)))
	var chips: Array = []
	for pin in s.pinned:
		if pin.target_id == t.target_id:
			chips.append(("%s — %s" % [T.t("mice.axis.%s.short" % pin.axis), T.loc(Campaign.clue_by_id(Game.content, pin.clue_id).title)]) if pin.axis != "" else T.loc(Campaign.clue_by_id(Game.content, pin.clue_id).title))
	var pinned_l := Style.para(("• " + "\n• ".join(chips)) if not chips.is_empty() else T.t("board.dropHere"), 470, Style.mono(), 12, Style.INK)
	pinned_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(pinned_l)
	general.add_child(gv)
	v.add_child(general)

	# «Интуиция»: сколько улик по цели ещё не найдено.
	var left := Campaign.undiscovered_for_target(s, Game.content, t.target_id)
	var intu := Style.label(T.t("board.intuition", {"n": left}) if left > 0 else T.t("board.intuitionDone"), Style.form(), 13, Color(Style.INK, 0.65))
	intu.name = "intuition-" + t.target_id
	v.add_child(intu)

	var actions := Style.hbox(8)
	if not an.approved and not ts.recruited and not ts.lost:
		var ab := Style.paper_button(T.t("board.analysis"), "analysis-" + t.target_id)
		ab.pressed.connect(Game.open_analysis.bind(t.target_id))
		actions.add_child(ab)
	# Встреча на «Тембр-2М»: вечером и по утверждённому досье.
	if an.approved and Meeting.meet_error(s, Game.content, t.target_id) == "":
		var mb := Style.paper_button(T.t("board.meet"), "meet-" + t.target_id)
		mb.pressed.connect(Game.start_meeting.bind(t.target_id))
		actions.add_child(mb)
	if actions.get_child_count() > 0:
		v.add_child(actions)
	p.add_child(v)
	return p


static func _axis_cell(t: Dictionary, axis: String) -> Control:
	var s: Dictionary = Game.state
	var k := Campaign.axis_knowledge(s, Game.content, t.target_id, axis)
	var n := Campaign.axis_pin_count(s, t.target_id, axis)
	var cell := DropZone.new(t.target_id, axis)
	cell.name = "drop-%s-%s" % [t.target_id, axis]
	cell.set_meta("knowledge", k)
	var border: Color = {"unknown": Color("#8a8578"), "hypothesis": Style.OCHRE_DARK, "confirmed": Style.THREAD_RED}[k]
	cell.add_theme_stylebox_override("panel", Style.box(Color(0, 0, 0, 0.03), border, 3 if k == "confirmed" else 1, 0, 6))
	cell.custom_minimum_size = Vector2(117, 92)
	cell.tooltip_text = T.t("mice.axis." + axis)
	var cv := Style.vbox(0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := Style.label(T.t("mice.axis.%s.short" % axis), Style.form(true), 24, Style.INK)
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(letter)
	var name_l := Style.label(T.t("mice.axis." + axis), Style.form(), 12, Color(Style.INK, 0.7))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(name_l)
	var status := T.t("board.cellUnknown") if k == "unknown" else (T.t("board.cellCount", {"n": n}) if k == "hypothesis" else T.t("board.cellConfirmed", {"value": t.mice_profile[axis].true_value}))
	var st := Style.label(status, Style.form(k == "confirmed"), 13, Style.STAMP_RED if k == "confirmed" else Style.INK)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(st)
	if k == "confirmed" and float(t.mice_profile[axis].get("backfire_risk", 0)) >= RED_LINE:
		var red := Style.label(T.t("board.redLine"), Style.form(true), 11, Style.STAMP_RED)
		red.name = "red-line-%s-%s" % [t.target_id, axis]
		red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(red)
	for c in cv.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(cv)
	return cell


# ——— Заключение по досье ———

static func _analysis_panel(target_id: String) -> Control:
	var s: Dictionary = Game.state
	var t := Campaign.target_by_id(Game.content, target_id)
	var an := Campaign.analysis_state(s, target_id)
	var form: Dictionary = Game.board_form
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := Style.rect(Color(0, 0, 0, 0.55), Rect2(0, 0, 1536, 756))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var p := Style.panel(Style.PAPER, 28)
	p.name = "analysis-panel"
	p.position = Vector2(300, 40)
	p.custom_minimum_size = Vector2(936, 0)
	var v := Style.vbox(10)
	var head := Style.hbox(10)
	head.add_child(Style.label(T.t("board.analysisTitle", {"name": T.loc(t.name)}).to_upper(), Style.form(true), 24, Style.INK))
	v.add_child(head)
	var pins := Campaign.pinned_clue_count(s, target_id)
	v.add_child(Style.para(T.t("board.analysisIntro", {"n": pins}), 880, Style.mono(), 13, Color(Style.INK, 0.8)))

	var groups := [
		["axis", T.t("board.fieldAxis"), AXES.map(func(a): return [a, "%s — %s" % [T.t("mice.axis.%s.short" % a), T.t("mice.axis." + a)]])],
		["access", T.t("board.fieldAccess"), t.analysis.access_options.map(func(o): return [o.id, T.loc(o.text)])],
		["channel", T.t("board.fieldChannel"), CHANNELS.map(func(c): return [c, T.t("board.channel." + c)])],
	]
	for g in groups:
		v.add_child(Style.label(g[1].to_upper(), Style.form(true), 15, Style.INK))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 6)
		for opt in g[2]:
			var on: bool = form.get(g[0], "") == opt[0]
			var b := Style.button(opt[1], "form-%s-%s" % [g[0], opt[0]], Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK, 13)
			b.pressed.connect(Game.set_board_form.bind(g[0], opt[0]))
			row.add_child(b)
		v.add_child(row)

	# Итог прошлой попытки (мягкая подсказка Golden Idol).
	if an.attempts > 0 and not an.approved:
		var res := Style.label(T.t("board.near") if an.wrong <= 2 else T.t("board.allWrong"), Style.form(true), 16, Style.STAMP_RED)
		res.name = "analysis-result"
		v.add_child(res)

	var actions := Style.hbox(10)
	var submit := Style.paper_button(T.t("board.submit"), "analysis-submit")
	submit.disabled = pins < ContentRules.THREE_CLUES or not (form.has("axis") and form.has("access") and form.has("channel"))
	submit.pressed.connect(func():
		Game.dispatch({"type": "submit_analysis", "target_id": target_id, "axis": Game.board_form.get("axis", ""), "access": Game.board_form.get("access", ""), "channel": Game.board_form.get("channel", "")})
		if Campaign.analysis_state(Game.state, target_id).approved:
			Game.open_analysis(""))
	actions.add_child(submit)
	var hint := Style.paper_button(T.t("board.hintButton", {"n": an.hint_level}), "analysis-hint")
	hint.disabled = an.hint_level >= 3
	hint.pressed.connect(Game.dispatch.bind({"type": "use_hint", "target_id": target_id}))
	actions.add_child(hint)
	var close := Style.paper_button(T.t("board.close"), "analysis-close")
	close.pressed.connect(Game.open_analysis.bind(""))
	actions.add_child(close)
	v.add_child(actions)
	if pins < ContentRules.THREE_CLUES:
		v.add_child(Style.label(T.t("board.needThree"), Style.mono(), 13, Style.STAMP_RED))

	# Подсказки: намёк → документ → ответ.
	if an.hint_level > 0:
		var hv := Style.vbox(4)
		hv.name = "analysis-hints"
		hv.add_child(Style.para("1. " + T.loc(t.analysis.hint), 880, Style.mono(), 13, Style.INK))
		if an.hint_level >= 2:
			hv.add_child(Style.para("2. " + _document_hint(t), 880, Style.mono(), 13, Style.INK))
		if an.hint_level >= 3:
			hv.add_child(Style.para("3. " + T.t("board.hintAnswer", {"axis": T.t("mice.axis." + t.analysis.leading_axis)}), 880, Style.mono(), 13, Style.INK))
		v.add_child(hv)
	p.add_child(v)
	root.add_child(p)
	return root


## Подсказка второго уровня: какую найденную улику о ведущем мотиве стоит перечитать.
static func _document_hint(t: Dictionary) -> String:
	var axis: String = t.analysis.leading_axis
	for clue in Game.content.clues:
		if clue.reveals.any(func(r): return r.target_id == t.target_id and r.axis == axis) and Game.state.clues.has(clue.clue_id):
			return T.t("board.hintDocument", {"title": T.loc(clue.title)})
	return T.t("board.hintDocumentNone")
