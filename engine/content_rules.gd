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
		if not goal.any(func(id): return full.recruited.has(id)):
			_push(ctx, "error", "softlock", "Тупик: цель акта %d (%s) недостижима даже при идеальной игре" % [act.act, " или ".join(goal)], where, "", "campaign.json")
			continue
		var failures: Array = []
		for t in c.targets:
			if t.act <= act.act and not (goal.size() == 1 and goal[0] == t.target_id):
				failures.append({"label": "не удастся завербовать «%s»" % t.target_id, "targets": [t.target_id], "ops": []})
		for o in c.ops:
			if o.act <= act.act:
				failures.append({"label": "сорвётся операция «%s»" % o.op_id, "targets": [], "ops": [o.op_id]})
		for f in failures:
			var res := ContentSim.run(c, {"max_act": act.act, "failed_targets": f.targets, "failed_ops": f.ops})
			if not goal.any(func(id): return not f.targets.has(id) and res.recruited.has(id)):
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


## 8. Экзамены на полиграфе: категории вопросов и формулы.
static func _polygraph(ctx: Dictionary) -> void:
	var allowed := POLYGRAPH_VARS + ["AND", "OR"]
	var word := RegEx.create_from_string("[A-Za-z_]+")
	var junk := RegEx.create_from_string("[A-Za-z_]+|\\d+|>=|<=|==|[<>+\\-()\\s]")
	for exam in ctx.content.polygraph:
		for i in exam.question_sequence.size():
			var q: Dictionary = exam.question_sequence[i]
			var where := "question_sequence[%d]" % i
			if q.category == "relevant_critical" and not q.has("pass_formula"):
				_push(ctx, "error", "polygraph", "Значимый вопрос «%s» без условия прохождения pass_formula" % q.q_id, where, exam.exam_id)
			if q.category == "control_comparison" and q.choices.size() < 2:
				_push(ctx, "error", "polygraph", "У контрольного вопроса «%s» должно быть минимум 2 варианта ответа" % q.q_id, where, exam.exam_id)
			if q.has("pass_formula"):
				var bad: Array = []
				for m in word.search_all(q.pass_formula):
					if not allowed.has(m.get_string()):
						bad.append(m.get_string())
				var rest: String = junk.sub(q.pass_formula, "", true)
				if not bad.is_empty() or rest != "":
					if rest != "":
						bad.append(rest)
					_push(ctx, "error", "polygraph", "Непонятная формула: %s. Допустимо: %s, числа, >= <= == < > + - ( )" % [", ".join(bad), ", ".join(allowed)], where + ".pass_formula", exam.exam_id)


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
		if g.fund_usd == 0 and g.centre_trust == 0 and g.moscow_pressure == 0 and g.extend_act_weeks == 0:
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
		var t := Campaign.target_by_id(c, d.target_id)
		if t.is_empty():
			_push(ctx, "error", "dialog", "Беседа с несуществующей целью «%s»" % d.target_id, "%s.target_id" % id, id)
			continue
		if seen.has(d.target_id):
			_push(ctx, "error", "dialog", "У цели «%s» уже есть беседа «%s»: нужна одна" % [d.target_id, seen[d.target_id]], "%s.target_id" % id, id)
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
