class_name Shells
## Оболочки модулей. Каждая уже показывает живые данные кампании, а полноценная механика
## появится в своём шаге плана (номер шага — в подписи «в разработке»).

const PLAN_STEP := {"mice": 5, "cipher": 6, "dialog": 7, "finance": 8, "counterintel": 13}
const AXES := ["money", "ideology", "compromise", "ego"]


static func _shell(id: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.%s.name" % id), T.t("shell.wip", {"step": PLAN_STEP[id], "details": T.t("module.%s.details" % id)})))
	return root


## Доска мотивов: досье установленных целей с мотивами Д/И/К/С.
static func mice() -> Control:
	var root := _shell("mice")
	var s: Dictionary = Game.state
	var cork := Panel.new()
	cork.position = Vector2(28, 70)
	cork.size = Vector2(1480, 662)
	cork.add_theme_stylebox_override("panel", Style.box(Color("#a37c4f"), Color("#5a3f27"), 14))
	cork.add_child(CorkTexture.new(cork.size))
	root.add_child(cork)
	var flow := HFlowContainer.new()
	flow.name = "dossiers"
	flow.position = Vector2(70, 110)
	flow.size = Vector2(1400, 600)
	flow.add_theme_constant_override("h_separation", 32)
	flow.add_theme_constant_override("v_separation", 32)
	var hidden := 0
	for t in Game.content.targets:
		var ts: Dictionary = s.targets[t.target_id]
		if not ts.unlocked:
			if t.act <= s.act:
				hidden += 1
			continue
		flow.add_child(_dossier(t, ts))
	root.add_child(flow)
	if hidden > 0:
		var note := Style.label(T.t("mice.hidden", {"count": hidden}), Style.mono(), 15, Style.PAPER_LIGHT)
		note.position = Vector2(70, 690)
		note.name = "dossiers-hidden"
		root.add_child(note)
	return root


static func _dossier(t: Dictionary, ts: Dictionary) -> Control:
	var p := Style.panel(Style.PAPER_LIGHT, 18)
	p.name = "dossier-" + t.target_id
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	p.custom_minimum_size = Vector2(320, 0)
	p.rotation_degrees = -1.0 if hash(t.target_id) % 2 == 0 else 1.2
	var v := Style.vbox(6)
	var head := Style.hbox(8)
	head.add_child(Style.label(T.loc(t.name), Style.form(true), 22, Style.INK))
	if ts.recruited or ts.lost:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		head.add_child(Style.stamp(T.t("mice.recruited" if ts.recruited else "mice.lost"), Style.STAMP_RED, 14, -6))
	v.add_child(head)
	v.add_child(Style.para(T.loc(t.role), 284, Style.mono(), 13, Style.INK))
	var row := Style.hbox(6)
	for axis in AXES:
		var k := Campaign.axis_knowledge(Game.state, Game.content, t.target_id, axis)
		var cell := PanelContainer.new()
		cell.name = "axis-" + axis
		cell.set_meta("knowledge", k)
		var border: Color = {"unknown": Color("#8a8578"), "hypothesis": Style.OCHRE_DARK, "confirmed": Style.THREAD_RED}[k]
		cell.add_theme_stylebox_override("panel", Style.box(Color(0, 0, 0, 0), border, 2 if k == "confirmed" else 1, 0, 6))
		cell.custom_minimum_size = Vector2(66, 0)
		cell.tooltip_text = T.t("mice.axis." + axis)
		var cv := Style.vbox(0)
		var letter := Style.label(T.t("mice.axis.%s.short" % axis), Style.form(true), 22, Style.INK)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(letter)
		var note := Style.label(T.t("mice." + k), Style.form(), 12, Style.INK)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(note)
		cell.add_child(cv)
		cell.modulate.a = 0.45 if k == "unknown" else 1.0
		row.add_child(cell)
	v.add_child(row)
	p.add_child(v)
	return p


## Шифроузел: последняя директива на телетайпной ленте.
static func cipher() -> Control:
	var root := _shell("cipher")
	var s: Dictionary = Game.state
	var last := {}
	for c in Game.content.cables:
		if c.kind == "directive" and s.delivered_cables.has(c.cable_id):
			last = c
	var tape := Style.panel(Style.PAPER_LIGHT, 28)
	tape.name = "teletype"
	tape.position = Vector2(28, 76)
	var v := Style.vbox(10)
	if last.is_empty():
		v.add_child(Style.label(T.t("cipher.empty"), Style.mono(), 17, Style.INK))
	else:
		v.add_child(Style.para("%s %s · %s" % [T.t("cipher.from"), T.loc(last.sender), T.loc(last.subject)], 760, Style.mono(), 14, Color(Style.INK, 0.7)))
		var body := Style.para(T.loc(last.body).to_upper(), 760, Style.mono(), 17, Style.INK)
		body.add_theme_constant_override("line_spacing", 8)
		v.add_child(body)
	tape.add_child(v)
	root.add_child(tape)
	var trust := Style.label(T.t("cipher.trust", {"trust": s.centre_trust}), Style.mono(), 15, Color(Style.PAPER, 0.8))
	trust.position = Vector2(900, 80)
	root.add_child(trust)
	return root


## Финансовый журнал: остаток спецфонда и порог отчёта о валютной операции.
static func finance() -> Control:
	var root := _shell("finance")
	var page := Style.panel(Style.PAPER_LIGHT, 40)
	page.name = "ledger"
	page.position = Vector2(28, 76)
	page.custom_minimum_size = Vector2(1480, 640)
	var v := Style.vbox(24)
	v.add_child(Style.label(T.t("finance.balance", {"usd": Fmt.usd(Game.state.fund_usd)}), Style.mono(), 22, Style.INK))
	v.add_child(Style.label(T.t("finance.threshold"), Style.mono(), 16, Color(Style.INK, 0.75)))
	page.add_child(v)
	root.add_child(page)
	return root


static func dialog() -> Control:
	var root := _shell("dialog")
	root.add_child(Style.art("recorder", Rect2(28, 76, 760, 640)))
	var note := Style.label(T.t("dialog.empty"), Style.mono(), 15, Color(Style.PAPER, 0.8))
	note.position = Vector2(830, 90)
	root.add_child(note)
	return root


static func counterintel() -> Control:
	var root := _shell("counterintel")
	var note := Style.label(T.t("counterintel.empty"), Style.mono(), 15, Color(Style.PAPER, 0.8))
	note.position = Vector2(28, 90)
	root.add_child(note)
	return root


## Пробковая фактура: случайные (но одинаковые от запуска к запуску) крапинки.
class CorkTexture extends Control:
	func _init(sz: Vector2) -> void:
		size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1985
		for i in 2600:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(0.8, 1.8), Color("#8b663e") if i % 2 == 0 else Color("#b8915f"))
