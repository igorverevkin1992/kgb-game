class_name CipherView
## Шифроузел «Фиалка» (М-125) и телетайп. Слева — ключевой блокнот (ключ роторов и контрольная
## группа недели) и вкладки; справа — машина: входящие директивы Центра (короткий ритуал:
## ключ по блокноту → принять → лента печатает открытый текст → сверка контрольной группы)
## или исходящая шифрограмма: факты недели «как есть / приукрасить / умолчать», запрос в Центр
## и видимые последствия до отправки.

const LEFT_W := 380.0
const RIGHT_X := 440.0
const RIGHT_W := 1068.0
const TOP := 76.0
const H := 660.0
const TAPE := Color("#efe9d6")
const MACHINE := Color("#2b2d27")
## Высота нижней плашки шифрограммы: вид донесения, последствия, кнопка отправки.
const FOOT := 150.0


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.cipher.name"), T.t("cipher.note", {"trust": s.centre_trust, "pressure": s.risks.moscow_pressure})))
	var dirs := Cipher.directives(s, Game.content)
	var selected := _selected(dirs)
	var notebook_week: int = s.week
	if Game.cipher_tab == "incoming" and not selected.is_empty():
		notebook_week = selected.week
	var left := Style.vbox(14)
	left.position = Vector2(28, TOP)
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_child(_notebook(s.act if selected.is_empty() else selected.act, notebook_week))
	left.add_child(_tabs(s, dirs))
	if Game.cipher_tab == "incoming":
		left.add_child(_directive_list(s, dirs, selected))
	root.add_child(left)
	if Game.cipher_tab == "outgoing":
		root.add_child(_outgoing(s))
	elif selected.is_empty():
		var empty := Style.label(T.t("cipher.empty"), Style.mono(), 17, Color(Style.PAPER, 0.7))
		empty.name = "cipher-empty"
		empty.position = Vector2(RIGHT_X, TOP + 10)
		root.add_child(empty)
	else:
		root.add_child(_incoming(s, selected))
	return root


## Выбранная директива: явный выбор, иначе первая ждущая решения, иначе последняя.
static func _selected(dirs: Array) -> Dictionary:
	for c in dirs:
		if c.cable_id == Game.cipher_selected:
			return c
	for c in dirs:
		if not Game.state.verified.has(c.cable_id):
			return c
	return dirs[-1] if not dirs.is_empty() else {}


# ——— Левая колонка ———

static func _notebook(act: int, week: int) -> Control:
	var p := Style.panel(Color("#e8dcb4"), 20, Color("#9c8a5c"), 1)
	p.name = "key-notebook"
	var v := Style.vbox(6)
	v.add_child(Style.label(T.t("cipher.notebook").to_upper(), Style.form(true), 16, Style.INK))
	v.add_child(Style.label(T.t("cipher.notebookPage", {"week": week}), Style.form(), 14, Color(Style.INK, 0.7)))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.label(T.t("cipher.key"), Style.form(), 14, Color(Style.INK, 0.75)))
	var spaced: Array = []
	for ch in Cipher.week_key(act, week):
		spaced.append(ch)
	var key := Style.label(" ".join(spaced), Style.mono(), 24, Style.INK)
	key.name = "notebook-key"
	v.add_child(key)
	v.add_child(Style.label(T.t("cipher.group"), Style.form(), 14, Color(Style.INK, 0.75)))
	var group := Style.label(Cipher.week_group(act, week), Style.mono(), 30, Style.STAMP_RED)
	group.name = "notebook-group"
	v.add_child(group)
	v.add_child(Style.para(T.t("cipher.notebookHint"), LEFT_W - 40, Style.mono(), 12, Color(Style.INK, 0.7)))
	p.add_child(v)
	return p


static func _tabs(s: Dictionary, dirs: Array) -> Control:
	var row := Style.hbox(8)
	var pending: int = dirs.filter(func(c): return not s.verified.has(c.cable_id)).size()
	for tab in ["incoming", "outgoing"]:
		var on: bool = Game.cipher_tab == tab
		var text := T.t("cipher.tab." + tab)
		if tab == "incoming" and pending > 0:
			text += " (%d)" % pending
		var b := Style.button(text, "cipher-tab-" + tab, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.55), 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Game.set_cipher_tab.bind(tab))
		row.add_child(b)
	return row


