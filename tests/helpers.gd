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
