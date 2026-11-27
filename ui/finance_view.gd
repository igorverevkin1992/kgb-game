class_name FinanceView
## Финансовый журнал: слева — тетрадь учёта спецфонда (остаток и записи) и папка с правилами
## банковского контроля США; справа — агенты: три открытые шкалы (лояльность, банковский след,
## образ жизни), обещанное и калькулятор транша с предпросмотром последствий.

const LEFT_W := 560.0
const RIGHT_X := 620.0
const RIGHT_W := 888.0
const TOP := 76.0
const PAGE := Color("#ece4cc")
const RULES := Color("#d9cfa9")


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.finance.name"), T.t("finance.note", {"treasury": s.risks.treasury})))
	root.add_child(_left(s))
	root.add_child(_agents(s))
	return root


# ——— Тетрадь спецфонда и правила ———

static func _left(s: Dictionary) -> Control:
	var v := Style.vbox(12)
	v.position = Vector2(28, TOP)
	v.custom_minimum_size = Vector2(LEFT_W, 0)
	var page := Style.panel(PAGE, 22)
	page.name = "ledger"
	var pv := Style.vbox(6)
	pv.add_child(Style.label(T.t("finance.fund").to_upper(), Style.form(true), 16, Style.INK))
	var bal := Style.label(Fmt.usd(int(s.fund_usd)), Style.mono(), 30, Style.INK)
	bal.name = "fund-balance"
	pv.add_child(bal)
	pv.add_child(Style.hline(Color(Style.INK, 0.3)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LEFT_W - 44, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := Style.vbox(4)
	rows.name = "ledger-rows"
	var entries: Array = s.log.filter(func(x): return x.event.type == "fund_changed")
	entries.reverse()
	for x in entries:
		var e: Dictionary = x.event
		var row := Style.hbox(8)
		var what := Style.para("%s · %s" % [T.t("calendar.week", {"week": x.week}), _reason(e)], LEFT_W - 190, Style.mono(), 13, Style.INK)
		row.add_child(what)
		var d: int = int(e.to) - int(e.from)
		var amt := Style.label(("+" if d > 0 else "-") + Fmt.thousands(absi(d)), Style.mono(), 13, Color("#2f6b2a") if d > 0 else Style.STAMP_RED)
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		amt.custom_minimum_size.x = 110
		row.add_child(amt)
		rows.add_child(row)
	if entries.is_empty():
		rows.add_child(Style.label(T.t("finance.noEntries"), Style.mono(), 13, Color(Style.INK, 0.6)))
	scroll.add_child(rows)
	pv.add_child(scroll)
	page.add_child(pv)
	v.add_child(page)
	v.add_child(_rules(s))
	return v


static func _reason(e: Dictionary) -> String:
	var c: Dictionary = Game.content
	var ref: String = e.get("ref", "")
	match e.reason:
		"op_expense":
			return T.t("finance.reason.op", {"name": T.loc(Campaign.op_by_id(c, ref).get("title", {"ru": ref}))})
		"tranche":
			return T.t("finance.reason.tranche", {"name": T.loc(Campaign.target_by_id(c, ref).get("name", {"ru": ref}))})
		"request":
			return T.t("finance.reason.request", {"name": T.loc(Cipher.request_by_id(c, ref).get("title", {"ru": ref}))})
	return T.t("finance.reason.other")


## Папка с правилами банковского контроля: что действует сейчас и что изменится (без сюрпризов).
static func _rules(s: Dictionary) -> Control:
	var b: Dictionary = Game.content.balance.finance
	var p := Style.panel(RULES, 18, Color("#8a7a4a"), 1)
	p.name = "rules"
	var v := Style.vbox(6)
	v.add_child(Style.label(T.t("finance.rules").to_upper(), Style.form(true), 15, Style.INK))
	var parts: PackedStringArray = String(b.mlca_date).split("-")
	var mlca := Fmt.date({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])})
	var lines := [T.t("finance.rule.bsa", {"usd": Fmt.usd(int(b.ctr_threshold_usd))})]
	if Finance.mlca_in_force(s, Game.content):
		lines.append(T.t("finance.rule.mlcaNow", {"date": mlca}))
	else:
		lines.append(T.t("finance.rule.splitOk"))
		lines.append(T.t("finance.rule.mlcaAhead", {"date": mlca}))
	lines.append(T.t("finance.rule.escrow", {"n": b.escrow_min_loyalty}))
	for l in lines:
		v.add_child(Style.para("— " + l, LEFT_W - 36, Style.mono(), 12, Style.INK))
	p.add_child(v)
	return p


