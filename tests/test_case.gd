class_name TestCase
extends RefCounted
## База для тестов: методы test_* запускает tests/run_tests.gd. Проверки копят ошибки,
## тест не падает на первой — видно все расхождения сразу.

var failures: Array[String] = []


func eq(actual: Variant, expected: Variant, msg := "") -> void:
	if not _same(actual, expected):
		failures.append("%sожидалось %s, получено %s" % [_m(msg), _s(expected), _s(actual)])


func ok(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%sусловие не выполнено" % _m(msg))


func has_text(text: String, part: String, msg := "") -> void:
	if not text.contains(part):
		failures.append("%sв «%s» нет «%s»" % [_m(msg), text, part])


## Есть ли среди проблем валидатора проблема с этим правилом (и, если задано, фрагментом текста).
func has_issue(issues: Array, rule: String, part := "", msg := "") -> void:
	for i in issues:
		if i.rule == rule and i.level == "error" and (part == "" or String(i.message).contains(part)):
			return
	failures.append("%sнет ошибки [%s]%s; есть: %s" % [_m(msg), rule, (" с «%s»" % part) if part != "" else "", _s(issues.map(func(x): return "%s: %s" % [x.rule, x.message]))])


func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(a), float(b))
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if typeof(a) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(b) in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(a) == String(b)
	return typeof(a) == typeof(b) and a == b


func _m(msg: String) -> String:
	return (msg + ": ") if msg != "" else ""


func _s(v: Variant) -> String:
	var t := JSON.stringify(v) if typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY] else str(v)
	return t.substr(0, 300)
