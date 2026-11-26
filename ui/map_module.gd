class_name MapModule
## Оперативная карта Вашингтона и Северной Вирджинии (GDD, Блок 3, модуль 1).
## День — выбор операции и прокладка проверочного маршрута из трёх бытовых точек.
## Вечер — выезд: «Сбор» (точка за точкой) → «Вердикт» с блокнотом сравнения примет → итог.

const PANEL_W := 420.0


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.map.name"), "%s · %s" % [T.t("phase." + s.phase), T.t("sdr.legend")]))

	var run: Dictionary = Game.sdr_run
	var draft: Dictionary = Game.map_draft
	var planning: bool = s.phase == "day" and draft.op_id != ""
	var running: bool = not run.is_empty() and run.result == "" and s.routes.has(run.op_id)
	var route: Array = s.routes[run.op_id].stops if running else (draft.stops if planning else [])
	var target_id := ""
	if not run.is_empty():
		target_id = Campaign.op_by_id(Game.content, run.op_id).get("location", {}).get("site_id", "")
	elif planning:
		target_id = Campaign.op_by_id(Game.content, draft.op_id).location.site_id

	var canvas := MapCanvas.new(route, target_id, planning and run.is_empty(), run.step if running else -1,
		Signals.sog_marks(s.risks.sog_heat), s.site_visits.keys())
	canvas.position = Vector2(24, 70)
	canvas.stop_clicked.connect(_toggle_stop)
	root.add_child(canvas)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(1088, 70)
	scroll.size = Vector2(PANEL_W + 16, 670)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var panel := Style.vbox(10)
	panel.name = "map-panel"
	panel.custom_minimum_size.x = PANEL_W
	if not run.is_empty():
		_run_panel(panel, run)
	elif s.phase == "day":
		_plan_panel(panel)
	elif s.phase == "evening":
		panel.add_child(_h3(T.t("sdr.evening.title")))
		if s.planned_ops.is_empty():
			panel.add_child(_note(T.t("sdr.evening.none")))
		_planned(panel, false, true)
	else:
		panel.add_child(_note(T.t("sdr.idle")))
		_planned(panel, false, false)
	scroll.add_child(panel)
	root.add_child(scroll)
	return root


static func _toggle_stop(id: String) -> void:
	var d: Dictionary = Game.map_draft
	var stops: Array = d.stops.duplicate()
	if stops.has(id):
		stops.erase(id)
	elif stops.size() < 3:
		stops.append(id)
	Game.set_map_draft(d.op_id, stops)


static func _h3(text: String) -> Label:
	return Style.label(text.to_upper(), Style.form(true), 19, Style.PAPER_LIGHT)


static func _note(text: String) -> Label:
	return Style.para(text, PANEL_W, Style.mono(), 13, Color(Style.PAPER, 0.75))


static func _site_name(id: String) -> String:
	var s = MapGeo.site(Game.content, id)
	return T.loc(s.name) if s != null else id


static func _issue_text(issue: Dictionary) -> String:
	match issue.kind:
		"few_districts":
			return T.t("sdr.warn.fewDistricts", {"districts": issue.districts})
		"outside_zone":
			return T.t("sdr.warn.outsideZone", {"name": _site_name(issue.site_id)})
	return T.t("sdr.warn.invalid")


