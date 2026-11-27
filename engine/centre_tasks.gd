class_name CentreTasks
## Задания Центра (раз в 2–3 недели): «подготовить характеристику и предложения по дальнейшему
## использованию», «проверить сведения», «доложить порядок». Задание приходит утром, у него срок.
## Ответ — выбор по вопросам: часть вопросов проверяется по делу (мотив агента — по досье,
## устойчивость — по шкале лояльности), часть — по фактам эпохи из документов и памяток.
## Все верно — Доверие Центра растёт; ошибки — давление; срок прошёл — давление и потеря Доверия.
## Предложения (proposal) верных ответов не имеют: у каждого варианта — свои последствия.
## Задание прошлой фазы операции при смене фаз снимается с контроля без штрафа.
##
## state.tasks: {task_id: {status: open|done|partial|failed|withdrawn, due, week, wrong}}

const AXES := ["money", "ideology", "compromise", "ego"]


static func by_id(content: Dictionary, id: String) -> Dictionary:
	for t in content.get("tasks", []):
		if t.task_id == id:
			return t
	return {}


## Пришло ли задание: фаза, неделя, нужный агент завербован, флаги поставлены.
static func due_now(s: Dictionary, t: Dictionary) -> bool:
	if int(t.act) != int(s.act) or int(t.week) > int(s.week):
		return false
	var ag: String = t.get("requires_recruited", "")
	if ag != "" and (not s.targets.has(ag) or not s.targets[ag].recruited or s.targets[ag].lost):
		return false
	return t.get("requires_flags", []).all(func(f): return s.flags.has(f))


static func open_tasks(s: Dictionary, content: Dictionary) -> Array:
	return content.get("tasks", []).filter(func(t): return s.get("tasks", {}).has(t.task_id) and s.tasks[t.task_id].status == "open")


## Варианты вопроса: свои из контента или собранные по делу (auto).
static func options(s: Dictionary, content: Dictionary, q: Dictionary) -> Array:
	var auto: String = q.get("auto", "")
	if auto.begins_with("axis:"):
		return AXES.map(func(a): return {"id": a, "label": {"ru": Campaign.AXIS_NAME_RU[a].capitalize()}})
	if auto.begins_with("stability:"):
		return [{"id": "stable", "label": {"ru": "Устойчив: работает добровольно, лоялен"}},
			{"id": "unstable", "label": {"ru": "Неустойчив: лояльность низкая или работает по принуждению"}}]
	return q.options


## Верный ответ на вопрос ("" — верного нет: предложение, решает резидент).
static func correct(s: Dictionary, content: Dictionary, q: Dictionary) -> String:
	var auto: String = q.get("auto", "")
	if auto.begins_with("axis:"):
		var t := Campaign.target_by_id(content, auto.trim_prefix("axis:"))
		return String(t.get("analysis", {}).get("leading_axis", ""))
	if auto.begins_with("stability:"):
		var ag = s.agents.get(auto.trim_prefix("stability:"))
		if ag == null:
			return "unstable"
		var ok: bool = not ag.get("coerced", false) and int(ag.loyalty) >= int(content.balance.finance.reports_min_loyalty)
		return "stable" if ok else "unstable"
	for o in q.options:
		if o.get("correct", false):
			return o.id
	return ""


## Почему нельзя ответить ("" — можно): задание открыто, ответы на все вопросы, документы прочитаны.
static func answer_error(s: Dictionary, content: Dictionary, task_id: String, answers: Dictionary) -> String:
	var t := by_id(content, task_id)
	if t.is_empty():
		return "Такого задания нет"
	if not s.get("tasks", {}).has(task_id) or s.tasks[task_id].status != "open":
		return "Задание уже закрыто"
	for id in t.get("needs_cables", []):
		if not s.read_cables.has(id):
			return "Сначала изучите материалы, на которые ссылается Центр"
	for q in t.questions:
		var a: String = answers.get(q.q_id, "")
		if not options(s, content, q).any(func(o): return o.id == a):
			return "Ответьте на все пункты задания"
	return ""


## Последствия ответа (без изменения состояния) — для предпросмотра и для движка:
## {wrong, trust, pressure, effects: [словари эффектов выбранных предложений]}.
static func evaluate(s: Dictionary, content: Dictionary, t: Dictionary, answers: Dictionary) -> Dictionary:
	var b: Dictionary = content.balance.tasks
	var wrong := 0
	var effects: Array = []
	for q in t.questions:
		var a: String = answers.get(q.q_id, "")
		var right := correct(s, content, q)
		if right != "" and a != right:
			wrong += 1
		for o in q.get("options", []):
			if o.id == a and o.has("effects"):
				effects.append(o.effects)
	var trust: int = int(b.done_trust) if wrong == 0 else -int(b.wrong_trust) * wrong
	return {"wrong": wrong, "trust": trust, "pressure": int(b.wrong_pressure) * wrong, "effects": effects}
