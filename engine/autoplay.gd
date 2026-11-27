class_name Autoplay
## Балансный прогон: автоигрок проходит всю кампанию через настоящий движок (Campaign.dispatch),
## зная контент (верные заключения, хвосты, лучшие ответы на встречах и полиграфе).
## Стратегии:
##   careful — уходит от хвоста, сверяет пакет по всем каналам, реализует «Список» с флагом
##             «Ховард» и естественными провалами, не больше двух «чистых» арестов за ночь,
##             готовит полиграф полностью, тормозит траты «Кроноса», платит без формы 4789;
##   hasty   — не уходит от хвоста, принимает пакет сразу, арестовывает всех в первую ночь,
##             платит наличными одной суммой, к полиграфу не готовится;
##   rush    — осторожно до «Списка», а в финале спешит: пакет без проверки, все аресты
##             в первую ночь, полиграф без подготовки (исторический вектор: «Центр продавил»).
## Результат: {ending, state, weeks: {act: [from, to]}, snapshots: [{act, week, risks, trust, fund}], errors}.

const STRATEGIES := ["careful", "rush", "hasty"]
const MAX_WEEKS := 80


static func run(content: Dictionary, strategy := "careful") -> Dictionary:
	var ctx := {"c": content, "st": strategy, "s": Campaign.new_campaign(content).state, "errors": [], "snapshots": [], "weeks": {}}
	var guard := 0
	while ctx.s.ending == null and guard < MAX_WEEKS:
		guard += 1
		_week(ctx)
	return {"ending": ctx.s.ending, "state": ctx.s, "weeks": ctx.weeks, "snapshots": ctx.snapshots, "errors": ctx.errors}


static func _do(ctx: Dictionary, a: Dictionary) -> bool:
	var r := Campaign.dispatch(ctx.s, ctx.c, a)
	if r.error != "":
		return false
	ctx.s = r.state
	return true


## Осторожность на маршрутах, в деньгах и встречах (у rush — тоже).
static func _careful(ctx: Dictionary) -> bool:
	return ctx.st != "hasty"


## Осторожность в финале: пакет, «Окно арестов», полиграф.
static func _careful_finale(ctx: Dictionary) -> bool:
	return ctx.st == "careful"


# ——— Неделя ———

