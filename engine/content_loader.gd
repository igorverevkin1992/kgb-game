class_name ContentLoader
## Чтение и проверка контента из папки `content/`. Результат `load_dir()`:
##   {content: Dictionary|null, issues: Array, errors: Array, warnings: Array}
## content — словарь: campaign, balance, map, cues, targets, clues, cables, ops, polygraph, requests, dialogs.

const DEFAULT_DIR := "res://content"
const SINGLE := {
	"campaign.json": "campaign",
	"balance.json": "balance",
	"map/sites.json": "map",
	"map/cues.json": "cues",
}
## Папки: тип контента и лежит ли в файле массив элементов.
const FOLDERS := {
	"targets": {"spec": "target", "id": "target_id", "list": false, "kind": "Цель"},
	"clues": {"spec": "clue", "id": "clue_id", "list": true, "kind": "Улика"},
	"cables": {"spec": "cable", "id": "cable_id", "list": true, "kind": "Депеша"},
	"ops": {"spec": "op", "id": "op_id", "list": false, "kind": "Операция"},
	"polygraph": {"spec": "polygraph", "id": "exam_id", "list": false, "kind": "Экзамен"},
	"requests": {"spec": "request", "id": "request_id", "list": true, "kind": "Запрос в Центр"},
	"dialogs": {"spec": "dialog", "id": "dialog_id", "list": false, "kind": "Беседа"},
	"achievements": {"spec": "achievement", "id": "id", "list": true, "kind": "Достижение"},
	"archive": {"spec": "archive", "id": "id", "list": true, "kind": "Запись архива"},
	"operatives": {"spec": "operative", "id": "operative_id", "list": true, "kind": "Оперработник"},
	"decisions": {"spec": "decision", "id": "decision_id", "list": false, "kind": "Решение резидента"},
	"list": {"spec": "list_card", "id": "card_id", "list": true, "kind": "Дело из «Списка»"},
	"tasks": {"spec": "centre_task", "id": "task_id", "list": true, "kind": "Задание Центра"},
	"tutorial": {"spec": "tutorial_step", "id": "step_id", "list": true, "kind": "Шаг обучения"},
	"help": {"spec": "help", "id": "view", "list": true, "kind": "Памятка модуля"},
}

static var _cached := {}


## Все *.json в папке (рекурсивно), пути относительно неё: [{path, data}] и битые файлы.
static func read_dir(dir: String = DEFAULT_DIR) -> Dictionary:
	var entries: Array = []
	var broken: Array = []
	_walk(dir, "", entries, broken)
	entries.sort_custom(func(a, b): return a.path < b.path)
	return {"entries": entries, "broken": broken}


static func _walk(root: String, rel: String, entries: Array, broken: Array) -> void:
	var d := DirAccess.open(root.path_join(rel))
	if d == null:
		return
	for sub in d.get_directories():
		_walk(root, rel.path_join(sub) if rel != "" else sub, entries, broken)
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var path := rel.path_join(f) if rel != "" else f
		var r := Util.read_json(root.path_join(path))
		if r.ok:
			entries.append({"path": path, "data": r.data})
		else:
			broken.append({"path": path, "message": r.error})


## Полная проверка: схемы, затем связи и правила дизайна (ContentRules).
static func validate(entries: Array, opts := {}) -> Dictionary:
	var parsed := parse(entries)
	var issues: Array = parsed.issues.duplicate()
	var schema_ok: bool = parsed.content != null and issues.all(func(x): return x.level != "error")
	if schema_ok:
		issues.append_array(ContentRules.check(parsed.content, parsed.file_of, opts))
	return {
		"content": parsed.content if schema_ok else null,
		"issues": issues,
		"errors": issues.filter(func(x): return x.level == "error"),
		"warnings": issues.filter(func(x): return x.level == "warning"),
		"file_of": parsed.file_of,
	}


## Проверенный контент игры (кэшируется). Ошибки контента — фатальны: в игру он не попадёт молча.
static func game_content() -> Dictionary:
	if _cached.is_empty():
		var r := read_dir()
		var report := validate(r.entries)
		if report.content == null or not report.errors.is_empty() or not r.broken.is_empty():
			var lines: Array = r.broken.map(func(b): return "%s: %s" % [b.path, b.message])
			lines.append_array(report.errors.map(format_issue))
			push_error("Контент игры содержит ошибки:\n" + "\n".join(lines))
			return {}
		_cached = report.content
	return _cached