static func _directive_list(s: Dictionary, dirs: Array, selected: Dictionary) -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LEFT_W, 230)
	var list := Style.vbox(6)
	list.name = "cipher-list"
	list.custom_minimum_size.x = LEFT_W - 12
	var shown := dirs.duplicate()
	shown.reverse()
	for c in shown:
		var status := Cipher.directive_status(s, c.cable_id)
		var cur: bool = not selected.is_empty() and c.cable_id == selected.cable_id
		var b := Button.new()
		b.name = "cipher-item-" + c.cable_id
		b.focus_mode = Control.FOCUS_NONE
		var sb := Style.box(Color(Style.PAPER, 0.22 if cur else 0.08), Style.STAMP_RED if not s.verified.has(c.cable_id) else Color(0, 0, 0, 0), 0, 0, 10)
		sb.border_width_left = 4
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate()
		hov.bg_color = Color(Style.PAPER, 0.16)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.pressed.connect(Game.select_directive.bind(c.cable_id))
		var v := Style.vbox(2)
		v.position = Vector2(14, 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Style.label("%s · %s" % [T.t("calendar.week", {"week": c.week}), T.t("cipher.status." + status)], Style.form(), 13, Color(Style.PAPER, 0.7)))
		# До расшифровки тема неизвестна: видна только шапка ленты.
		var subj := T.loc(c.subject) if status != "encrypted" else T.t("cipher.encryptedSubject")
		var l := Style.para(subj, LEFT_W - 40, Style.form(status == "encrypted"), 16, Style.PAPER)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
		b.add_child(v)
		b.custom_minimum_size = Vector2(LEFT_W - 12, maxf(56, v.get_combined_minimum_size().y + 16))
		list.add_child(b)
	scroll.add_child(list)
	return scroll


# ——— Входящие: ритуал расшифровки и сверка ———

static func _incoming(s: Dictionary, cable: Dictionary) -> Control:
	var id: String = cable.cable_id
	var status := Cipher.directive_status(s, id)
	var key_set: bool = status != "encrypted" or Game.cipher_key_set == id
	var v := Style.vbox(14)
	v.position = Vector2(RIGHT_X, TOP)
	v.custom_minimum_size = Vector2(RIGHT_W, 0)
	v.add_child(_rotors(Cipher.week_key(cable.act, cable.week) if key_set else Cipher.idle_rotors(cable), key_set))
	if status == "encrypted":
		v.add_child(_cipher_tape(cable))
		var step := Style.para(T.t("cipher.step2") if key_set else T.t("cipher.step1", {"week": cable.week}), RIGHT_W, Style.mono(), 14, Color(Style.PAPER, 0.85))
		step.name = "cipher-step"
		v.add_child(step)
		var row := Style.hbox(10)
		var kb := Style.button(T.t("cipher.setKey"), "cipher-set-key", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 15)
		kb.disabled = key_set
		kb.pressed.connect(Game.set_cipher_key.bind(id))
		row.add_child(kb)
		var db := Style.button(T.t("cipher.decode"), "cipher-decode", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 15)
		db.disabled = not key_set
		db.pressed.connect(Game.decode_directive.bind(id))
		row.add_child(db)
		v.add_child(row)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(RIGHT_W, H - 96)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner := Style.vbox(14)
		inner.custom_minimum_size.x = RIGHT_W - 16
		inner.add_child(_plain_tape(cable))
		inner.add_child(_verify(s, cable))
		scroll.add_child(inner)
		v.add_child(scroll)
	return v


