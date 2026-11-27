class_name Decisions
## Решения резидента: документ с несколькими вариантами и видимыми последствиями (раскрытие
## «Монополии», товарищ под наружкой и т. п.). Появляется, когда выполнено условие trigger
## (неделя, найденные сведения, флаг). Пока решение не принято, неделю не закрыть докладом.


static func by_id(content: Dictionary, id: String) -> Dictionary:
	for d in content.get("decisions", []):
		if d.decision_id == id:
			return d
	return {}


static func option(d: Dictionary, option_id: String) -> Dictionary:
	for o in d.options:
		if o.option_id == option_id:
			return o
	return {}


static func triggered(s: Dictionary, d: Dictionary) -> bool:
	var t: Dictionary = d.trigger
	# Решение относится к своей фазе операции: после неё оно уже не актуально.
	if int(d.act) != int(s.act):
		return false
	if int(t.week) > 0 and int(s.week) < int(t.week):
		return false
	if t.clue_id != "" and not s.clues.has(t.clue_id):
		return false
	if t.flag != "" and not s.flags.has(t.flag):
		return false
	return true


## Решения, которые ждут резидента.
static func pending(s: Dictionary, content: Dictionary) -> Array:
	return content.get("decisions", []).filter(func(d): return not s.decisions.has(d.decision_id) and triggered(s, d))


## Решения, уже поступившие (ждут или приняты) — для лотка почты.
static func arrived(s: Dictionary, content: Dictionary) -> Array:
	return content.get("decisions", []).filter(func(d): return s.decisions.has(d.decision_id) or triggered(s, d))


## Еженедельная наружка от принятых решений (например, оперативная игра с дезинформацией).
static func weekly_sog(s: Dictionary, content: Dictionary) -> int:
	var n := 0
	for id in s.decisions:
		var o := option(by_id(content, id), s.decisions[id])
		n += int(o.get("effects", {}).get("weekly_sog_heat", 0))
	return n
