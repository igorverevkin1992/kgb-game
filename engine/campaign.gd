class_name Campaign
## Движок кампании. `dispatch(state, content, action)` — чистая функция: возвращает
## {state, events, error}; исходное состояние не меняется, неверное действие — error по-русски.
## Неделя: утро (почта, донесения агентов) → день (plan_op) → вечер (resolve_op, recruitment)
## → ночь (submit_report: сверка лжи, пересчёт рисков, концовки, следующий акт).
## Действия:
##   {type: "advance_phase"} · {type: "read_cable", cable_id}
##   {type: "plan_op", op_id, route: [3 site_id]} · {type: "cancel_op", op_id}
##   {type: "resolve_op", op_id, decision: "continue"|"abort"}
##   {type: "recruitment", target_id, result: "success"|"failed"|"postponed"}
##   {type: "take_clue", clue_id} — снять улику-фрагмент из документа (любая фаза)
##   {type: "pin_clue", clue_id, target_id, axis} — приколоть улику к досье (axis "" — общее поле)
##   {type: "submit_analysis", target_id, axis, access, channel} — заключение по досье (проверка тройкой)
##   {type: "use_hint", target_id} — подсказка: намёк → документ → ответ
##   {type: "start_meeting", target_id} · {type: "meeting_turn", tone, clue_id?} — вербовочная беседа
##   {type: "meeting_offer"} · {type: "meeting_abort"} — сделать предложение / прервать контакт
##   (`recruitment` — прямой исход без беседы, для тестов и отладки)
##   {type: "pay_agent", target_id, amount, instrument: "cash"|"escrow", parts} — транш (день и вечер)
##   {type: "plan_op", …, operative: "op_…"} — поручить выход подчинённому (resolve_op решает сам)
##   {type: "decide", decision_id, option_id} — решение резидента
##   {type: "verify_cable", cable_id, decision: "accept"|"query"} — сверка директивы (шифроузел)
##   {type: "check_package", channel: "archive"} · {type: "accept_package"} · {type: "reject_package"}
##     — пробный пакет «крота» и проверка на подставу (Dangle)
##   {type: "list_action", card_id, action: "arrest"|"natural"|"game"|"cancel"} — «Окно арестов»
##   {type: "contest_quota"} — оспорить ближайшую квоту Центра · {type: "restrain_agent", target_id}
##     — «притормозить» траты агента (раз в неделю)
##   {type: "polygraph_prep", prep_id} · {type: "polygraph_start", rehearsal: bool}
##   {type: "polygraph_answer", choice_id} · {type: "polygraph_rationalize", option_id} — полиграф ЦРУ
##   {type: "submit_report", report: "truth"|"embellished"|"silence"} — быстрое донесение, или
##   {type: "submit_report", choices: {fact_key: "as_is"|"embellish"|"omit"}, request: "req_…"|""}
##     — шифрограмма из фактов недели (Cipher.week_facts); вид донесения определяет Cipher.classify

const PHASES := ["morning", "day", "evening", "night"]
const RISKS := ["sog_heat", "mole_hunt", "treasury", "moscow_pressure"]
const NEXT_PHASE := {"morning": "day", "day": "evening", "evening": "night"}
const PHASE_RU := {"morning": "утро", "day": "день", "evening": "вечер", "night": "ночь"}
## Названия мотивов для сообщений игроку (доска мотивов: Д/И/К/С).
const AXIS_NAME_RU := {"money": "деньги", "ideology": "идеология", "compromise": "компромат", "ego": "самолюбие"}
const IRONMAN_FLAG := "mode_ironman"


# ——— Новая кампания ———

static func new_campaign(content: Dictionary) -> Dictionary:
	var acts: Array = content.campaign.acts.duplicate()
	acts.sort_custom(func(a, b): return a.act < b.act)
	var first: Dictionary = acts[0]
	var b: Dictionary = content.balance
	var targets := {}
	for t in content.targets:
		targets[t.target_id] = initial_target_state(t)
	var s := {
		"act": first.act,
		"week": first.weeks.from,
		"phase": "morning",
		"risks": b.start.risks.duplicate(),
		"centre_trust": b.start.centre_trust,
		"fund_usd": b.start.fund_usd,
		"flags": [],
		"delivered_cables": [],
		"read_cables": [],
		"clues": [],
		"targets": targets,
		"planned_ops": [],
		"routes": {},
		"op_results": {},
		"site_visits": {},
		"week_failures": 0,
		"week_field_activity": false,
		"lies": [],
		"goal_reached": false,
		"pinned": [],
		"analysis": {},
		"verified": {},
		"requests": [],
		"meeting": null,
		"tapes": [],
		"agents": {},
		"payments": [],
		"decisions": {},
		"personal_ops": 0,
		"package": null,
		"handled": {},
		"list": null,
		"polygraph": null,
		"rng": b.start.seed,
		"ending": null,
		"log": [],
	}
	var ctx := _ctx(s, content)
	_start_morning(ctx)
	return {"state": s, "events": ctx.events}


static func initial_target_state(t: Dictionary) -> Dictionary:
	return {
		"unlocked": false, "recruited": false, "lost": false, "discovered_axes": [],
		"rapport": t.initial_state.rapport, "paranoia": t.initial_state.paranoia, "reports_delivered": 0,
	}


# ——— Главная функция ———