## Окошко роторов: 10 букв. Пока ключ не выставлен — случайное положение.
static func _rotors(letters: String, is_set: bool) -> Control:
	var p := Style.panel(MACHINE, 12, Color("#5a5c52"), 2)
	p.name = "cipher-rotors"
	p.set_meta("letters", letters)
	var row := Style.hbox(8)
	row.add_child(Style.label(T.t("cipher.rotors").to_upper(), Style.form(true), 14, Color(Style.PAPER, 0.7)))
	for ch in letters:
		var cell := Style.panel(Color("#d8d2bd") if is_set else Color("#8d8a7c"), 6)
		cell.custom_minimum_size = Vector2(38, 0)
		var l := Style.label(ch, Style.mono(), 24, Style.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		row.add_child(cell)
	if is_set:
		row.add_child(Style.label(T.t("cipher.keySet"), Style.form(true), 14, Color("#a9c89c")))
	p.add_child(row)
	return p


static func _cipher_tape(cable: Dictionary) -> Control:
	var p := Style.panel(TAPE, 22)
	p.name = "cipher-tape"
	var v := Style.vbox(8)
	v.add_child(Style.label(T.t("cipher.tapeHead", {"week": cable.week}).to_upper(), Style.mono(), 14, Color(Style.INK, 0.65)))
	var groups := Cipher.cipher_groups(cable)
	var text := ""
	for i in groups.size():
		text += groups[i] + ("\n" if (i + 1) % 10 == 0 else "   ")
	var body := Style.para(text.strip_edges(), RIGHT_W - 44, Style.mono(), 19, Style.INK)
	body.add_theme_constant_override("line_spacing", 8)
	v.add_child(body)
	p.add_child(v)
	return p


## Лента с открытым текстом. Сразу после расшифровки печатается (1,6 с, клик — пропустить),
## при «Мгновенном выводе текста» — сразу целиком.
static func _plain_tape(cable: Dictionary) -> Control:
	var p := Style.panel(TAPE, 24)
	p.name = "cipher-plain"
	var v := Style.vbox(10)
	var group := Style.label(T.t("cipher.received", {"group": Cipher.received_group(cable)}), Style.mono(), 20, Style.INK)
	group.name = "received-group"
	group.set_meta("group", Cipher.received_group(cable))
	v.add_child(group)
	v.add_child(Style.para("%s %s · %s" % [T.t("cipher.from"), T.loc(cable.sender).to_upper(), T.loc(cable.subject).to_upper()], RIGHT_W - 48, Style.mono(), 14, Color(Style.INK, 0.7)))
	var body := DocumentView.body(cable, RIGHT_W - 48, Style.mono(), 18, Style.INK, true)
	v.add_child(body)
	v.add_child(DocumentView.intuition(cable, RIGHT_W - 48, Color(Style.INK, 0.6)))
	p.add_child(v)
	var anim: Dictionary = Game.cipher_anim
	if anim.get("cable_id", "") == cable.cable_id:
		var done := clampf((Time.get_ticks_msec() - int(anim.start)) / (Game.DECODE_SECONDS * 1000.0), 0.0, 1.0)
		body.visible_ratio = done
		p.set_meta("typing", true)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		body.mouse_filter = Control.MOUSE_FILTER_PASS  # клик по тексту доходит до ленты
		p.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: Game.finish_decode())
		var tw := body.create_tween()
		tw.tween_property(body, "visible_ratio", 1.0, Game.DECODE_SECONDS * (1.0 - done))
		tw.tween_callback(func(): Game.cipher_anim = {})
	return p


static func _verify(s: Dictionary, cable: Dictionary) -> Control:
	var b: Dictionary = Game.content.balance.cipher
	var p := Style.panel(Color(0, 0, 0, 0.25), 18, Color(Style.PAPER, 0.3), 1)
	p.name = "cipher-verify"
	var v := Style.vbox(10)
	if s.verified.has(cable.cable_id):
		var decision: String = s.verified[cable.cable_id]
		var outcome := Cipher.verify_outcome(cable, decision)
		v.add_child(Style.stamp(T.t("cipher.stamp." + decision), Color("#e2826f") if decision == "query" else Color("#a9c89c"), 16, -3))
		var res := Style.para(T.t("cipher.outcome." + outcome), RIGHT_W - 40, Style.mono(), 15, Style.PAPER)
		res.name = "cipher-verdict"
		res.set_meta("outcome", outcome)
		v.add_child(res)
	else:
		v.add_child(Style.para(T.t("cipher.verifyHint"), RIGHT_W - 40, Style.mono(), 15, Style.PAPER))
		v.add_child(Style.para(T.t("cipher.verifyStakes", {
			"trust": _signed(b.query_genuine_trust), "pressure": _signed(b.query_genuine_pressure),
			"sog": _signed(b.accept_forged_sog_heat), "bonus": _signed(b.query_forged_trust)}), RIGHT_W - 40, Style.mono(), 13, Color(Style.PAPER, 0.7)))
		var row := Style.hbox(10)
		var acc := Style.button(T.t("cipher.accept"), "cipher-accept", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 15)
		acc.pressed.connect(Game.verify_directive.bind(cable.cable_id, "accept"))
		row.add_child(acc)
		var q := Style.button(T.t("cipher.query"), "cipher-query", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 15)
		q.pressed.connect(Game.verify_directive.bind(cable.cable_id, "query"))
		row.add_child(q)
		v.add_child(row)
	p.add_child(v)
	return p


