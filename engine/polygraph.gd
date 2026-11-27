class_name Polygraph
## Плановый полиграф ЦРУ для «крота» (четвёртая фаза). Две части:
##  · подготовка — инструктаж «Кроноса»: сон, отказ от седативных, стратегия поведения под
##    экзаменатора, финансовая легенда. Сколько пунктов успеть — зависит от агента в Управлении
##    безопасности ЦРУ (source_agent): с ним дата известна за две недели и виден профиль
##    экзаменатора, без него — за три дня и вслепую;
##  · допрос по методу контрольных вопросов — нейтральные, контрольные и значимые вопросы.
##    Задача — не «обнулить пульс», а держать контраст: на контрольных — заметный пик
##    (limited hangout), на значимых — ниже контрольного. Проскочил пик — нужно объяснение
##    волнения (рационализация). Итог — по формулам pass_formula у значимых вопросов и
##    пределу скепсиса экзаменатора.
## Подготовка задаёт исходные кривые, тактика на допросе — остальное. Репетиция — тот же допрос
## без последствий. Все числа видны игроку.
##
## state.polygraph: {exam_id, notified_week, slots, prep: [prep_id], exam: null|{…}, result, rehearsals}
## exam: {rehearsal, step, rapport, skepticism, control_peak, relevant_peak, stability,
##        finance_stress, pending: bool, used: [option_id], lines: [{q_id, choice_id, peak, spike, kind}]}

const DONE_FLAG := "polygraph_done"
const PASS_FLAG := "polygraph_passed"
const INCONCLUSIVE_FLAG := "polygraph_inconclusive"
const FAIL_FLAG := "polygraph_failed"
## «Кронос» потерян до проверки — пятая фаза идёт по своему варианту.
const ABSENT_FLAG := "kronos_absent"
const RESULTS := ["pass", "inconclusive", "fail", "none"]


static func exam_def(content: Dictionary) -> Dictionary:
	var list: Array = content.get("polygraph", [])
	return list[0] if not list.is_empty() else {}


static func by_id(content: Dictionary, id: String) -> Dictionary:
	for e in content.get("polygraph", []):
		if e.exam_id == id:
			return e
	return {}


static func prep_option(e: Dictionary, prep_id: String) -> Dictionary:
	for p in e.prep_options:
		if p.prep_id == prep_id:
			return p
	return {}


## Источник в Управлении безопасности ЦРУ завербован и лоялен: дата заранее, профиль виден.
static func source_ready(s: Dictionary, content: Dictionary, e: Dictionary) -> bool:
	var ts = s.targets.get(e.source_agent)
	if ts == null or not ts.recruited or ts.lost:
		return false
	return not s.agents.has(e.source_agent) or int(s.agents[e.source_agent].loyalty) >= int(content.balance.finance.reports_min_loyalty)


## Неделя, когда о проверке становится известно.
static func notice_week(s: Dictionary, content: Dictionary, e: Dictionary) -> int:
	return int(e.week) - (int(e.notice.weeks_with_source) if source_ready(s, content, e) else 0)


static func new_state(s: Dictionary, content: Dictionary, e: Dictionary) -> Dictionary:
	var src := source_ready(s, content, e)
	return {"exam_id": e.exam_id, "notified_week": int(s.week), "source": src,
		"slots": int(e.notice.prep_slots_with_source if src else e.notice.prep_slots_without),
		"prep": [], "exam": null, "result": "", "rehearsals": 0}


## Подготовка доступна: пункт ещё не выбран, есть время, для легенды — банковский контур.
static func prep_error(s: Dictionary, content: Dictionary, prep_id: String) -> String:
	var p = s.get("polygraph")
	if p == null or p.result != "":
		return "Проверки на полиграфе сейчас нет"
	var e := by_id(content, p.exam_id)
	var o := prep_option(e, prep_id)
	if o.is_empty():
		return "Такого пункта инструктажа нет"
	if p.prep.has(prep_id):
		return "Этот пункт инструктажа уже проведён"
	if p.prep.size() >= int(p.slots):
		return "Времени на подготовку больше нет"
	if p.exam != null and not p.exam.rehearsal:
		return "Проверка уже идёт"
	if o.kind == "strategy" and p.prep.any(func(id): return prep_option(e, id).kind == "strategy"):
		return "Стратегия поведения уже выбрана"
	if o.kind == "legend" and not Finance.legend_available(s, content):
		return "Финансовой легенды нет: нужен агент с банковским контуром"
	return ""


