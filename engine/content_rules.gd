class_name ContentRules
## Правила дизайна контента: ссылки, «Правило трёх улик», тупики, честность проверочного
## маршрута, недели, длина текстов, полиграф, баланс. Каждое правило покрыто тестом,
## который портит настоящий контент (tests/test_validate.gd).

## Лимиты длины документа (GDD, риск №2): до 120 слов — норма, больше 150 — ошибка.
const WORDS_WARN := 120
const WORDS_MAX := 150
## Сколько улик нужно, чтобы вывод считался подтверждённым.
const THREE_CLUES := 3
const POLYGRAPH_VARS := ["control_peak", "relevant_peak", "rapport", "skepticism"]
const CHANNEL_RU := {"agent": "агент", "document": "документ", "field": "полевая разведка", "meeting": "беседа"}
const AXIS_RU := {"money": "Деньги", "ideology": "Идеология", "compromise": "Компромат", "ego": "Самолюбие"}


static func check(content: Dictionary, file_of: Dictionary, opts := {}) -> Array:
	var ctx := {"content": content, "file_of": file_of, "issues": []}
	_references(ctx)
	_unlock(ctx)
	_key_axes(ctx)
	_reachability(ctx)
	_map_and_sdr(ctx)
	_weeks(ctx)
	_texts(ctx, opts.get("translation", false))
	_polygraph(ctx)
	_balance(ctx)
	_board(ctx)
	_cipher(ctx)
	_dialogs(ctx)
	_finance(ctx)
	_achievements(ctx)
	_age16(ctx)
	_archive(ctx)
	_act2(ctx)
	_act3(ctx)
	_act4(ctx)
	_volume(ctx, opts.get("ui", {}))
	_diamonds(ctx)
	return ctx.issues


static func _push(ctx: Dictionary, level: String, rule: String, message: String, where := "", id := "", file := "") -> void:
	var f := file
	if f == "" and id != "":
		f = ctx.file_of.get(id, "")
	var issue := {"level": level, "rule": rule, "message": message}
	if f != "":
		issue.file = f
	if where != "":
		issue.where = where
	ctx.issues.append(issue)


static func _ids(list: Array, key: String) -> Dictionary:
	var d := {}
	for x in list:
		d[x[key]] = true
	return d


static func source_key(src: Dictionary) -> String:
	return "%s:%s" % [src.channel, src.from]


