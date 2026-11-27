class_name TaskView
## Задание Центра на бланке: текст, срок, материалы, вопросы с вариантами. Последствия видны
## заранее (без подсказки, какой ответ верный); после ответа — штамп и разбор по пунктам.

const W := 900.0


static func build(t: Dictionary) -> Control:
	var s: Dictionary = Game.state
	var st: Dictionary = s.tasks.get(t.task_id, {})
	var status: String = st.get("status", "open")
	var draft: Dictionary = Game.task_draft.get(t.task_id, {})
	var b: Dictionary = Game.content.balance.tasks
	var sb := Style.box(Style.PAPER, Color(0, 0, 0, 0), 0, 0, 0)
	sb.content_margin_left = 56
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 40
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	var p := PanelContainer.new()
	p.name = "task"
	p.set_meta("task", t.task_id)
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(12)
	v.custom_minimum_size.x = W - 104
	var head := Style.hbox(16)
	var kick := Style.label(T.t("task.kicker").to_upper(), Style.form(true), 14, Style.STAMP_RED)
	kick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(kick)
	var due := Style.label(T.t("task.due", {"week": st.get("due", 0)}), Style.form(true), 14, Style.STAMP_RED if status == "open" else Color(Style.INK, 0.6))
	due.name = "task-due"
	head.add_child(due)
	v.add_child(head)
	v.add_child(Style.para(T.loc(t.title), W - 104, Style.serif(true), 26, Style.INK))
	v.add_child(Style.hline(Color(Style.INK, 0.3)))
	v.add_child(Style.para(T.loc(t.text), W - 104, Style.mono(), 16, Style.INK))
	# Материалы, на которые ссылается Центр: открыть одним нажатием.
	for cid in t.get("needs_cables", []):
		var cab := Campaign.cable_by_id(Game.content, cid)
		var read: bool = s.read_cables.has(cid)
		var mb := Style.button(T.t("task.material", {"title": T.loc(cab.subject)}) + ("" if read else T.t("task.unread")), "task-material-" + cid, Style.INK, Color(0, 0, 0, 0.05), Color(Style.INK, 0.4), 13)
		mb.pressed.connect(Game.select_document.bind(cid))
		v.add_child(mb)
	for q in t.questions:
		var box := Style.panel(Color(0, 0, 0, 0.05), 14, Color(Style.INK, 0.35), 1)
		var qv := Style.vbox(6)
		qv.add_child(Style.para(T.loc(q.prompt), W - 140, Style.form(true), 17, Style.INK))
		var right := CentreTasks.correct(s, Game.content, q)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		for o in CentreTasks.options(s, Game.content, q):
			var picked: bool = draft.get(q.q_id, "") == o.id
			var label := T.loc(o.label)
			if o.has("effects") and o.effects != null:
				label += " — " + DecisionView.effects_text(o.effects).trim_suffix(".")
			if status != "open":
				picked = st.get("answers", {}).get(q.q_id, "") == o.id
				if right != "" and o.id == right:
					label += T.t("task.rightMark")
			var ob := Style.button(label, "task-opt-%s-%s" % [q.q_id, o.id], Style.PAPER if picked else Style.INK, Style.INK if picked else Color(0, 0, 0, 0), Color(Style.INK, 0.45), 14)
			ob.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ob.custom_minimum_size.x = W - 160
			ob.disabled = status != "open"
			ob.pressed.connect(Game.set_task_answer.bind(t.task_id, q.q_id, o.id))
			flow.add_child(ob)
		qv.add_child(flow)
		box.add_child(qv)
		v.add_child(box)
	if status == "open":
		v.add_child(Style.para(T.t("task.rules", {"ok": b.done_trust, "wt": b.wrong_trust, "wp": b.wrong_pressure, "ot": b.overdue_trust, "op": b.overdue_pressure}), W - 104, Style.mono(), 13, Color(Style.INK, 0.75)))
		var send := Style.paper_button(T.t("task.send"), "task-send")
		send.disabled = CentreTasks.answer_error(s, Game.content, t.task_id, draft) != ""
		send.tooltip_text = CentreTasks.answer_error(s, Game.content, t.task_id, draft)
		send.pressed.connect(Game.dispatch.bind({"type": "answer_task", "task_id": t.task_id, "answers": draft}))
		var row := Style.hbox(8)
		row.add_child(send)
		v.add_child(row)
	else:
		v.add_child(Style.stamp(T.t("task.status." + status, {"n": st.get("wrong", 0)}), Style.STAMP_RED, 16, -3))
	p.add_child(v)
	return p