static func _plan_panel(panel: VBoxContainer) -> void:
	var s: Dictionary = Game.state
	var draft: Dictionary = Game.map_draft
	var ops := Campaign.available_ops(s, Game.content)
	var limit: bool = s.planned_ops.size() >= int(Game.content.balance.ops.per_week)
	panel.add_child(_h3(T.t("sdr.plan.title")))
	if ops.is_empty():
		panel.add_child(_note(T.t("map.noOps")))
	else:
		panel.add_child(_note(T.t("map.opExpense", {"usd": Fmt.usd(int(Game.content.balance.finance.op_expense_usd)), "fund": Fmt.usd(int(s.fund_usd))})))
	for op in ops:
		var cur: bool = op.op_id == draft.op_id
		var sched := _schedule_note(op)
		var b := Style.button("%s\n%s%s" % [T.loc(op.title), _site_name(op.location.site_id), ("\n" + sched) if sched != "" else ""], "op-" + op.op_id, Style.PAPER,
			Color(Style.OCHRE, 0.18) if cur else Color(0, 0, 0, 0.25), Style.OCHRE if cur else Color(Style.PAPER, 0.55), 13)
		b.disabled = limit
		b.pressed.connect(Game.set_map_draft.bind(op.op_id, []))
		panel.add_child(b)
	if limit:
		panel.add_child(_note(T.t("sdr.plan.limit", {"n": Game.content.balance.ops.per_week})))
	if draft.op_id != "" and ops.any(func(o): return o.op_id == draft.op_id):
		var builder := Style.vbox(8)
		builder.name = "route-builder"
		builder.add_child(_note(T.t("sdr.plan.hint")))
		for i in 3:
			var txt := "%d.  %s" % [i + 1, T.t("sdr.plan.empty")]
			if i < draft.stops.size():
				var st = MapGeo.site(Game.content, draft.stops[i])
				txt = "%d.  %s\n     %s · %s" % [i + 1, T.loc(st.name), T.loc(Game.content.map.districts[st.district]), T.loc(st.get("cover_reason", {"ru": ""}))]
			builder.add_child(Style.label(txt, Style.form(), 15, Style.PAPER if i < draft.stops.size() else Color(Style.PAPER, 0.5)))
		var analysis := MapGeo.analyze_route(Game.content, draft.stops)
		if draft.stops.size() == 3 and not analysis.warnings.is_empty():
			var warn := Style.panel(Color(Style.STAMP_RED, 0.25), 10)
			warn.name = "route-warnings"
			var wv := Style.vbox(4)
			for w in analysis.warnings:
				wv.add_child(Style.para("• " + _issue_text(w), PANEL_W - 24, Style.mono(), 13, Style.PAPER))
			warn.add_child(wv)
			builder.add_child(warn)
		builder.add_child(_executor(draft))
		var actions := Style.hbox(8)
		var confirm := Style.button(T.t("sdr.plan.confirm"), "confirm-route", Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER, 13)
		confirm.disabled = not analysis.blocking.is_empty()
		confirm.pressed.connect(func():
			var stops: Array = Game.map_draft.stops.duplicate()
			var op_id: String = Game.map_draft.op_id
			var who: String = Game.map_draft.get("operative", Delegation.RESIDENT)
			Game.map_draft = {"op_id": "", "stops": []}
			Game.dispatch({"type": "plan_op", "op_id": op_id, "route": stops, "operative": who}))
		actions.add_child(confirm)
		var reset := Style.button(T.t("sdr.plan.reset"), "reset-route")
		reset.pressed.connect(Game.set_map_draft.bind(draft.op_id, []))
		actions.add_child(reset)
		builder.add_child(actions)
		# Список бытовых точек по районам (цвет — как у булавок на карте).
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 4)
		for did in Game.content.map.districts:
			var stops: Array = Game.content.map.sites.filter(func(x): return x.role == "stop" and x.district == did)
			if stops.is_empty():
				continue
			var col := Style.vbox(4)
			col.custom_minimum_size.x = (PANEL_W - 10) / 2
			var head := Style.hbox(6)
			var sw := ColorRect.new()
			sw.color = MapCanvas.district_color(did)
			sw.custom_minimum_size = Vector2(10, 10)
			sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(sw)
			head.add_child(Style.label(T.loc(Game.content.map.districts[did]), Style.form(true), 14, Color(Style.PAPER, 0.8)))
			col.add_child(head)
			for st in stops:
				var idx: int = draft.stops.find(st.site_id)
				var b := Style.button(("[%d] " % (idx + 1) if idx >= 0 else "") + T.loc(st.name), "stop-" + st.site_id, Style.PAPER,
					Color(Style.OCHRE, 0.25) if idx >= 0 else Color(0, 0, 0, 0.25), Style.OCHRE if idx >= 0 else Color(Style.PAPER, 0.45), 12)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.custom_minimum_size.x = (PANEL_W - 10) / 2
				b.pressed.connect(_toggle_stop.bind(st.site_id))
				col.add_child(b)
			grid.add_child(col)
		builder.add_child(grid)
		panel.add_child(builder)
	_planned(panel, true, false)


