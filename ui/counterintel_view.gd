class_name CounterintelView
## Пульт контрразведывательной обстановки: Московская картотека («Окно арестов»).
## Сверху — график недель окна с квотами Центра и счётчик арестов «без Ховарда» на эту ночь
## (предупреждение о каскаде заранее). Слева — 18 карточек дел, справа — выбранное дело:
## что о нём известно, какие меры возможны и что каждая изменит (никаких скрытых чисел).

const DAMAGE_COLOR := {"critical": Color("#8e2b22"), "high": Color("#a0662a"), "medium": Color("#6b6a4e")}
const CARD_W := 296.0
const CARD_H := 80.0
const DETAIL_X := 980.0
const DETAIL_W := 528.0


static func build() -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cfg := ArrestWindow.config(c)
	var note := T.t("counterintel.note", {"from": cfg.get("from", 0), "to": cfg.get("to", 0)}) if not cfg.is_empty() else ""
	root.add_child(ModuleView.header(T.t("module.counterintel.name"), note))
	if s.get("list") == null:
		var empty := Style.para(T.t("counterintel.empty"), 900, Style.mono(), 15, Color(Style.PAPER, 0.8))
		empty.position = Vector2(28, 90)
		root.add_child(empty)
		return root
	root.add_child(_schedule(s, c, cfg))
	root.add_child(_grid(s, c))
	root.add_child(_detail(s, c))
	return root


# ——— График недель и квоты ———

static func _schedule(s: Dictionary, c: Dictionary, cfg: Dictionary) -> Control:
	var box := Style.vbox(6)
	box.name = "list-schedule"
	box.position = Vector2(28, 70)
	box.custom_minimum_size.x = 1480
	var weeks := Style.hbox(6)
	for w in range(int(cfg.from), int(cfg.to) + 1):
		var cur: bool = w == int(s.week)
		var q := {}
		for x in cfg.quotas:
			if int(x.by_week) == w:
				q = x
		var d := Campaign.week_date(c, int(s.act), w)
		var txt := T.t("counterintel.week", {"week": w, "date": "%d.%02d" % [d.day, d.month]})
		if not q.is_empty():
			var res: String = s.list.quotas.get(str(w), "")
			txt += "\n" + T.t("counterintel.quotaShort", {"n": q.arrests, "what": T.t("counterintel.critical") if q.get("damage", "") == "critical" else T.t("counterintel.total")})
			if res != "":
				txt += " — " + T.t("counterintel.quota." + res)
		var lb := Style.label(txt, Style.mono(), 12, Style.INK if cur else Style.PAPER)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var p := Style.panel(Style.OCHRE if cur else Color(0, 0, 0, 0.25), 6, Color(Style.PAPER, 0.4), 1)
		p.custom_minimum_size = Vector2(178, 52)
		p.name = "list-week-%d" % w
		p.add_child(lb)
		weeks.add_child(p)
	box.add_child(weeks)
	var line := Style.hbox(18)
	var tonight := ArrestWindow.plain_tonight(s, c)
	var after := int(c.balance.list.cascade_after)
	var counts := T.t("counterintel.counts", {"arrested": ArrestWindow.arrests(s, c), "realized": ArrestWindow.realized(s, c), "of": c.list.size()})
	line.add_child(Style.label(counts, Style.form(true), 15, Style.PAPER))
	var warn := Style.label(T.t("counterintel.tonight", {"n": tonight, "max": after}), Style.form(true), 15,
		Color("#e2a27f") if tonight >= after else Color(Style.PAPER, 0.8))
	warn.name = "list-tonight"
	line.add_child(warn)
	var q := ArrestWindow.next_quota(s, c)
	if not q.is_empty() and ArrestWindow.open(s, c):
		var qt := Style.label(T.t("counterintel.next", {"text": T.loc(q.text), "week": q.by_week, "done": ArrestWindow.quota_progress(s, c, q), "need": q.arrests}), Style.form(), 14, Style.PAPER)
		qt.name = "list-quota"
		line.add_child(qt)
		box.add_child(line)
		line = Style.hbox(18)
		if not s.list.get("contests", []).has(int(q.by_week)):
			var granted := ArrestWindow.contest_granted(s, c)
			var b := Style.button(T.t("counterintel.contest", {"fx": T.t("counterintel.contestYes", {"d": c.balance.list.contest_trust_cost}) if granted else T.t("counterintel.contestNo", {"d": c.balance.list.contest_refused_pressure})}),
				"list-contest", Style.PAPER, Color(Style.STAMP_RED, 0.35), Color(Style.PAPER, 0.5), 13)
			b.pressed.connect(Game.dispatch.bind({"type": "contest_quota"}))
			line.add_child(b)
	elif s.flags.has(ArrestWindow.WINDOW_CLOSED_FLAG):
		line.add_child(Style.label(T.t("counterintel.closed"), Style.form(true), 15, Color("#e9d8a6")))
	box.add_child(line)
	if s.flags.has(Dangle.DANGLE_FLAG):
		var dw := Style.para(T.t("counterintel.dangleWarning"), 1480, Style.mono(), 13, Color("#e2a27f"))
		dw.name = "list-dangle-warning"
		box.add_child(dw)
	return box


