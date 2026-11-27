class_name PackageView
## Пробный пакет «крота» на столе: папка с материалами и листом проверки по трём каналам —
## тайник, картотека, учёты Центра. Каждый канал показывает итог или как его проверить;
## правило подставы видно заранее (никаких скрытых чисел). Внизу — «Принять» и «Отклонить».

const W := 900.0
const ITEM := "pkg"
const COLOR := {"ok": Color("#2e6b3a"), "mismatch": Style.STAMP_RED, "pending": Color(Style.INK, 0.55), "unavailable": Color(Style.INK, 0.4)}


static func build() -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var cfg := Dangle.config(c)
	var p: Dictionary = s.package
	var sb := Style.box(Color("#e8dcb8"), Color(0, 0, 0, 0), 0, 0, 0)
	sb.content_margin_left = 56
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	var panel := PanelContainer.new()
	panel.name = "package"
	panel.set_meta("source", p.source)
	panel.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(12)
	v.custom_minimum_size.x = W - 104
	var head := Style.hbox(16)
	var kick := Style.label(T.t("package.kicker").to_upper(), Style.form(true), 14, Style.STAMP_RED)
	kick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kick)
	head.add_child(Style.label(T.t("package.source." + p.source, {"week": p.week}), Style.form(), 14, Color(Style.INK, 0.65)))
	v.add_child(head)
	v.add_child(Style.para(T.loc(cfg.title), W - 104, Style.serif(true), 26, Style.INK))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.para(T.loc(cfg.text), W - 104, Style.mono(), 16, Style.INK))
	v.add_child(Style.label(T.t("package.checks").to_upper(), Style.form(true), 14, Color(Style.INK, 0.75)))
	var checks := Dangle.checks(s, c)
	for ch in Dangle.CHANNELS:
		v.add_child(_check_row(ch, checks[ch]))
	var rule := Style.para(T.t("package.rule"), W - 104, Style.serif(false, true), 15, Color(Style.INK, 0.8))
	rule.name = "package-rule"
	v.add_child(rule)
	if p.accepted:
		v.add_child(Style.stamp(T.t("package.accepted"), Style.STAMP_RED, 16, -3))
	elif p.rejected:
		v.add_child(Style.stamp(T.t("package.rejected"), Style.STAMP_RED, 16, -3))
		v.add_child(Style.para(T.t("package.rejectedHint", {"op": T.loc(Campaign.op_by_id(c, cfg.handover_op).title)}), W - 104, Style.mono(), 14, Style.INK))
	else:
		var mism := Dangle.count(s, c, "mismatch")
		var okn := Dangle.count(s, c, "ok")
		var verdict := Style.para(T.t("package.verdict.mismatch", {"n": mism}) if mism > 0 else T.t("package.verdict.ok", {"n": okn}),
			W - 104, Style.form(true), 16, COLOR.mismatch if mism > 0 else Style.INK)
		verdict.name = "package-verdict"
		v.add_child(verdict)
		var row := Style.hbox(10)
		var acc := Style.paper_button(T.t("package.accept"), "package-accept")
		acc.pressed.connect(Game.dispatch.bind({"type": "accept_package"}))
		row.add_child(acc)
		if Dangle.can_reject(s, c):
			var rej := Style.paper_button(T.t("package.reject"), "package-reject")
			rej.pressed.connect(Game.dispatch.bind({"type": "reject_package"}))
			row.add_child(rej)
		v.add_child(row)
	panel.add_child(v)
	return panel


static func _check_row(ch: String, status: String) -> Control:
	var box := Style.panel(Color(0, 0, 0, 0.05), 12, Color(Style.INK, 0.3), 1)
	box.name = "package-check-" + ch
	box.set_meta("status", status)
	var h := Style.hbox(14)
	var left := Style.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Style.label(T.t("package.channel." + ch), Style.form(true), 16, Style.INK))
	left.add_child(Style.para(T.t("package.how.%s.%s" % [ch, status]), W - 330, Style.mono(), 13, Color(Style.INK, 0.75)))
	h.add_child(left)
	if ch == "archive" and status == "pending" and Dangle.open(Game.state):
		var b := Style.paper_button(T.t("package.checkArchive"), "package-check-archive-btn")
		b.pressed.connect(Game.dispatch.bind({"type": "check_package", "channel": "archive"}))
		h.add_child(b)
	else:
		h.add_child(Style.stamp(T.t("package.status." + status), COLOR[status], 13, -2))
	box.add_child(h)
	return box