static func _planned(panel: VBoxContainer, cancellable: bool, departable: bool) -> void:
	var s: Dictionary = Game.state
	if s.planned_ops.is_empty():
		return
	var box := Style.vbox(8)
	box.name = "planned-ops"
	box.add_child(Style.hline(Color(Style.PAPER, 0.3)))
	box.add_child(_h3(T.t("sdr.planned")))
	for id in s.planned_ops:
		var op := Campaign.op_by_id(Game.content, id)
		var stops: Array = s.routes.get(id, {}).get("stops", []).map(func(x): return _site_name(x).get_slice(",", 0))
		box.add_child(Style.label(T.loc(op.title), Style.mono(), 14, Style.PAPER_LIGHT))
		box.add_child(Style.para(" — ".join(stops), PANEL_W, Style.form(), 14, Color(Style.PAPER, 0.75)))
		var who: String = s.routes.get(id, {}).get("operative", Delegation.RESIDENT)
		if who != Delegation.RESIDENT:
			box.add_child(Style.para(T.t("sdr.executor.assigned", {"name": T.loc(Delegation.operative(Game.content, who).name),
				"p": int(round(Delegation.notice_chance(Game.content, who, s.routes[id].stops) * 100))}), PANEL_W, Style.mono(), 13, Color("#e9d8a6")))
		if op.get("drop") != null:
			box.add_child(Style.para(T.t("sdr.drop", {"code": op.drop.codename, "signal": T.loc(op.drop.signal), "container": T.loc(op.drop.container)}), PANEL_W, Style.mono(), 12, Color(Style.PAPER, 0.7)))
		if cancellable:
			var c := Style.button(T.t("sdr.cancel"), "cancel-" + id)
			c.pressed.connect(Game.dispatch.bind({"type": "cancel_op", "op_id": id}))
			box.add_child(c)
		if departable and who != Delegation.RESIDENT:
			var rb := Style.button(T.t("sdr.executor.report", {"name": T.loc(Delegation.operative(Game.content, who).name).get_slice(" — ", 0)}), "report-" + id, Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER)
			rb.pressed.connect(_resolve.bind({"op_id": id, "step": 3, "verdict": false, "marks": [], "result": "", "delegated": true}, "auto"))
			box.add_child(rb)
		elif departable:
			var d := Style.button(T.t("sdr.depart"), "depart-" + id, Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER)
			d.pressed.connect(Game.set_sdr_run.bind({"op_id": id, "step": 1, "verdict": false, "marks": [], "result": ""}))
			box.add_child(d)
	panel.add_child(box)


## Текст приметы; у сменившего одежду — своё описание на каждой точке.
static func _cue_text(tag: String, stop := 0) -> String:
	for c in Game.content.cues:
		if c.tag == tag:
			var vs: Array = c.get("variants", [])
			return T.loc(vs[stop % vs.size()]) if not vs.is_empty() else T.loc(c.text)
	return tag


## Графики наружки от агента в ФБР: видно, будет ли хвост на этом выходе.
static func _schedule_note(op: Dictionary) -> String:
	var s: Dictionary = Game.state
	var src := ""
	for t in Game.content.targets:
		if t.get("perks", []).has("sog_schedule") and s.targets[t.target_id].recruited and not s.targets[t.target_id].lost:
			src = T.loc(t.name)
	if src == "":
		return ""
	return T.t("sdr.schedule.tail" if Campaign.tail_present(s, op) else "sdr.schedule.clean", {"name": src})


## Кто идёт: резидент сам (проверочный маршрут вручную) или подчинённый (с видимой вероятностью).
static func _executor(draft: Dictionary) -> Control:
	var s: Dictionary = Game.state
	var c: Dictionary = Game.content
	var who: String = draft.get("operative", Delegation.RESIDENT)
	var box := Style.vbox(6)
	box.name = "executor"
	box.add_child(Style.label(T.t("sdr.executor.title").to_upper(), Style.form(true), 14, Color(Style.PAPER, 0.8)))
	var opts: Array = [[Delegation.RESIDENT, T.t("sdr.executor.self")]]
	if Delegation.unlocked(s, c):
		for o in Delegation.available(s, c):
			var p := int(round(Delegation.notice_chance(c, o.operative_id, draft.stops) * 100))
			opts.append([o.operative_id, T.t("sdr.executor.other", {"name": T.loc(o.name), "p": p})])
	for o in opts:
		var on: bool = who == o[0]
		var b := Style.button(o[1], "executor-" + o[0], Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 12)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = PANEL_W
		b.pressed.connect(Game.set_map_operative.bind(o[0]))
		box.add_child(b)
	if not Delegation.unlocked(s, c):
		box.add_child(_note(T.t("sdr.executor.locked", {"n": c.balance.delegation.unlock_after_personal_ops, "k": int(s.get("personal_ops", 0))})))
	elif who != Delegation.RESIDENT:
		box.add_child(_note(T.loc(Delegation.operative(c, who).bio)))
	return box