## 1. Все ссылки ведут на существующие сущности.
static func _references(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var targets := _ids(c.targets, "target_id")
	var clues := _ids(c.clues, "clue_id")
	var exists := {"agent": targets, "document": _ids(c.cables, "cable_id"), "field": _ids(c.ops, "op_id"), "meeting": _ids(c.dialogs, "dialog_id")}
	var kind_ru := {"agent": "цели", "document": "депеши", "field": "операции", "meeting": "беседы"}
	for clue in c.clues:
		var src: Dictionary = clue.source
		if not exists[src.channel].has(src.from):
			_push(ctx, "error", "refs", "Улика ссылается на несуществующий источник: нет %s «%s»" % [kind_ru[src.channel], src.from], "%s.source.from" % clue.clue_id, clue.clue_id)
		for i in clue.reveals.size():
			if not targets.has(clue.reveals[i].target_id):
				_push(ctx, "error", "refs", "Улика вскрывает мотив у несуществующей цели «%s»" % clue.reveals[i].target_id, "%s.reveals[%d]" % [clue.clue_id, i], clue.clue_id)
		if src.channel == "agent" and clue.reveals.any(func(r): return r.target_id == src.from):
			_push(ctx, "warning", "refs", "Агент доносит сам на себя: улика от агента вскрывает его же мотивы", clue.clue_id, clue.clue_id)
	for t in c.targets:
		for i in t.unlock.clue_ids.size():
			var id: String = t.unlock.clue_ids[i]
			if not clues.has(id):
				_push(ctx, "error", "refs", "Нет улики «%s», а цель «%s» открывается через неё" % [id, t.target_id], "unlock.clue_ids[%d]" % i, t.target_id)
	for op in c.ops:
		for id in op.requires_targets_unlocked:
			if not targets.has(id):
				_push(ctx, "error", "refs", "Операция требует открытую цель «%s», но такой цели нет" % id, "requires_targets_unlocked", op.op_id)
	for i in c.campaign.acts.size():
		var a: Dictionary = c.campaign.acts[i]
		for id in a.goal.recruit_any_of:
			if not targets.has(id):
				_push(ctx, "error", "refs", "Цель акта %d — несуществующая цель «%s»" % [a.act, id], "acts[%d].goal.recruit_any_of" % i, "", "campaign.json")


## 2. Открытие цели выполнимо и защищено «Правилом трёх улик».
static func _unlock(ctx: Dictionary) -> void:
	var by_id := {}
	for clue in ctx.content.clues:
		by_id[clue.clue_id] = clue
	for t in ctx.content.targets:
		var ids: Array = t.unlock.clue_ids
		var required: int = t.unlock.clues_required
		if _ids(ids.map(func(x): return {"k": x}), "k").size() != ids.size():
			_push(ctx, "error", "unlock", "В списке улик есть повторы", "unlock.clue_ids", t.target_id)
		if ids.size() < required:
			_push(ctx, "error", "unlock", "Нужно %d улик(и), а в списке всего %d: цель невозможно открыть" % [required, ids.size()], "unlock", t.target_id)
			continue
		var known: Array = ids.filter(func(id): return by_id.has(id)).map(func(id): return by_id[id])
		var sources := {}
		for k in known:
			sources[source_key(k.source)] = k.source
		if sources.size() < THREE_CLUES:
			_push(ctx, "error", "three-clue", "«Правило трёх улик»: к цели ведут улики только из %d независимых источников, нужно минимум %d" % [sources.size(), THREE_CLUES], "unlock.clue_ids", t.target_id)
			continue
		# Если любой один источник сорвётся, оставшихся улик всё равно должно хватить.
		for key in sources:
			var left: int = known.filter(func(k): return source_key(k.source) != key).size()
			if left < required:
				var src: Dictionary = sources[key]
				_push(ctx, "error", "three-clue", "«Правило трёх улик»: если сорвётся источник «%s %s», останется %d улик(и) из %d нужных — тупик" % [CHANNEL_RU[src.channel], src.from, left, required], "unlock.clue_ids", t.target_id)


## 3. Ведущие мотивы вскрываются минимум тремя уликами.
static func _key_axes(ctx: Dictionary) -> void:
	for t in ctx.content.targets:
		for axis in t.approach.key_axes:
			if t.mice_profile[axis].trigger == null:
				_push(ctx, "warning", "mice-three-clue", "Мотив «%s» указан ведущим, но у него нет рычага (trigger: null)" % AXIS_RU[axis], "mice_profile.%s.trigger" % axis, t.target_id)
			var n := 0
			for clue in ctx.content.clues:
				if clue.reveals.any(func(r): return r.target_id == t.target_id and r.axis == axis):
					n += 1
			if n < THREE_CLUES:
				_push(ctx, "error", "mice-three-clue", "«Правило трёх улик»: ведущий мотив «%s» вскрывают %d улик(и), нужно минимум %d" % [AXIS_RU[axis], n, THREE_CLUES], "approach.key_axes", t.target_id)


## 4. Цель каждого акта достижима и не ломается, если сорвётся любая одна ветка.
static func _reachability(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	for i in c.campaign.acts.size():
		var act: Dictionary = c.campaign.acts[i]
		var goal: Array = act.goal.recruit_any_of
		var where := "acts[%d].goal" % i
		var full := ContentSim.run(c, {"max_act": act.act})
		if not ContentSim.goal_met(act, full):
			_push(ctx, "error", "softlock", "Тупик: цель акта %d (%s) недостижима даже при идеальной игре" % [act.act, " или ".join(goal)], where, "", "campaign.json")
			continue
		var failures: Array = []
		for t in c.targets:
			if t.act <= act.act and not (goal.size() == 1 and goal[0] == t.target_id):
				failures.append({"label": "не удастся завербовать «%s»" % t.target_id, "targets": [t.target_id], "ops": []})
		for o in c.ops:
			# Ключевое мероприятие (essential) после отмены повторяется — «сорваться» навсегда не может.
			if o.act <= act.act and not o.get("essential", false):
				failures.append({"label": "сорвётся операция «%s»" % o.op_id, "targets": [], "ops": [o.op_id]})
		for f in failures:
			var res := ContentSim.run(c, {"max_act": act.act, "failed_targets": f.targets, "failed_ops": f.ops})
			if not ContentSim.goal_met(act, res, f.targets):
				_push(ctx, "error", "robustness", "Тупик: если %s, цель акта %d становится недостижимой" % [f.label, act.act], where, "", "campaign.json")
	var all := ContentSim.run(c)
	for clue in c.clues:
		if not all.clues.has(clue.clue_id):
			_push(ctx, "warning", "unreachable", "Улику «%s» невозможно получить ни при каком прохождении (источник %s %s недоступен)" % [clue.clue_id, CHANNEL_RU[clue.source.channel], clue.source.from], clue.clue_id, clue.clue_id)


## 5. Карта и проверочный маршрут честны: «один раз — совпадение, дважды — работа противника».
static func _map_and_sdr(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var MAP := "map/sites.json"
	var CUES := "map/cues.json"
	var cues := {}
	for cue in c.cues:
		cues[cue.tag] = cue
	var embassy = MapGeo.site(c, c.balance.sdr.embassy_site)
	if embassy == null:
		_push(ctx, "error", "sdr", "Нет точки посольства «%s» в %s" % [c.balance.sdr.embassy_site, MAP], "sdr.embassy_site", "", "balance.json")

	var seen := {}
	for site in c.map.sites:
		if not c.map.districts.has(site.district):
			_push(ctx, "error", "sdr", "Район «%s» не описан в districts" % site.district, "%s.district" % site.site_id, "", MAP)
		if site.role != "stop":
			continue
		if not site.has("cover_reason"):
			_push(ctx, "error", "sdr", "У бытовой точки маршрута нет легенды визита (cover_reason)", site.site_id, "", MAP)
		if site.ambient_tags.is_empty():
			_push(ctx, "error", "sdr", "У точки маршрута нет местных примет", "%s.ambient_tags" % site.site_id, "", MAP)
		for tag in site.ambient_tags:
			if not cues.has(tag):
				_push(ctx, "error", "refs", "Нет приметы «%s» в %s" % [tag, CUES], "%s.ambient_tags" % site.site_id, "", MAP)
			elif cues[tag].kind != "ambient":
				_push(ctx, "error", "sdr", "Примета «%s» — не местная (kind: %s), её нельзя привязать к точке" % [tag, cues[tag].kind], "%s.ambient_tags" % site.site_id, "", MAP)
			if seen.has(tag):
				_push(ctx, "error", "sdr", "Примета «%s» есть и у точки «%s»: на маршруте через обе она повторится — ложный сигнал хвоста" % [tag, seen[tag]], "%s.ambient_tags" % site.site_id, "", MAP)
			seen[tag] = site.site_id

	# Разные приметы с одинаковым текстом игрок примет за повтор — ложный сигнал хвоста.
	var by_text := {}
	for cue in c.cues:
		var key: String = cue.text.ru.strip_edges().to_lower()
		if by_text.has(key):
			_push(ctx, "error", "sdr", "Текст приметы совпадает с «%s» — игрок увидит ложный повтор" % by_text[key], cue.tag, "", CUES)
		by_text[key] = cue.tag

	var noise: int = c.cues.filter(func(x): return x.kind == "noise").size()
	if noise < 3:
		_push(ctx, "error", "sdr", "Нужно минимум 3 приметы-«шума» (kind: noise), чтобы они не повторялись на трёх точках; сейчас %d" % noise, "", "", CUES)

	var good := {}
	for s in c.map.sites:
		if s.role == "stop" and (embassy == null or MapGeo.within_zone(c, s)):
			good[s.district] = true
	if good.size() < int(c.balance.sdr.min_districts_for_double_sighting):
		_push(ctx, "error", "sdr", "Бытовые точки внутри 25-мильной зоны есть только в %d районах — правильный проверочный маршрут построить нельзя" % good.size(), "", "", MAP)

	for op in c.ops:
		var site = MapGeo.site(c, op.location.site_id)
		if site == null:
			_push(ctx, "error", "refs", "Нет точки «%s» в %s" % [op.location.site_id, MAP], "location.site_id", op.op_id)
		elif site.role != "target":
			_push(ctx, "error", "sdr", "Точка «%s» не является целью операции (role: %s)" % [site.site_id, site.role], "location.site_id", op.op_id)
		elif embassy != null and not MapGeo.within_zone(c, site):
			_push(ctx, "warning", "sdr", "Цель вне 25-мильной зоны: выезд потребует согласования с Госдепом", "location.site_id", op.op_id)
		var sdr: Dictionary = op.sdr
		if sdr.surveillance_present:
			if sdr.repeating_cue == null:
				_push(ctx, "error", "sdr", "Хвост есть, но не указана его примета", "sdr.repeating_cue", op.op_id)
			elif not cues.has(sdr.repeating_cue) or cues[sdr.repeating_cue].kind != "tail":
				_push(ctx, "error", "sdr", "Примета хвоста «%s» должна быть в %s с kind: \"tail\"" % [sdr.repeating_cue, CUES], "sdr.repeating_cue", op.op_id)
			if not sdr.has("ignore_consequence"):
				_push(ctx, "warning", "sdr", "Хвост есть, но не задано последствие, если игрок его пропустит", "sdr.ignore_consequence", op.op_id)
		elif sdr.repeating_cue != null:
			_push(ctx, "error", "sdr", "Хвоста нет, но указана его примета", "sdr.repeating_cue", op.op_id)


## 6. Недели депеш и операций попадают в рамки своего акта.
static func _weeks(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var ranges := {}
	for i in c.campaign.acts.size():
		var a: Dictionary = c.campaign.acts[i]
		ranges[a.act] = a.weeks
		if a.weeks.from > a.weeks.to:
			_push(ctx, "error", "weeks", "Неделя начала акта позже недели конца", "acts[%d].weeks" % i, "", "campaign.json")
	var items: Array = []
	for x in c.cables:
		items.append({"id": x.cable_id, "act": x.act, "week": x.week})
	for x in c.ops:
		items.append({"id": x.op_id, "act": x.act, "week": x.week})
	for it in items:
		if not ranges.has(it.act):
			continue  # акт ещё не описан в campaign.json — не придираемся
		var r: Dictionary = ranges[it.act]
		if it.week < r.from or it.week > r.to:
			_push(ctx, "error", "weeks", "Неделя %d вне акта %d (недели %d–%d)" % [it.week, it.act, r.from, r.to], "%s.week" % it.id, it.id)


## 7. Длина документов; напоминание о переводе — только по запросу (английская версия позже).
static func _texts(ctx: Dictionary, translation: bool) -> void:
	var c: Dictionary = ctx.content
	var long: Array = []
	for x in c.clues:
		long.append({"id": x.clue_id, "where": "%s.text" % x.clue_id, "text": x.text})
	for x in c.cables:
		long.append({"id": x.cable_id, "where": "%s.body" % x.cable_id, "text": x.body})
	for item in long:
		for lang in ["ru", "en"]:
			if not item.text.has(lang):
				continue
			var n := Util.count_words(item.text[lang])
			if n > WORDS_MAX:
				_push(ctx, "error", "text-length", "%d слов — больше лимита %d. Сократите документ" % [n, WORDS_MAX], "%s.%s" % [item.where, lang], item.id)
			elif n > WORDS_WARN:
				_push(ctx, "warning", "text-length", "%d слов — длиннее рекомендуемых %d" % [n, WORDS_WARN], "%s.%s" % [item.where, lang], item.id)
	if translation:
		var counts := [0, 0]
		_count_translations(c, counts)
		if counts[1] > 0:
			_push(ctx, "warning", "translation", "Без английского перевода: %d из %d текстов" % [counts[1], counts[0]])


static func _count_translations(v: Variant, counts: Array) -> void:
	if typeof(v) == TYPE_ARRAY:
		for x in v:
			_count_translations(x, counts)
	elif typeof(v) == TYPE_DICTIONARY:
		if v.has("ru") and typeof(v.ru) == TYPE_STRING:
			counts[0] += 1
			if String(v.get("en", "")).strip_edges() == "":
				counts[1] += 1
			return
		for k in v:
			_count_translations(v[k], counts)


## 8. Экзамены на полиграфе: категории вопросов, формулы, неделя, проходимость.
static func _polygraph(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var allowed := POLYGRAPH_VARS + ["AND", "OR"]
	var word := RegEx.create_from_string("[A-Za-z_]+")
	var junk := RegEx.create_from_string("[A-Za-z_]+|\\d+|>=|<=|==|[<>+\\-()\\s]")
	var target_ids := _ids(c.targets, "target_id")
	for exam in c.polygraph:
		var id: String = exam.exam_id
		for key in ["subject", "source_agent"]:
			if not target_ids.has(exam[key]):
				_push(ctx, "error", "refs", "Нет кандидата «%s»" % exam[key], key, id)
		var act: Dictionary = {}
		for a in c.campaign.acts:
			if int(a.act) == int(exam.act):
				act = a
		if act.is_empty():
			_push(ctx, "error", "polygraph", "Фазы %d нет в campaign.json" % exam.act, "act", id)
		elif int(exam.week) < int(act.weeks.from) or int(exam.week) > int(act.weeks.to):
			_push(ctx, "error", "polygraph", "Неделя проверки %d вне фазы %d (недели %d–%d)" % [exam.week, exam.act, act.weeks.from, act.weeks.to], "week", id)
		for i in exam.question_sequence.size():
			var q: Dictionary = exam.question_sequence[i]
			var where := "question_sequence[%d]" % i
			if q.category == "relevant_critical" and not q.has("pass_formula"):
				_push(ctx, "error", "polygraph", "Значимый вопрос «%s» без условия прохождения pass_formula" % q.q_id, where, id)
			if q.category == "relevant_critical" and int(q.base_peak) == 0:
				_push(ctx, "warning", "polygraph", "Значимый вопрос «%s» без исходного пика base_peak" % q.q_id, where, id)
			if q.category == "control_comparison" and q.choices.size() < 2:
				_push(ctx, "error", "polygraph", "У контрольного вопроса «%s» должно быть минимум 2 варианта ответа" % q.q_id, where, id)
			for ch in q.choices:
				if ch.requires_prep != "" and Polygraph.prep_option(exam, ch.requires_prep).is_empty():
					_push(ctx, "error", "polygraph", "Ответ «%s» ждёт несуществующей подготовки «%s»" % [ch.choice_id, ch.requires_prep], where, id)
			if q.has("pass_formula"):
				var bad: Array = []
				for m in word.search_all(q.pass_formula):
					if not allowed.has(m.get_string()):
						bad.append(m.get_string())
				var rest: String = junk.sub(q.pass_formula, "", true)
				if not bad.is_empty() or rest != "":
					if rest != "":
						bad.append(rest)
					_push(ctx, "error", "polygraph", "Непонятная формула: %s. Допустимо: %s, числа, >= <= == < > + - ( )" % [", ".join(bad), ", ".join(allowed)], where + ".pass_formula", id)
		if not exam.prep_options.any(func(o): return o.kind == "strategy" and o.archetype == exam.examiner_profile.archetype):
			_push(ctx, "error", "polygraph", "Нет стратегии поведения под экзаменатора «%s»" % exam.examiner_profile.archetype, "prep_options", id)
		# Проходимость: с лучшей подготовкой на все пункты — обязательно; вслепую — желательно.
		var best: Array = []
		for o in exam.prep_options:
			if o.kind != "strategy" or o.archetype == exam.examiner_profile.archetype:
				best.append(o.prep_id)
		best = best.slice(0, int(exam.notice.prep_slots_with_source))
		if not Polygraph.winnable(c, exam, best):
			_push(ctx, "error", "polygraph", "Проверку невозможно пройти даже с полной подготовкой (%s)" % ", ".join(best), id, id)
		elif not Polygraph.winnable(c, exam, []):
			_push(ctx, "warning", "polygraph", "Без подготовки проверку не пройти никакой тактикой", id, id)


## 9. Пороги сигналов баланса идут по возрастанию.
static func _balance(ctx: Dictionary) -> void:
	var th: Dictionary = ctx.content.balance.thresholds
	if th.warning >= th.danger:
		_push(ctx, "error", "balance", "Порог «warning» (%d) должен быть меньше порога «danger» (%d)" % [th.warning, th.danger], "thresholds", "", "balance.json")


## 10. Доска мотивов: фрагменты-улики есть в документах, заключение по досье согласовано.
static func _board(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var cables := {}
	for x in c.cables:
		cables[x.cable_id] = x
	for clue in c.clues:
		var where: String = "%s.chunk" % clue.clue_id
		if clue.source.channel == "document":
			if not clue.has("chunk"):
				_push(ctx, "error", "board", "Улика из документа без фрагмента chunk: игроку нечего выделить в тексте", where, clue.clue_id)
			elif cables.has(clue.source.from) and not String(cables[clue.source.from].body.ru).contains(clue.chunk):
				_push(ctx, "error", "board", "Фрагмента «%s» нет в тексте документа «%s» (нужно дословное совпадение)" % [clue.chunk, clue.source.from], where, clue.clue_id)
		elif clue.source.channel == "meeting":
			var d := Meeting.dialog_by_id(c, clue.source.from)
			if not clue.has("chunk"):
				_push(ctx, "error", "board", "Оговорка на встрече без фрагмента chunk: игроку нечего выделить в стенограмме", where, clue.clue_id)
			elif not d.is_empty() and not _dialog_replies(d).any(func(t): return t.contains(clue.chunk)):
				_push(ctx, "error", "board", "Фрагмента «%s» нет в репликах собеседника в беседе «%s» (нужно дословное совпадение)" % [clue.chunk, d.dialog_id], where, clue.clue_id)
		elif clue.has("chunk"):
			_push(ctx, "warning", "board", "Фрагмент chunk нужен только уликам из документов", where, clue.clue_id)
	for t in c.targets:
		var a: Dictionary = t.analysis
		if not t.approach.key_axes.has(a.leading_axis):
			_push(ctx, "error", "board", "Ведущий мотив заключения «%s» не входит в ведущие мотивы подхода (approach.key_axes)" % AXIS_RU[a.leading_axis], "analysis.leading_axis", t.target_id)
		if not a.access_options.any(func(o): return o.id == a.correct_access):
			_push(ctx, "error", "board", "Правильного варианта доступа «%s» нет среди access_options" % a.correct_access, "analysis.correct_access", t.target_id)
		var relevant := 0
		for clue in c.clues:
			if clue.reveals.any(func(r): return r.target_id == t.target_id) or t.unlock.clue_ids.has(clue.clue_id):
				relevant += 1
		if relevant < THREE_CLUES:
			_push(ctx, "error", "board", "По цели всего %d улик(и): для заключения на доске нужно минимум %d" % [relevant, THREE_CLUES], "", t.target_id)


## 11. Шифроузел: подложными бывают только директивы, запросы привязаны к существующим актам.
static func _cipher(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	for x in c.cables:
		if x.forged and x.kind != "directive":
			_push(ctx, "error", "cipher", "Подложной (forged) может быть только директива Центра", "%s.forged" % x.cable_id, x.cable_id)
	var acts := {}
	for a in c.campaign.acts:
		acts[a.act] = true
	for r in c.requests:
		if not acts.has(r.act):
			_push(ctx, "error", "cipher", "Запрос привязан к акту %d, которого нет в campaign.json" % r.act, "%s.act" % r.request_id, r.request_id)
		var g: Dictionary = r.granted
		if not r.get("package_check", false) and g.fund_usd == 0 and g.centre_trust == 0 and g.moscow_pressure == 0 and g.extend_act_weeks == 0:
			_push(ctx, "warning", "cipher", "Одобренный запрос ничего не меняет: задайте хотя бы одно поле в granted", "%s.granted" % r.request_id, r.request_id)


## Реплики собеседника в беседе (русский текст): вопросы, ответы на тоны и козыри, согласие.
static func _dialog_replies(d: Dictionary) -> Array:
	var out: Array = [String(d.offer.reply.ru)]
	for b in d.beats:
		out.append(String(b.prompt.ru))
		for tone in Meeting.TONES:
			out.append(String(b.tones[tone].reply.ru))
	for t in d.trumps:
		out.append(String(t.ready.reply.ru))
		out.append(String(t.early.reply.ru))
	return out


## 12. Беседы: цель существует, козыри — улики по этой цели, беседу можно выиграть.
static func _dialogs(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var seen := {}
	for d in c.dialogs:
		var id: String = d.dialog_id
		if Meeting.is_conversation(d):
			_conversation(ctx, d)
			continue
		var t := Campaign.target_by_id(c, d.target_id)
		if t.is_empty():
			_push(ctx, "error", "dialog", "Беседа с несуществующей целью «%s»" % d.target_id, "%s.target_id" % id, id)
			continue
		if Meeting.is_handling(d):
			_handling(ctx, d, t)
			continue
		if seen.has(d.target_id):
			_push(ctx, "error", "dialog", "У цели «%s» уже есть вербовочная беседа «%s»: нужна одна" % [d.target_id, seen[d.target_id]], "%s.target_id" % id, id)
		seen[d.target_id] = id
		var relevant: Array = []
		for i in d.trumps.size():
			var clue := Campaign.clue_by_id(c, d.trumps[i].clue_id)
			if clue.is_empty():
				_push(ctx, "error", "dialog", "Козырь ссылается на несуществующую улику «%s»" % d.trumps[i].clue_id, "%s.trumps[%d]" % [id, i], id)
			elif not Campaign.clue_relevant(c, clue, d.target_id):
				_push(ctx, "error", "dialog", "Козырь «%s» не относится к цели: его не приколоть к её досье" % clue.clue_id, "%s.trumps[%d]" % [id, i], id)
			else:
				relevant.append(clue.clue_id)
		var r0: int = t.initial_state.rapport
		var a0: int = t.initial_state.paranoia
		if a0 >= int(d.max_anxiety):
			_push(ctx, "error", "dialog", "Стартовая тревога цели (%d) уже не ниже предела беседы (%d)" % [a0, d.max_anxiety], "%s.max_anxiety" % id, id)
		elif not Meeting.winnable(d, r0, a0, relevant):
			_push(ctx, "error", "dialog", "Беседу невозможно выиграть даже идеальной игрой: Раппорт не доходит до %d%% раньше, чем Тревога до %d%%" % [d.offer_rapport, d.max_anxiety], id, id)
		elif Meeting.winnable(d, r0, a0, []):
			_push(ctx, "warning", "dialog", "Беседу можно выиграть без козырей из досье — доска мотивов на встрече не нужна", id, id)


## Встреча на связи: агент с личным контактом, порядок без повторов, выигрываемость при средней
## лояльности (HANDLING_CHECK_LOYALTY), донесения — от этого агента, условия существуют.
const HANDLING_CHECK_LOYALTY := 50


static func _handling(ctx: Dictionary, d: Dictionary, t: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var id: String = d.dialog_id
	if t.approach.flag_mode == "contactless":
		_push(ctx, "error", "dialog", "С «%s» связь только бесконтактная — встреча на связи невозможна" % t.target_id, "%s.target_id" % id, id)
	var my_flags: Array = d.get("requires", {}).get("flags", [])
	var same: Array = Meeting.handling_dialogs(c, d.target_id).filter(func(x): return int(x.order) == int(d.order) \
		and (x.get("requires", {}).get("flags", []) == my_flags or my_flags.is_empty()))
	if same.size() > 1:
		_push(ctx, "error", "dialog", "У агента «%s» две встречи с номером %d" % [d.target_id, d.order], "%s.order" % id, id)
	if d.get("success") == null:
		_push(ctx, "error", "dialog", "У встречи на связи нет итога success", id, id)
	else:
		for cid in d.success.get("clue_ids", []):
			var cl := Campaign.clue_by_id(c, cid)
			if cl.is_empty() or cl.source.channel != "agent" or cl.source.from != d.target_id:
				_push(ctx, "error", "dialog", "На встрече агент может передать только своё донесение (улику с канала agent от «%s»), а «%s» — не такое" % [d.target_id, cid], "%s.success.clue_ids" % id, id)
	var trumps: Array = d.trumps.map(func(x): return x.clue_id)
	if int(d.start_anxiety) >= int(d.max_anxiety):
		_push(ctx, "error", "dialog", "Стартовая настороженность не ниже предела беседы", "%s.start_anxiety" % id, id)
	elif not Meeting.winnable(d, HANDLING_CHECK_LOYALTY, int(d.start_anxiety), trumps):
		_push(ctx, "error", "dialog", "Встречу на связи не выиграть при лояльности агента %d%%" % HANDLING_CHECK_LOYALTY, id, id)


## Разговор не с кандидатом: собеседник назван, итог есть, выигрывается со своих стартовых чисел.
static func _conversation(ctx: Dictionary, d: Dictionary) -> void:
	var id: String = d.dialog_id
	if d.get("person") == null:
		_push(ctx, "error", "dialog", "У разговора нет собеседника (person)", id, id)
	if d.get("target_id", "") != "":
		_push(ctx, "warning", "dialog", "У разговора указана цель — для встречи с агентом используйте kind: handling", id, id)
	if d.get("success") == null:
		_push(ctx, "error", "dialog", "У разговора нет итога success", id, id)
	if int(d.start_anxiety) >= int(d.max_anxiety):
		_push(ctx, "error", "dialog", "Стартовая настороженность не ниже предела беседы", "%s.start_anxiety" % id, id)
	elif not Meeting.winnable(d, int(d.start_rapport), int(d.start_anxiety), []):
		_push(ctx, "error", "dialog", "Разговор невозможно выиграть даже идеальной игрой", id, id)


## 13. Финансы: обещанное агенту можно выплатить из стартового спецфонда и переводов Центра.
static func _finance(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	for a in c.campaign.acts:
		if not a.goal.settle_promise:
			continue
		var fund := int(c.balance.start.fund_usd)
		for x in c.campaign.acts:
			if int(x.act) <= int(a.act):
				fund += int(x.get("fund_usd", 0))
		for id in a.goal.recruit_any_of:
			var t := Campaign.target_by_id(c, id)
			if t.is_empty():
				continue
			if t.get("finance") == null:
				_push(ctx, "warning", "finance", "Цель акта %d без блока finance: обещания нет, задача засчитается сразу после вербовки" % a.act, "finance", id)
			elif int(t.finance.promised_usd) > fund:
				_push(ctx, "error", "finance", "Обещано %d долларов, а в спецфонде с переводами Центра всего %d — задачу акта не выполнить" % [t.finance.promised_usd, fund], "finance.promised_usd", id)


## 14. Достижения висят на событиях, которые движок действительно испускает.
static func _achievements(ctx: Dictionary) -> void:
	for a in ctx.content.achievements:
		if not Achievements.EVENTS.has(a.event):
			_push(ctx, "error", "achievements", "Неизвестное событие «%s». Допустимо: %s" % [a.event, ", ".join(Achievements.EVENTS)], "%s.event" % a.id, a.id)


## 15. Возрастная категория 16+ (436-ФЗ, 15-ФЗ; требование грантов ИРИ и ПФКИ):
## нецензурная лексика — ошибка; табак, курение и употребление алкоголя — предупреждение
## (в тексте допустимы как сведения о слабостях противника, но не как сцена или романтизация).
## «^» — начало слова, «$» — конец (граница \\b в RegEx не видит кириллицу); текст сравнивается в нижнем регистре.
const AGE16_OBSCENE := ["^х[уy][йеёяию]", "^пизд", "^[ьъ]?еб[аеиоуы][лнтшщ]", "^бля[дт]?", "^муд[аио]"]
const AGE16_WARN := {
	"табак и курение": ["^кур(ит|ят|ил|ила|ение|ения|ящ|ильщ)", "^сигарет", "^сигар[аыу]?$", "табак", "^пепельниц", "^затяну"],
	"употребление алкоголя": ["^пь(ёт|ют|ян)", "^выпи(л|ть|вк|ва)", "^напи(лся|лась|ться)", "^рюмк", "^водк", "^виск[иь]$", "^коньяк", "^пив[оа]$", "^бокал", "^налива", "^разлива"],
}
const _WORD_START := "(?<![а-яёa-z])"
const _WORD_END := "(?![а-яёa-z])"
static var _age16_re := {}


static func _age16(ctx: Dictionary) -> void:
	if _age16_re.is_empty():
		_age16_re["obscene"] = AGE16_OBSCENE.map(_age16_compile)
		for k in AGE16_WARN:
			_age16_re[k] = AGE16_WARN[k].map(_age16_compile)
	var c: Dictionary = ctx.content
	var texts: Array = []
	for key in ["targets", "clues", "cables", "ops", "polygraph", "requests", "dialogs", "achievements", "archive", "decisions", "list"]:
		for item in c.get(key, []):
			var id := _item_id(item)
			_collect_ru(item, id, id, texts)
	for key in ["campaign", "map", "cues"]:
		if c.has(key):
			_collect_ru(c[key], "", key, texts)
	for t in texts:
		var low: String = String(t.text).to_lower()
		for re in _age16_re.obscene:
			if re.search(low) != null:
				_push(ctx, "error", "age16", "Нецензурная лексика переводит игру в 18+ — уберите слово", t.where, t.id)
				break
		for k in AGE16_WARN:
			for re in _age16_re[k]:
				var m: RegExMatch = re.search(low)
				if m != null:
					_push(ctx, "warning", "age16", "16+: %s («%s») — допустимо только как сведения в документе, без сцены и романтизации" % [k, m.get_string()], t.where, t.id)
					break


static func _age16_compile(p: String) -> RegEx:
	var body := p
	if body.begins_with("^"):
		body = _WORD_START + body.substr(1)
	if body.ends_with("$"):
		body = body.substr(0, body.length() - 1) + _WORD_END
	return RegEx.create_from_string(body)


static func _item_id(item: Dictionary) -> String:
	for k in ["target_id", "clue_id", "cable_id", "op_id", "exam_id", "request_id", "dialog_id", "decision_id", "card_id", "id"]:
		if item.has(k):
			return str(item[k])
	return ""


static func _collect_ru(v: Variant, id: String, where: String, out: Array) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("ru") and typeof(v.ru) == TYPE_STRING:
			out.append({"id": id, "where": where, "text": v.ru})
			return
		for k in v:
			_collect_ru(v[k], id, "%s.%s" % [where, k], out)
	elif typeof(v) == TYPE_ARRAY:
		for i in v.size():
			_collect_ru(v[i], id, "%s[%d]" % [where, i], out)


## 16. Архив: записи открываются по событиям, которые движок испускает.
static func _archive(ctx: Dictionary) -> void:
	for a in ctx.content.archive:
		for part in String(a.unlock).split("+"):
			if part.begins_with("flag:") or part.begins_with("ending:") or part == "" or Achievements.EVENTS.has(part):
				continue
			_push(ctx, "error", "archive", "Запись открывается по неизвестному событию «%s»" % part, "%s.unlock" % a.id, a.id)
		if a.unlock.contains("+"):
			continue
		if a.unlock.begins_with("flag:"):
			continue
		if a.unlock.begins_with("ending:"):
			if not Archive.ENDINGS.has(a.unlock.trim_prefix("ending:")):
				_push(ctx, "error", "archive", "Неизвестная концовка в «%s». Допустимо: %s" % [a.unlock, ", ".join(Archive.ENDINGS)], "%s.unlock" % a.id, a.id)
		elif a.unlock != "" and not Achievements.EVENTS.has(a.unlock):
			_push(ctx, "error", "archive", "Запись открывается по неизвестному событию «%s»" % a.unlock, "%s.unlock" % a.id, a.id)


## 17. Вторая фаза: приёмы наружки, тайники, подчинённые, решения резидента.
static func _act2(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var clue_ids := _ids(c.clues, "clue_id")
	var op_ids := {}
	for o in c.operatives:
		op_ids[o.operative_id] = true
	var tech_ru := {"relay": "эстафета машин", "clothes": "смена одежды", "aircraft": "наблюдение с воздуха"}
	for op in c.ops:
		var id: String = op.op_id
		# Новый приём ФБР — только после ориентировки о нём (раньше по времени, а не в ту же неделю).
		var tech: String = op.sdr.get("technique", "")
		if tech != "":
			var taught: bool = c.cables.any(func(x): return x.teaches == tech and (int(x.act) < int(op.act) or (int(x.act) == int(op.act) and int(x.week) < int(op.week))))
			if not taught:
				_push(ctx, "error", "technique", "Приём «%s» на маршруте без ориентировки о нём раньше этой недели (поле teaches у депеши)" % tech_ru[tech], "%s.sdr.technique" % id, id)
			if not op.sdr.surveillance_present:
				_push(ctx, "warning", "technique", "Приём наружки указан, но хвоста на маршруте нет", "%s.sdr.technique" % id, id)
		var who: String = op.get("operative_id", Delegation.RESIDENT)
		if who != Delegation.RESIDENT and not op_ids.has(who):
			_push(ctx, "error", "delegation", "Нет оперработника «%s» в operatives/" % who, "%s.operative_id" % id, id)
		var ct: String = op.get("contact_target_id", "")
		if ct != "":
			var t := Campaign.target_by_id(c, ct)
			if t.is_empty():
				_push(ctx, "error", "refs", "Тайник для несуществующего кандидата «%s»" % ct, "%s.contact_target_id" % id, id)
			elif not op.requires_targets_unlocked.has(ct):
				_push(ctx, "error", "refs", "Тайник для «%s» должен требовать установленного кандидата (requires_targets_unlocked)" % ct, "%s.requires_targets_unlocked" % id, id)
			if op.get("drop") == null:
				_push(ctx, "warning", "refs", "У тайника нет описания drop (псевдоним, сигнал, контейнер)", "%s.drop" % id, id)
	for d in c.decisions:
		var id: String = d.decision_id
		var tr: Dictionary = d.trigger
		if int(tr.week) == 0 and tr.clue_id == "" and tr.flag == "":
			_push(ctx, "warning", "decisions", "У решения нет условия: появится сразу в начале фазы операции", "%s.trigger" % id, id)
		if tr.clue_id != "" and not clue_ids.has(tr.clue_id):
			_push(ctx, "error", "decisions", "Решение ждёт несуществующие сведения «%s»" % tr.clue_id, "%s.trigger.clue_id" % id, id)
		for o in d.options:
			var out: String = o.effects.get("operative_out", "")
			if out != "" and not op_ids.has(out):
				_push(ctx, "error", "decisions", "Вариант выводит из работы несуществующего оперработника «%s»" % out, "%s.options" % id, id)
	for cue in c.cues:
		if not cue.variants.is_empty() and cue.kind != "tail":
			_push(ctx, "warning", "technique", "Варианты описания нужны только приметам хвоста (смена одежды)", cue.tag, "", "map/cues.json")


## 18. Третья фаза: пробный пакет, «слепое окно», условия выходов и бесед.
static func _act3(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var op_ids := _ids(c.ops, "op_id")
	var target_ids := _ids(c.targets, "target_id")
	var dec_ids := _ids(c.decisions, "decision_id")
	var flags_known := {Dangle.ACCEPTED_FLAG: true, Dangle.REJECTED_FLAG: true, Dangle.DANGLE_FLAG: true}
	for d in c.decisions:
		for o in d.options:
			if o.effects.get("flag_set", "") != "":
				flags_known[o.effects.flag_set] = true
	for o in c.ops:
		var cons = o.sdr.get("ignore_consequence")
		if cons != null and cons.get("flag_set", "") != "":
			flags_known[cons.flag_set] = true
	for t in c.targets:
		flags_known["recruited_" + t.target_id] = true
	for o in c.ops:
		if o.get("contact_target_id", "") != "":
			flags_known["contact_" + o.contact_target_id] = true
		if String(o.get("success_flag", "")) != "":
			flags_known[o.success_flag] = true
	for dd in c.dialogs:
		for key in ["success", "failure"]:
			var fx = dd.get(key)
			if fx != null and String(fx.get("flag_set", "")) != "":
				flags_known[fx.flag_set] = true
	for cab in c.cables:
		for f in cab.get("requires_flags", []):
			if not flags_known.has(f) and not ArrestWindow.ENGINE_FLAGS.has(f):
				_push(ctx, "error", "refs", "Документ ждёт флаг «%s», который ничто не ставит" % f, "%s.requires_flags" % cab.cable_id, cab.cable_id)
	for dd in c.dialogs:
		for f in dd.get("requires", {}).get("flags", []):
			if not flags_known.has(f) and not ArrestWindow.ENGINE_FLAGS.has(f) and not ["package_accepted", "package_rejected", "dangle_accepted"].has(f):
				_push(ctx, "error", "refs", "Беседа ждёт флаг «%s», который ничто не ставит" % f, "%s.requires" % dd.dialog_id, dd.dialog_id)
	var pkg := Dangle.config(c)
	if not pkg.is_empty():
		for key in ["drop_op", "handover_op"]:
			if not op_ids.has(pkg[key]):
				_push(ctx, "error", "package", "Пробный пакет: нет мероприятия «%s»" % pkg[key], "package.%s" % key, "", "campaign.json")
		for key in ["agent", "archive_agent"]:
			if not target_ids.has(pkg[key]):
				_push(ctx, "error", "package", "Пробный пакет: нет кандидата «%s»" % pkg[key], "package.%s" % key, "", "campaign.json")
		var req := Cipher.request_by_id(c, pkg.request_id)
		if req.is_empty() or not req.get("package_check", false):
			_push(ctx, "error", "package", "Пробный пакет: запрос «%s» должен существовать и иметь package_check: true" % pkg.request_id, "package.request_id", "", "campaign.json")
		elif int(req.min_trust) > 0:
			_push(ctx, "warning", "package", "Сверку пакета Центр может не одобрить (min_trust > 0) — канал проверки пропадёт", "package.request_id", "", "campaign.json")
		var ho := Campaign.op_by_id(c, pkg.handover_op)
		if not ho.is_empty() and not ho.get("requires_flags", []).has(Dangle.REJECTED_FLAG):
			_push(ctx, "error", "package", "Личная передача должна требовать флаг «%s» (отклонённый пакет)" % Dangle.REJECTED_FLAG, "%s.requires_flags" % pkg.handover_op, pkg.handover_op)
	var has_schedule: bool = c.targets.any(func(t): return t.get("perks", []).has("sog_schedule"))
	for o in c.ops:
		var id: String = o.op_id
		if o.sdr.get("blind_window", false) and not has_schedule:
			_push(ctx, "warning", "blind-window", "«Слепое окно» не откроется: ни у одного кандидата нет perk sog_schedule", "%s.sdr.blind_window" % id, id)
		for t in o.get("requires_recruited", []):
			if not target_ids.has(t):
				_push(ctx, "error", "refs", "Выход ждёт вербовки несуществующего кандидата «%s»" % t, "%s.requires_recruited" % id, id)
		for f in o.get("requires_flags", []):
			if not flags_known.has(f) and not ArrestWindow.ENGINE_FLAGS.has(f):
				_push(ctx, "error", "refs", "Выход ждёт флаг «%s», который ничто не ставит" % f, "%s.requires_flags" % id, id)
		for d in o.get("requires_decisions", []):
			if not dec_ids.has(d):
				_push(ctx, "error", "refs", "Выход ждёт несуществующее решение «%s»" % d, "%s.requires_decisions" % id, id)
	for d in c.dialogs:
		var need: String = d.get("requires_op", "")
		if need != "" and not op_ids.has(need):
			_push(ctx, "error", "dialog", "Встреча назначается несуществующим выходом «%s»" % need, "%s.requires_op" % d.dialog_id, d.dialog_id)
	for d in c.decisions:
		if d.trigger.flag != "" and not flags_known.has(d.trigger.flag) and not ArrestWindow.ENGINE_FLAGS.has(d.trigger.flag):
			_push(ctx, "error", "decisions", "Решение ждёт флаг «%s», который ничто не ставит" % d.trigger.flag, "%s.trigger.flag" % d.decision_id, d.decision_id)
		for o in d.options:
			var lt: String = o.effects.get("loyalty_target", "")
			if lt != "" and not target_ids.has(lt):
				_push(ctx, "error", "decisions", "Вариант меняет лояльность несуществующего агента «%s»" % lt, "%s.options" % d.decision_id, d.decision_id)


## 19. Четвёртая фаза: «Окно арестов» — квоты выполнимы, дела описаны.
static func _act4(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var cfg := ArrestWindow.config(c)
	if cfg.is_empty():
		if not c.get("list", []).is_empty():
			_push(ctx, "warning", "list", "Дела «Списка» есть, но ни у одной фазы нет arrest_window", "", "", "campaign.json")
		return
	var act := ArrestWindow.act_of(c)
	var where := "acts[act %d].arrest_window" % act
	var a: Dictionary = {}
	for x in c.campaign.acts:
		if int(x.act) == act:
			a = x
	if int(cfg.from) < int(a.weeks.from) or int(cfg.to) > int(a.weeks.to) or int(cfg.from) > int(cfg.to):
		_push(ctx, "error", "list", "Недели окна %d–%d вне фазы %d (недели %d–%d)" % [cfg.from, cfg.to, act, a.weeks.from, a.weeks.to], where, "", "campaign.json")
	var cards: Array = c.get("list", [])
	if cards.is_empty():
		_push(ctx, "error", "list", "«Окно арестов» без дел: добавьте content/list/", where, "", "campaign.json")
	var last := 0
	for q in cfg.quotas:
		if int(q.by_week) < int(cfg.from) or int(q.by_week) > int(cfg.to):
			_push(ctx, "error", "list", "Квота к неделе %d вне окна %d–%d" % [q.by_week, cfg.from, cfg.to], where + ".quotas", "", "campaign.json")
		if int(q.by_week) <= last:
			_push(ctx, "error", "list", "Квоты должны идти по возрастанию недель", where + ".quotas", "", "campaign.json")
		last = int(q.by_week)
		# Квота выполнима даже при подставе: подделки не в счёт.
		var pool: int = cards.filter(func(x): return not x.get("dangle", false) and (q.get("damage", "") == "" or x.damage == q.damage)).size()
		if int(q.arrests) > pool:
			_push(ctx, "error", "list", "Квота к неделе %d требует %d арестов, а подходящих настоящих дел только %d" % [q.by_week, q.arrests, pool], where + ".quotas", "", "campaign.json")
	var howard: int = cards.filter(func(x): return x.howard).size()
	if howard * 2 >= cards.size() and cards.size() > 0:
		_push(ctx, "warning", "list", "Флаг «Ховард» у %d из %d дел: перебежчик объясняет слишком многое — выбор теряет смысл" % [howard, cards.size()], "", "", "list/")


## 20. Объём текста: потолок слов на всю игру и доля текста одной ветки решения.
static func _volume(ctx: Dictionary, ui: Dictionary) -> void:
	var c: Dictionary = ctx.content
	var b: Dictionary = c.balance.text_budget
	var r := WordCount.report(c, ui)
	if int(r.total) > int(b.max_words):
		_push(ctx, "error", "volume", "В игре %d слов — больше потолка %d. Сократите тексты или поднимите text_budget.max_words" % [r.total, b.max_words], "text_budget.max_words", "", "balance.json")
	for br in WordCount.branches(c):
		var share := float(br.words) / maxf(1.0, float(r.total))
		if share > float(b.branch_share_max):
			_push(ctx, "warning", "volume", "Вариант «%s» открывает %d слов (%d%% игры) — ветка слишком толстая, её увидит не каждый" % [br.option_id, br.words, int(share * 100)], "%s.options" % br.decision_id, br.decision_id)


## 21. Бриллиантовое ветвление: при любом варианте решения задачи следующих фаз достижимы —
## ветки расходятся и сходятся обратно.
static func _diamonds(ctx: Dictionary) -> void:
	var c: Dictionary = ctx.content
	for d in c.decisions:
		for o in d.options:
			for act in c.campaign.acts:
				if int(act.act) < int(d.act):
					continue
				var st := ContentSim.run(c, {"max_act": int(act.act), "choices": {d.decision_id: o.option_id}})
				if not ContentSim.goal_met(act, st):
					_push(ctx, "error", "diamond", "Ветка не сходится: при варианте «%s» задача фазы %d недостижима" % [o.option_id, act.act], "%s.options" % d.decision_id, d.decision_id)