## Карта предтестового состояния: что дала подготовка.
static func prep_summary(s: Dictionary, content: Dictionary) -> Dictionary:
	var p: Dictionary = s.polygraph
	var e := by_id(content, p.exam_id)
	var out := {"stability": 0, "rapport": 0, "skepticism": 0, "finance_shield": false, "shield_reason": ""}
	for id in p.prep:
		var o := prep_option(e, id)
		out.stability += int(o.stability)
		out.skepticism += int(o.skepticism)
		if o.kind == "strategy":
			out.rapport += int(o.rapport) if o.archetype == e.examiner_profile.archetype else -absi(int(o.rapport)) / 2
		else:
			out.rapport += int(o.rapport)
		if o.kind == "legend":
			out.finance_shield = true
			out.shield_reason = "legend"
	var ag = s.agents.get(e.subject)
	if not out.finance_shield and ag != null and int(ag.lifestyle) < int(content.balance.thresholds.warning):
		out.finance_shield = true
		out.shield_reason = "modest"
	return out


static func start_exam(s: Dictionary, content: Dictionary, rehearsal: bool) -> Dictionary:
	var e := by_id(content, s.polygraph.exam_id)
	var sm := prep_summary(s, content)
	return {"rehearsal": rehearsal, "step": 0,
		"rapport": Util.clamp100(int(e.start.rapport) + sm.rapport),
		"skepticism": Util.clamp100(int(e.start.skepticism) + sm.skepticism),
		"control_peak": 0, "relevant_peak": 0, "stability": sm.stability,
		"finance_stress": 0 if sm.finance_shield else int(e.finance_stress),
		"pending": false, "used": [], "lines": []}


static func question(content: Dictionary, s: Dictionary) -> Dictionary:
	var e := by_id(content, s.polygraph.exam_id)
	var x: Dictionary = s.polygraph.exam
	return e.question_sequence[x.step] if x.step < e.question_sequence.size() else {}


## Варианты ответа на текущий вопрос (некоторые — только после нужной подготовки).
static func choices(content: Dictionary, s: Dictionary) -> Array:
	var q := question(content, s)
	if q.is_empty():
		return []
	return q.choices.filter(func(c): return c.requires_prep == "" or s.polygraph.prep.has(c.requires_prep))


## Пик реакции на значимый вопрос при этом ответе: исходный − устойчивость + стресс денег.
static func relevant_peak(q: Dictionary, x: Dictionary, choice: Dictionary) -> int:
	var peak := int(q.base_peak) - int(x.stability) + int(choice.effects.relevant_peak)
	if q.finance:
		peak += int(x.finance_stress)
	return clampi(peak, 0, 100)


## Ответ: новое состояние экзамена (исходное не меняется).
static func answer(content: Dictionary, s: Dictionary, choice: Dictionary) -> Dictionary:
	var q := question(content, s)
	var x: Dictionary = s.polygraph.exam.duplicate(true)
	var fx: Dictionary = choice.effects
	x.rapport = Util.clamp100(int(x.rapport) + int(fx.rapport))
	x.skepticism = Util.clamp100(int(x.skepticism) + int(fx.skepticism))
	var line := {"q_id": q.q_id, "choice_id": choice.choice_id, "kind": q.category, "peak": 0, "spike": false}
	match q.category:
		"control_comparison":
			line.peak = int(fx.control_peak)
			x.control_peak = maxi(int(x.control_peak), int(fx.control_peak))
		"relevant_critical":
			line.peak = relevant_peak(q, x, choice)
			x.relevant_peak = maxi(int(x.relevant_peak), line.peak)
			line.spike = line.peak > int(x.control_peak)
			x.pending = line.spike
		_:
			line.peak = 10
	x.lines.append(line)
	x.step = int(x.step) + 1
	return x


