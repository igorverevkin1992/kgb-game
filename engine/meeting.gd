class_name Meeting
## Вербовочная беседа (магнитофон «Тембр-2М»): чистые функции над состоянием и контентом.
## Беседа — несколько реплик собеседника (beats). На каждую резидент отвечает тоном (эмпатия,
## деловой прагматизм, мягкое давление, апелляция к эго) и, по желанию, козырем из досье —
## уликой, приколотой к доске. Козырь «готов», если Раппорт уже не ниже его порога; рано
## выложенный козырь (например, шантаж на старте) даёт всплеск Тревоги. Тревога дошла до
## предела — собеседник уходит, подход провален. Раппорт дошёл до порога — можно сделать
## предложение. «Прервать контакт» доступно всегда: Раппорт сохраняется, Тревога к следующей
## встрече спадает (balance.meeting.anxiety_cooldown).
##
## Состояние встречи (state.meeting): {target_id, dialog_id, beat, rapport, anxiety, used, lines}.
## Строки стенограммы — ссылки на контент (тексты берутся из него при показе):
##   {kind: "setting"} · {kind: "prompt", beat} · {kind: "my_tone", beat, tone}
##   {kind: "reply_tone", beat, tone, dr, da} · {kind: "my_trump", tone, clue_id}
##   {kind: "reply_trump", clue_id, ready, dr, da} · {kind: "my_offer"} · {kind: "reply_offer"}
##   {kind: "end", outcome: "recruited"|"failed"|"aborted"}

const TONES := ["empathy", "pragmatic", "pressure", "ego"]


## Вербовочная беседа кандидата (одна).
static func dialog_for(content: Dictionary, target_id: String) -> Dictionary:
	for d in content.dialogs:
		if d.target_id == target_id and d.get("kind", "recruitment") == "recruitment":
			return d
	return {}


static func is_handling(d: Dictionary) -> bool:
	return d.get("kind", "recruitment") == "handling"


## Разговор не с кандидатом: инициативник, подчинённый, инспектор, родные (person вместо цели).
static func is_conversation(d: Dictionary) -> bool:
	return d.get("kind", "recruitment") == "conversation"


## Встреча с итогом «договорились» (не вербовка): на связи или разговор.
static func is_agreement(d: Dictionary) -> bool:
	return is_handling(d) or is_conversation(d)


## Имя собеседника: цель вербовки или person разговора.
static func person_name(content: Dictionary, d: Dictionary) -> Dictionary:
	if d.get("target_id", "") != "":
		return Campaign.target_by_id(content, d.target_id).get("name", {"ru": d.target_id})
	return d.get("person", {"ru": ""})


## Разговоры, которые можно провести сейчас.
static func conversations(s: Dictionary, content: Dictionary) -> Array:
	return content.dialogs.filter(func(d): return is_conversation(d) and conversation_error(s, content, d.dialog_id) == "")


## Почему нельзя провести разговор ("" — можно). Условия — без подсказок наперёд.
static func conversation_error(s: Dictionary, content: Dictionary, dialog_id: String) -> String:
	var d := dialog_by_id(content, dialog_id)
	if d.is_empty() or not is_conversation(d):
		return "Такого разговора нет"
	if s.get("handled", {}).has(dialog_id):
		return "Разговор уже состоялся"
	if not _requires_met(s, d):
		return "Повода для разговора пока нет"
	if s.meeting != null:
		return "Встреча уже идёт"
	if s.phase != "day" and s.phase != "evening":
		return "Разговоры — днём или вечером"
	if s.tapes.any(func(t): return t.dialog_id == dialog_id and t.week == s.week):
		return "Этот разговор уже был на этой неделе — вернитесь к нему позже"
	return ""


static func _requires_met(s: Dictionary, d: Dictionary) -> bool:
	var req: Dictionary = d.get("requires", {})
	if int(s.act) < int(req.get("act", 1)) or int(s.week) < int(req.get("week", 0)):
		return false
	if not req.get("flags", []).all(func(f): return s.flags.has(f)):
		return false
	if req.get("polygraph", false) and (s.get("polygraph") == null or s.polygraph.result != ""):
		return false
	return true


