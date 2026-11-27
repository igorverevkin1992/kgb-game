class_name H
## Общие помощники тестов.

## Правильный проверочный маршрут: три бытовые точки в трёх разных районах внутри зоны.
const GOOD_ROUTE := ["site_peoples_drug_connecticut", "site_georgetown_post_office", "site_lee_highway_cleaners"]
const NEXT := {"type": "advance_phase"}


static func content() -> Dictionary:
	return ContentLoader.game_content()


## Свежая копия файлов контента, которую тест может портить.
static func entries() -> Array:
	var r := ContentLoader.read_dir()
	return r.entries.duplicate(true)


static func file(entries: Array, path: String) -> Variant:
	for e in entries:
		if e.path == path:
			return e.data
	push_error("нет файла " + path)
	return null


static func clue(entries: Array, id: String) -> Dictionary:
	for e in entries:
		if String(e.path).begins_with("clues/"):
			for c in e.data:
				if c.clue_id == id:
					return c
	push_error("нет улики " + id)
	return {}


static func errors(entries: Array) -> Array:
	return ContentLoader.validate(entries).errors


static func report(r: String) -> Dictionary:
	return {"type": "submit_report", "report": r}


static func quiet_week(r := "truth") -> Array:
	return [NEXT, NEXT, NEXT, report(r)]


static func plan(op_id: String, route: Array = GOOD_ROUTE) -> Dictionary:
	return {"type": "plan_op", "op_id": op_id, "route": route}


## Транш агенту: по умолчанию — всё обещанное, наличными, одной частью.
static func pay(target_id: String, amount := -1, instrument := "cash", parts := 1) -> Dictionary:
	var a := amount if amount >= 0 else Finance.promised(content(), target_id)
	return {"type": "pay_agent", "target_id": target_id, "amount": a, "instrument": instrument, "parts": parts}


static func resolve(op_id: String, decision := "continue") -> Dictionary:
	return {"type": "resolve_op", "op_id": op_id, "decision": decision}


## Применяет действия по очереди. Отклонённое действие — ошибка в t.failures и остановка.
## collect: после каждого действия снимать улики-фрагменты из пришедших документов
## (как внимательный игрок), чтобы старые сценарии не зависели от доски.
static func play(t: TestCase, state: Dictionary, actions: Array, collect := true) -> Dictionary:
	var s := state
	var events: Array = []
	if collect:
		s = _collect(s, events)
	for a in actions:
		if a.type == "submit_report":
			s = auto_decide(s)
		var r := Campaign.dispatch(s, content(), a)
		if r.error != "":
			t.failures.append("действие %s отклонено: %s" % [JSON.stringify(a), r.error])
			break
		s = r.state
		events.append_array(r.events)
		if collect:
			s = _collect(s, events)
	return {"state": s, "events": events}


static func _collect(s: Dictionary, events: Array) -> Dictionary:
	if s.ending != null:
		return s
	for cable_id in s.delivered_cables:
		for clue in Campaign.untaken_chunks(s, content(), cable_id):
			var r := Campaign.dispatch(s, content(), {"type": "take_clue", "clue_id": clue.clue_id})
			s = r.state
			events.append_array(r.events)
	return s


## Приколоть все найденные улики к досье цели и утвердить верное заключение.
static func approve(t: TestCase, s: Dictionary, target_id: String) -> Dictionary:
	var c := content()
	var target := Campaign.target_by_id(c, target_id)
	for clue in c.clues:
		if not s.clues.has(clue.clue_id) or not Campaign.clue_relevant(c, clue, target_id):
			continue
		var axes: Array = clue.reveals.filter(func(r): return r.target_id == target_id).map(func(r): return r.axis)
		if axes.is_empty():
			axes = [""]
		for axis in axes:
			var r := Campaign.dispatch(s, c, {"type": "pin_clue", "clue_id": clue.clue_id, "target_id": target_id, "axis": axis})
			if r.error == "":
				s = r.state
	var res := Campaign.dispatch(s, c, {"type": "submit_analysis", "target_id": target_id,
		"axis": target.analysis.leading_axis, "access": target.analysis.correct_access, "channel": target.approach.flag_mode})
	if res.error != "":
		t.failures.append("заключение по %s отклонено: %s" % [target_id, res.error])
		return s
	return res.state


static func fresh() -> Dictionary:
	return Campaign.new_campaign(content()).state


static func weeks(n: int, actions_per_week: Array) -> Array:
	var out: Array = []
	for i in n:
		out.append_array(actions_per_week)
	return out


## Начало третьей фазы (неделя 17, утро): агенты из списка уже завербованы и лояльны,
## решения второй фазы приняты. Для тестов и сценариев интерфейса.
static func act3_state(agents: Array = []) -> Dictionary:
	var c := content()
	var s := fresh()
	for id in agents:
		s.targets[id].unlocked = true
		s.targets[id].recruited = true
		s.agents[id] = Finance.new_agent(s, c, id)
		s.agents[id].loyalty = 70
		s.agents[id].promise_kept = true
	for d in c.decisions:
		if int(d.act) < 3:
			s.decisions[d.decision_id] = d.options[0].option_id
	s.act = 2
	s.week = 16
	s.phase = "night"
	s.goal_reached = true
	return Campaign.dispatch(s, c, report("truth")).state


## Прогон действий без TestCase (для сценариев интерфейса): ошибки печатаются.
static func run(state: Dictionary, actions: Array) -> Dictionary:
	var s := _collect(state, [])
	for a in actions:
		if a.type == "submit_report":
			s = auto_decide(s)
		var r := Campaign.dispatch(s, content(), a)
		if r.error != "":
			push_error("действие %s отклонено: %s" % [JSON.stringify(a), r.error])
			return s
		s = _collect(r.state, [])
	return s


## Начало четвёртой фазы (неделя 31, утро): «Кронос» завербован и лоялен, «Окно арестов» открыто.
static func act4_state(agents: Array = ["tar_caldwell_arthur"], flags: Array = []) -> Dictionary:
	var c := content()
	var s := act3_state(agents)
	s.act = 3
	s.week = 30
	s.phase = "night"
	s.goal_reached = true
	for f in flags:
		s.flags.append(f)
	return Campaign.dispatch(s, c, report("truth")).state



## Решения «для атмосферы», которые старые сценарии не проверяют: перед ночным докладом
## принимаются первым вариантом, чтобы не блокировать неделю. Решения второй фазы
## (их проверяют тесты) сюда не входят.
const AUTO_DECISIONS := ["dec_a1_journalist", "dec_a3_wedding", "dec_a4_draconian", "dec_a4_rome"]


static func auto_decide(s: Dictionary) -> Dictionary:
	for d in Decisions.pending(s, content()):
		if AUTO_DECISIONS.has(d.decision_id):
			var r := Campaign.dispatch(s, content(), {"type": "decide", "decision_id": d.decision_id, "option_id": d.options[0].option_id})
			if r.error == "":
				s = r.state
	return s