# ——— Агенты и транш ———

static func _agents(s: Dictionary) -> Control:
	var c: Dictionary = Game.content
	var v := Style.vbox(12)
	v.name = "agents"
	v.position = Vector2(RIGHT_X, TOP)
	v.custom_minimum_size = Vector2(RIGHT_W, 0)
	var ids := Finance.agents(s)
	if ids.is_empty():
		v.add_child(Style.para(T.t("finance.noAgents"), RIGHT_W, Style.mono(), 15, Color(Style.PAPER, 0.8)))
		return v
	var cur: String = Game.finance_agent if ids.has(Game.finance_agent) else ids[0]
	if ids.size() > 1:
		var tabs := Style.hbox(8)
		for id in ids:
			var on: bool = id == cur
			var b := Style.button(T.loc(Campaign.target_by_id(c, id).name), "agent-tab-" + id, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 14)
			b.pressed.connect(Game.select_finance_agent.bind(id))
			tabs.add_child(b)
		v.add_child(tabs)
	v.add_child(_agent_card(s, cur))
	v.add_child(_calculator(s, cur))
	return v


static func _agent_card(s: Dictionary, id: String) -> Control:
	var c: Dictionary = Game.content
	var b: Dictionary = c.balance.finance
	var ag: Dictionary = s.agents[id]
	var t := Campaign.target_by_id(c, id)
	var p := Style.panel(PAGE, 18)
	p.name = "agent-" + id
	var v := Style.vbox(8)
	v.add_child(Style.label(T.loc(t.name), Style.form(true), 20, Style.INK))
	var prof := Finance.profile(c, id)
	if not prof.is_empty() and int(prof.promised_usd) > 0:
		var promise := T.t("finance.promise", {"usd": Fmt.usd(int(prof.promised_usd)), "what": T.loc(prof.promise),
			"paid": Fmt.usd(int(ag.paid_usd)), "transit": Fmt.usd(Finance.in_transit(s, id))})
		var state_note := T.t("finance.promiseKept")
		if not ag.promise_kept:
			state_note = T.t("finance.promiseTransit") if Finance.promise_left(s, c, id) == 0 else T.t("finance.promiseOpen", {"n": b.loyalty_unpaid_week})
		promise += " " + state_note
		var pl := Style.para(promise, RIGHT_W - 36, Style.mono(), 14, Style.INK)
		pl.name = "promise-" + id
		v.add_child(pl)
	var th: int = c.balance.thresholds.danger
	if ag.get("coerced", false):
		var cn := Style.para(T.t("finance.coercedNote", {"w": b.loyalty_coerced_week}), RIGHT_W - 36, Style.mono(), 13, Style.STAMP_RED)
		cn.name = "coerced-" + id
		v.add_child(cn)
	v.add_child(_scale("scale-loyalty-" + id, T.t("finance.loyalty"), int(ag.loyalty), T.t("finance.loyaltyMarks", {"r": b.reports_min_loyalty, "e": b.escrow_min_loyalty}), Color("#4f7a3e")))
	v.add_child(_scale("scale-trace-" + id, T.t("finance.trace"), int(ag.trace), T.t("finance.traceNote"), Color("#8e2b22")))
	v.add_child(_scale("scale-lifestyle-" + id, T.t("finance.lifestyle"), int(ag.lifestyle), T.t("finance.lifestyleNote", {"n": th, "t": b.lifestyle_danger_treasury, "d": b.lifestyle_decay}), Color("#b07a2a")))
	p.add_child(v)
	return p


static func _scale(id: String, title: String, value: int, note: String, color: Color) -> Control:
	var box := Style.vbox(2)
	box.name = id
	box.set_meta("value", value)
	box.add_child(Style.label("%s: %d%%" % [title, value], Style.form(true), 14, Style.INK))
	var bar := DialogView.Bar.new(value, 0, color)
	bar.custom_minimum_size = Vector2(RIGHT_W - 36, 18)
	box.add_child(bar)
	box.add_child(Style.para(note, RIGHT_W - 36, Style.mono(), 11, Color(Style.INK, 0.65)))
	return box