static func dispatch(state: Dictionary, content: Dictionary, action: Dictionary) -> Dictionary:
	if state.ending != null:
		return _reject(state, "Операция завершена")
	var s: Dictionary = state.duplicate(true)
	var ctx := _ctx(s, content)
	var phase_ru: String = PHASE_RU[s.phase]
	match action.type:
		"advance_phase":
			if not NEXT_PHASE.has(s.phase):
				return _reject(state, "Ночью неделя закрывается докладом в Центр")
			if s.meeting != null:
				return _reject(state, "Идёт встреча: сделайте вербовочное предложение или прервите контакт")
			if s.phase == "evening" and not s.planned_ops.is_empty():
				return _reject(state, "Не проведены выходы: %s" % ", ".join(s.planned_ops.map(func(id): return _op_title(content, id))))
			_set_phase(ctx, NEXT_PHASE[s.phase])

		"read_cable":
			if not s.delivered_cables.has(action.cable_id):
				return _reject(state, "Этот документ ещё не поступал")
			if not s.read_cables.has(action.cable_id):
				s.read_cables.append(action.cable_id)

		"plan_op":
			if s.phase != "day":
				return _reject(state, "Выходы в город готовят днём, а сейчас %s" % phase_ru)
			if not available_ops(s, content).any(func(o): return o.op_id == action.op_id):
				return _reject(state, "Мероприятие «%s» сейчас недоступно" % _op_title(content, action.op_id))
			if s.planned_ops.size() >= int(content.balance.ops.per_week):
				return _reject(state, "На неделю можно подготовить не больше %d выходов" % content.balance.ops.per_week)
			var expense := int(content.balance.finance.op_expense_usd)
			if int(s.fund_usd) < expense:
				return _reject(state, "В валютных средствах нет %d долларов на оперативные расходы" % expense)
			var route: Array = action.get("route", [])
			if not MapGeo.analyze_route(content, route).blocking.is_empty():
				return _reject(state, "Проверочный маршрут — это три разные бытовые точки на карте")
			var op := op_by_id(content, action.op_id)
			var who: String = action.get("operative", Delegation.RESIDENT)
			if who != Delegation.RESIDENT:
				if Delegation.operative(content, who).is_empty():
					return _reject(state, "Такого оперработника нет")
				if not Delegation.unlocked(s, content):
					return _reject(state, "Поручать выходы подчинённым можно после %d личных выходов" % content.balance.delegation.unlock_after_personal_ops)
				if not Delegation.available(s, content).any(func(o): return o.operative_id == who):
					return _reject(state, "Этот оперработник на этой неделе занят или выведен из работы")
			var stops: Array = route.map(func(id): return MapGeo.site(content, id))
			s.routes[op.op_id] = {"stops": route.duplicate(), "observations": _build_observations(ctx, op, stops), "operative": who}
			s.planned_ops.append(op.op_id)
			_emit(ctx, {"type": "op_planned", "op_id": op.op_id})

		"cancel_op":
			if s.phase != "day":
				return _reject(state, "Отменить выход можно только днём")
			if not s.planned_ops.has(action.op_id):
				return _reject(state, "Этот выход не готовился")
			s.planned_ops = Util.without(s.planned_ops, action.op_id)
			s.routes.erase(action.op_id)
			_emit(ctx, {"type": "op_cancelled", "op_id": action.op_id})

		"resolve_op":
			if s.phase != "evening":
				return _reject(state, "В город выходят вечером, а сейчас %s" % phase_ru)
			if not s.planned_ops.has(action.op_id):
				return _reject(state, "Этот выход не готовился")
			var who: String = s.routes.get(action.op_id, {}).get("operative", Delegation.RESIDENT)
			var decision: String = action.get("decision", "continue")
			if who != Delegation.RESIDENT:
				# Подчинённый решает сам: заметил наружку — ушёл на бытовое прикрытие.
				decision = "continue"
				var op_d := op_by_id(content, action.op_id)
				if tail_present(s, op_d, content):
					var p := Delegation.notice_chance(content, who, s.routes[action.op_id].stops)
					var noticed := _roll(ctx) < p
					_emit(ctx, {"type": "operative_report", "op_id": action.op_id, "operative": who, "noticed": noticed})
					if noticed:
						decision = "abort"
			else:
				s.personal_ops = int(s.get("personal_ops", 0)) + 1
			_resolve_op(ctx, op_by_id(content, action.op_id), decision)

		"recruitment":
			if s.phase != "evening":
				return _reject(state, "Вербовочные беседы проводятся вечером, а сейчас %s" % phase_ru)
			var target := target_by_id(content, action.target_id)
			if target.is_empty() or not s.targets.has(action.target_id):
				return _reject(state, "Такого кандидата нет")
			var ts: Dictionary = s.targets[action.target_id]
			if ts.recruited or ts.lost:
				return _reject(state, "Работа с этим кандидатом уже закончена")
			if not ts.unlocked:
				return _reject(state, "Кандидат ещё не установлен: не хватает сведений")
			match action.result:
				"success":
					if not analysis_state(s, target.target_id).approved:
						return _reject(state, "Заключение по делу ещё не утверждено: сначала доска мотивов")
					var missing: Array = target.approach.key_axes.filter(func(a): return not ts.discovered_axes.has(a))
					if not missing.is_empty():
						return _reject(state, "Не вскрыты ведущие мотивы: %s" % ", ".join(missing.map(func(a): return AXIS_NAME_RU[a])))
					_recruit(ctx, target.target_id)
				"failed":
					_lose(ctx, target.target_id)
				_:
					_emit(ctx, {"type": "recruitment_postponed", "target_id": target.target_id})

		"take_clue":
			var clue := clue_by_id(content, action.clue_id)
			if clue.is_empty() or not ["document", "meeting"].has(clue.source.channel):
				return _reject(state, "Эти сведения нельзя взять из документов")
			if clue.source.channel == "document" and not s.delivered_cables.has(clue.source.from):
				return _reject(state, "Этот документ ещё не поступал")
			if clue.source.channel == "meeting" and not Meeting.heard(s, content, clue):
				return _reject(state, "Эта фраза ещё не прозвучала на встречах")
			if s.clues.has(clue.clue_id):
				return _reject(state, "Эти сведения уже отмечены")
			_give_clue(ctx, clue.clue_id)

		"pin_clue":
			var err := _pin_error(s, content, action.clue_id, action.target_id, action.get("axis", ""))
			if err != "":
				return _reject(state, err)
			s.pinned.append({"clue_id": action.clue_id, "target_id": action.target_id, "axis": action.get("axis", "")})
			_emit(ctx, {"type": "clue_pinned", "clue_id": action.clue_id, "target_id": action.target_id, "axis": action.get("axis", "")})

		"submit_analysis":
			var target := target_by_id(content, action.target_id)
			if target.is_empty() or not s.targets.has(action.target_id) or not s.targets[action.target_id].unlocked:
				return _reject(state, "Дело ещё не заведено: кандидат не установлен")
			var an: Dictionary = analysis_state(s, action.target_id)
			if an.approved:
				return _reject(state, "Заключение по этому делу уже утверждено")
			if pinned_clue_count(s, action.target_id) < ContentRules.THREE_CLUES:
				return _reject(state, "Мало сведений в деле: для заключения нужно не меньше трёх")
			var right := 0
			right += 1 if action.axis == target.analysis.leading_axis else 0
			right += 1 if action.access == target.analysis.correct_access else 0
			right += 1 if action.channel == target.approach.flag_mode else 0
			an.attempts += 1
			an.wrong = 3 - right
			s.analysis[action.target_id] = an
			if right == 3:
				an.approved = true
				_emit(ctx, {"type": "analysis_approved", "target_id": action.target_id})
			else:
				_emit(ctx, {"type": "analysis_rejected", "target_id": action.target_id, "wrong": 3 - right})

		"use_hint":
			if not s.targets.has(action.target_id) or not s.targets[action.target_id].unlocked:
				return _reject(state, "Дело ещё не заведено: кандидат не установлен")
			var an: Dictionary = analysis_state(s, action.target_id)
			if an.hint_level >= 3:
				return _reject(state, "Подсказок больше нет")
			an.hint_level += 1
			s.analysis[action.target_id] = an
			_emit(ctx, {"type": "hint_used", "target_id": action.target_id, "level": an.hint_level})

		"start_meeting":
			var did: String = action.get("dialog_id", "")
			var tid: String = action.get("target_id", "")
			if did != "":
				var hd := Meeting.dialog_by_id(content, did)
				tid = hd.get("target_id", tid)
			var hdd := Meeting.dialog_by_id(content, did)
			var err := ""
			if did == "":
				err = Meeting.meet_error(s, content, tid)
			elif Meeting.is_conversation(hdd):
				err = Meeting.conversation_error(s, content, did)
			else:
				err = Meeting.handling_error(s, content, did)
			if err != "":
				return _reject(state, err)
			s.meeting = Meeting.start(s, content, tid, did)
			_emit(ctx, {"type": "meeting_started", "target_id": tid, "dialog_id": s.meeting.dialog_id})

		"meeting_turn":
			if s.meeting == null:
				return _reject(state, "Встреча не идёт")
			var d := Meeting.dialog_by_id(content, s.meeting.dialog_id)
			if not Meeting.topics_left(d, s.meeting):
				return _reject(state, "Темы для разговора исчерпаны: сделайте вербовочное предложение или прервите контакт")
			if not Meeting.TONES.has(action.get("tone", "")):
				return _reject(state, "Выберите тон ответа")
			var clue_id: String = action.get("clue_id", "")
			if clue_id != "" and not Meeting.available_trumps(s, content, s.meeting).any(func(t): return t.clue_id == clue_id):
				return _reject(state, "Эти сведения сейчас не предъявить: они должны быть приобщены к делу и ещё не использованы")
			s.meeting = Meeting.apply_turn(d, s.meeting, action.tone, clue_id, Meeting.is_coercive(content, s.meeting.target_id, action.tone, clue_id))
			if s.meeting.anxiety >= Meeting.max_anxiety(d):
				_finish_meeting(ctx, "failed")

		"meeting_offer":
			if s.meeting == null:
				return _reject(state, "Встреча не идёт")
			var d := Meeting.dialog_by_id(content, s.meeting.dialog_id)
			if not Meeting.can_offer(d, s.meeting):
				return _reject(state, "Рано: контакт ниже %d%%" % d.offer_rapport)
			var target := target_by_id(content, s.meeting.target_id)
			var handling := Meeting.is_agreement(d)
			var missing: Array = [] if handling else target.approach.key_axes.filter(func(a): return not s.targets[target.target_id].discovered_axes.has(a))
			if not missing.is_empty():
				return _reject(state, "Не вскрыты ведущие мотивы: %s" % ", ".join(missing.map(func(a): return AXIS_NAME_RU[a])))
			s.meeting.lines.append({"kind": "my_offer"})
			s.meeting.lines.append({"kind": "reply_offer"})
			_finish_meeting(ctx, "agreed" if handling else "recruited")

		"meeting_abort":
			if s.meeting == null:
				return _reject(state, "Встреча не идёт")
			_finish_meeting(ctx, "aborted")

		"pay_agent":
			if s.phase != "day" and s.phase != "evening":
				return _reject(state, "Выплаты производят днём или вечером, а сейчас %s" % phase_ru)
			var plan := Finance.plan(s, content, action.get("target_id", ""), int(action.get("amount", 0)), action.get("instrument", ""), int(action.get("parts", 1)))
			if plan.error != "":
				return _reject(state, plan.error)
			_change_fund(ctx, -int(action.amount), "tranche", action.target_id)
			for p in plan.parts:
				s.payments.append(p)
			_emit(ctx, {"type": "tranche_sent", "target_id": action.target_id, "amount": int(action.amount), "instrument": action.instrument, "parts": plan.parts.size()})
			_deliver_payments(ctx)

		"decide":
			var d := Decisions.by_id(content, action.get("decision_id", ""))
			if d.is_empty() or not Decisions.pending(s, content).any(func(x): return x.decision_id == d.decision_id):
				return _reject(state, "Это решение сейчас не требуется")
			var o := Decisions.option(d, action.get("option_id", ""))
			if o.is_empty():
				return _reject(state, "Выберите один из вариантов")
			_decide(ctx, d, o)

		"check_package":
			if not Dangle.open(s):
				return _reject(state, "Пробного пакета нет или решение по нему уже принято")
			if action.get("channel", "") != "archive":
				return _reject(state, "Сверка с картотекой — здесь; запрос в Центр — с ночной шифрограммой")
			if s.package.archive != "":
				return _reject(state, "С картотекой пакет уже сверен")
			if not Dangle.archive_available(s, content):
				return _reject(state, "Сверить не с кем: нужен агент с доступом к картотеке ЦРУ")
			s.package.archive = Dangle.check_result(s)
			_emit(ctx, {"type": "package_checked", "channel": "archive", "result": s.package.archive})

		"accept_package":
			if not Dangle.open(s):
				return _reject(state, "Пробного пакета нет или решение по нему уже принято")
			s.package.accepted = true
			_set_flag(ctx, Dangle.ACCEPTED_FLAG)
			if s.package.dangle:
				_set_flag(ctx, Dangle.DANGLE_FLAG)
			_emit(ctx, {"type": "package_accepted", "checked": Dangle.count(s, content, "ok")})
			_check_goal(ctx)

		"reject_package":
			if not Dangle.can_reject(s, content):
				return _reject(state, "Другого канала передачи нет: пакет можно только принять")
			s.package.rejected = true
			_set_flag(ctx, Dangle.REJECTED_FLAG)
			_emit(ctx, {"type": "package_rejected"})

		"list_action":
			var err := ArrestWindow.action_error(s, content, action.get("card_id", ""), action.get("action", ""))
			if err != "":
				return _reject(state, err)
			var st: Dictionary = s.list.cards[action.card_id]
			match action.action:
				"arrest":
					st.status = "arrest"
				"natural":
					st.status = "prep"
					st.week = int(s.week) + int(content.balance.list.natural_prep_weeks)
				"game":
					st.status = "game_plan"
				"cancel":
					st.status = "pending"
					st.week = 0
			_emit(ctx, {"type": "list_planned", "card_id": action.card_id, "action": action.action})

		"contest_quota":
			if not ArrestWindow.open(s, content):
				return _reject(state, "«Окно арестов» закрыто")
			var q := ArrestWindow.next_quota(s, content)
			if q.is_empty():
				return _reject(state, "Квот Центра больше нет")
			if s.list.get("contests", []).has(int(q.by_week)):
				return _reject(state, "Эту квоту уже оспаривали")
			var lb: Dictionary = content.balance.list
			if not s.list.has("contests"):
				s.list.contests = []
			s.list.contests.append(int(q.by_week))
			var granted := ArrestWindow.contest_granted(s, content)
			_emit(ctx, {"type": "quota_contested", "by_week": int(q.by_week), "granted": granted})
			if granted:
				s.list.quotas[str(q.by_week)] = "contested"
				_add_trust(ctx, -int(lb.contest_trust_cost), "quota_contested")
			else:
				_add_risk(ctx, "moscow_pressure", int(lb.contest_refused_pressure), "quota_contested")

		"restrain_agent":
			var id: String = action.get("target_id", "")
			if not Finance.agents(s).has(id):
				return _reject(state, "Такого агента нет")
			var ag: Dictionary = s.agents[id]
			if int(ag.lifestyle) <= 0:
				return _reject(state, "Агент и так живёт скромно")
			if int(ag.get("restrained_week", 0)) == int(s.week):
				return _reject(state, "С агентом уже говорили об этом на этой неделе")
			var lb: Dictionary = content.balance.list
			ag.restrained_week = int(s.week)
			ag.lifestyle = Util.clamp100(int(ag.lifestyle) + int(lb.restrain_lifestyle))
			var from: int = ag.loyalty
			ag.loyalty = Util.clamp100(from + int(lb.restrain_loyalty))
			_emit(ctx, {"type": "agent_restrained", "target_id": id})
			_emit(ctx, {"type": "loyalty_changed", "target_id": id, "from": from, "to": ag.loyalty, "reason": "restrained"})

		"polygraph_prep":
			var err := Polygraph.prep_error(s, content, action.get("prep_id", ""))
			if err != "":
				return _reject(state, err)
			s.polygraph.prep.append(action.prep_id)
			_emit(ctx, {"type": "polygraph_prep", "prep_id": action.prep_id})

		"polygraph_start":
			var p = s.get("polygraph")
			if p == null or p.result != "":
				return _reject(state, "Проверки на полиграфе сейчас нет")
			var rehearsal: bool = action.get("rehearsal", false)
			var e := Polygraph.by_id(content, p.exam_id)
			if p.exam != null and not p.exam.rehearsal:
				return _reject(state, "Проверка уже идёт")
			if not rehearsal and int(s.week) < int(e.week):
				return _reject(state, "Проверка назначена на неделю %d — пока можно провести репетицию" % e.week)
			if s.phase == "night":
				return _reject(state, "Ночью проверку не проводят")
			p.exam = Polygraph.start_exam(s, content, rehearsal)
			if rehearsal:
				p.rehearsals = int(p.rehearsals) + 1
			_emit(ctx, {"type": "polygraph_started", "rehearsal": rehearsal})

		"polygraph_answer", "polygraph_rationalize":
			var p = s.get("polygraph")
			if p == null or p.exam == null or p.exam.has("verdict"):
				return _reject(state, "Проверка не идёт")
			var e := Polygraph.by_id(content, p.exam_id)
			if action.type == "polygraph_answer":
				if p.exam.pending:
					return _reject(state, "Пик на значимом вопросе: сначала объясните волнение")
				var ch: Array = Polygraph.choices(content, s).filter(func(c): return c.choice_id == action.get("choice_id", ""))
				if ch.is_empty():
					return _reject(state, "Такого ответа нет")
				p.exam = Polygraph.answer(content, s, ch[0])
			else:
				if not p.exam.pending:
					return _reject(state, "Объяснять нечего: пика не было")
				var opt: Array = e.rationalizations.filter(func(o): return o.option_id == action.get("option_id", "") and not p.exam.used.has(o.option_id))
				if opt.is_empty():
					return _reject(state, "Этим объяснением уже воспользовались")
				p.exam = Polygraph.rationalize(s, opt[0])
			if Polygraph.finished(content, s):
				_finish_polygraph(ctx)

		"verify_cable":
			var cable := cable_by_id(content, action.cable_id)
			if cable.is_empty() or cable.kind != "directive" or not s.delivered_cables.has(cable.cable_id):
				return _reject(state, "Такого указания не поступало")
			if not s.read_cables.has(cable.cable_id):
				return _reject(state, "Сначала расшифруйте указание")
			if s.verified.has(cable.cable_id):
				return _reject(state, "Решение по этому указанию уже принято")
			if not ["accept", "query"].has(action.get("decision", "")):
				return _reject(state, "Указание можно принять к исполнению или запросить подтверждение")
			_verify(ctx, cable, action.decision)

		"submit_report":
			if s.phase != "night":
				return _reject(state, "Доклад в Центр отправляют ночью, а сейчас %s" % phase_ru)
			var waiting := Decisions.pending(s, content)
			if not waiting.is_empty():
				return _reject(state, "Сначала примите решение: «%s»" % waiting[0].title.ru)
			var pg = s.get("polygraph")
			if pg != null and pg.result == "" and int(s.week) >= int(Polygraph.by_id(content, pg.exam_id).week):
				return _reject(state, "Сначала — проверка «Кроноса» на полиграфе (пульт обстановки)")
			var report: String = action.get("report", "")
			if action.has("choices"):
				var choices: Dictionary = action.choices
				if choices.values().any(func(c): return not Cipher.CHOICES.has(c)):
					return _reject(state, "По каждому пункту: как есть, приукрасить или умолчать")
				report = Cipher.classify(Cipher.week_facts(s), choices)
			if not Cipher.REPORTS.has(report):
				return _reject(state, "Неизвестный вид доклада")
			var request: String = action.get("request", "")
			if request != "" and not Cipher.available_requests(s, content).any(func(r): return r.request_id == request):
				return _reject(state, "Это ходатайство сейчас направить нельзя")
			_end_week(ctx, report, request)

		_:
			return _reject(state, "Неизвестное действие")
	return {"state": s, "events": ctx.events, "error": ""}