# ——— Исходящая шифрограмма ———

static func _outgoing(s: Dictionary) -> Control:
	var content: Dictionary = Game.content
	var draft: Dictionary = Game.report_draft()
	var facts := Cipher.week_facts(s)
	var root := Control.new()
	root.position = Vector2(RIGHT_X, TOP)
	root.size = Vector2(RIGHT_W, H)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(RIGHT_W, H - FOOT - 12)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := Style.panel(TAPE, 28)
	p.name = "ciphergram"
	p.custom_minimum_size.y = scroll.size.y
	var v := Style.vbox(10)
	v.custom_minimum_size.x = RIGHT_W - 72
	var w := RIGHT_W - 72
	v.add_child(Style.label(T.t("cipher.gramHead").to_upper(), Style.form(true), 22, Style.INK))
	v.add_child(Style.label(T.t("cipher.gramTo", {"week": s.week, "date": Fmt.date(Campaign.phase_date(content, s.act, s.week, "night"))}), Style.mono(), 14, Color(Style.INK, 0.7)))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.para(T.t("cipher.gramHint"), w, Style.mono(), 13, Color(Style.INK, 0.75)))

	for i in facts.size():
		v.add_child(_fact_row(i, facts[i], draft.choices.get(facts[i].key, "as_is"), w))

	var reqs := Cipher.available_requests(s, content)
	if not reqs.is_empty():
		v.add_child(Style.hline(Color(Style.INK, 0.3)))
		v.add_child(Style.label(T.t("cipher.requests").to_upper(), Style.form(true), 16, Style.INK))
		for r in reqs:
			v.add_child(_request_row(s, r, draft.request == r.request_id, w))

	p.add_child(v)
	scroll.add_child(p)
	root.add_child(scroll)

	# Итог и отправка всегда на виду, под листом шифрограммы.
	var foot := Style.panel(Color("#d8d0b6"), 16, Color(Style.INK, 0.5), 1)
	foot.position = Vector2(0, H - FOOT)
	foot.custom_minimum_size = Vector2(RIGHT_W, FOOT)
	var fh := Style.hbox(20)
	fh.add_child(_summary(s, Cipher.classify(facts, draft.choices), RIGHT_W - 360))
	var col := Style.vbox(6)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var send := Style.paper_button(T.t("cipher.send"), "cipher-send")
	send.disabled = s.phase != "night"
	send.pressed.connect(Game.send_report)
	col.add_child(send)
	if s.phase != "night":
		col.add_child(Style.para(T.t("cipher.sendAtNight"), 290, Style.mono(), 12, Color(Style.INK, 0.7)))
	fh.add_child(col)
	foot.add_child(fh)
	root.add_child(foot)
	return root


static func _fact_row(i: int, fact: Dictionary, choice: String, w: float) -> Control:
	var box := Style.vbox(6)
	box.name = "fact-%d" % i
	box.set_meta("key", fact.key)
	box.set_meta("negative", fact.negative)
	var top := Style.hbox(10)
	if fact.negative:
		top.add_child(Style.stamp(T.t("cipher.failure"), Style.STAMP_RED, 12, 0))
	var text: String
	var color := Style.INK
	match choice:
		"embellish":
			text = T.t("fact.%s.embellish" % fact.type, {"name": _fact_name(fact)})
			color = Color("#6b3a12")
		"omit":
			text = T.t("cipher.omitted", {"text": T.t("fact.%s.as_is" % fact.type, {"name": _fact_name(fact)})})
			color = Color(Style.INK, 0.4)
		_:
			text = T.t("fact.%s.as_is" % fact.type, {"name": _fact_name(fact)})
	var l := Style.para(text, w - (90 if fact.negative else 0), Style.mono(), 16, color)
	l.name = "fact-text-%d" % i
	top.add_child(l)
	box.add_child(top)
	var row := Style.hbox(8)
	for c in Cipher.CHOICES:
		var on: bool = c == choice
		var b := Style.button(T.t("cipher.choice." + c), "fact-%d-%s" % [i, c], Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK, 13)
		b.pressed.connect(Game.set_report_choice.bind(fact.key, c))
		row.add_child(b)
	box.add_child(row)
	return box