static func _calculator(s: Dictionary, id: String) -> Control:
	var c: Dictionary = Game.content
	var f := Game.finance_form_for(id)
	var p := Style.panel(Color(0, 0, 0, 0.25), 16, Color(Style.PAPER, 0.3), 1)
	p.name = "calculator"
	var v := Style.vbox(8)
	v.add_child(Style.label(T.t("finance.tranche").to_upper(), Style.form(true), 16, Style.PAPER))
	var amount := Style.hbox(8)
	var al := Style.label(T.t("finance.amount", {"usd": Fmt.usd(int(f.amount))}), Style.mono(), 16, Style.PAPER)
	al.name = "tranche-amount"
	al.custom_minimum_size.x = 300
	amount.add_child(al)
	for step in [-1000, -100, 100, 1000]:
		var sb := Style.button(("+" if step > 0 else "-") + Fmt.thousands(absi(step)), "amount-%s%d" % ["p" if step > 0 else "m", absi(step)], Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.5), 13)
		sb.pressed.connect(Game.set_finance_form.bind(id, "amount", maxi(0, int(f.amount) + step)))
		amount.add_child(sb)
	var left := Finance.promise_left(s, c, id)
	if left > 0:
		var rb := Style.button(T.t("finance.rest", {"usd": Fmt.usd(left)}), "amount-rest", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.5), 13)
		rb.pressed.connect(Game.set_finance_form.bind(id, "amount", left))
		amount.add_child(rb)
	v.add_child(amount)
	var inst := Style.hbox(8)
	for i in Finance.INSTRUMENTS:
		if i == "legend" and not Finance.legend_available(s, c):
			continue  # перевод «наследства» — только через агента с банковским контуром
		var on: bool = f.instrument == i
		var b := Style.button(T.t("finance.instrument." + i), "instrument-" + i, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 14)
		b.pressed.connect(Game.set_finance_form.bind(id, "instrument", i))
		inst.add_child(b)
	v.add_child(inst)
	inst = Style.hbox(8)
	if f.instrument == "cash":
		inst.add_child(Style.label(T.t("finance.parts"), Style.form(), 14, Color(Style.PAPER, 0.8)))
		for n in range(1, int(c.balance.finance.max_parts) + 1):
			var on: bool = int(f.parts) == n
			var b := Style.button(str(n), "parts-%d" % n, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 14)
			b.pressed.connect(Game.set_finance_form.bind(id, "parts", n))
			inst.add_child(b)
	v.add_child(inst)

	var plan := Finance.plan(s, c, id, int(f.amount), f.instrument, int(f.parts) if f.instrument == "cash" else 1)
	var pv := Style.vbox(3)
	pv.name = "tranche-preview"
	pv.set_meta("ctr", plan.total.ctr if plan.error == "" else 0)
	if plan.error != "":
		pv.add_child(Style.para(plan.error, RIGHT_W - 32, Style.mono(), 13, Color("#e2a27f")))
	else:
		for part in plan.parts:
			var line := T.t("finance.part", {"week": part.week, "usd": Fmt.usd(int(part.amount))})
			if part.ctr:
				line += " — " + T.t("finance.ctr")
			if part.structuring:
				line += " — " + T.t("finance.structuring")
			pv.add_child(Style.label(line, Style.mono(), 13, Color("#e2826f") if part.ctr or part.structuring else Style.PAPER))
		var tot: Dictionary = plan.total
		pv.add_child(Style.para(T.t("finance.total", {
			"trace": DialogView._signed(int(tot.treasury)), "life": DialogView._signed(int(tot.lifestyle)), "loyal": DialogView._signed(int(tot.loyalty))}),
			RIGHT_W - 32, Style.mono(), 13, Color(Style.PAPER, 0.85)))
		if tot.ctr == 0 and f.instrument == "cash":
			pv.add_child(Style.label(T.t("finance.noCtr"), Style.mono(), 13, Color("#a9c89c")))
	v.add_child(pv)
	var send := Style.button(T.t("finance.send"), "tranche-send", Style.PAPER, Color("#3d5a32"), Color(Style.PAPER, 0.6), 15)
	send.disabled = plan.error != "" or not ["day", "evening"].has(s.phase)
	send.pressed.connect(Game.send_tranche.bind(id))
	var row := Style.hbox(12)
	row.add_child(send)
	if not ["day", "evening"].has(s.phase):
		row.add_child(Style.label(T.t("finance.whenPay"), Style.mono(), 13, Color(Style.PAPER, 0.7)))
	v.add_child(row)
	p.add_child(v)
	return p
