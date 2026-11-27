class_name Overlays
## Оверлеи поверх стола: сводка аналитика, служебная папка (сохранения и настройки), итог кампании.

const PANEL_W := 860.0


static func _overlay(name: String, close_on_click := true) -> Array:
	var root := Control.new()
	root.name = name + "-overlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if close_on_click:
		dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: Game.close())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var sb := Style.box(Style.PAPER, Color(0, 0, 0, 0), 0, 0, 44)
	sb.content_margin_left = 52
	sb.content_margin_right = 52
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	var panel := PanelContainer.new()
	panel.name = name
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := Style.vbox(10)
	v.custom_minimum_size.x = PANEL_W - 104
	panel.add_child(v)
	return [root, v, panel]


static func _title(v: VBoxContainer, title: String, stamp: String) -> void:
	var h := Style.hbox(12)
	h.add_child(Style.label(title.to_upper(), Style.form(true), 28, Style.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(Style.stamp(stamp))
	v.add_child(h)


static func _h3(text: String) -> Label:
	return Style.label(text.to_upper(), Style.form(true), 17, Style.INK)


# ——— Сводка аналитика ———

static func analyst() -> Control:
	var o := _overlay("analyst")
	var v: VBoxContainer = o[1]
	var s: Dictionary = Game.state
	_title(v, T.t("analyst.title"), T.t("analyst.stamp"))
	for r in Campaign.RISKS:
		v.add_child(_bar("risk-" + r, T.t("risk." + r), s.risks[r], Campaign.risk_level(s.risks[r], Game.content), T.t("risk.%s.at100" % r)))
	v.add_child(_bar("centre-trust", T.t("analyst.trust"), s.centre_trust, "trust", ""))
	v.add_child(Style.label(T.t("analyst.fund", {"usd": Fmt.usd(s.fund_usd)}), Style.mono(), 14, Style.INK))
	v.add_child(_h3(T.t("analyst.journal")))
	var journal := Style.vbox(3)
	journal.name = "journal"
	var lines: Array = []
	for entry in s.log:
		var text := _event_text(entry.event)
		if text != "":
			lines.append("%s  %s" % [T.t("calendar.week", {"week": entry.week}), text])
	lines.reverse()
	for line in lines.slice(0, 12):
		journal.add_child(Style.para(line, PANEL_W - 104, Style.mono(), 13, Style.INK))
	v.add_child(journal)
	return o[0]


static func _bar(name: String, title: String, value: int, level: String, at100: String) -> Control:
	var col := Style.vbox(2)
	col.name = name
	var row := Style.hbox(12)
	var l := Style.label(title, Style.form(), 17, Style.INK)
	l.custom_minimum_size.x = 240
	row.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(PANEL_W - 104 - 252, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var w: float = bar.custom_minimum_size.x
	bar.add_child(Style.rect(Color(Style.INK, 0.12), Rect2(0, 0, w, 18)))
	var color: Color = {"calm": Color("#6b7356"), "warning": Style.OCHRE, "danger": Style.STAMP_RED, "trust": Color("#3d5a73")}[level]
	bar.add_child(Style.rect(color, Rect2(0, 0, w * value / 100.0, 18)))
	if level != "trust":
		var th: Dictionary = Game.content.balance.thresholds
		bar.add_child(Style.rect(Style.OCHRE_DARK, Rect2(w * th.warning / 100.0, -3, 2, 24)))
		bar.add_child(Style.rect(Style.STAMP_RED, Rect2(w * th.danger / 100.0, -3, 2, 24)))
	var pct := Style.label("%d%%" % value, Style.mono(), 12, Style.INK)
	pct.position = Vector2(w - 44, 0)
	bar.add_child(pct)
	row.add_child(bar)
	col.add_child(row)
	if at100 != "":
		var note := Style.label(at100, Style.form(), 13, Color(Style.INK, 0.7))
		note.custom_minimum_size.x = PANEL_W - 104
		col.add_child(note)
	return col


static func _tname(id: String) -> String:
	return T.loc(Campaign.target_by_id(Game.content, id).get("name", {"ru": id}))


static func _event_text(e: Dictionary) -> String:
	var c: Dictionary = Game.content
	match e.type:
		"cable_delivered":
			return T.t("event.cable_delivered", {"name": T.loc(Campaign.cable_by_id(c, e.cable_id).subject)})
		"clue_found":
			return T.t("event.clue_found", {"name": T.loc(Campaign.clue_by_id(c, e.clue_id).title)})
		"target_unlocked":
			return T.t("event.target_unlocked", {"name": T.loc(Campaign.target_by_id(c, e.target_id).name)})
		"target_recruited":
			return T.t("event.target_recruited", {"name": T.loc(Campaign.target_by_id(c, e.target_id).name)})
		"target_lost":
			return T.t("event.target_lost", {"name": T.loc(Campaign.target_by_id(c, e.target_id).name)})
		"op_resolved":
			return T.t("event.op_" + e.outcome, {"name": T.loc(Campaign.op_by_id(c, e.op_id).title)})
		"risk_changed":
			return T.t("event.risk_changed", {"risk": T.t("risk." + e.risk), "from": e.from, "to": e.to})
		"trust_changed":
			return T.t("event.trust_changed", {"from": e.from, "to": e.to})
		"lie_uncovered":
			return T.t("event.lie_uncovered", {"week": e.lie_week})
		"act_completed":
			return T.t("event.act_completed", {"phase": Fmt.op_phase_gen(e.act)})
		"directive_verified":
			return T.t("event.directive_" + e.outcome, {"name": T.loc(Campaign.cable_by_id(c, e.cable_id).subject)})
		"report_submitted":
			return T.t("event.report_" + e.report)
		"request_answered":
			return T.t("event.request_" + ("granted" if e.granted else "refused"), {"name": T.loc(Cipher.request_by_id(c, e.request_id).title)})
		"decision_made":
			return T.t("event.decision_made", {"name": T.loc(Decisions.by_id(c, e.decision_id).get("title", {"ru": e.decision_id}))})
		"contact_established":
			return T.t("event.contact_established", {"name": _tname(e.target_id)})
		"operative_report":
			return T.t("event.operative_noticed" if e.noticed else "event.operative_missed", {"name": T.loc(Delegation.operative(c, e.operative).get("name", {"ru": e.operative}))})
		"agent_broke":
			return T.t("event.agent_broke", {"name": _tname(e.target_id)})
		"meeting_ended":
			return T.t("event.meeting_" + e.outcome, {"name": T.loc(Meeting.person_name(c, Meeting.dialog_by_id(c, e.get("dialog_id", Meeting.dialog_for(c, e.target_id).get("dialog_id", "")))))})
		"tranche_sent":
			return T.t("event.tranche_sent", {"name": _tname(e.target_id), "usd": Fmt.usd(e.amount), "how": T.t("finance.instrument." + e.instrument)})
		"tranche_delivered":
			return T.t("event.tranche_delivered", {"name": _tname(e.target_id), "usd": Fmt.usd(e.amount)})
		"ctr_filed":
			return T.t("event.ctr_filed", {"name": _tname(e.target_id), "usd": Fmt.usd(e.amount)})
		"structuring_noted":
			return T.t("event.structuring_noted", {"name": _tname(e.target_id)})
		"promise_kept":
			return T.t("event.promise_kept", {"name": _tname(e.target_id)})
		"loyalty_changed":
			return T.t("event.loyalty_changed", {"name": _tname(e.target_id), "from": e.from, "to": e.to})
		"fund_changed":
			if e.get("reason", "") == "allocation":
				return T.t("event.fund_allocation", {"usd": Fmt.usd(e.to - e.from)})
			return T.t("event.fund_changed", {"from": Fmt.usd(e.from), "to": Fmt.usd(e.to)})
		"package_received", "package_accepted", "package_rejected":
			return T.t("event." + e.type)
		"list_arrested", "list_game", "list_fake_arrested", "list_fake_revealed":
			return T.t("event." + e.type, {"name": T.loc(ArrestWindow.card(c, e.card_id).get("name", {"ru": e.card_id}))})
		"list_planned":
			return T.t("event.list_planned", {"name": T.loc(ArrestWindow.card(c, e.card_id).get("name", {"ru": e.card_id})), "action": T.t("counterintel.action." + e.action).to_lower()})
		"list_cascade":
			return T.t("event.list_cascade")
		"quota_checked":
			return T.t("event.quota_met" if e.met else "event.quota_failed", {"week": e.by_week, "done": e.get("done", 0), "need": e.get("need", 0)})
		"quota_contested":
			return T.t("event.quota_contested_yes" if e.granted else "event.quota_contested_no", {"week": e.by_week})
		"list_window_closed":
			return T.t("event.list_window_closed", {"n": e.realized})
		"polygraph_scheduled":
			return T.t("event.polygraph_scheduled", {"week": e.week})
		"polygraph_prep":
			return T.t("event.polygraph_prep", {"name": T.loc(Polygraph.prep_option(Polygraph.exam_def(c), e.prep_id).get("label", {"ru": e.prep_id}))})
		"polygraph_started":
			return T.t("event.polygraph_rehearsal" if e.rehearsal else "event.polygraph_started")
		"polygraph_rehearsed", "polygraph_result":
			return T.t("event." + e.type, {"result": T.t("polygraph.verdict." + e.result)})
		"agent_restrained":
			return T.t("event.agent_restrained", {"name": _tname(e.target_id)})
		"package_checked":
			return T.t("event.package_checked." + e.result, {"channel": T.t("package.channel." + e.channel)})
	return ""


# ——— Служебная папка ———

static var service_tab := "saves"
static var _confirm_new := false
static var _ironman_choice := false
static var _load_error := ""


static func service() -> Control:
	var o := _overlay("service-folder")
	var v: VBoxContainer = o[1]
	_title(v, T.t("service.title"), T.t("service.stamp"))
	var tabs := Style.hbox(8)
	for tab in ["saves", "settings"]:
		var on: bool = service_tab == tab
		var b := Style.button(T.t("service.tab." + tab), "service-tab-" + tab, Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK)
		b.pressed.connect(func():
			service_tab = tab
			Game.changed.emit())
		tabs.add_child(b)
	v.add_child(tabs)
	if service_tab == "saves":
		_saves_tab(v)
	else:
		_settings_tab(v)
	var row := Style.hbox(12)
	var close := Style.paper_button("%s  [Esc]" % T.t("desk.back"), "service-close")
	close.pressed.connect(Game.close)
	row.add_child(close)
	# Выход: игра и так сохранена после последнего действия — об этом сказано рядом.
	var quit := Style.paper_button(T.t("service.quit"), "service-quit")
	quit.pressed.connect(Game.quit_game)
	row.add_child(quit)
	row.add_child(Style.para(T.t("service.quitHint"), 360, Style.mono(), 12, Color(Style.INK, 0.6)))
	v.add_child(row)
	return o[0]


static func _slot_label(info: Dictionary) -> String:
	var at: String = String(info.saved_at).replace("T", " ").substr(0, 16)
	return "%s · %s · %s — %s" % [Fmt.op_phase(info.act), T.t("calendar.week", {"week": info.week}), T.t("phase." + info.phase), at]


static func _saves_tab(v: VBoxContainer) -> void:
	var st = Game.storage
	var iron := Campaign.is_ironman(Game.state)
	var box := Style.vbox(8)
	box.name = "saves"
	var auto := Saves.slot_info(st, Saves.AUTOSAVE, Game.content)
	var head := T.t("saves.ironmanOn") if iron else T.t("saves.autosave")
	var auto_l := Style.para("%s %s" % [head, _slot_label(auto) if not auto.is_empty() else ""], PANEL_W - 104, Style.mono(), 14, Style.INK)
	auto_l.name = "autosave-info"
	box.add_child(auto_l)

	box.add_child(_h3(T.t("saves.manual")))
	for i in Saves.MANUAL_SLOTS.size():
		var slot: String = Saves.MANUAL_SLOTS[i]
		var info := Saves.slot_info(st, slot, Game.content)
		var row := Style.hbox(12)
		row.name = "slot-" + slot
		var l := Style.label("%s   %s" % [T.t("saves.slot", {"n": i + 1}), _slot_label(info) if not info.is_empty() else T.t("saves.empty")], Style.mono(), 14, Style.INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var w := Style.paper_button(T.t("saves.write"), "save-" + slot)
		w.disabled = iron
		w.pressed.connect(func(): Game.save_to_slot(slot))
		row.add_child(w)
		var ld := Style.paper_button(T.t("saves.load"), "load-" + slot)
		ld.disabled = iron or info.is_empty()
		ld.pressed.connect(func(): _load_error = Game.load_game(slot))
		row.add_child(ld)
		box.add_child(row)

	box.add_child(_h3(T.t("saves.checkpoints")))
	if iron:
		box.add_child(Style.label(T.t("saves.ironmanNoCheckpoints"), Style.mono(), 14, Style.INK))
	else:
		var list := Saves.list_checkpoints(st)
		list.reverse()
		var cps := Style.vbox(4)
		cps.name = "checkpoints"
		for slot in list:
			var info := Saves.slot_info(st, slot, Game.content)
			if info.is_empty():
				continue
			var row := Style.hbox(12)
			var l := Style.label(_slot_label(info), Style.mono(), 14, Style.INK)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var ld := Style.paper_button(T.t("saves.load"), "load-" + slot)
			ld.pressed.connect(func(): _load_error = Game.load_game(slot))
			row.add_child(ld)
			cps.add_child(row)
		if cps.get_child_count() == 0:
			cps.add_child(Style.label(T.t("saves.noCheckpoints"), Style.mono(), 14, Style.INK))
		box.add_child(cps)
	if _load_error != "":
		box.add_child(Style.label(_load_error, Style.mono(), 14, Style.STAMP_RED))

	box.add_child(_h3(T.t("saves.newTitle")))
	if not _confirm_new:
		var nb := Style.paper_button(T.t("saves.new"), "new-campaign")
		nb.pressed.connect(func():
			_confirm_new = true
			Game.changed.emit())
		box.add_child(nb)
	else:
		var cb := CheckBox.new()
		cb.name = "ironman-toggle"
		cb.text = T.t("saves.ironman")
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = _ironman_choice
		cb.add_theme_font_override("font", Style.form())
		cb.add_theme_font_size_override("font_size", Style.fs(16))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			cb.add_theme_color_override(c, Style.INK)
		cb.toggled.connect(func(on): _ironman_choice = on)
		box.add_child(cb)
		box.add_child(Style.para(T.t("saves.ironmanHint"), PANEL_W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
		var row := Style.hbox(8)
		var ok := Style.paper_button(T.t("saves.newConfirm"), "new-campaign-confirm")
		ok.pressed.connect(func():
			_confirm_new = false
			Game.new_game(_ironman_choice)
			_ironman_choice = false)
		row.add_child(ok)
		var cancel := Style.paper_button(T.t("saves.cancel"), "new-campaign-cancel")
		cancel.pressed.connect(func():
			_confirm_new = false
			Game.changed.emit())
		row.add_child(cancel)
		box.add_child(row)
	v.add_child(box)


static func _settings_tab(v: VBoxContainer) -> void:
	var box := Style.vbox(8)
	box.name = "settings"
	box.add_child(_h3(T.t("settings.textScale")))
	var row := Style.hbox(8)
	for sc in Game.TEXT_SCALES:
		var on: bool = is_equal_approx(Game.settings.text_scale, sc)
		var b := Style.button("%d%%" % int(round(sc * 100)), "text-scale-%d" % int(round(sc * 100)), Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK)
		b.pressed.connect(Game.set_text_scale.bind(sc))
		row.add_child(b)
	box.add_child(row)
	box.add_child(Style.para(T.t("settings.textScaleHint"), PANEL_W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
	box.add_child(_h3(T.t("settings.instantText")))
	var it := Style.button(T.t("settings.on") if Game.settings.instant_text else T.t("settings.off"), "instant-text-toggle", Style.INK, Color(0, 0, 0, 0), Style.INK)
	it.pressed.connect(func(): Game.set_instant_text(not Game.settings.instant_text))
	var irow := Style.hbox(8)
	irow.add_child(it)
	box.add_child(irow)
	box.add_child(Style.para(T.t("settings.instantTextHint"), PANEL_W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
	box.add_child(_h3(T.t("settings.crt")))
	var crow := Style.hbox(8)
	var crt := Style.button(T.t("settings.on") if Game.settings.crt else T.t("settings.off"), "crt-toggle", Style.INK, Color(0, 0, 0, 0), Style.INK)
	crt.pressed.connect(func(): Game.set_setting("crt", not Game.settings.crt))
	crow.add_child(crt)
	box.add_child(crow)
	box.add_child(Style.para(T.t("settings.crtHint"), PANEL_W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
	box.add_child(_h3(T.t("settings.sound")))
	for k in ["vol_master", "vol_sfx", "vol_ambient"]:
		var row2 := Style.hbox(8)
		var lab := Style.label(T.t("settings." + k), Style.form(), 15, Style.INK)
		lab.custom_minimum_size.x = 220
		row2.add_child(lab)
		for step in Game.VOLUME_STEPS:
			var on: bool = int(Game.settings[k]) == step
			var vb := Style.button(T.t("settings.mute") if step == 0 else "%d%%" % step, "%s-%d" % [k.replace("_", "-"), step], Style.PAPER if on else Style.INK, Style.INK if on else Color(0, 0, 0, 0), Style.INK)
			vb.pressed.connect(Game.set_setting.bind(k, step))
			row2.add_child(vb)
		box.add_child(row2)
	box.add_child(_h3(T.t("settings.telemetry")))
	var trow := Style.hbox(8)
	var tb := Style.button(T.t("settings.on") if Game.settings.telemetry else T.t("settings.off"), "telemetry-toggle", Style.INK, Color(0, 0, 0, 0), Style.INK)
	tb.pressed.connect(func(): Game.set_setting("telemetry", not Game.settings.telemetry))
	trow.add_child(tb)
	if OS.has_feature("pc"):
		var fb := Style.button(T.t("settings.telemetryFolder"), "telemetry-folder", Style.INK, Color(0, 0, 0, 0), Style.INK)
		fb.pressed.connect(func():
			DirAccess.make_dir_recursive_absolute(Telemetry.DIR)
			OS.shell_open(ProjectSettings.globalize_path(Telemetry.DIR)))
		trow.add_child(fb)
	box.add_child(trow)
	box.add_child(Style.para(T.t("settings.telemetryHint", {"key": "[F8]"}), PANEL_W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
	# Сборка и Steam — для отчётов тестеров.
	var steam_status: String = Game.steam.status if Game.steam != null else "absent"
	var build := Style.label(T.t("settings.build", {"version": ProjectSettings.get_setting("application/config/version", ""), "platform": "Steam", "steam": T.t("steam." + steam_status)}), Style.mono(), 12, Color(Style.INK, 0.6))
	build.name = "build-info"
	box.add_child(build)
	# Переключатель языка вернётся вместе с английской версией (см. docs/plan.md).
	v.add_child(box)


# ——— Смена фаз операции ———

static func phase_card(done_act: int) -> Control:
	var o := _overlay("phase-card", false)
	var v: VBoxContainer = o[1]
	var c: Dictionary = Game.content
	var prev := {}
	var next := Campaign.current_act_def(Game.state, c)
	for a in c.campaign.acts:
		if int(a.act) == done_act:
			prev = a
	_title(v, T.t("phase.done", {"phase": Fmt.op_phase(done_act)}), T.t("phase.stamp"))
	if not prev.is_empty() and Campaign.act_text(Game.state, prev, "outro") != null:
		v.add_child(Style.para(T.loc(Campaign.act_text(Game.state, prev, "outro")), PANEL_W - 104, Style.mono(), 16, Style.INK))
	if not next.is_empty():
		v.add_child(Style.hline(Color(Style.INK, 0.3)))
		v.add_child(Style.label("%s «%s»" % [Fmt.op_phase(next.act), T.loc(Campaign.act_text(Game.state, next, "title"))], Style.serif(true), 22, Style.INK))
		v.add_child(Style.label(Fmt.date(Campaign.week_date(c, next.act, Game.state.week)), Style.form(), 14, Color(Style.INK, 0.65)))
		if Campaign.act_text(Game.state, next, "intro") != null:
			v.add_child(Style.para(T.loc(Campaign.act_text(Game.state, next, "intro")), PANEL_W - 104, Style.mono(), 16, Style.INK))
	var row := Style.hbox(12)
	var go := Style.paper_button(T.t("phase.continue"), "phase-card-continue")
	go.pressed.connect(Game.close_phase_card)
	row.add_child(go)
	v.add_child(row)
	return o[0]


# ——— Итог кампании ———

static func ending() -> Control:
	var o := _overlay("ending", false)
	var v: VBoxContainer = o[1]
	var e: String = Game.state.ending
	o[2].set_meta("ending", e)
	_title(v, T.t("ending.%s.title" % e), T.t("ending.demo_stamp" if e == Campaign.DEMO_END else "ending.stamp"))
	v.add_child(Style.para(T.t("ending.%s.text" % e, {"week": Game.state.week}), PANEL_W - 104, Style.mono(), 16, Style.INK))
	# Итог кампании: цифры и условия «Чистого триумфа» — без скрытых чисел.
	if Endings.is_final(e):
		var st: Dictionary = Game.state
		var poly = st.get("polygraph")
		var stats := Style.para(T.t("ending.stats", {"realized": ArrestWindow.realized(st, Game.content), "sog": st.risks.sog_heat,
			"mole": st.risks.mole_hunt, "tr": st.risks.treasury, "mp": st.risks.moscow_pressure,
			"poly": T.t("ending.poly." + (poly.result if poly != null and poly.result != "" else "none"))}), PANEL_W - 104, Style.mono(), 14, Style.INK)
		stats.name = "ending-stats"
		v.add_child(stats)
		var ns: Array = Endings.notes(st)
		if not ns.is_empty():
			var nl := Style.para(" ".join(ns.map(func(f): return T.t("ending.note." + f))), PANEL_W - 104, Style.serif(false, true), 14, Style.INK)
			nl.name = "ending-notes"
			v.add_child(nl)
		var chk := Style.vbox(2)
		chk.name = "ending-checklist"
		chk.add_child(Style.label(T.t("ending.check.title"), Style.form(true), 14, Style.INK))
		for x in Endings.checklist(st, Game.content):
			chk.add_child(Style.label((T.t("ending.check.yes") if x.ok else T.t("ending.check.no")) + T.t("ending.check." + x.id, {"need": x.need, "value": x.value}), Style.mono(), 13, Style.INK if x.ok else Style.STAMP_RED))
		v.add_child(chk)
	var row := Style.hbox(12)
	# Конец демоверсии: в демоверсии — страница полной игры, в полной игре — продолжить.
	if e == Campaign.DEMO_END:
		if Game.demo_build:
			if int(ProjectSettings.get_setting("steam/full_app_id", 0)) > 0:
				var wb := Style.paper_button(T.t("ending.wishlist"), "ending-wishlist")
				wb.pressed.connect(Game.open_store)
				row.add_child(wb)
		else:
			var cb := Style.paper_button(T.t("ending.continue_full"), "ending-continue-full")
			cb.pressed.connect(Game.continue_full)
			row.add_child(cb)
	if not Campaign.is_ironman(Game.state):
		var ld := Style.paper_button(T.t("ending.load"), "ending-load")
		ld.pressed.connect(Game.open_service)
		row.add_child(ld)
	# Документальный эпилог: хроника дела Эймса (в финале операции).
	if not Archive.epilogue(Game.state, Game.content).is_empty():
		var eb := Style.paper_button(T.t("ending.epilogue"), "ending-epilogue")
		eb.pressed.connect(Game.set_epilogue_page.bind(0))
		row.add_child(eb)
	# Факт и вымысел (открывается вместе с концом фазы операции).
	var epi := Archive.entry_by_id(Game.content, "arc_epilogue_real")
	if not epi.is_empty() and Archive.is_open(Game.state, epi):
		var ab := Style.paper_button(T.t("ending.archive"), "ending-archive")
		ab.pressed.connect(Game.open_archive.bind("arc_epilogue_fiction"))
		row.add_child(ab)
	var nb := Style.paper_button(T.t("ending.new_game"), "new-game")
	nb.pressed.connect(func(): Game.new_game(false))
	row.add_child(nb)
	v.add_child(row)
	return o[0]
