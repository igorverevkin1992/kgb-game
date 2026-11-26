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
##   {type: "verify_cable", cable_id, decision: "accept"|"query"} — сверка директивы (шифроузел)
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
			var stops: Array = route.map(func(id): return MapGeo.site(content, id))
			s.routes[op.op_id] = {"stops": route.duplicate(), "observations": _build_observations(ctx, op, stops)}
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
			_resolve_op(ctx, op_by_id(content, action.op_id), action.decision)

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
			var err := Meeting.meet_error(s, content, action.get("target_id", ""))
			if err != "":
				return _reject(state, err)
			s.meeting = Meeting.start(s, content, action.target_id)
			_emit(ctx, {"type": "meeting_started", "target_id": action.target_id})

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
			s.meeting = Meeting.apply_turn(d, s.meeting, action.tone, clue_id)
			if s.meeting.anxiety >= Meeting.max_anxiety(d):
				_finish_meeting(ctx, "failed")

		"meeting_offer":
			if s.meeting == null:
				return _reject(state, "Встреча не идёт")
			var d := Meeting.dialog_by_id(content, s.meeting.dialog_id)
			if not Meeting.can_offer(d, s.meeting):
				return _reject(state, "Рано: контакт ниже %d%%" % d.offer_rapport)
			var target := target_by_id(content, s.meeting.target_id)
			var missing: Array = target.approach.key_axes.filter(func(a): return not s.targets[target.target_id].discovered_axes.has(a))
			if not missing.is_empty():
				return _reject(state, "Не вскрыты ведущие мотивы: %s" % ", ".join(missing.map(func(a): return AXIS_NAME_RU[a])))
			s.meeting.lines.append({"kind": "my_offer"})
			s.meeting.lines.append({"kind": "reply_offer"})
			_finish_meeting(ctx, "recruited")

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
	for t in ctx.content.targets:
		var ts = s.targets.get(t.target_id)
		if ts == null or ts.unlocked or not t.unlock.clue_ids.has(clue_id):
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
		if cable.act <= s.act and cable.week <= s.week and not s.delivered_cables.has(cable.cable_id):
			s.delivered_cables.append(cable.cable_id)
			_emit(ctx, {"type": "cable_delivered", "cable_id": cable.cable_id})
			# Улики из документов игрок снимает сам (подсвеченные фрагменты, take_clue).
	_deliver_payments(ctx)
	# Каждый завербованный агент приносит по одному донесению в неделю — если лоялен.
	for t in content.targets:
		var ts = s.targets.get(t.target_id)
		if ts == null or not ts.recruited or ts.lost:
			continue
		if s.agents.has(t.target_id) and int(s.agents[t.target_id].loyalty) < int(content.balance.finance.reports_min_loyalty):
			continue
		var reports: Array = content.clues.filter(func(c): return c.source.channel == "agent" and c.source.from == t.target_id)
		if ts.reports_delivered < reports.size():
			var nxt: Dictionary = reports[ts.reports_delivered]
			ts.reports_delivered += 1
			_give_clue(ctx, nxt.clue_id)


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
	var tail = op.sdr.repeating_cue if tail_present(ctx.s, op) else null
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
	var tail := tail_present(s, op)
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
	for clue in content.clues:
		if clue.source.channel == "field" and clue.source.from == op.op_id:
			_give_clue(ctx, clue.clue_id)


## Конец встречи: запись уходит на катушку, исход применяется к цели.
static func _finish_meeting(ctx: Dictionary, outcome: String) -> void:
	var s: Dictionary = ctx.s
	var m: Dictionary = s.meeting
	var ts: Dictionary = s.targets[m.target_id]
	m.lines.append({"kind": "end", "outcome": outcome})
	s.tapes.append({"target_id": m.target_id, "dialog_id": m.dialog_id, "week": s.week, "outcome": outcome, "lines": m.lines})
	s.meeting = null
	ts.rapport = m.rapport
	ts.paranoia = maxi(0, m.anxiety - int(ctx.content.balance.meeting.anxiety_cooldown))
	_emit(ctx, {"type": "meeting_ended", "target_id": m.target_id, "outcome": outcome})
	match outcome:
		"recruited":
			_recruit(ctx, m.target_id)
		"failed":
			_lose(ctx, m.target_id)


static func _recruit(ctx: Dictionary, target_id: String) -> void:
	var s: Dictionary = ctx.s
	s.targets[target_id].recruited = true
	s.agents[target_id] = Finance.new_agent(s, ctx.content, target_id)
	_emit(ctx, {"type": "target_recruited", "target_id": target_id})
	_check_goal(ctx)


## Задача акта: завербовать одну из целей (и, если задано, выплатить ей обещанное).
static func _check_goal(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var def := current_act_def(s, ctx.content)
	if def.is_empty() or s.goal_reached:
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
		ag.lifestyle = maxi(0, int(ag.lifestyle) - int(b.lifestyle_decay))


static func _lose(ctx: Dictionary, target_id: String) -> void:
	var s: Dictionary = ctx.s
	s.targets[target_id].lost = true
	s.week_failures += 1
	_emit(ctx, {"type": "target_lost", "target_id": target_id})
	_add_risk(ctx, "sog_heat", ctx.content.balance.sog_heat.failed_recruitment, "failed_recruitment")


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

	var act := current_act_def(s, content)
	if s.goal_reached:
		_add_risk(ctx, "moscow_pressure", mp.act_goal_reached, "act_goal_reached")
		_emit(ctx, {"type": "act_completed", "act": s.act})
	elif not act.is_empty() and s.week > Cipher.act_deadline(s, content):
		_add_risk(ctx, "moscow_pressure", mp.per_week_overdue, "act_overdue")
	elif not act.is_empty() and s.week - act.weeks.from + 1 > int(mp.grace_weeks):
		_add_risk(ctx, "moscow_pressure", mp.per_week_without_goal, "no_progress")

	_agents_night(ctx)
	if not s.week_field_activity:
		_add_risk(ctx, "sog_heat", b.sog_heat.quiet_week, "quiet_week")

	for pair in [["sog_heat", "persona_non_grata"], ["moscow_pressure", "recalled"], ["mole_hunt", "mole_arrested"]]:
		if s.risks[pair[0]] >= 100:
			_end(ctx, pair[1])
			return

	if s.goal_reached:
		var nxt := next_act_def(s, content)
		if nxt.is_empty():
			_end(ctx, "campaign_complete")
			return
		s.act = nxt.act
		s.week = maxi(s.week + 1, nxt.weeks.from)  # сюжетный скачок во времени между актами
		s.goal_reached = false
	else:
		s.week += 1
		if s.week > 30:
			_end(ctx, "recalled")
			return
	_start_morning(ctx)


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
			and op.requires_targets_unlocked.all(func(t): return s.targets.has(t) and s.targets[t].unlocked))


## Есть ли хвост на маршруте. Вовремя свернув на бытовую легенду, игрок «спасает операцию»:
## повторный выход после отказа проходит чисто (GDD, Блок 3).
static func tail_present(s: Dictionary, op: Dictionary) -> bool:
	return op.sdr.surveillance_present and s.op_results.get(op.op_id) != "aborted"


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
			unix += (week - int(a.weeks.from)) * 7 * 86400
			var d := Time.get_datetime_dict_from_unix_time(unix)
			return {"year": d.year, "month": d.month, "day": d.day}
	return {}


static func is_ironman(s: Dictionary) -> bool:
	return s.flags.has(IRONMAN_FLAG)
