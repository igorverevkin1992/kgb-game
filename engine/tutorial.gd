class_name Tutorial
## Обучение: записки наставника (заместителя резидента) — шаги из content/tutorial/ — и памятки
## по модулям (content/help/). Шаг закрывается сам, когда в игре выполнено его условие (done),
## поэтому игрок, начавший раньше или ушедший вперёд, пропускает пройденное. Условие "ack" —
## шаг-подсказка, его закрывает кнопка «Понятно». Прогресс подтверждений хранится в настройках
## (не в сохранении): обучение — про игрока, а не про кампанию.

const CONDITIONS := ["opened_inbox", "took_clue", "verified_directive", "reached_day", "planned_op",
	"reached_evening", "resolved_op", "pinned_clue", "sent_report", "approved_analysis",
	"met_candidate", "paid_agent", "ack"]


## Выполнено ли условие шага: s — состояние кампании, view — открытый модуль.
static func done(cond: String, s: Dictionary, view: String) -> bool:
	var later_week := int(s.week) > 1 or int(s.act) > 1
	match cond:
		"opened_inbox":
			return view == "inbox" or not s.read_cables.is_empty() or later_week
		"took_clue":
			return not s.clues.is_empty() or later_week
		"verified_directive":
			return not s.verified.is_empty() or later_week
		"reached_day":
			return s.phase != "morning" or later_week
		"planned_op":
			return not s.planned_ops.is_empty() or not s.op_results.is_empty() or later_week
		"reached_evening":
			return s.phase in ["evening", "night"] or later_week
		"resolved_op":
			return not s.op_results.is_empty() or int(s.week) > 2 or int(s.act) > 1
		"pinned_clue":
			return not s.pinned.is_empty() or int(s.act) > 1
		"sent_report":
			return later_week
		"approved_analysis":
			return s.analysis.values().any(func(a): return a.get("approved", false)) or int(s.act) > 1
		"met_candidate":
			return not s.tapes.is_empty() or int(s.act) > 1
		"paid_agent":
			return not s.payments.is_empty() or s.agents.values().any(func(a): return a.get("promise_kept", false)) or int(s.act) > 1
	return false


## Текущий шаг: первый не выполненный и не подтверждённый; {} — обучение пройдено.
static func current(content: Dictionary, s: Dictionary, view: String, acked: Array) -> Dictionary:
	if s.is_empty() or s.get("ending") != null:
		return {}
	for st in content.get("tutorial", []):
		if acked.has(st.step_id):
			continue
		if not done(st.done, s, view):
			return st
	return {}


## Номер шага и всего шагов — «3 из 10».
static func progress(content: Dictionary, step: Dictionary) -> Array:
	var all: Array = content.get("tutorial", [])
	return [all.find(step) + 1, all.size()]


static func help_for(content: Dictionary, view: String) -> Dictionary:
	for h in content.get("help", []):
		if h.view == view:
			return h
	return {}