# ——— Внутренности ———

static func _ctx(s: Dictionary, content: Dictionary) -> Dictionary:
	return {"s": s, "content": content, "events": []}


static func _reject(state: Dictionary, error: String) -> Dictionary:
	return {"state": state, "events": [], "error": error}


static func _emit(ctx: Dictionary, event: Dictionary) -> void:
	ctx.events.append(event)
	ctx.s.log.append({"week": ctx.s.week, "phase": ctx.s.phase, "event": event})


static func _set_phase(ctx: Dictionary, phase: String) -> void:
	ctx.s.phase = phase
	_emit(ctx, {"type": "phase_changed", "phase": phase})


static func _set_flag(ctx: Dictionary, flag: String) -> void:
	if ctx.s.flags.has(flag):
		return
	ctx.s.flags.append(flag)
	_emit(ctx, {"type": "flag_set", "flag": flag})


static func _add_risk(ctx: Dictionary, risk: String, delta: int, reason: String) -> void:
	if delta == 0:
		return
	var d := delta
	if risk == "mole_hunt" and d > 0 and ctx.s.flags.has("treasury_audit"):
		d = int(round(d * float(ctx.content.balance.treasury.audit_mole_hunt_multiplier)))
	var from: int = ctx.s.risks[risk]
	var to := Util.clamp100(from + d)
	if to == from:
		return
	ctx.s.risks[risk] = to
	_emit(ctx, {"type": "risk_changed", "risk": risk, "from": from, "to": to, "reason": reason})
	if risk == "treasury" and to >= 100:
		_set_flag(ctx, "treasury_audit")


