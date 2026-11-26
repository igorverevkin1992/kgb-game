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
##   {type: "submit_report", report: "truth"|"embellished"|"silence"}

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
		return _reject(state, "Кампания окончена")
	var s: Dictionary = state.duplicate(true)
	var ctx := _ctx(s, content)
	var phase_ru: String = PHASE_RU[s.phase]
	match action.type:
		"advance_phase":
			if not NEXT_PHASE.has(s.phase):
				return _reject(state, "Ночью неделя завершается донесением в Центр")
			if s.phase == "evening" and not s.planned_ops.is_empty():
				return _reject(state, "Не разыграны операции: %s" % ", ".join(s.planned_ops.map(func(id): return _op_title(content, id))))
			_set_phase(ctx, NEXT_PHASE[s.phase])

		"read_cable":
			if not s.delivered_cables.has(action.cable_id):
				return _reject(state, "Этот документ ещё не поступал")
			if not s.read_cables.has(action.cable_id):
				s.read_cables.append(action.cable_id)

		"plan_op":
			if s.phase != "day":
				return _reject(state, "Операции планируют днём, а сейчас %s" % phase_ru)
			if not available_ops(s, content).any(func(o): return o.op_id == action.op_id):
				return _reject(state, "Операция «%s» сейчас недоступна" % _op_title(content, action.op_id))
			if s.planned_ops.size() >= int(content.balance.ops.per_week):
				return _reject(state, "На неделю можно запланировать не больше %d операций" % content.balance.ops.per_week)
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
				return _reject(state, "Отменить операцию можно только днём")
			if not s.planned_ops.has(action.op_id):
				return _reject(state, "Эта операция не запланирована")
			s.planned_ops = Util.without(s.planned_ops, action.op_id)
			s.routes.erase(action.op_id)
			_emit(ctx, {"type": "op_cancelled", "op_id": action.op_id})

		"resolve_op":
			if s.phase != "evening":
				return _reject(state, "Операции проводятся вечером, а сейчас %s" % phase_ru)
			if not s.planned_ops.has(action.op_id):
				return _reject(state, "Эта операция не запланирована")
			_resolve_op(ctx, op_by_id(content, action.op_id), action.decision)

		"recruitment":
			if s.phase != "evening":
				return _reject(state, "Вербовочные беседы проводятся вечером, а сейчас %s" % phase_ru)
			var target := target_by_id(content, action.target_id)
			if target.is_empty() or not s.targets.has(action.target_id):
				return _reject(state, "Такой цели нет")
			var ts: Dictionary = s.targets[action.target_id]
			if ts.recruited or ts.lost:
				return _reject(state, "С этой целью работа уже закончена")
			if not ts.unlocked:
				return _reject(state, "Цель ещё не установлена: не хватает улик")
			match action.result:
				"success":
					var missing: Array = target.approach.key_axes.filter(func(a): return not ts.discovered_axes.has(a))
					if not missing.is_empty():
						return _reject(state, "Не вскрыты ведущие мотивы: %s" % ", ".join(missing.map(func(a): return AXIS_NAME_RU[a])))
					ts.recruited = true
					_emit(ctx, {"type": "target_recruited", "target_id": target.target_id})
					var def := current_act_def(s, content)
					if not def.is_empty() and def.goal.recruit_any_of.has(target.target_id):
						s.goal_reached = true
				"failed":
					ts.lost = true
					s.week_failures += 1
					_emit(ctx, {"type": "target_lost", "target_id": target.target_id})
					_add_risk(ctx, "sog_heat", content.balance.sog_heat.failed_recruitment, "failed_recruitment")
				_:
					_emit(ctx, {"type": "recruitment_postponed", "target_id": target.target_id})

		"submit_report":
			if s.phase != "night":
				return _reject(state, "Донесение в Центр отправляют ночью, а сейчас %s" % phase_ru)
			_end_week(ctx, action.report)

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
			for clue in content.clues:
				if clue.source.channel == "document" and clue.source.from == cable.cable_id:
					_give_clue(ctx, clue.clue_id)
	# Каждый завербованный агент приносит по одному донесению в неделю.
	for t in content.targets:
		var ts = s.targets.get(t.target_id)
		if ts == null or not ts.recruited:
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


## Ночь: донесение, сверка лжи, пересчёт рисков, концовки и переход к следующей неделе.
static func _end_week(ctx: Dictionary, report: String) -> void:
	var s: Dictionary = ctx.s
	var content: Dictionary = ctx.content
	var b: Dictionary = content.balance
	var mp: Dictionary = b.moscow_pressure
	var ct: Dictionary = b.centre_trust
	var failures: bool = s.week_failures > 0
	_emit(ctx, {"type": "report_submitted", "report": report})
	match report:
		"truth":
			if failures:
				_add_trust(ctx, ct.report_truth_with_failures, "report_truth_with_failures")
				_add_risk(ctx, "moscow_pressure", mp.report_truth_with_failures, "report_truth_with_failures")
			else:
				_add_trust(ctx, ct.report_truth, "report_truth")
		"embellished":
			_add_trust(ctx, ct.report_embellished, "report_embellished")
			_add_risk(ctx, "moscow_pressure", mp.report_embellished, "report_embellished")
			s.lies.append({"week": s.week, "kind": "embellished"})
		_:
			_add_trust(ctx, ct.report_silence, "report_silence")
			if failures:
				s.lies.append({"week": s.week, "kind": "silence"})

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
	elif not act.is_empty() and s.week > act.weeks.to:
		_add_risk(ctx, "moscow_pressure", mp.per_week_overdue, "act_overdue")
	elif not act.is_empty() and s.week - act.weeks.from + 1 > int(mp.grace_weeks):
		_add_risk(ctx, "moscow_pressure", mp.per_week_without_goal, "no_progress")

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


## Что игрок знает о мотиве цели: unknown → hypothesis (1–2 улики) → confirmed (3+).
static func axis_knowledge(s: Dictionary, content: Dictionary, target_id: String, axis: String) -> String:
	var n := 0
	for c in content.clues:
		if s.clues.has(c.clue_id) and c.reveals.any(func(r): return r.target_id == target_id and r.axis == axis):
			n += 1
	if n == 0:
		return "unknown"
	return "confirmed" if n >= ContentRules.THREE_CLUES else "hypothesis"


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