static func _fact_name(fact: Dictionary) -> String:
	var c: Dictionary = Game.content
	match fact.type:
		"op_done", "op_aborted":
			return T.loc(Campaign.op_by_id(c, fact.ref).title)
		"directive_exposed":
			return T.loc(Campaign.cable_by_id(c, fact.ref).subject)
		"quiet":
			return ""
	return T.loc(Campaign.target_by_id(c, fact.ref).name)


static func _request_row(s: Dictionary, r: Dictionary, on: bool, w: float) -> Control:
	var box := Style.vbox(4)
	var b := Style.button(("[+] " if on else "[  ] ") + T.loc(r.title), "request-" + r.request_id, Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK, 14)
	b.pressed.connect(Game.set_report_request.bind(r.request_id))
	var row := Style.hbox(8)
	row.add_child(b)
	box.add_child(row)
	var grant := Cipher.would_grant(s, r)
	var cond := Style.para(T.t("cipher.requestCond", {
		"min": r.min_trust, "trust": s.centre_trust,
		"verdict": T.t("cipher.willGrant") if grant else T.t("cipher.willRefuse"),
		"granted": _fx_text(r.granted), "refused": _fx_text(r.refused)}), w, Style.mono(), 13, Color(Style.INK, 0.75))
	cond.name = "request-cond-" + r.request_id
	box.add_child(cond)
	if on:
		box.add_child(Style.para("«%s»" % T.loc(r.phrase), w, Style.mono(), 15, Style.INK))
	return box


static func _fx_text(fx: Dictionary) -> String:
	var parts: Array = []
	if fx.get("fund_usd", 0) != 0:
		parts.append(T.t("cipher.fx.fund", {"usd": Fmt.usd(fx.fund_usd)}))
	if fx.get("centre_trust", 0) != 0:
		parts.append(T.t("cipher.fx.trust", {"d": _signed(fx.centre_trust)}))
	if fx.get("moscow_pressure", 0) != 0:
		parts.append(T.t("cipher.fx.pressure", {"d": _signed(fx.moscow_pressure)}))
	if fx.get("extend_act_weeks", 0) != 0:
		var n: int = fx.extend_act_weeks
		parts.append(T.t("cipher.fx.weeks", {"n": n, "w": Fmt.plural(n, "неделя", "недели", "недель")}))
	return ", ".join(parts) if not parts.is_empty() else T.t("cipher.fx.none")


## Итог до отправки: вид донесения и те же числа, что применит движок (никаких скрытых чисел).
static func _summary(s: Dictionary, report: String, w: float) -> Control:
	var b: Dictionary = Game.content.balance
	var fx := Cipher.report_effects(s, Game.content, report)
	var p := MarginContainer.new()
	p.name = "report-summary"
	p.custom_minimum_size.x = w
	p.set_meta("report", report)
	var v := Style.vbox(4)
	v.add_child(Style.label(T.t("cipher.kind." + report).to_upper(), Style.form(true), 18, Style.STAMP_RED if report != "truth" else Style.INK))
	v.add_child(Style.para(T.t("cipher.effects", {"trust": _signed(fx.trust), "pressure": _signed(fx.pressure)}), w, Style.mono(), 14, Style.INK))
	if int(fx.get("overdue_tasks", 0)) > 0:
		v.add_child(Style.para(T.t("cipher.overdueTasks", {"n": fx.overdue_tasks}), w, Style.mono(), 13, Style.STAMP_RED))
	if fx.lie:
		v.add_child(Style.para(T.t("cipher.lieRisk", {
			"week": fx.check_week, "pct": int(round(fx.lie_chance * 100)),
			"trust": _signed(b.centre_trust.lie_uncovered), "pressure": _signed(b.moscow_pressure.lie_uncovered)}), w, Style.mono(), 14, Style.STAMP_RED))
	p.add_child(v)
	return p


static func _signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)