static func _add_trust(ctx: Dictionary, delta: int, reason: String) -> void:
	var from: int = ctx.s.centre_trust
	var to := Util.clamp100(from + delta)
	if to == from:
		return
	ctx.s.centre_trust = to
	_emit(ctx, {"type": "trust_changed", "from": from, "to": to, "reason": reason})


static func _roll(ctx: Dictionary) -> float:
	var r := Rng.next(ctx.s.rng)
	ctx.s.rng = r[1]
	return r[0]


static func _give_clue(ctx: Dictionary, clue_id: String) -> void:
	var s: Dictionary = ctx.s
	if s.clues.has(clue_id):
		return
	var clue := clue_by_id(ctx.content, clue_id)
	if clue.is_empty():
		return
	s.clues.append(clue_id)
	_emit(ctx, {"type": "clue_found", "clue_id": clue_id})
	for r in clue.reveals:
		var ts = s.targets.get(r.target_id)
		if ts != null and not ts.discovered_axes.has(r.axis):
			ts.discovered_axes.append(r.axis)
			_emit(ctx, {"type": "axis_discovered", "target_id": r.target_id, "axis": r.axis})
	_check_unlocks(ctx)
	_check_goal(ctx)  # задача фазы может требовать сведений (например, «Список»)


## Кандидаты открываются по найденным сведениям — но не раньше своей фазы операции.
static func _check_unlocks(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	for t in ctx.content.targets:
		var ts = s.targets.get(t.target_id)
		if ts == null or ts.unlocked or int(t.act) > int(s.act):
			continue
		var found: int = t.unlock.clue_ids.filter(func(id): return s.clues.has(id)).size()
		if found >= int(t.unlock.clues_required):
			ts.unlocked = true
			_emit(ctx, {"type": "target_unlocked", "target_id": t.target_id})


## Утро: свежая почта, донесения агентов, обнуление недельных счётчиков.
static func _start_morning(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var content: Dictionary = ctx.content
	s.phase = "morning"
	s.week_failures = 0
	s.week_field_activity = false
	_emit(ctx, {"type": "week_started", "week": s.week, "act": s.act})
	for cable in content.cables:
		if cable.act <= s.act and cable.week <= s.week and not s.delivered_cables.has(cable.cable_id) \
				and cable.get("requires_flags", []).all(func(f): return s.flags.has(f)):
			s.delivered_cables.append(cable.cable_id)
			_emit(ctx, {"type": "cable_delivered", "cable_id": cable.cable_id})
			# Улики из документов игрок снимает сам (подсвеченные фрагменты, take_clue).
	_deliver_payments(ctx)
	_check_unlocks(ctx)  # новая фаза операции: могли открыться кандидаты по старым сведениям
	_polygraph_notice(ctx)
	# Каждый завербованный агент приносит по одному донесению в неделю — если лоялен.
	for t in content.targets:
		var ts = s.targets.get(t.target_id)
		if ts == null or not ts.recruited or ts.lost:
			continue
		if s.agents.has(t.target_id) and int(s.agents[t.target_id].loyalty) < int(content.balance.finance.reports_min_loyalty):
			continue
		var reports: Array = content.clues.filter(func(c): return c.source.channel == "agent" and c.source.from == t.target_id and int(c.get("act", 1)) <= int(s.act))
		# Первое ещё не полученное донесение (новые фазы операции добавляют свои).
		var fresh: Array = reports.filter(func(c): return not s.clues.has(c.clue_id))
		if not fresh.is_empty():
			ts.reports_delivered += 1
			_give_clue(ctx, fresh[0].clue_id)


## Карточки наблюдений для трёх точек маршрута. На каждой — местная примета и случайный
## прохожий («шум», без повторов). Если за резидентом хвост, его примета мелькает: на маршруте
## через разные районы — дважды («дважды — работа противника»), а если точки в одном-двух
## районах — один раз: бригада наружки меняет машины, и повтор не виден.
static func _build_observations(ctx: Dictionary, op: Dictionary, stops: Array) -> Array:
	var content: Dictionary = ctx.content
	var noise: Array = content.cues.filter(func(c): return c.kind == "noise").map(func(c): return c.tag)
	for i in range(noise.size() - 1, 0, -1):
		var j := int(floor(_roll(ctx) * (i + 1)))
		var tmp = noise[i]
		noise[i] = noise[j]
		noise[j] = tmp
	var tail = op.sdr.repeating_cue if tail_present(ctx.s, op, ctx.content) else null
	var tail_stops: Array = []
	if tail != null:
		var districts := {}
		for st in stops:
			districts[st.district] = true
		if districts.size() >= int(content.balance.sdr.min_districts_for_double_sighting):
			var skip := int(floor(_roll(ctx) * 3))
			tail_stops = [0, 1, 2].filter(func(i): return i != skip)
		else:
			tail_stops = [2]
	var out: Array = []
	for i in stops.size():
		var cards: Array = []
		var ambient: Array = stops[i].ambient_tags
		if not ambient.is_empty():
			cards.append(ambient[int(floor(_roll(ctx) * ambient.size()))])
		if i < noise.size():
			cards.append(noise[i])
		if tail != null and tail_stops.has(i):
			cards.insert(int(floor(_roll(ctx) * (cards.size() + 1))), tail)
		out.append(cards)
	return out


static func _resolve_op(ctx: Dictionary, op: Dictionary, decision: String) -> void:
	var s: Dictionary = ctx.s
	var content: Dictionary = ctx.content
	var b: Dictionary = content.balance.sog_heat
	var tail := tail_present(s, op, content)
	var route_stops: Array = []
	if s.routes.has(op.op_id):
		for id in s.routes[op.op_id].stops:
			var st = MapGeo.site(content, id)
			if st != null:
				route_stops.append(st)
	s.planned_ops = Util.without(s.planned_ops, op.op_id)
	s.routes.erase(op.op_id)
	s.week_field_activity = true
	_change_fund(ctx, -int(content.balance.finance.op_expense_usd), "op_expense", op.op_id)
	# Каждая точка маршрута за 25 милями — заметный для ФБР выезд, даже если операцию свернули.
	for st in route_stops:
		if not MapGeo.within_zone(content, st):
			_add_risk(ctx, "sog_heat", b.outside_25_mile_zone, "outside_25_miles")
	if decision == "abort":
		s.op_results[op.op_id] = "aborted"
		s.week_failures += 1
		_emit(ctx, {"type": "op_resolved", "op_id": op.op_id, "outcome": "aborted"})
		return
	var site_id: String = op.location.site_id
	var visits: int = s.site_visits.get(site_id, 0)
	s.site_visits[site_id] = visits + 1
	if visits > 0:
		_add_risk(ctx, "sog_heat", b.site_reuse_per_use * visits, "site_reuse")
	var target = MapGeo.site(content, site_id)
	if target != null and not MapGeo.within_zone(content, target):
		_add_risk(ctx, "sog_heat", b.outside_25_mile_zone, "outside_25_miles")
	# Хвост был, а игрок продолжил: улики добыты, но ФБР всё зафиксировало (скрытый флаг).
	var outcome := "tail_missed" if tail else "clean"
	if tail:
		var c: Dictionary = op.sdr.get("ignore_consequence", {})
		_add_risk(ctx, "sog_heat", c.get("sog_heat_delta", b.missed_tail_default), "missed_tail")
		if c.has("flag_set"):
			_set_flag(ctx, c.flag_set)
	s.op_results[op.op_id] = outcome
	_emit(ctx, {"type": "op_resolved", "op_id": op.op_id, "outcome": outcome})
	if outcome == "clean" and String(op.get("success_flag", "")) != "":
		_set_flag(ctx, op.success_flag)
	# Тайник для бесконтактного агента: чистая закладка — контакт установлен.
	var contact: String = op.get("contact_target_id", "")
	if contact != "" and outcome == "clean" and s.targets.has(contact) and not s.targets[contact].recruited and not s.targets[contact].lost:
		_emit(ctx, {"type": "contact_established", "target_id": contact, "op_id": op.op_id})
		_set_flag(ctx, "contact_" + contact)  # для документов линии бесконтактного агента
		_recruit(ctx, contact)
	# Пробный пакет «крота»: из тайника или личной передачей.
	if Dangle.package_ops(content).has(op.op_id):
		s.package = Dangle.received(content, s, op.op_id, outcome)
		_emit(ctx, {"type": "package_received", "source": s.package.source})
	for clue in content.clues:
		if clue.source.channel == "field" and clue.source.from == op.op_id:
			_give_clue(ctx, clue.clue_id)


## Конец встречи: запись уходит на катушку, исход применяется к цели.
static func _finish_meeting(ctx: Dictionary, outcome: String) -> void:
	var s: Dictionary = ctx.s
	var m: Dictionary = s.meeting
	var d := Meeting.dialog_by_id(ctx.content, m.dialog_id)
	var handling := Meeting.is_agreement(d)
	if handling and outcome == "failed":
		outcome = "broken_off"  # агент не потерян: встреча сорвалась, лояльность падает
	m.lines.append({"kind": "end", "outcome": outcome})
	s.tapes.append({"target_id": m.target_id, "dialog_id": m.dialog_id, "week": s.week, "outcome": outcome, "lines": m.lines})
	s.meeting = null
	if handling:
		_emit(ctx, {"type": "meeting_ended", "target_id": m.target_id, "outcome": outcome, "dialog_id": d.dialog_id})
		_finish_handling(ctx, d, outcome)
		return
	var ts: Dictionary = s.targets[m.target_id]
	ts.rapport = m.rapport
	ts.paranoia = maxi(0, m.anxiety - int(ctx.content.balance.meeting.anxiety_cooldown))
	_emit(ctx, {"type": "meeting_ended", "target_id": m.target_id, "outcome": outcome})
	match outcome:
		"recruited":
			_recruit(ctx, m.target_id, int(m.get("coercion", 0)) >= int(ctx.content.balance.meeting.coercion_threshold))
		"failed":
			_lose(ctx, m.target_id)


## Итог встречи на связи: договорились — последствия success; сорвалось — failure; прервали —
## встречу можно повторить в другой день. Личная встреча греет наружку при любом исходе.
static func _finish_handling(ctx: Dictionary, d: Dictionary, outcome: String) -> void:
	var s: Dictionary = ctx.s
	var id: String = d.target_id
	if Meeting.is_handling(d):
		_add_risk(ctx, "sog_heat", int(ctx.content.balance.meeting.get("handling_sog_heat", 2)), "agent_meeting")
	if outcome == "aborted":
		return
	if not s.has("handled"):
		s.handled = {}
	s.handled[d.dialog_id] = outcome
	var fx = d.get("success") if outcome == "agreed" else d.get("failure")
	if fx == null:
		return
	if String(fx.get("loyalty_target", "")) != "":
		id = fx.loyalty_target
	var ag = s.agents.get(id)
	if ag != null and int(fx.get("loyalty", 0)) != 0:
		var from: int = ag.loyalty
		ag.loyalty = Util.clamp100(from + int(fx.loyalty))
		_emit(ctx, {"type": "loyalty_changed", "target_id": id, "from": from, "to": ag.loyalty, "reason": "agent_meeting"})
	for r in ["sog_heat", "mole_hunt", "moscow_pressure"]:
		_add_risk(ctx, r, int(fx.get(r, 0)), "agent_meeting")
	_add_trust(ctx, int(fx.get("centre_trust", 0)), "agent_meeting")
	_change_fund(ctx, int(fx.get("fund_usd", 0)), "decision", d.dialog_id)
	if String(fx.get("flag_set", "")) != "":
		_set_flag(ctx, fx.flag_set)
	if outcome != "agreed":
		return
	if ag != null and int(fx.get("lifestyle", 0)) != 0:
		ag.lifestyle = Util.clamp100(int(ag.lifestyle) + int(fx.lifestyle))
	for c in fx.get("clue_ids", []):
		_give_clue(ctx, c)
	if int(fx.get("polygraph_slots", 0)) > 0 and s.get("polygraph") != null:
		s.polygraph.slots = int(s.polygraph.slots) + int(fx.polygraph_slots)
	_check_goal(ctx)


## coerced — завербован принуждением: агент неустойчив (ниже лояльность, она падает каждую неделю).
static func _recruit(ctx: Dictionary, target_id: String, coerced := false) -> void:
	var s: Dictionary = ctx.s
	s.targets[target_id].recruited = true
	s.agents[target_id] = Finance.new_agent(s, ctx.content, target_id, coerced)
	_set_flag(ctx, "recruited_" + target_id)  # для документов и разговоров линии агента
	_emit(ctx, {"type": "target_recruited", "target_id": target_id, "coerced": coerced})
	_check_goal(ctx)


## Задача акта: завербовать одну из целей (и, если задано, выплатить ей обещанное).
static func _check_goal(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var def := current_act_def(s, ctx.content)
	if def.is_empty() or s.goal_reached:
		return
	if not def.goal.get("clues_all", []).all(func(c): return s.clues.has(c)):
		return
	if not def.goal.get("flags_all", []).all(func(f): return s.flags.has(f)):
		return
	for id in def.goal.recruit_any_of:
		if s.targets.has(id) and s.targets[id].recruited and not s.targets[id].lost \
				and (not def.goal.settle_promise or (s.agents.has(id) and s.agents[id].promise_kept)):
			s.goal_reached = true
			return


static func _change_fund(ctx: Dictionary, delta: int, reason: String, ref := "") -> void:
	if delta == 0:
		return
	var s: Dictionary = ctx.s
	var from: int = s.fund_usd
	s.fund_usd = from + delta
	_emit(ctx, {"type": "fund_changed", "from": from, "to": s.fund_usd, "reason": reason, "ref": ref})


## Доставка частей траншей, срок которых наступил: деньги у агента, банк реагирует.
static func _deliver_payments(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var keep: Array = []
	for p in s.payments:
		if int(p.week) > int(s.week):
			keep.append(p)
			continue
		var ag = s.agents.get(p.target_id)
		if ag == null:
			continue
		ag.paid_usd += int(p.amount)
		ag.lifestyle = Util.clamp100(int(ag.lifestyle) + int(p.lifestyle))
		ag.loyalty = Util.clamp100(int(ag.loyalty) + int(p.loyalty))
		_emit(ctx, {"type": "tranche_delivered", "target_id": p.target_id, "amount": int(p.amount), "instrument": p.instrument})
		if p.ctr:
			_emit(ctx, {"type": "ctr_filed", "target_id": p.target_id, "amount": int(p.amount)})
		if p.structuring:
			_emit(ctx, {"type": "structuring_noted", "target_id": p.target_id})
		if int(p.treasury) > 0:
			ag.trace = Util.clamp100(int(ag.trace) + int(p.treasury))
			_add_risk(ctx, "treasury", int(p.treasury), "ctr" if p.ctr else "structuring")
		if p.completes_promise:
			ag.promise_kept = true
			_emit(ctx, {"type": "promise_kept", "target_id": p.target_id})
	s.payments = keep
	_check_goal(ctx)


## Ночь: агенты ждут обещанного, образ жизни остывает или бросается в глаза.
static func _agents_night(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var b: Dictionary = ctx.content.balance.finance
	for id in Finance.agents(s):
		var ag: Dictionary = s.agents[id]
		if not ag.promise_kept and int(s.week) > int(ag.since_week) and Finance.promise_left(s, ctx.content, id) > 0:
			var from: int = ag.loyalty
			ag.loyalty = Util.clamp100(from - int(b.loyalty_unpaid_week))
			_emit(ctx, {"type": "loyalty_changed", "target_id": id, "from": from, "to": ag.loyalty, "reason": "promise_unpaid"})
		if int(ag.lifestyle) >= int(ctx.content.balance.thresholds.danger):
			ag.trace = Util.clamp100(int(ag.trace) + int(b.lifestyle_danger_treasury))
			_add_risk(ctx, "treasury", int(b.lifestyle_danger_treasury), "lifestyle")
		# Агент тратит и сам (дом, машина): образ жизни растёт без выплат.
		ag.lifestyle = Util.clamp100(int(ag.lifestyle) + int(Finance.profile(ctx.content, id).get("spending_per_week", 0)))
		if int(ag.lifestyle) >= int(ctx.content.balance.thresholds.danger) and ArrestWindow.act_of(ctx.content) > 0 \
				and int(s.act) >= ArrestWindow.act_of(ctx.content):
			_add_risk(ctx, "mole_hunt", int(ctx.content.balance.list.lifestyle_mole_hunt), "lifestyle")
		ag.lifestyle = maxi(0, int(ag.lifestyle) - int(b.lifestyle_decay))
		# Завербованный принуждением служит из страха, а не по согласию: лояльность тает.
		if ag.get("coerced", false):
			var from: int = ag.loyalty
			ag.loyalty = Util.clamp100(from - int(b.loyalty_coerced_week))
			_emit(ctx, {"type": "loyalty_changed", "target_id": id, "from": from, "to": ag.loyalty, "reason": "coerced"})
		# Лояльность на нуле — агент рвёт связь (и может пойти в ФБР).
		if int(ag.loyalty) <= 0:
			_emit(ctx, {"type": "agent_broke", "target_id": id})
			_lose(ctx, id)


static func _lose(ctx: Dictionary, target_id: String) -> void:
	var s: Dictionary = ctx.s
	s.targets[target_id].lost = true
	s.week_failures += 1
	_emit(ctx, {"type": "target_lost", "target_id": target_id})
	_add_risk(ctx, "sog_heat", ctx.content.balance.sog_heat.failed_recruitment, "failed_recruitment")


## Решение резидента: последствия сразу и (для оперативных игр) каждую ночь.
static func _decide(ctx: Dictionary, d: Dictionary, o: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var fx: Dictionary = o.effects
	s.decisions[d.decision_id] = o.option_id
	_emit(ctx, {"type": "decision_made", "decision_id": d.decision_id, "option_id": o.option_id})
	for r in RISKS:
		_add_risk(ctx, r, int(fx.get(r, 0)), "decision")
	_add_trust(ctx, int(fx.centre_trust), "decision")
	_change_fund(ctx, int(fx.fund_usd), "decision", d.decision_id)
	if fx.flag_set != "":
		_set_flag(ctx, fx.flag_set)
	if fx.operative_out != "":
		_set_flag(ctx, "out_" + fx.operative_out)
	var lt: String = fx.get("loyalty_target", "")
	if lt != "" and int(fx.get("loyalty", 0)) != 0 and s.agents.has(lt):
		var ag: Dictionary = s.agents[lt]
		var from: int = ag.loyalty
		ag.loyalty = Util.clamp100(from + int(fx.loyalty))
		_emit(ctx, {"type": "loyalty_changed", "target_id": lt, "from": from, "to": ag.loyalty, "reason": "decision"})
	_check_goal(ctx)  # задача фазы может ждать флага решения (например, «сеть сдана»)


## Директива сверена: принять к исполнению или запросить подтверждение у Центра.
static func _verify(ctx: Dictionary, cable: Dictionary, decision: String) -> void:
	var b: Dictionary = ctx.content.balance.cipher
	var outcome := Cipher.verify_outcome(cable, decision)
	ctx.s.verified[cable.cable_id] = decision
	_emit(ctx, {"type": "directive_verified", "cable_id": cable.cable_id, "decision": decision, "outcome": outcome})
	match outcome:
		"accepted_forged":
			_add_risk(ctx, "sog_heat", b.accept_forged_sog_heat, "forged_directive")
			_set_flag(ctx, b.accept_forged_flag)
		"confirmed":
			_add_trust(ctx, b.query_genuine_trust, "needless_query")
			_add_risk(ctx, "moscow_pressure", b.query_genuine_pressure, "needless_query")
		"exposed":
			_add_trust(ctx, b.query_forged_trust, "forgery_exposed")


## Запрос в Центр: решение — по Доверию Центра в момент отправки (до последствий донесения).
static func _request(ctx: Dictionary, request_id: String) -> void:
	var s: Dictionary = ctx.s
	var r := Cipher.request_by_id(ctx.content, request_id)
	var granted := Cipher.would_grant(s, r)
	s.requests.append({"request_id": request_id, "act": s.act, "week": s.week, "granted": granted})
	_emit(ctx, {"type": "request_answered", "request_id": request_id, "granted": granted})
	var fx: Dictionary = r.granted if granted else r.refused
	_add_trust(ctx, fx.centre_trust, "request")
	_add_risk(ctx, "moscow_pressure", fx.moscow_pressure, "request")
	if granted:
		_change_fund(ctx, int(fx.get("fund_usd", 0)), "request", request_id)
	if r.get("package_check", false) and Dangle.centre_waiting(s):
		s.package.centre = Dangle.check_result(s)
		_emit(ctx, {"type": "package_checked", "channel": "centre", "result": s.package.centre})


## Ночь: донесение, сверка лжи, пересчёт рисков, концовки и переход к следующей неделе.
static func _end_week(ctx: Dictionary, report: String, request := "") -> void:
	var s: Dictionary = ctx.s
	var content: Dictionary = ctx.content
	var b: Dictionary = content.balance
	var mp: Dictionary = b.moscow_pressure
	var ct: Dictionary = b.centre_trust
	var fx := Cipher.report_effects(s, content, report)
	_emit(ctx, {"type": "report_submitted", "report": report, "request": request})
	if request != "":
		_request(ctx, request)
	_add_trust(ctx, fx.trust, "report_" + report)
	_add_risk(ctx, "moscow_pressure", fx.pressure, "report_" + report)
	if fx.lie:
		s.lies.append({"week": s.week, "kind": report})

	# Сверка донесений: каждая ложь либо вскрывается, либо уходит в архив навсегда.
	if s.week % int(b.lies.check_every_weeks) == 0 and not s.lies.is_empty():
		for lie in s.lies:
			var chance: float = b.lies.uncover_chance_embellished if lie.kind == "embellished" else b.lies.uncover_chance_silence
			if _roll(ctx) < chance:
				_emit(ctx, {"type": "lie_uncovered", "lie_week": lie.week})
				_add_trust(ctx, ct.lie_uncovered, "lie_uncovered")
				_add_risk(ctx, "moscow_pressure", mp.lie_uncovered, "lie_uncovered")
				_set_flag(ctx, "centre_caught_lie")
		s.lies = []

	_list_night(ctx)
	if s.flags.has(ArrestWindow.ANLACE_FLAG):
		_add_risk(ctx, "sog_heat", int(b.list.anlace_weekly_sog), "anlace")
	var act := current_act_def(s, content)
	if s.goal_reached:
		_add_risk(ctx, "moscow_pressure", mp.act_goal_reached, "act_goal_reached")
		_emit(ctx, {"type": "act_completed", "act": s.act})
	elif not act.is_empty() and s.week > Cipher.act_deadline(s, content):
		_add_risk(ctx, "moscow_pressure", mp.per_week_overdue, "act_overdue")
	elif not act.is_empty() and s.week - act.weeks.from + 1 > int(mp.grace_weeks):
		_add_risk(ctx, "moscow_pressure", mp.per_week_without_goal, "no_progress")

	_agents_night(ctx)
	_add_risk(ctx, "sog_heat", Decisions.weekly_sog(s, content), "operational_game")
	if not s.week_field_activity:
		_add_risk(ctx, "sog_heat", b.sog_heat.quiet_week, "quiet_week")

	for pair in [["sog_heat", "persona_non_grata"], ["moscow_pressure", "recalled"], ["mole_hunt", "mole_arrested"]]:
		if s.risks[pair[0]] >= 100:
			_end(ctx, pair[1])
			return

	if s.goal_reached:
		var nxt := next_act_def(s, content)
		if nxt.is_empty():
			_end(ctx, Endings.final(s, content))  # четыре концовки кампании
			return
		s.act = nxt.act
		s.week = maxi(s.week + 1, nxt.weeks.from)  # сюжетный скачок во времени между актами
		s.goal_reached = false
		_change_fund(ctx, int(nxt.get("fund_usd", 0)), "allocation", "act_%d" % nxt.act)
		if nxt.get("arrest_window") != null and s.get("list") == null:
			s.list = ArrestWindow.new_state(content)
	else:
		s.week += 1
		# Задача фазы сорвана окончательно: Центр отзывает резидента.
		if s.week > Cipher.act_deadline(s, content) + int(b.moscow_pressure.get("recall_after_overdue_weeks", 8)):
			_end(ctx, "recalled")
			return
	_start_morning(ctx)


## Ночь «Окна арестов»: исполнение мер, каскад тревоги в Лэнгли, квоты Центра, закрытие окна.
static func _list_night(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var content: Dictionary = ctx.content
	if s.get("list") == null or int(s.act) != ArrestWindow.act_of(content) or s.flags.has(ArrestWindow.WINDOW_CLOSED_FLAG):
		return
	var b: Dictionary = content.balance.list
	var cfg := ArrestWindow.config(content)
	var plain := 0
	for c in content.list:
		var st: Dictionary = s.list.cards[c.card_id]
		var fake := ArrestWindow.is_fake(s, c)
		match st.status:
			"arrest":
				if fake:
					st.status = "fake_arrested"
					_emit(ctx, {"type": "list_fake_arrested", "card_id": c.card_id})
					_add_trust(ctx, int(b.fake_trust), "fake_arrested")
					_set_flag(ctx, ArrestWindow.EXPOSED_FLAG)
				else:
					st.status = "arrested"
					_emit(ctx, {"type": "list_arrested", "card_id": c.card_id, "howard": c.howard, "natural": false})
					_add_risk(ctx, "mole_hunt", int(b.howard_mole_hunt) if c.howard else int(b.plain_mole_hunt), "arrest")
					if not c.howard:
						plain += 1
			"prep":
				if int(st.week) > int(s.week):
					continue
				if fake:
					st.status = "fake"
					_emit(ctx, {"type": "list_fake_revealed", "card_id": c.card_id})
				else:
					st.status = "natural"
					_emit(ctx, {"type": "list_arrested", "card_id": c.card_id, "howard": c.howard, "natural": true})
					_add_risk(ctx, "mole_hunt", int(b.natural_mole_hunt), "natural_arrest")
			"game_plan":
				if fake:
					st.status = "fake"
					_emit(ctx, {"type": "list_fake_revealed", "card_id": c.card_id})
				else:
					st.status = "game"
					_emit(ctx, {"type": "list_game", "card_id": c.card_id})
					_add_risk(ctx, "mole_hunt", int(b.game_mole_hunt), "operational_game")
					_add_risk(ctx, "moscow_pressure", int(b.game_critical_pressure) if c.damage == "critical" else int(b.game_pressure), "operational_game")
	# Слишком много арестов «без Ховарда» за неделю — в Лэнгли понимают, что течёт изнутри.
	if plain > int(b.cascade_after):
		_emit(ctx, {"type": "list_cascade", "arrests": plain})
		_add_risk(ctx, "mole_hunt", int(b.cascade_mole_hunt), "cascade")
		_set_flag(ctx, ArrestWindow.CASCADE_FLAG)
		_set_flag(ctx, ArrestWindow.ANLACE_FLAG)
	if int(s.risks.mole_hunt) >= int(b.anlace_mole_hunt):
		_set_flag(ctx, ArrestWindow.ANLACE_FLAG)
	for q in cfg.quotas:
		var key := str(q.by_week)
		if int(q.by_week) != int(s.week) or s.list.quotas.has(key):
			continue
		var done := ArrestWindow.quota_progress(s, content, q)
		var met: bool = done >= int(q.arrests)
		s.list.quotas[key] = "met" if met else "failed"
		_emit(ctx, {"type": "quota_checked", "by_week": int(q.by_week), "met": met, "done": done, "need": int(q.arrests)})
		if met:
			_add_trust(ctx, int(b.quota_met_trust), "quota_met")
			_add_risk(ctx, "moscow_pressure", int(b.quota_met_pressure), "quota_met")
		else:
			_add_trust(ctx, int(b.quota_failed_trust), "quota_failed")
			_add_risk(ctx, "moscow_pressure", int(b.quota_failed_pressure), "quota_failed")
	if int(s.week) >= int(cfg.to):
		_set_flag(ctx, ArrestWindow.WINDOW_CLOSED_FLAG)
		_emit(ctx, {"type": "list_window_closed", "realized": ArrestWindow.realized(s, content)})
		_check_goal(ctx)


## Утро: «Кроноса» вызывают на плановый полиграф (с источником в Управлении безопасности —
## заранее, без него — в последний момент).
static func _polygraph_notice(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var e := Polygraph.exam_def(ctx.content)
	if e.is_empty() or s.get("polygraph") != null or int(s.act) != int(e.act) or s.flags.has(Polygraph.DONE_FLAG):
		return
	if int(s.week) < Polygraph.notice_week(s, ctx.content, e):
		return
	var ts = s.targets.get(e.subject)
	s.polygraph = Polygraph.new_state(s, ctx.content, e)
	if ts == null or not ts.recruited or ts.lost:
		s.polygraph.result = "none"
		_set_flag(ctx, Polygraph.DONE_FLAG)
		_set_flag(ctx, Polygraph.ABSENT_FLAG)
		return
	_emit(ctx, {"type": "polygraph_scheduled", "week": int(e.week), "source": s.polygraph.source})


## Итог проверки на полиграфе (репетиция — только вердикт без последствий).
static func _finish_polygraph(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var p: Dictionary = s.polygraph
	var v := Polygraph.verdict(ctx.content, p.exam, p.exam_id)
	p.exam.verdict = v
	if p.exam.rehearsal:
		_emit(ctx, {"type": "polygraph_rehearsed", "result": v})
		return
	var e := Polygraph.by_id(ctx.content, p.exam_id)
	p.result = v
	_emit(ctx, {"type": "polygraph_result", "result": v})
	_add_risk(ctx, "mole_hunt", int(e.outcomes[v].mole_hunt), "polygraph")
	_set_flag(ctx, {"pass": Polygraph.PASS_FLAG, "inconclusive": Polygraph.INCONCLUSIVE_FLAG, "fail": Polygraph.FAIL_FLAG}[v])
	_set_flag(ctx, Polygraph.DONE_FLAG)
	_check_goal(ctx)


static func _end(ctx: Dictionary, ending: String) -> void:
	ctx.s.ending = ending
	_emit(ctx, {"type": "game_over", "ending": ending})


# ——— Селекторы ———

static func op_by_id(content: Dictionary, id: String) -> Dictionary:
	for o in content.ops:
		if o.op_id == id:
			return o
	return {}


static func target_by_id(content: Dictionary, id: String) -> Dictionary:
	for t in content.targets:
		if t.target_id == id:
			return t
	return {}


static func clue_by_id(content: Dictionary, id: String) -> Dictionary:
	for c in content.clues:
		if c.clue_id == id:
			return c
	return {}


static func cable_by_id(content: Dictionary, id: String) -> Dictionary:
	for c in content.cables:
		if c.cable_id == id:
			return c
	return {}


static func _op_title(content: Dictionary, id: String) -> String:
	var op := op_by_id(content, id)
	return op.title.ru if not op.is_empty() else id


static func current_act_def(s: Dictionary, content: Dictionary) -> Dictionary:
	for a in content.campaign.acts:
		if a.act == s.act:
			return a
	return {}


## Название, вводная или итог фазы с учётом вариантов (по флагам кампании).
static func act_text(s: Dictionary, def: Dictionary, key: String):
	for v in def.get("variants", []):
		if v.flags_all.all(func(f): return s.flags.has(f)) and v.get(key) != null:
			return v[key]
	return def.get(key)


static func next_act_def(s: Dictionary, content: Dictionary) -> Dictionary:
	var best := {}
	for a in content.campaign.acts:
		if a.act > s.act and (best.is_empty() or a.act < best.act):
			best = a
	return best


## Операции, которые можно запланировать прямо сейчас.
static func available_ops(s: Dictionary, content: Dictionary) -> Array:
	return content.ops.filter(func(op):
		var r = s.op_results.get(op.op_id)
		return op.act <= s.act and op.week <= s.week and r != "clean" and r != "tail_missed" \
			and not s.planned_ops.has(op.op_id) \
			and op.requires_targets_unlocked.all(func(t): return s.targets.has(t) and s.targets[t].unlocked) \
			and op.get("requires_recruited", []).all(func(t): return s.targets.has(t) and s.targets[t].recruited and not s.targets[t].lost) \
			and op.get("requires_flags", []).all(func(f): return s.flags.has(f)) \
			and op.get("requires_decisions", []).all(func(d): return s.decisions.has(d)) \
			and (op.get("contact_target_id", "") == "" or (s.targets.has(op.contact_target_id) and analysis_state(s, op.contact_target_id).approved \
				and not s.targets[op.contact_target_id].recruited)))


## Есть ли хвост на маршруте. Вовремя свернув на бытовую легенду, игрок «спасает операцию»:
## повторный выход после отказа проходит чисто (GDD, Блок 3).
## «Слепое окно»: агент с графиками наружки знает пересменку бригад — на таком выходе хвоста нет.
static func tail_present(s: Dictionary, op: Dictionary, content := {}) -> bool:
	if not op.sdr.surveillance_present or s.op_results.get(op.op_id) == "aborted":
		return false
	return not blind_window(s, op, content)


static func blind_window(s: Dictionary, op: Dictionary, content: Dictionary) -> bool:
	return not content.is_empty() and op.sdr.get("blind_window", false) and Finance.perk_active(s, content, "sog_schedule")


## Что игрок знает о мотиве цели по своей доске: unknown → hypothesis (1–2 приколотые улики)
## → confirmed (3+, «Правило трёх улик»: открывается истинная цифра уязвимости).
static func axis_knowledge(s: Dictionary, _content: Dictionary, target_id: String, axis: String) -> String:
	var n := axis_pin_count(s, target_id, axis)
	if n == 0:
		return "unknown"
	return "confirmed" if n >= ContentRules.THREE_CLUES else "hypothesis"


static func axis_pin_count(s: Dictionary, target_id: String, axis: String) -> int:
	return s.pinned.filter(func(p): return p.target_id == target_id and p.axis == axis).size()


## Сколько разных улик приколото к досье (для заключения нужно три).
static func pinned_clue_count(s: Dictionary, target_id: String) -> int:
	var ids := {}
	for p in s.pinned:
		if p.target_id == target_id:
			ids[p.clue_id] = true
	return ids.size()


## Относится ли улика к цели: вскрывает её мотив или входит в улики, по которым цель устанавливают.
static func clue_relevant(content: Dictionary, clue: Dictionary, target_id: String) -> bool:
	if clue.reveals.any(func(r): return r.target_id == target_id):
		return true
	var t := target_by_id(content, target_id)
	return not t.is_empty() and t.unlock.clue_ids.has(clue.clue_id)


## Почему нельзя приколоть улику (пустая строка — можно).
static func _pin_error(s: Dictionary, content: Dictionary, clue_id: String, target_id: String, axis: String) -> String:
	var clue := clue_by_id(content, clue_id)
	if clue.is_empty() or not s.clues.has(clue_id):
		return "Сведения ещё не добыты"
	if not s.targets.has(target_id) or not s.targets[target_id].unlocked:
		return "Дело ещё не заведено: кандидат не установлен"
	if s.pinned.any(func(p): return p.clue_id == clue_id and p.target_id == target_id and p.axis == axis):
		return "Эти сведения уже приобщены сюда"
	if axis == "":
		return "" if clue_relevant(content, clue, target_id) else "Не вяжется: сведения не относятся к этому кандидату"
	if not clue.reveals.any(func(r): return r.target_id == target_id and r.axis == axis):
		return "Не вяжется: эти сведения ничего не говорят об этом мотиве" if clue_relevant(content, clue, target_id) else "Не вяжется: сведения не относятся к этому кандидату"
	return ""


## Улики, которые ещё лежат в стопке «Новые улики»: найдены, но ни разу не приколоты.
static func unpinned_clues(s: Dictionary, content: Dictionary) -> Array:
	var pinned := {}
	for p in s.pinned:
		pinned[p.clue_id] = true
	return content.clues.filter(func(c): return s.clues.has(c.clue_id) and not pinned.has(c.clue_id))


## Улики-фрагменты в документе, которые игрок ещё не снял («Интуиция»).
static func untaken_chunks(s: Dictionary, content: Dictionary, cable_id: String) -> Array:
	return content.clues.filter(func(c): return c.source.channel == "document" and c.source.from == cable_id and not s.clues.has(c.clue_id))


## Сколько улик по цели ещё не найдено («Интуиция» на досье).
static func undiscovered_for_target(s: Dictionary, content: Dictionary, target_id: String) -> int:
	return content.clues.filter(func(c): return clue_relevant(content, c, target_id) and not s.clues.has(c.clue_id)).size()


static func analysis_state(s: Dictionary, target_id: String) -> Dictionary:
	var a: Dictionary = s.analysis.get(target_id, {})
	return {"approved": a.get("approved", false), "attempts": a.get("attempts", 0), "wrong": a.get("wrong", -1), "hint_level": a.get("hint_level", 0)}


static func risk_level(value: int, content: Dictionary) -> String:
	var th: Dictionary = content.balance.thresholds
	if value >= th.danger:
		return "danger"
	return "warning" if value >= th.warning else "calm"


static func unread_cables(s: Dictionary) -> Array:
	return s.delivered_cables.filter(func(id): return not s.read_cables.has(id))


## Календарная дата начала недели по start_date акта: {year, month, day}.
static func week_date(content: Dictionary, act: int, week: int) -> Dictionary:
	for a in content.campaign.acts:
		if a.act == act:
			var parts: PackedStringArray = String(a.start_date).split("-")
			var unix := Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12})
			unix += (week - int(a.weeks.from)) * int(a.get("days_per_week", 7)) * 86400
			var d := Time.get_datetime_dict_from_unix_time(unix)
			return {"year": d.year, "month": d.month, "day": d.day}
	return {}


static func is_ironman(s: Dictionary) -> bool:
	return s.flags.has(IRONMAN_FLAG)