## Объяснение волнения после пика на значимом вопросе.
static func rationalize(s: Dictionary, option: Dictionary) -> Dictionary:
	var x: Dictionary = s.polygraph.exam.duplicate(true)
	var fx: Dictionary = option.effects
	x.rapport = Util.clamp100(int(x.rapport) + int(fx.rapport))
	x.skepticism = Util.clamp100(int(x.skepticism) + int(fx.skepticism))
	x.relevant_peak = clampi(int(x.relevant_peak) + int(fx.relevant_peak), 0, 100)
	x.used.append(option.option_id)
	x.pending = false
	x.lines.append({"q_id": "", "choice_id": option.option_id, "kind": "rationalization", "peak": 0, "spike": false})
	return x


static func finished(content: Dictionary, s: Dictionary) -> bool:
	var x = s.polygraph.exam
	return x != null and not x.pending and int(x.step) >= by_id(content, s.polygraph.exam_id).question_sequence.size()


## Итог: pass — все формулы значимых вопросов верны и скепсис ниже предела; fail — скепсис
## дошёл до предела; иначе — inconclusive (результат «на грани»).
static func verdict(content: Dictionary, x: Dictionary, exam_id: String) -> String:
	var e := by_id(content, exam_id)
	if int(x.skepticism) >= int(e.examiner_profile.skepticism_fail_limit):
		return "fail"
	for q in e.question_sequence:
		if q.has("pass_formula") and not formula(q.pass_formula, x):
			return "inconclusive"
	return "pass"


## Формула прохождения: переменные экзамена, числа, сравнения, + − и AND / OR.
static func formula(text: String, x: Dictionary) -> bool:
	var ex := Expression.new()
	var names := PackedStringArray(["control_peak", "relevant_peak", "rapport", "skepticism"])
	var src := text.replace(" AND ", " and ").replace(" OR ", " or ")
	if ex.parse(src, names) != OK:
		return false
	var r = ex.execute([int(x.control_peak), int(x.relevant_peak), int(x.rapport), int(x.skepticism)], null, false)
	return not ex.has_execute_failed() and bool(r)


## Кривые самописца для ленты: дыхание, давление и пульс, кожно-гальваническая реакция.
static func curves(x: Dictionary) -> Array:
	var out: Array = []
	for l in x.lines:
		var p := int(l.peak)
		out.append({"breath": clampi(35 + p / 4 + (100 - int(x.rapport)) / 5, 0, 100),
			"pulse": clampi(30 + p * 3 / 5, 0, 100), "gsr": clampi(p, 0, 100), "kind": l.kind, "spike": l.spike})
	return out


# ——— Проверка контента: можно ли пройти проверку ———

## Есть ли путь ответов и объяснений к итогу «pass» при этой подготовке.
static func winnable(content: Dictionary, e: Dictionary, prep: Array, lifestyle := 0) -> bool:
	var s := {"polygraph": {"exam_id": e.exam_id, "prep": prep, "exam": null}, "agents": {e.subject: {"lifestyle": lifestyle}}}
	s.polygraph.exam = start_exam(s, content, true)
	return _search(content, s)


static func _search(content: Dictionary, s: Dictionary) -> bool:
	if finished(content, s):
		return verdict(content, s.polygraph.exam, s.polygraph.exam_id) == "pass"
	var e := by_id(content, s.polygraph.exam_id)
	if s.polygraph.exam.pending:
		for o in e.rationalizations:
			if s.polygraph.exam.used.has(o.option_id):
				continue
			var n := s.duplicate(true)
			n.polygraph.exam = rationalize(s, o)
			if _search(content, n):
				return true
		return false
	for c in choices(content, s):
		var n := s.duplicate(true)
		n.polygraph.exam = answer(content, s, c)
		if _search(content, n):
			return true
	return false
