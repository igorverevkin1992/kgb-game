class_name PolygraphView
## Протокол полиграфа на пульте обстановки. Слева — карта предтестового состояния: когда
## проверка, кто экзаменатор (если источник в Управлении безопасности ЦРУ его назвал), пункты
## инструктажа «Кроноса» с их действием. Справа — бумажная лента с тремя кривыми (дыхание,
## давление и пульс, кожно-гальваническая реакция), шкалы контакта и скепсиса экзаменатора,
## вопрос и варианты ответа; после пика на значимом вопросе — объяснение волнения.

const LEFT_W := 560.0
const RIGHT_X := 620.0
const RIGHT_W := 888.0
const CURVE_COLORS := {"breath": Color("#2f5f9e"), "pulse": Color("#8e2b22"), "gsr": Color("#3d6b3a")}


static func build() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s: Dictionary = Game.state
	var p = s.get("polygraph")
	if p == null:
		var empty := Style.para(T.t("polygraph.empty"), 900, Style.mono(), 15, Color(Style.PAPER, 0.8))
		empty.position = Vector2(28, 120)
		root.add_child(empty)
		return root
	var e := Polygraph.by_id(Game.content, p.exam_id)
	root.add_child(_prep(s, p, e))
	root.add_child(_tape(s, p, e))
	return root


# ——— Подготовка ———

static func _prep(s: Dictionary, p: Dictionary, e: Dictionary) -> Control:
	var c: Dictionary = Game.content
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 118)
	scroll.size = Vector2(LEFT_W + 16, 640)
	var panel := Style.panel(Color("#e8dcb8"), 20)
	panel.name = "polygraph-prep"
	panel.custom_minimum_size.x = LEFT_W
	var v := Style.vbox(8)
	var w := LEFT_W - 40
	var d := Campaign.week_date(c, int(s.act), int(e.week))
	v.add_child(Style.label(T.t("polygraph.prepTitle").to_upper(), Style.form(true), 14, Style.STAMP_RED))
	v.add_child(Style.para(T.loc(e.title), w, Style.serif(true), 19, Style.INK))
	v.add_child(Style.para(T.t("polygraph.when", {"week": e.week, "date": Fmt.date(d) if d.size() > 0 else ""}), w, Style.form(true), 14, Style.INK))
	v.add_child(Style.para(T.loc(e.notice.text_with_source if p.source else e.notice.text_without), w, Style.mono(), 13, Color(Style.INK, 0.85)))
	var prof := T.t("polygraph.examiner", {"name": T.loc(e.examiner_profile.name), "text": T.loc(e.examiner_profile.description)}) if p.source else T.t("polygraph.examinerUnknown")
	var pl := Style.para(prof, w, Style.mono(), 13, Style.INK)
	pl.name = "polygraph-examiner"
	v.add_child(pl)
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	var slots := Style.label(T.t("polygraph.slots", {"used": p.prep.size(), "of": p.slots}), Style.form(true), 14, Style.INK)
	slots.name = "polygraph-slots"
	v.add_child(slots)
	for o in e.prep_options:
		var box := Style.vbox(3)
		box.name = "prep-" + o.prep_id
		box.add_child(Style.para(T.loc(o.label), w, Style.form(true), 14, Style.INK))
		box.add_child(Style.para(T.loc(o.text) + " " + _prep_fx(o, e, p.source), w, Style.mono(), 12, Color(Style.INK, 0.75)))
		if p.prep.has(o.prep_id):
			box.add_child(Style.stamp(T.t("polygraph.prepDone"), Style.STAMP_RED, 12, -2))
		else:
			var err := Polygraph.prep_error(s, c, o.prep_id)
			if err == "":
				var b := Style.paper_button(T.t("polygraph.prepDo"), "prep-do-" + o.prep_id)
				b.pressed.connect(Game.dispatch.bind({"type": "polygraph_prep", "prep_id": o.prep_id}))
				box.add_child(b)
			else:
				box.add_child(Style.para(err, w, Style.mono(), 12, Color(Style.INK, 0.55)))
		v.add_child(box)
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	var sm := Polygraph.prep_summary(s, c)
	var sum := Style.para(T.t("polygraph.summary", {"st": sm.stability, "r": _signed(sm.rapport), "sk": _signed(sm.skepticism),
		"fin": T.t("polygraph.shield." + (sm.shield_reason if sm.finance_shield else "none"), {"n": e.finance_stress})}), w, Style.mono(), 13, Style.INK)
	sum.name = "polygraph-summary"
	v.add_child(sum)
	v.add_child(Style.para(T.t("polygraph.rule"), w, Style.serif(false, true), 13, Color(Style.INK, 0.8)))
	panel.add_child(v)
	scroll.add_child(panel)
	return scroll


