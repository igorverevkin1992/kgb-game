class_name T
## Строки интерфейса из i18n/ru.json (сейчас только русская версия; en.json заморожен).
## T.t("calendar.week", {"week": 2}) → «Неделя 2».

static var _dict := {}
static var _en := {}
static var lang := "ru"


static func _load() -> void:
	if _dict.is_empty():
		var r := Util.read_json("res://i18n/ru.json")
		_dict = r.data if r.ok else {}
		var e := Util.read_json("res://i18n/en.json")
		_en = e.data if e.ok else {}


static func t(key: String, params := {}) -> String:
	_load()
	var tpl: String = (_en.get(key, "") if lang == "en" else "")
	if tpl == "":
		tpl = _dict.get(key, key)
	for k in params:
		tpl = tpl.replace("{%s}" % k, str(params[k]))
	return tpl


static func keys() -> Array:
	_load()
	return _dict.keys()


## Двуязычный текст из контента на текущем языке.
static func loc(text: Variant) -> String:
	if typeof(text) != TYPE_DICTIONARY:
		return str(text)
	if lang == "en" and String(text.get("en", "")) != "":
		return text.en
	return text.get("ru", "")