# ——— Карточки ———

static func _grid(s: Dictionary, c: Dictionary) -> Control:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 216)
	scroll.size = Vector2(930, 524)
	var grid := GridContainer.new()
	grid.name = "list-grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for card in c.list:
		grid.add_child(_card(s, card))
	scroll.add_child(grid)
	return scroll


static func _card(s: Dictionary, card: Dictionary) -> Control:
	var st := ArrestWindow.status(s, card.card_id)
	var sel: bool = Game.card_selected == card.card_id
	var b := Button.new()
	b.name = "card-" + card.card_id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	var done: bool = ArrestWindow.DONE.has(st)
	var sb := Style.box(Color("#e8dcb8") if not done else Color("#b9ad8c"), Style.OCHRE if sel else Color(0, 0, 0, 0.3), 3 if sel else 1, 2, 0)
	sb.border_width_left = 6
	sb.border_color = DAMAGE_COLOR[card.damage] if not sel else Style.OCHRE
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, sb)
	b.pressed.connect(Game.select_card.bind(card.card_id))
	var v := Style.vbox(2)
	v.position = Vector2(14, 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := T.t("counterintel.damage." + card.damage)
	if card.howard:
		top += " · " + T.t("counterintel.howardShort")
	v.add_child(Style.label(top, Style.form(true), 12, DAMAGE_COLOR[card.damage]))
	v.add_child(Style.label(T.loc(card.name), Style.form(true), 16, Style.INK))
	v.add_child(Style.label(T.t("counterintel.status." + st), Style.mono(), 12, Color(Style.INK, 0.75)))
	b.add_child(v)
	return b


# ——— Выбранное дело ———

static func _detail(s: Dictionary, c: Dictionary) -> Control:
	var panel := Style.panel(Color("#e8dcb8"), 22)
	panel.name = "card-detail"
	panel.position = Vector2(DETAIL_X, 216)
	panel.custom_minimum_size = Vector2(DETAIL_W, 0)
	var v := Style.vbox(8)
	v.custom_minimum_size.x = DETAIL_W - 44
	var card := ArrestWindow.card(c, Game.card_selected)
	if card.is_empty():
		v.add_child(Style.para(T.t("counterintel.pick"), DETAIL_W - 44, Style.mono(), 14, Color(Style.INK, 0.7)))
		panel.add_child(v)
		return panel
	var w := DETAIL_W - 44
	var st := ArrestWindow.status(s, card.card_id)
	v.add_child(Style.label(T.t("counterintel.damage." + card.damage).to_upper() + " · " + T.t("counterintel.agency." + card.agency), Style.form(true), 13, DAMAGE_COLOR[card.damage]))
	v.add_child(Style.para(T.loc(card.name), w, Style.serif(true), 22, Style.INK))
	v.add_child(Style.para(T.loc(card.role), w, Style.form(), 15, Color(Style.INK, 0.8)))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.para(T.loc(card.text), w, Style.mono(), 13, Style.INK))
	v.add_child(Style.para(T.t("counterintel.howard." + ("yes" if card.howard else "no")), w, Style.mono(), 13, Color(Style.INK, 0.85)))
	v.add_child(Style.para(T.t("counterintel.natural." + (card.natural if card.natural != "" else "none")), w, Style.mono(), 13, Color(Style.INK, 0.85)))
	v.add_child(Style.para(T.t("counterintel.game." + ("yes" if card.game else "no")), w, Style.mono(), 13, Color(Style.INK, 0.85)))
	var stamp := Style.stamp(T.t("counterintel.status." + st), Style.STAMP_RED, 13, -2)
	stamp.name = "card-status"
	v.add_child(stamp)
	if ArrestWindow.open(s, c) and s.phase != "night":
		for a in ArrestWindow.ACTIONS:
			if ArrestWindow.action_error(s, c, card.card_id, a) != "":
				continue
			var fx := ArrestWindow.preview(s, c, card.card_id, a)
			var label := T.t("counterintel.action." + a)
			if a != "cancel":
				label += " — " + _fx_text(fx)
			var b := Style.paper_button(label, "card-action-" + a)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = w
			b.pressed.connect(Game.dispatch.bind({"type": "list_action", "card_id": card.card_id, "action": a}))
			v.add_child(b)
	elif ArrestWindow.open(s, c):
		v.add_child(Style.para(T.t("counterintel.nightNote"), w, Style.mono(), 13, Color(Style.INK, 0.7)))
	panel.add_child(v)
	return panel


static func _fx_text(fx: Dictionary) -> String:
	var parts: Array = []
	if int(fx.mole_hunt) != 0:
		parts.append("%s %s" % [T.t("risk.mole_hunt"), ("+%d" % fx.mole_hunt) if fx.mole_hunt > 0 else str(fx.mole_hunt)])
	if int(fx.pressure) != 0:
		parts.append("%s +%d" % [T.t("risk.moscow_pressure"), fx.pressure])
	if fx.cascade:
		parts.append(T.t("counterintel.cascade"))
	return ", ".join(parts) if not parts.is_empty() else T.t("cipher.fx.none")