## Встречи на связи с агентом по порядку.
static func handling_dialogs(content: Dictionary, target_id: String) -> Array:
	var out: Array = content.dialogs.filter(func(d): return d.target_id == target_id and is_handling(d))
	out.sort_custom(func(a, b): return int(a.order) < int(b.order))
	return out


## Ближайшая непроведённая встреча на связи или {}. Встречи с одним номером — варианты для
## разных исходов (например, после полиграфа): берётся та, чьи флаги уже поставлены.
static func next_handling(s: Dictionary, content: Dictionary, target_id: String) -> Dictionary:
	var groups := {}
	for d in handling_dialogs(content, target_id):
		if not groups.has(int(d.order)):
			groups[int(d.order)] = []
		groups[int(d.order)].append(d)
	var orders: Array = groups.keys()
	orders.sort()
	for o in orders:
		var group: Array = groups[o]
		if group.any(func(d): return s.get("handled", {}).has(d.dialog_id)):
			continue
		var ready: Array = group.filter(func(d): return d.get("requires", {}).get("flags", []).all(func(f): return s.flags.has(f)))
		return ready[0] if not ready.is_empty() else group[0]
	return {}


## Почему нельзя провести встречу на связи ("" — можно).
static func handling_error(s: Dictionary, content: Dictionary, dialog_id: String) -> String:
	var d := dialog_by_id(content, dialog_id)
	if d.is_empty() or not is_handling(d):
		return "Такой встречи нет"
	var ts = s.targets.get(d.target_id)
	if ts == null or not ts.recruited or ts.lost:
		return "Встречи на связи — только с завербованным агентом"
	if next_handling(s, content, d.target_id).get("dialog_id", "") != dialog_id:
		return "Эта встреча уже проведена или ещё не по порядку"
	var req: Dictionary = d.get("requires", {})
	if int(s.act) < int(req.get("act", 1)):
		return "Встреча — %s" % Fmt.op_phase_in(int(req.get("act", 1)))
	for f in req.get("flags", []):
		if not s.flags.has(f):
			return "Повода для встречи пока нет"
	if req.get("polygraph", false) and s.get("polygraph") == null:
		return "Встреча — когда «Кроноса» вызовут на полиграф"
	if req.get("polygraph", false) and s.polygraph.result != "":
		return "Проверка уже позади"
	if s.meeting != null:
		return "Встреча уже идёт"
	if s.phase != "evening":
		return "Встречи назначают на вечер"
	if s.tapes.any(func(t): return t.target_id == d.target_id and t.week == s.week):
		return "С этим агентом вы уже встречались на этой неделе"
	return ""


static func dialog_by_id(content: Dictionary, id: String) -> Dictionary:
	for d in content.dialogs:
		if d.dialog_id == id:
			return d
	return {}


static func trump_for(dialog: Dictionary, clue_id: String) -> Dictionary:
	for t in dialog.trumps:
		if t.clue_id == clue_id:
			return t
	return {}


## Почему нельзя назначить встречу ("" — можно).
static func meet_error(s: Dictionary, content: Dictionary, target_id: String) -> String:
	var ts = s.targets.get(target_id)
	if ts == null or not ts.unlocked:
		return "Кандидат ещё не установлен"
	if ts.recruited or ts.lost:
		return "Работа с этим кандидатом уже закончена"
	if dialog_for(content, target_id).is_empty():
		if content.ops.any(func(o): return o.get("contact_target_id", "") == target_id):
			return "Связь — только бесконтактная, через тайник: выход на карте"
		return "Для этого кандидата нет беседы"
	var need_op: String = dialog_for(content, target_id).get("requires_op", "")
	if need_op != "" and not ["clean", "tail_missed"].has(s.op_results.get(need_op, "")):
		return "Встреча назначается выходом в город: «%s» на карте" % Campaign.op_by_id(content, need_op).get("title", {}).get("ru", need_op)
	if s.meeting != null:
		return "Встреча уже идёт"
	if s.phase != "evening":
		return "Встречи назначают на вечер"
	if not Campaign.analysis_state(s, target_id).approved:
		return "Сначала утвердите заключение по делу на доске мотивов"
	if s.tapes.any(func(t): return t.target_id == target_id and t.week == s.week):
		return "С этим кандидатом вы уже встречались на этой неделе — вернитесь в другой день"
	return ""


