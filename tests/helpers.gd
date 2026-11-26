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
static func play(t: TestCase, state: Dictionary, actions: Array) -> Dictionary:
	var s := state
	var events: Array = []
	for a in actions:
		var r := Campaign.dispatch(s, content(), a)
		if r.error != "":
			t.failures.append("действие %s отклонено: %s" % [JSON.stringify(a), r.error])
			break
		s = r.state
		events.append_array(r.events)
	return {"state": s, "events": events}


static func fresh() -> Dictionary:
	return Campaign.new_campaign(content()).state


static func weeks(n: int, actions_per_week: Array) -> Array:
	var out: Array = []
	for i in n:
		out.append_array(actions_per_week)
	return out
