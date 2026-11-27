class_name TelemetrySummary
## Сводка журналов плейтеста (ui/telemetry.gd): где тестеры застревали, где бросали игру,
## какие действия у них не получались. Вход — сессии, каждая — массив записей из .jsonl.

const PHASE_RU := {"morning": "утро", "day": "день", "evening": "вечер", "night": "ночь"}
const VIEW_RU := {"": "стол", "map": "карта", "mice": "доска мотивов", "cipher": "шифрпункт",
	"finance": "журнал", "dialog": "магнитофон", "counterintel": "пульт", "inbox": "почта"}


## Место в игре одной строкой: «фаза 1 · неделя 3 · вечер · карта».
static func place(e: Dictionary) -> String:
	var c: Dictionary = e.get("ctx", {})
	if c.is_empty():
		return "—"
	return "фаза %s · неделя %s · %s · %s" % [_num(c.get("act", "?")), _num(c.get("week", "?")),
		PHASE_RU.get(c.get("phase", ""), "?"), VIEW_RU.get(c.get("view", ""), str(c.get("view", "")))]


## Числа из JSON приходят дробными: 1.0 → «1».
static func _num(v: Variant) -> String:
	return str(int(v)) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else str(v)


static func summarize(sessions: Array) -> Dictionary:
	var out := {"sessions": sessions.size(), "seconds": 0, "completed": 0, "endings": {}, "last_places": {},
		"stuck": {}, "idle": {}, "errors": {}, "hints": 0, "rejected_analysis": 0}
	for lines in sessions:
		if lines.is_empty():
			continue
		var done := false
		var last: Dictionary = {}
		for e in lines:
			match e.get("type", ""):
				"action":
					last = e
					if e.has("err"):
						out.errors[e.err] = out.errors.get(e.err, 0) + 1
					if e.get("a", "") == "use_hint":
						out.hints += 1
				"event":
					var ev: String = e.get("e", "")
					if (ev == "act_completed" and int(e.get("act", 0)) == 1) or (ev == "game_over" and (e.get("ending", "") == "campaign_complete" or Endings.is_final(e.get("ending", "")))):
						done = true
					if ev == "game_over":
						out.endings[e.get("ending", "?")] = out.endings.get(e.get("ending", "?"), 0) + 1
					if ev == "analysis_rejected":
						out.rejected_analysis += 1
				"stuck":
					var k := place(e)
					out.stuck[k] = out.stuck.get(k, 0) + 1
				"idle":
					var k := place(e)
					out.idle[k] = out.idle.get(k, 0) + int(e.get("seconds", 0))
				"view":
					last = e
		out.seconds += int(lines[-1].get("t", 0))
		if done:
			out.completed += 1
		elif not last.is_empty():
			var k := place(last)
			out.last_places[k] = out.last_places.get(k, 0) + 1
	return out


static func _top(d: Dictionary, n: int) -> Array:
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return d[a] > d[b])
	return keys.slice(0, n)


## Текст отчёта по-русски.
static func format(s: Dictionary) -> String:
	var lines: Array = []
	var n: int = s.sessions
	lines.append("Сессий: %d, общее время: %d мин." % [n, int(s.seconds / 60)])
	var pct := int(round(100.0 * s.completed / n)) if n > 0 else 0
	lines.append("Дошли до конца первой фазы операции: %d из %d (%d%%; цель плейтеста — от 80%%)." % [s.completed, n, pct])
	if not s.endings.is_empty():
		lines.append("Концовки: " + ", ".join(s.endings.keys().map(func(k): return "%s — %d" % [k, s.endings[k]])))
	for block in [["Где бросили игру (последнее действие)", "last_places", "%d"], ["Отметки «застрял здесь» (F8)", "stuck", "%d"],
			["Долгие раздумья (простой больше 2 минут, сумма секунд)", "idle", "%d с"], ["Частые отказы движка", "errors", "%d"]]:
		var d: Dictionary = s[block[1]]
		if d.is_empty():
			continue
		lines.append("")
		lines.append(block[0] + ":")
		for k in _top(d, 10):
			lines.append("  • %s — %s" % [k, block[2] % d[k]])
	lines.append("")
	lines.append("Подсказок взято: %d; отклонённых заключений по делу: %d." % [s.hints, s.rejected_analysis])
	return "\n".join(lines)