static func start(s: Dictionary, content: Dictionary, target_id: String, dialog_id := "") -> Dictionary:
	var d := dialog_for(content, target_id) if dialog_id == "" else dialog_by_id(content, dialog_id)
	var ts: Dictionary = s.targets.get(target_id, {"rapport": int(d.get("start_rapport", 40)), "paranoia": int(d.get("start_anxiety", 20))})
	var r := int(ts.rapport)
	var a := int(ts.paranoia)
	# Встреча на связи: контакт — лояльность агента, настороженность — своя у встречи.
	if is_handling(d):
		r = int(s.agents.get(target_id, {}).get("loyalty", r))
		a = int(d.start_anxiety)
	return {
		"target_id": target_id, "dialog_id": d.dialog_id, "beat": 0,
		"rapport": r, "anxiety": a, "used": [], "coercion": 0,
		"lines": [{"kind": "setting"}, {"kind": "prompt", "beat": 0}],
	}


## Козыри, которые можно выложить сейчас: улика приколота к досье цели, в беседе для неё есть
## реплика, и она ещё не использовалась.
static func available_trumps(s: Dictionary, content: Dictionary, m: Dictionary) -> Array:
	var d := dialog_by_id(content, m.dialog_id)
	var pinned := {}
	for p in s.pinned:
		if p.target_id == m.target_id:
			pinned[p.clue_id] = true
	return d.trumps.filter(func(t): return pinned.has(t.clue_id) and not m.used.has(t.clue_id))


## Последствия хода (без изменения состояния): {dr, da, ready}.
static func turn_effects(d: Dictionary, m: Dictionary, tone: String, clue_id: String) -> Dictionary:
	var t: Dictionary = d.beats[m.beat].tones[tone]
	var out := {"dr": int(t.rapport), "da": int(t.anxiety), "ready": false}
	if clue_id != "":
		var tr := trump_for(d, clue_id)
		out.ready = m.rapport >= int(tr.min_rapport)
		var fx: Dictionary = tr.ready if out.ready else tr.early
		out.dr += int(fx.rapport)
		out.da += int(fx.anxiety)
	return out


## Ход резидента: возвращает новую встречу (исходную не меняет).
## Принуждение на встрече: каждый ответ нажимом и каждые предъявленные компрометирующие
## сведения. От порога (balance.meeting.coercion_threshold) агент получится неустойчивым.
static func is_coercive(content: Dictionary, target_id: String, tone: String, clue_id: String) -> int:
	var n := 1 if tone == "pressure" else 0
	if clue_id != "":
		var clue := Campaign.clue_by_id(content, clue_id)
		if clue.get("reveals", []).any(func(r): return r.target_id == target_id and r.axis == "compromise"):
			n += 1
	return n


static func apply_turn(d: Dictionary, meeting: Dictionary, tone: String, clue_id: String, coercion := 0) -> Dictionary:
	var m: Dictionary = meeting.duplicate(true)
	m.coercion = int(m.get("coercion", 0)) + coercion
	var fx := turn_effects(d, m, tone, clue_id)
	if clue_id == "":
		m.lines.append({"kind": "my_tone", "beat": m.beat, "tone": tone})
		m.lines.append({"kind": "reply_tone", "beat": m.beat, "tone": tone, "dr": fx.dr, "da": fx.da})
	else:
		m.used.append(clue_id)
		m.lines.append({"kind": "my_trump", "tone": tone, "clue_id": clue_id})
		m.lines.append({"kind": "reply_trump", "clue_id": clue_id, "ready": fx.ready, "dr": fx.dr, "da": fx.da})
	m.rapport = Util.clamp100(m.rapport + fx.dr)
	m.anxiety = Util.clamp100(m.anxiety + fx.da)
	m.beat += 1
	if m.beat < d.beats.size() and m.anxiety < max_anxiety(d):
		m.lines.append({"kind": "prompt", "beat": m.beat})
	return m