static func _prep_fx(o: Dictionary, e: Dictionary, source: bool) -> String:
	var parts: Array = []
	if int(o.stability) != 0:
		parts.append(T.t("polygraph.fx.stability", {"n": o.stability}))
	if int(o.skepticism) != 0:
		parts.append(T.t("polygraph.fx.skepticism", {"n": _signed(int(o.skepticism))}))
	if o.kind == "strategy":
		parts.append(T.t("polygraph.fx.strategy", {"n": o.rapport}) if source else T.t("polygraph.fx.strategyBlind", {"n": o.rapport}))
	elif int(o.rapport) != 0:
		parts.append(T.t("polygraph.fx.rapport", {"n": _signed(int(o.rapport))}))
	if o.kind == "legend":
		parts.append(T.t("polygraph.fx.legend", {"n": e.finance_stress}))
	return "(" + ", ".join(parts) + ")" if not parts.is_empty() else ""


# ——— Лента и допрос ———

static func _tape(s: Dictionary, p: Dictionary, e: Dictionary) -> Control:
	var c: Dictionary = Game.content
	var v := Style.vbox(10)
	v.name = "polygraph-tape"
	v.position = Vector2(RIGHT_X, 118)
	v.custom_minimum_size.x = RIGHT_W
	var x = p.exam
	var head := Style.hbox(16)
	var title := T.t("polygraph.tapeRehearsal") if x != null and x.rehearsal else T.t("polygraph.tape")
	var tl := Style.label(title.to_upper(), Style.form(true), 15, Style.PAPER)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	for k in ["breath", "pulse", "gsr"]:
		head.add_child(Style.label("— " + T.t("polygraph.curve." + k), Style.form(), 13, CURVE_COLORS[k].lightened(0.35)))
	v.add_child(head)
	var tape := TapeCanvas.new(Polygraph.curves(x) if x != null else [], Vector2(RIGHT_W, 190))
	tape.name = "polygraph-curves"
	v.add_child(tape)
	if x != null:
		var bars := Style.hbox(20)
		bars.add_child(_bar("polygraph-rapport", T.t("polygraph.rapport", {"n": x.rapport, "need": e.examiner_profile.rapport_threshold_pass}), int(x.rapport), int(e.examiner_profile.rapport_threshold_pass), Color("#4f7a3e")))
		bars.add_child(_bar("polygraph-skepticism", T.t("polygraph.skepticism", {"n": x.skepticism, "limit": e.examiner_profile.skepticism_fail_limit}), int(x.skepticism), int(e.examiner_profile.skepticism_fail_limit), Color("#8e2b22")))
		v.add_child(bars)
		var peaks := Style.label(T.t("polygraph.peaks", {"c": x.control_peak, "r": x.relevant_peak}), Style.mono(), 13, Color(Style.PAPER, 0.85))
		peaks.name = "polygraph-peaks"
		v.add_child(peaks)
	v.add_child(_question_box(s, p, e, x))
	return v


static func _question_box(s: Dictionary, p: Dictionary, e: Dictionary, x) -> Control:
	var c: Dictionary = Game.content
	var box := Style.vbox(8)
	box.name = "polygraph-question"
	var w := RIGHT_W
	if x != null and x.has("verdict"):
		var out: Dictionary = e.outcomes[x.verdict]
		box.add_child(Style.stamp(T.t("polygraph.verdict." + x.verdict), Style.STAMP_RED if x.verdict != "pass" else Color("#2e6b3a"), 16, -3))
		if x.rehearsal:
			box.add_child(Style.para(T.t("polygraph.rehearsalDone"), w, Style.mono(), 14, Style.PAPER))
		else:
			var ot := Style.para(T.loc(out.text), w, Style.serif(false, true), 16, Style.PAPER)
			ot.name = "polygraph-outcome"
			box.add_child(ot)
	elif x != null and x.pending:
		box.add_child(Style.para(T.t("polygraph.spike"), w, Style.form(true), 15, Color("#e2a27f")))
		for o in e.rationalizations:
			if x.used.has(o.option_id):
				continue
			var b := Style.button(T.loc(o.label) + " — " + _fx(o.effects), "rationalize-" + o.option_id, Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 13)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = w
			b.pressed.connect(Game.dispatch.bind({"type": "polygraph_rationalize", "option_id": o.option_id}))
			box.add_child(b)
	elif x != null:
		var q := Polygraph.question(c, s)
		box.add_child(Style.label(T.t("polygraph.qcat." + q.category) + " · " + T.t("polygraph.qnum", {"n": int(x.step) + 1, "of": e.question_sequence.size()}), Style.form(true), 13, Color(Style.PAPER, 0.75)))
		var qt := Style.para("— " + T.loc(q.text), w, Style.serif(true), 19, Style.PAPER_LIGHT)
		qt.name = "polygraph-qtext"
		box.add_child(qt)
		for ch in Polygraph.choices(c, s):
			var label := T.loc(ch.label)
			var fx := _fx(ch.effects, q, x, ch)
			if fx != "":
				label += " — " + fx
			var b := Style.button(label, "answer-" + ch.choice_id, Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 13)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = w
			b.pressed.connect(Game.dispatch.bind({"type": "polygraph_answer", "choice_id": ch.choice_id}))
			box.add_child(b)
	if p.result == "" and (x == null or x.rehearsal):
		var row := Style.hbox(10)
		var rb := Style.button(T.t("polygraph.rehearse"), "polygraph-rehearse", Style.PAPER, Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.6), 14)
		rb.pressed.connect(Game.dispatch.bind({"type": "polygraph_start", "rehearsal": true}))
		row.add_child(rb)
		if int(s.week) >= int(e.week):
			var sb := Style.button(T.t("polygraph.begin"), "polygraph-begin", Style.PAPER, Color(Style.STAMP_RED, 0.45), Color(Style.PAPER, 0.6), 14)
			sb.pressed.connect(Game.dispatch.bind({"type": "polygraph_start", "rehearsal": false}))
			row.add_child(sb)
		else:
			row.add_child(Style.label(T.t("polygraph.notYet", {"week": e.week}), Style.mono(), 13, Color(Style.PAPER, 0.75)))
		box.add_child(row)
	return box