static func parse(entries: Array) -> Dictionary:
	var issues: Array = []
	var file_of := {}
	var content := {"targets": [], "clues": [], "cables": [], "ops": [], "polygraph": [], "requests": [], "dialogs": [], "achievements": [], "archive": [], "operatives": [], "decisions": [], "list": [], "tasks": [], "tutorial": [], "help": []}
	var singles := {}

	var register := func(id: String, kind: String, path: String) -> void:
		if file_of.has(id):
			issues.append({"level": "error", "rule": "duplicate", "file": path, "message": "%s «%s» уже описан(а) в файле %s" % [kind, id, file_of[id]]})
		else:
			file_of[id] = path

	for entry in entries:
		var path: String = entry.path.replace("\\", "/").trim_prefix("./")
		if SINGLE.has(path):
			singles[SINGLE[path]] = {"path": path, "data": entry.data}
			continue
		var folder: String = path.get_slice("/", 0) if path.contains("/") else ""
		if not FOLDERS.has(folder):
			issues.append({"level": "error", "rule": "layout", "file": path, "message": "Файл лежит вне известных папок. Допустимо: campaign.json, balance.json, map/sites.json, map/cues.json, targets/, clues/, cables/, ops/, polygraph/, requests/, dialogs/, achievements/, archive/, operatives/, decisions/, list/, tasks/, tutorial/, help/"})
			continue
		var f: Dictionary = FOLDERS[folder]
		var spec := ContentSchemas.get_spec(f.spec)
		if f.list:
			if typeof(entry.data) != TYPE_ARRAY:
				issues.append({"level": "error", "rule": "schema", "file": path, "where": "(весь файл)", "message": "ожидался массив [ … ]"})
				continue
			for i in (entry.data as Array).size():
				var n := issues.size()
				var item = Schema.check(entry.data[i], spec, path, "[%d]" % i, issues)
				if _no_new_errors(issues, n):
					register.call(item[f.id], f.kind, path)
					content[folder].append(item)
		else:
			var n := issues.size()
			var item = Schema.check(entry.data, spec, path, "", issues)
			if _no_new_errors(issues, n):
				register.call(item[f.id], f.kind, path)
				content[folder].append(item)

	for key in ["campaign", "balance", "map", "cues"]:
		if not singles.has(key):
			var name: String = SINGLE.find_key(key)
			issues.append({"level": "error", "rule": "layout", "message": "Нет файла %s" % name})
			continue
		var n := issues.size()
		var v = Schema.check(singles[key].data, ContentSchemas.get_spec(key), singles[key].path, "", issues)
		if _no_new_errors(issues, n):
			content[key] = v
	if content.has("map"):
		for site in content.map.sites:
			register.call(site.site_id, "Точка карты", "map/sites.json")
	if content.has("cues"):
		for cue in content.cues:
			register.call(cue.tag, "Примета", "map/cues.json")

	var complete := ["campaign", "balance", "map", "cues"].all(func(k): return content.has(k))
	return {"content": content if complete else null, "issues": issues, "file_of": file_of}


static func _no_new_errors(issues: Array, since: int) -> bool:
	for i in range(since, issues.size()):
		if issues[i].level == "error":
			return false
	return true


const RULE_RU := {
	"schema": "формат", "layout": "файлы", "duplicate": "повтор", "refs": "ссылки", "unlock": "открытие цели",
	"three-clue": "три улики", "mice-three-clue": "три улики на мотив", "softlock": "тупик",
	"robustness": "устойчивость", "unreachable": "недостижимо", "sdr": "проверочный маршрут",
	"weeks": "недели", "text-length": "длина текста", "translation": "перевод", "polygraph": "полиграф",
	"balance": "баланс", "board": "доска мотивов", "cipher": "шифроузел", "dialog": "беседа", "finance": "финансы", "achievements": "достижения", "age16": "возраст 16+", "archive": "архив", "decisions": "решения", "delegation": "поручения", "technique": "приёмы наружки", "package": "пробный пакет", "blind-window": "слепое окно", "list": "«Окно арестов»", "tasks": "задания Центра", "volume": "объём текста", "diamond": "ветвление",
}


static func format_issue(i: Dictionary) -> String:
	var place: Array = []
	if i.get("file", "") != "":
		place.append(i.file)
	if i.get("where", "") != "":
		place.append(i.where)
	var p := " → ".join(place)
	return "%s%s [%s]" % [(p + ": ") if p != "" else "", i.message, RULE_RU.get(i.rule, i.rule)]