static func max_anxiety(d: Dictionary) -> int:
	return int(d.max_anxiety)


static func topics_left(d: Dictionary, m: Dictionary) -> bool:
	return m.beat < d.beats.size()


static func can_offer(d: Dictionary, m: Dictionary) -> bool:
	return m.rapport >= int(d.offer_rapport)


# ——— Тексты стенограммы ———

## Кто говорит: "me" (резидент), "them" (собеседник), "scene" (обстановка и итог).
static func speaker(line: Dictionary) -> String:
	match line.kind:
		"my_tone", "my_trump", "my_offer":
			return "me"
		"prompt", "reply_tone", "reply_trump", "reply_offer":
			return "them"
	return "scene"


## Текст строки (двуязычный словарь из контента) или {} для служебных строк.
static func line_text(d: Dictionary, line: Dictionary) -> Dictionary:
	match line.kind:
		"setting":
			return d.setting
		"prompt":
			return d.beats[line.beat].prompt
		"my_tone":
			return d.beats[line.beat].tones[line.tone].line
		"reply_tone":
			return d.beats[line.beat].tones[line.tone].reply
		"my_trump":
			return trump_for(d, line.clue_id).line
		"reply_trump":
			var tr := trump_for(d, line.clue_id)
			return tr.ready.reply if line.ready else tr.early.reply
		"my_offer":
			return d.offer.line
		"reply_offer":
			return d.offer.reply
	return {}


## Все записи беседы: завершённые катушки и идущая встреча.
static func all_tapes(s: Dictionary) -> Array:
	var out: Array = s.tapes.duplicate()
	if s.meeting != null:
		out.append({"target_id": s.meeting.target_id, "dialog_id": s.meeting.dialog_id, "week": s.week, "outcome": "", "lines": s.meeting.lines})
	return out


## Прозвучала ли оговорка (фраза улики с канала meeting) на какой-нибудь записи.
static func heard(s: Dictionary, content: Dictionary, clue: Dictionary) -> bool:
	for tape in all_tapes(s):
		if tape.dialog_id != clue.source.from:
			continue
		var d := dialog_by_id(content, tape.dialog_id)
		for line in tape.lines:
			if speaker(line) == "them" and String(line_text(d, line).get("ru", "")).contains(clue.chunk):
				return true
	return false


# ——— Проверка контента: можно ли выиграть беседу ———

## Лучший достижимый Раппорт, пока Тревога ниже предела, с данными козырями (поиск с памятью).
## Возвращает true, если идеальный игрок доходит до порога предложения.
static func winnable(d: Dictionary, rapport: int, anxiety: int, trump_ids: Array) -> bool:
	var trumps: Array = d.trumps.filter(func(t): return trump_ids.has(t.clue_id))
	return _search(d, trumps, 0, rapport, anxiety, 0, {})


static func _search(d: Dictionary, trumps: Array, beat: int, rapport: int, anxiety: int, used: int, memo: Dictionary) -> bool:
	if anxiety >= max_anxiety(d):
		return false
	if rapport >= int(d.offer_rapport):
		return true
	if beat >= d.beats.size():
		return false
	var key := "%d:%d:%d:%d" % [beat, rapport, anxiety, used]
	if memo.has(key):
		return false
	memo[key] = true
	for tone in TONES:
		var t: Dictionary = d.beats[beat].tones[tone]
		var dr := int(t.rapport)
		var da := int(t.anxiety)
		if _search(d, trumps, beat + 1, Util.clamp100(rapport + dr), Util.clamp100(anxiety + da), used, memo):
			return true
		for i in trumps.size():
			if used & (1 << i):
				continue
			var tr: Dictionary = trumps[i]
			var fx: Dictionary = tr.ready if rapport >= int(tr.min_rapport) else tr.early
			if _search(d, trumps, beat + 1, Util.clamp100(rapport + dr + int(fx.rapport)), Util.clamp100(anxiety + da + int(fx.anxiety)), used | (1 << i), memo):
				return true
	return false
