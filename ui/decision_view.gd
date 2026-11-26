class_name DecisionView
## Решение резидента на столе: служебная записка с вариантами. У каждого варианта видны
## последствия (никаких скрытых чисел); после выбора — штамп и итог.

const W := 900.0
const FX := ["sog_heat", "mole_hunt", "treasury", "moscow_pressure"]


static func build(d: Dictionary) -> Control:
	var s: Dictionary = Game.state
	var chosen: String = s.decisions.get(d.decision_id, "")
	var sb := Style.box(Style.PAPER, Color(0, 0, 0, 0), 0, 0, 0)
	sb.content_margin_left = 56
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	var p := PanelContainer.new()
	p.name = "decision"
	p.set_meta("decision", d.decision_id)
	p.set_meta("chosen", chosen)
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(12)
	v.custom_minimum_size.x = W - 104
	var head := Style.hbox(16)
	var kick := Style.label(T.t("decision.kicker").to_upper(), Style.form(true), 14, Style.STAMP_RED)
	kick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kick)
	head.add_child(Style.label(T.loc(d.sender), Style.form(), 14, Color(Style.INK, 0.65)))
	v.add_child(head)
	v.add_child(Style.para(T.loc(d.title), W - 104, Style.serif(true), 26, Style.INK))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.para(T.loc(d.text), W - 104, Style.mono(), 16, Style.INK))
	for o in d.options:
		var box := Style.panel(Color(0, 0, 0, 0.05) if chosen != o.option_id else Color("#e9c46a55"), 14, Color(Style.INK, 0.35), 1)
		var ov := Style.vbox(6)
		ov.add_child(Style.para(T.loc(o.label), W - 140, Style.form(true), 17, Style.INK))
		ov.add_child(Style.para(effects_text(o.effects), W - 140, Style.mono(), 13, Color(Style.INK, 0.75)))
		if chosen == "":
			var b := Style.paper_button(T.t("decision.choose"), "decide-%s-%s" % [d.decision_id, o.option_id])
			b.pressed.connect(Game.dispatch.bind({"type": "decide", "decision_id": d.decision_id, "option_id": o.option_id}))
			var row := Style.hbox(8)
			row.add_child(b)
			ov.add_child(row)
		elif chosen == o.option_id:
			ov.add_child(Style.stamp(T.t("decision.stamp"), Style.STAMP_RED, 14, -3))
			var out := Style.para(T.loc(o.outcome), W - 140, Style.serif(false, true), 16, Style.INK)
			out.name = "decision-outcome"
			ov.add_child(out)
		box.add_child(ov)
		v.add_child(box)
	p.add_child(v)
	return p


static func effects_text(fx: Dictionary) -> String:
	var parts: Array = []
	for r in FX:
		if int(fx.get(r, 0)) != 0:
			parts.append("%s %s" % [T.t("risk." + r), _signed(int(fx[r]))])
	if int(fx.get("centre_trust", 0)) != 0:
		parts.append(T.t("cipher.fx.trust", {"d": _signed(int(fx.centre_trust))}))
	if int(fx.get("fund_usd", 0)) != 0:
		parts.append(T.t("cipher.fx.fund", {"usd": Fmt.usd(int(fx.fund_usd))}))
	if int(fx.get("weekly_sog_heat", 0)) != 0:
		parts.append(T.t("decision.weekly", {"d": _signed(int(fx.weekly_sog_heat))}))
	if String(fx.get("operative_out", "")) != "":
		parts.append(T.t("decision.operativeOut", {"name": T.loc(Delegation.operative(Game.content, fx.operative_out).get("name", {"ru": fx.operative_out}))}))
	return T.t("decision.effects", {"list": ", ".join(parts) if not parts.is_empty() else T.t("cipher.fx.none")})


static func _signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)