## Что изменит ответ (для значимого вопроса — пик реакции при нынешней подготовке).
static func _fx(fx: Dictionary, q := {}, x = null, ch := {}) -> String:
	var parts: Array = []
	if int(fx.rapport) != 0:
		parts.append(T.t("polygraph.fx.rapport", {"n": _signed(int(fx.rapport))}))
	if int(fx.skepticism) != 0:
		parts.append(T.t("polygraph.fx.skepticism", {"n": _signed(int(fx.skepticism))}))
	if int(fx.control_peak) != 0:
		parts.append(T.t("polygraph.fx.control", {"n": fx.control_peak}))
	if not q.is_empty() and q.category == "relevant_critical" and x != null:
		parts.append(T.t("polygraph.fx.relevant", {"n": Polygraph.relevant_peak(q, x, ch)}))
	elif int(fx.relevant_peak) != 0:
		parts.append(T.t("polygraph.fx.relevantDelta", {"n": _signed(int(fx.relevant_peak))}))
	return ", ".join(parts)


static func _bar(id: String, title: String, value: int, mark: int, color: Color) -> Control:
	var b := Style.vbox(2)
	b.name = id
	b.set_meta("value", value)
	b.add_child(Style.label(title, Style.form(true), 13, Style.PAPER))
	var bar := DialogView.Bar.new(value, mark, color)
	bar.custom_minimum_size = Vector2(RIGHT_W / 2 - 12, 14)
	b.add_child(bar)
	return b


static func _signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)


## Бумажная лента самописца: три кривые по шагам допроса; пики на значимых вопросах — красные метки.
class TapeCanvas extends Control:
	var points: Array
	func _init(p_points: Array, sz: Vector2) -> void:
		points = p_points
		custom_minimum_size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#ece4cc"))
		for i in range(0, int(size.x), 24):
			draw_line(Vector2(i, 0), Vector2(i, size.y), Color(0.55, 0.45, 0.35, 0.18))
		for j in range(0, int(size.y), 19):
			draw_line(Vector2(0, j), Vector2(size.x, j), Color(0.55, 0.45, 0.35, 0.18))
		var lanes := {"breath": 0, "pulse": 1, "gsr": 2}
		var lane_h := size.y / 3.0
		var step := size.x / 8.0
		for k in lanes:
			var base: float = lane_h * (int(lanes[k]) + 1) - 8
			var pts := PackedVector2Array([Vector2(0, base)])
			for i in points.size():
				var v: float = points[i][k]
				var x0 := step * i
				# Небольшая «дрожь» пера, одинаковая от запуска к запуску.
				for t in 6:
					var xx := x0 + step * (t + 1) / 6.0
					var amp := (v / 100.0) * (lane_h - 14) * sin(PI * (t + 1) / 6.0)
					pts.append(Vector2(xx, base - amp + (2 if t % 2 == 0 else -2)))
			pts.append(Vector2(size.x, base))
			draw_polyline(pts, PolygraphView.CURVE_COLORS[k], 2.0, true)
		for i in points.size():
			var kind: String = points[i].kind
			var mx := step * i + step / 2
			if kind == "control_comparison":
				draw_string(Style.form(true), Vector2(mx - 4, 14), "К", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.2, 0.2, 0.2))
			elif kind == "relevant_critical":
				draw_string(Style.form(true), Vector2(mx - 4, 14), "З", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8e2b22") if points[i].spike else Color(0.2, 0.2, 0.2))
				if points[i].spike:
					draw_rect(Rect2(step * i + 2, 2, step - 4, size.y - 4), Color("#8e2b22"), false, 2.0)