static func _resolve(run: Dictionary, decision: String) -> void:
	Game.dispatch({"type": "resolve_op", "op_id": run.op_id, "decision": decision})
	var r: Dictionary = run.duplicate()
	r.result = Game.state.op_results.get(run.op_id, "")
	Game.set_sdr_run(r)


static func _run_panel(panel: VBoxContainer, run: Dictionary) -> void:
	var s: Dictionary = Game.state
	var op := Campaign.op_by_id(Game.content, run.op_id)
	var target_name := _site_name(op.location.site_id).get_slice(",", 0)

	if run.result != "":
		var res := Style.panel(Style.PAPER, 16)
		res.name = "sdr-result"
		res.set_meta("result", "aborted" if run.result == "aborted" else "done")
		var v := Style.vbox(8)
		var aborted: bool = run.result == "aborted"
		v.add_child(Style.label(T.t("sdr.result.aborted" if aborted else "sdr.result.done").to_upper(), Style.form(true), 20, Style.INK))
		v.add_child(Style.para(T.t("sdr.result.abortedText") if aborted else T.t("sdr.result.doneText", {"name": target_name}), PANEL_W - 32, Style.mono(), 14, Style.INK))
		for e in Game.last_events:
			if e.type == "operative_report":
				v.add_child(Style.para(T.t("sdr.executor.noticed" if e.noticed else "sdr.executor.notNoticed", {"name": T.loc(Delegation.operative(Game.content, e.operative).name)}), PANEL_W - 32, Style.mono(), 13, Style.INK))
			elif e.type == "contact_established":
				v.add_child(Style.para("• " + T.t("event.contact_established", {"name": T.loc(Campaign.target_by_id(Game.content, e.target_id).name)}), PANEL_W - 32, Style.mono(), 13, Style.STAMP_RED))
			elif e.type == "clue_found":
				v.add_child(Style.para("• " + T.t("event.clue_found", {"name": T.loc(Campaign.clue_by_id(Game.content, e.clue_id).title)}), PANEL_W - 32, Style.mono(), 13, Style.INK))
			elif e.type == "target_unlocked":
				v.add_child(Style.para("• " + T.t("event.target_unlocked", {"name": T.loc(Campaign.target_by_id(Game.content, e.target_id).name)}), PANEL_W - 32, Style.mono(), 13, Style.STAMP_RED))
		var done := Style.paper_button(T.t("sdr.backToMap"), "sdr-done")
		done.pressed.connect(Game.set_sdr_run.bind({}))
		v.add_child(done)
		res.add_child(v)
		panel.add_child(res)
		return

	if not s.routes.has(run.op_id):
		return
	var route: Dictionary = s.routes[run.op_id]

	if run.verdict:
		var box := Style.vbox(10)
		box.name = "sdr-verdict"
		box.add_child(_h3(T.t("sdr.verdict.title")))
		box.add_child(_note(T.t("sdr.verdict.hint")))
		var book := Style.panel(Style.PAPER_LIGHT, 12)
		var cols := Style.hbox(10)
		cols.name = "sdr-notebook"
		for i in route.stops.size():
			var col := Style.vbox(6)
			col.custom_minimum_size.x = (PANEL_W - 44) / 3
			col.add_child(Style.para("%d. %s" % [i + 1, _site_name(route.stops[i]).get_slice(",", 0)], (PANEL_W - 44) / 3, Style.form(true), 13, Color(Style.INK, 0.8)))
			for tag in route.observations[i]:
				var key := "%d:%s" % [i + 1, tag]
				var marked: bool = run.marks.has(key)
				var b := Style.button(_cue_text(tag, i), "note-%d-%s" % [i + 1, tag], Style.INK,
					Color(Style.THREAD_RED, 0.08) if marked else Color(0, 0, 0, 0), Style.THREAD_RED if marked else Color(0, 0, 0, 0), 12)
				(b.get_theme_stylebox("normal") as StyleBoxFlat).set_border_width_all(2)
				(b.get_theme_stylebox("normal") as StyleBoxFlat).set_corner_radius_all(14)
				b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				b.custom_minimum_size.x = (PANEL_W - 44) / 3
				b.set_meta("cue", tag)
				b.set_meta("marked", marked)
				b.pressed.connect(func():
					var r: Dictionary = Game.sdr_run.duplicate(true)
					if r.marks.has(key):
						r.marks.erase(key)
					else:
						r.marks.append(key)
					Game.set_sdr_run(r))
				col.add_child(b)
			cols.add_child(col)
		book.add_child(cols)
		box.add_child(book)
		var clean := Style.button(T.t("sdr.verdict.clean", {"name": target_name}), "sdr-verdict-clean", Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER)
		clean.pressed.connect(_resolve.bind(run, "continue"))
		box.add_child(clean)
		var tail := Style.button(T.t("sdr.verdict.tail"), "sdr-verdict-tail", Color("#f0b8ad"), Color(0, 0, 0, 0.25), Color("#c96a5c"))
		tail.pressed.connect(_resolve.bind(run, "abort"))
		box.add_child(tail)
		var back := Style.button(T.t("sdr.verdict.back"), "sdr-verdict-back")
		back.pressed.connect(func():
			var r: Dictionary = Game.sdr_run.duplicate(true)
			r.verdict = false
			Game.set_sdr_run(r))
		box.add_child(back)
		panel.add_child(box)
		return

	# «Сбор»: карточки наблюдений всплывают точка за точкой.
	var box := Style.vbox(10)
	box.name = "sdr-run"
	box.add_child(_h3(T.loc(op.title)))
	box.add_child(_note(T.t("sdr.run.rule")))
	for i in run.step:
		var st = MapGeo.site(Game.content, route.stops[i])
		var stop := Style.panel(Color(Style.OCHRE, 0.12) if i == run.step - 1 else Color(0, 0, 0, 0), 10)
		stop.name = "sdr-stop-%d" % (i + 1)
		var v := Style.vbox(6)
		v.add_child(Style.label("%d. %s" % [i + 1, T.loc(st.name)], Style.form(true), 15, Style.PAPER_LIGHT))
		v.add_child(Style.label(T.loc(st.get("cover_reason", {"ru": ""})), Style.form(), 13, Color(Style.PAPER, 0.65)))
		var cards := HFlowContainer.new()
		cards.add_theme_constant_override("h_separation", 6)
		cards.add_theme_constant_override("v_separation", 6)
		for tag in route.observations[i]:
			var card := Style.panel(Style.PAPER_LIGHT, 7)
			card.name = "card-" + tag
			card.set_meta("cue", tag)
			card.add_child(Style.label(_cue_text(tag, i), Style.form(), 14, Style.INK))
			cards.add_child(card)
		v.add_child(cards)
		stop.add_child(v)
		box.add_child(stop)
	var actions := Style.vbox(8)
	if run.step < 3:
		var nb := Style.button(T.t("sdr.run.next"), "sdr-next", Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER)
		nb.pressed.connect(func():
			var r: Dictionary = Game.sdr_run.duplicate(true)
			r.step += 1
			Game.set_sdr_run(r))
		actions.add_child(nb)
	else:
		var vb := Style.button(T.t("sdr.run.toVerdict"), "sdr-to-verdict", Style.PAPER, Color(0, 0, 0, 0.25), Style.PAPER)
		vb.pressed.connect(func():
			var r: Dictionary = Game.sdr_run.duplicate(true)
			r.verdict = true
			Game.set_sdr_run(r))
		actions.add_child(vb)
	var ab := Style.button(T.t("sdr.run.abort"), "sdr-abort", Color("#f0b8ad"), Color(0, 0, 0, 0.25), Color("#c96a5c"))
	ab.pressed.connect(_resolve.bind(run, "abort"))
	actions.add_child(ab)
	box.add_child(actions)
	panel.add_child(box)