static func _week(ctx: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var act := int(s.act)
	if not ctx.weeks.has(act):
		ctx.weeks[act] = [int(s.week), int(s.week)]
	ctx.weeks[act][1] = int(s.week)
	_desk(ctx)
	_do(ctx, {"type": "advance_phase"})  # день
	_desk(ctx)
	_plan_ops(ctx)
	_pay(ctx)
	_do(ctx, {"type": "advance_phase"})  # вечер
	_resolve_ops(ctx)
	_meetings(ctx)
	_desk(ctx)
	_pay(ctx)
	_do(ctx, {"type": "advance_phase"})  # ночь
	_desk(ctx)  # решения, пришедшие вечером
	var req := ""
	if Dangle.centre_waiting(ctx.s) and _careful_finale(ctx):
		req = String(Dangle.config(ctx.c).request_id)
	elif not Cipher.available_requests(ctx.s, ctx.c).is_empty():
		for r in Cipher.available_requests(ctx.s, ctx.c):
			if int(r.granted.get("fund_usd", 0)) > 0 and Cipher.would_grant(ctx.s, r):
				req = r.request_id
				break
	ctx.snapshots.append({"act": int(ctx.s.act), "week": int(ctx.s.week), "risks": ctx.s.risks.duplicate(), "trust": int(ctx.s.centre_trust), "fund": int(ctx.s.fund_usd)})
	if not _do(ctx, {"type": "submit_report", "report": "truth", "request": req}):
		if not _do(ctx, {"type": "submit_report", "report": "truth"}):
			ctx.errors.append("неделя %d: доклад не принят" % ctx.s.week)
			ctx.s.ending = "recalled"


## Всё, что делают за столом в любую фазу: почта, улики, директивы, решения, доска,
## пакет, «Окно арестов», полиграф, траты агентов.
static func _desk(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.c
	for id in Campaign.unread_cables(ctx.s):
		_do(ctx, {"type": "read_cable", "cable_id": id})
	for cl in c.clues:
		if not ctx.s.clues.has(cl.clue_id) and ["document", "meeting"].has(cl.source.channel):
			_do(ctx, {"type": "take_clue", "clue_id": cl.clue_id})
	for cab in Cipher.pending_directives(ctx.s, c):
		_do(ctx, {"type": "verify_cable", "cable_id": cab.cable_id, "decision": "query" if cab.forged and _careful(ctx) else "accept"})
	for d in Decisions.pending(ctx.s, c):
		_do(ctx, {"type": "decide", "decision_id": d.decision_id, "option_id": _decision_choice(ctx, d)})
	for t in c.targets:
		_board(ctx, t)
	_package(ctx)
	_list(ctx)
	_polygraph(ctx)
	if _careful(ctx):
		for id in Finance.agents(ctx.s):
			if int(ctx.s.agents[id].lifestyle) >= int(c.balance.thresholds.warning):
				_do(ctx, {"type": "restrain_agent", "target_id": id})


static func _decision_choice(ctx: Dictionary, d: Dictionary) -> String:
	if _careful(ctx):
		var pref := {"dec_a3_defector": "calm", "dec_a2_monopoly": "game"}
		if pref.has(d.decision_id) and not Decisions.option(d, pref[d.decision_id]).is_empty():
			return pref[d.decision_id]
	return d.options[0].option_id


## Доска мотивов: приколоть всё по делу и утвердить верное заключение, когда хватает сведений.
static func _board(ctx: Dictionary, t: Dictionary) -> void:
	var s: Dictionary = ctx.s
	var c: Dictionary = ctx.c
	var ts = s.targets.get(t.target_id)
	if ts == null or not ts.unlocked or ts.recruited or ts.lost or Campaign.analysis_state(s, t.target_id).approved:
		return
	for cl in c.clues:
		if not s.clues.has(cl.clue_id) or not Campaign.clue_relevant(c, cl, t.target_id):
			continue
		var axes: Array = cl.reveals.filter(func(r): return r.target_id == t.target_id).map(func(r): return r.axis)
		if axes.is_empty():
			axes = [""]
		for axis in axes:
			_do(ctx, {"type": "pin_clue", "clue_id": cl.clue_id, "target_id": t.target_id, "axis": axis})
	if not t.approach.key_axes.all(func(a): return ctx.s.targets[t.target_id].discovered_axes.has(a)):
		return
	_do(ctx, {"type": "submit_analysis", "target_id": t.target_id, "axis": t.analysis.leading_axis,
		"access": t.analysis.correct_access, "channel": t.approach.flag_mode})


# ——— Выходы в город ———

## Правильный проверочный маршрут: три бытовые точки в разных районах внутри зоны.
static func route(c: Dictionary) -> Array:
	var used := {}
	var out: Array = []
	for st in c.map.sites:
		if st.role == "stop" and MapGeo.within_zone(c, st) and not used.has(st.district):
			used[st.district] = true
			out.append(st.site_id)
			if out.size() == 3:
				break
	return out


static func _plan_ops(ctx: Dictionary) -> void:
	var ops: Array = Campaign.available_ops(ctx.s, ctx.c)
	# Сначала ключевые и связанные с кандидатами, потом разведка, которая ещё что-то даст.
	ops.sort_custom(func(a, b): return _op_priority(ctx, a) > _op_priority(ctx, b))
	for op in ops:
		if _op_priority(ctx, op) <= 0:
			continue
		_do(ctx, {"type": "plan_op", "op_id": op.op_id, "route": route(ctx.c)})


static func _op_priority(ctx: Dictionary, op: Dictionary) -> int:
	var p := 0
	if op.get("essential", false) or op.get("contact_target_id", "") != "":
		p += 10
	if ctx.c.clues.any(func(cl): return cl.source.channel == "field" and cl.source.from == op.op_id and not ctx.s.clues.has(cl.clue_id)):
		p += 5
	if Dangle.package_ops(ctx.c).has(op.op_id) and ctx.s.get("package") != null and not ctx.s.package.rejected:
		p = 0
	return p


static func _resolve_ops(ctx: Dictionary) -> void:
	for id in ctx.s.planned_ops.duplicate():
		var op := Campaign.op_by_id(ctx.c, id)
		var tail := Campaign.tail_present(ctx.s, op, ctx.c)
		_do(ctx, {"type": "resolve_op", "op_id": id, "decision": "abort" if tail and _careful(ctx) else "continue"})


# ——— Встречи ———

static func _meetings(ctx: Dictionary) -> void:
	for t in ctx.c.targets:
		if Meeting.meet_error(ctx.s, ctx.c, t.target_id) != "":
			continue
		_do(ctx, {"type": "start_meeting", "target_id": t.target_id})
		var m: Dictionary = ctx.s.meeting
		var d := Meeting.dialog_by_id(ctx.c, m.dialog_id)
		var trumps: Array = Meeting.available_trumps(ctx.s, ctx.c, m)
		var path := meeting_path(d, int(m.rapport), int(m.anxiety), trumps)
		if path.is_empty() and not Meeting.can_offer(d, m):
			_do(ctx, {"type": "meeting_abort"})
			continue
		for mv in path:
			if ctx.s.meeting == null:
				break
			_do(ctx, {"type": "meeting_turn", "tone": mv[0], "clue_id": mv[1]})
		if ctx.s.meeting != null:
			if not _do(ctx, {"type": "meeting_offer"}):
				_do(ctx, {"type": "meeting_abort"})


## Ходы до порога предложения без срыва ([[tone, clue_id]], пусто — пути нет или уже можно).
static func meeting_path(d: Dictionary, rapport: int, anxiety: int, trumps: Array) -> Array:
	var out: Array = []
	_mp(d, trumps, 0, rapport, anxiety, 0, {}, [], out)
	return out


static func _mp(d: Dictionary, trumps: Array, beat: int, r: int, a: int, used: int, memo: Dictionary, path: Array, out: Array) -> bool:
	if a >= Meeting.max_anxiety(d):
		return false
	if r >= int(d.offer_rapport):
		out.append_array(path)
		return true
	if beat >= d.beats.size():
		return false
	var key := "%d:%d:%d:%d" % [beat, r, a, used]
	if memo.has(key):
		return false
	memo[key] = true
	for tone in Meeting.TONES:
		var t: Dictionary = d.beats[beat].tones[tone]
		for i in range(-1, trumps.size()):
			if i >= 0 and used & (1 << i):
				continue
			var dr := int(t.rapport)
			var da := int(t.anxiety)
			var clue := ""
			var nu := used
			if i >= 0:
				var tr: Dictionary = trumps[i]
				var fx: Dictionary = tr.ready if r >= int(tr.min_rapport) else tr.early
				dr += int(fx.rapport)
				da += int(fx.anxiety)
				clue = tr.clue_id
				nu = used | (1 << i)
			if _mp(d, trumps, beat + 1, Util.clamp100(r + dr), Util.clamp100(a + da), nu, memo, path + [[tone, clue]], out):
				return true
	return false


# ——— Деньги ———

static func _pay(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.c
	var b: Dictionary = c.balance.finance
	for id in Finance.agents(ctx.s):
		var left := Finance.promise_left(ctx.s, c, id)
		if left <= 0 or left > int(ctx.s.fund_usd):
			continue
		var inst := "cash"
		var parts := 1
		if _careful(ctx):
			if Finance.legend_available(ctx.s, c):
				inst = "legend"
			elif int(ctx.s.agents[id].loyalty) >= int(b.escrow_min_loyalty):
				inst = "escrow"
			elif not Finance.mlca_in_force(ctx.s, c):
				parts = mini(int(b.max_parts), int(ceil(left / float(b.ctr_threshold_usd))))
		_do(ctx, {"type": "pay_agent", "target_id": id, "amount": left, "instrument": inst, "parts": parts})


# ——— Пробный пакет, «Окно арестов», полиграф ———

static func _package(ctx: Dictionary) -> void:
	if not Dangle.open(ctx.s):
		return
	if not _careful_finale(ctx):
		_do(ctx, {"type": "accept_package"})
		return
	if Dangle.archive_available(ctx.s, ctx.c) and ctx.s.package.archive == "":
		_do(ctx, {"type": "check_package", "channel": "archive"})
	var ch := Dangle.checks(ctx.s, ctx.c)
	if ch.values().has("mismatch") and Dangle.can_reject(ctx.s, ctx.c):
		_do(ctx, {"type": "reject_package"})
	elif ch.centre != "pending" or ch.values().has("mismatch"):
		_do(ctx, {"type": "accept_package"})


static func _list(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.c
	if not ArrestWindow.open(ctx.s, c) or ctx.s.phase == "night":
		return
	var after := int(c.balance.list.cascade_after)
	for card in c.list:
		if ArrestWindow.status(ctx.s, card.card_id) != "pending":
			continue
		if not _careful_finale(ctx):
			_do(ctx, {"type": "list_action", "card_id": card.card_id, "action": "arrest"})
			continue
		var suspicious: bool = ctx.s.flags.has(Dangle.DANGLE_FLAG)
		if card.howard and not suspicious:
			_do(ctx, {"type": "list_action", "card_id": card.card_id, "action": "arrest"})
		elif card.natural != "":
			_do(ctx, {"type": "list_action", "card_id": card.card_id, "action": "natural"})
		elif card.game and (card.damage != "critical" or suspicious):
			_do(ctx, {"type": "list_action", "card_id": card.card_id, "action": "game"})
		elif not suspicious and ArrestWindow.plain_tonight(ctx.s, c) < after:
			_do(ctx, {"type": "list_action", "card_id": card.card_id, "action": "arrest"})


static func _polygraph(ctx: Dictionary) -> void:
	var p = ctx.s.get("polygraph")
	if p == null or p.result != "":
		return
	var e := Polygraph.by_id(ctx.c, p.exam_id)
	if _careful_finale(ctx):
		var order: Array = []
		for kind in ["sleep", "legend", "strategy", "sedatives"]:
			for o in e.prep_options:
				if o.kind == kind and (kind != "strategy" or o.archetype == ("chummy_veteran" if not p.source else e.examiner_profile.archetype)):
					order.append(o.prep_id)
		for id in order:
			_do(ctx, {"type": "polygraph_prep", "prep_id": id})
	if int(ctx.s.week) < int(e.week) or ctx.s.phase == "night":
		return
	if not _do(ctx, {"type": "polygraph_start", "rehearsal": false}):
		return
	var path := polygraph_path(ctx.c, ctx.s) if _careful_finale(ctx) else []
	for mv in path:
		_do(ctx, mv)
	# Пути к «pass» нет — первые ответы, первые объяснения.
	var guard := 0
	while ctx.s.polygraph.result == "" and guard < 40:
		guard += 1
		if ctx.s.polygraph.exam.pending:
			for o in e.rationalizations:
				if _do(ctx, {"type": "polygraph_rationalize", "option_id": o.option_id}):
					break
		else:
			var ch: Array = Polygraph.choices(ctx.c, ctx.s)
			if ch.is_empty() or not _do(ctx, {"type": "polygraph_answer", "choice_id": ch[0].choice_id}):
				break


## Действия до итога «pass» на идущем экзамене (пусто — такого пути нет).
static func polygraph_path(c: Dictionary, s: Dictionary) -> Array:
	var out: Array = []
	_pp(c, {"polygraph": s.polygraph.duplicate(true), "agents": s.agents}, [], out)
	return out


static func _pp(c: Dictionary, s: Dictionary, path: Array, out: Array) -> bool:
	if Polygraph.finished(c, s):
		if Polygraph.verdict(c, s.polygraph.exam, s.polygraph.exam_id) == "pass":
			out.append_array(path)
			return true
		return false
	var e := Polygraph.by_id(c, s.polygraph.exam_id)
	if s.polygraph.exam.pending:
		for o in e.rationalizations:
			if s.polygraph.exam.used.has(o.option_id):
				continue
			var n := s.duplicate(true)
			n.polygraph.exam = Polygraph.rationalize(s, o)
			if _pp(c, n, path + [{"type": "polygraph_rationalize", "option_id": o.option_id}], out):
				return true
		return false
	for ch in Polygraph.choices(c, s):
		var n := s.duplicate(true)
		n.polygraph.exam = Polygraph.answer(c, s, ch)
		if _pp(c, n, path + [{"type": "polygraph_answer", "choice_id": ch.choice_id}], out):
			return true
	return false
