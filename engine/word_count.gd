class_name WordCount
## Контроль объёма текста (шаг 16): сколько слов в каждом разделе контента и интерфейса,
## сколько текста видно только в одной ветке решения (бриллиантовое ветвление: ветки должны
## расходиться ненадолго и сходиться обратно, а не плодить отдельные сюжеты).
## Слово — непрерывная последовательность букв и цифр (дефис внутри слова — одно слово).

## Разделы контента в отчёте — в порядке показа.
const GROUPS := ["cables", "clues", "dialogs", "targets", "ops", "decisions", "list", "polygraph",
	"archive", "campaign", "requests", "achievements", "operatives", "map", "cues", "ui"]

static var _re: RegEx


static func words(text: String) -> int:
	if _re == null:
		_re = RegEx.create_from_string("[\\p{L}\\p{N}]+(?:[-’'][\\p{L}\\p{N}]+)*")
	return _re.search_all(text).size()


## Слова во всех русских текстах значения (словари {ru: …} на любой глубине).
static func in_value(v: Variant) -> int:
	var out: Array = []
	ContentRules._collect_ru(v, "", "", out)
	var n := 0
	for x in out:
		n += words(x.text)
	return n


## {total, groups: {раздел: слова}}; ui — словарь строк интерфейса (ru.json), если нужен.
static func report(content: Dictionary, ui: Dictionary = {}) -> Dictionary:
	var groups := {}
	for g in GROUPS:
		if g == "ui":
			var n := 0
			for k in ui:
				if typeof(ui[k]) == TYPE_STRING:
					n += words(ui[k])
			groups[g] = n
		elif content.has(g):
			groups[g] = in_value(content[g])
	var total := 0
	for g in groups:
		total += int(groups[g])
	return {"total": total, "groups": groups}


## Текст, который увидит только игрок, выбравший конкретный вариант решения: решения и
## выходы, открытые флагом этого варианта. [{decision_id, option_id, flag, words}]
static func branches(content: Dictionary) -> Array:
	var out: Array = []
	for d in content.get("decisions", []):
		for o in d.options:
			var flag: String = o.effects.get("flag_set", "")
			if flag == "":
				continue
			var n := 0
			for x in content.get("decisions", []):
				if x.trigger.flag == flag:
					n += in_value(x)
			for op in content.get("ops", []):
				if op.get("requires_flags", []).has(flag):
					n += in_value(op)
			out.append({"decision_id": d.decision_id, "option_id": o.option_id, "flag": flag, "words": n + in_value(o.outcome)})
	return out
