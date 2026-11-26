class_name Schema
## Компактная проверка данных по схеме (замена Zod). Схема — словарь:
##   {"type": "string", "pattern": "^tar_", "msg": "…"}      строка (pattern — регулярное выражение)
##   {"type": "int", "min": 0, "max": 100}                     целое
##   {"type": "number", "min": 0, "max": 1}                    число
##   {"type": "bool"} · {"type": "enum", "values": [...]}
##   {"type": "text"}                                          двуязычный текст {ru, en?}
##   {"type": "array", "of": схема, "min": 1, "len": 3}
##   {"type": "dict", "of": схема}                             словарь с произвольными ключами
##   {"type": "object", "fields": {имя: схема}}
## Поле объекта может иметь "optional": true, "default": значение, "nullable": true.
## Результат: значение с подставленными значениями по умолчанию; ошибки — в issues (по-русски).

const TEXT := {"type": "object", "fields": {
	"ru": {"type": "string", "min_len": 1, "msg": "русский текст не может быть пустым"},
	"en": {"type": "string", "optional": true},
}}


static func check(value: Variant, spec: Dictionary, file: String, path: String, issues: Array) -> Variant:
	var t: String = spec.get("type", "")
	if t == "text":
		return check(value, TEXT, file, path, issues)
	if value == null and spec.get("nullable", false):
		return null
	match t:
		"any":
			return value
		"string":
			if typeof(value) != TYPE_STRING:
				return _err(issues, file, path, "ожидалась строка")
			if spec.has("min_len") and String(value).length() < int(spec.min_len):
				return _err(issues, file, path, spec.get("msg", "строка слишком короткая"))
			if spec.has("pattern"):
				var re := RegEx.create_from_string(spec.pattern)
				if re.search(value) == null:
					return _err(issues, file, path, spec.get("msg", "строка не подходит под формат"))
			return value
		"int":
			if typeof(value) != TYPE_INT:
				return _err(issues, file, path, "ожидалось целое число")
			return _range(value, spec, file, path, issues)
		"number":
			if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
				return _err(issues, file, path, "ожидалось число")
			return _range(value, spec, file, path, issues)
		"bool":
			if typeof(value) != TYPE_BOOL:
				return _err(issues, file, path, "ожидалось true или false")
			return value
		"enum":
			if not (spec.values as Array).has(value):
				return _err(issues, file, path, "допустимо: %s" % ", ".join((spec.values as Array).map(func(x): return str(x))))
			return value
		"array":
			if typeof(value) != TYPE_ARRAY:
				return _err(issues, file, path, "ожидался массив [ … ]")
			var arr: Array = value
			if spec.has("len") and arr.size() != int(spec.len):
				_err(issues, file, path, spec.get("msg", "нужно ровно %d элемента(ов)" % int(spec.len)))
			if spec.has("min") and arr.size() < int(spec.min):
				_err(issues, file, path, "нужно минимум %d элемент(а)" % int(spec.min))
			var out: Array = []
			for i in arr.size():
				out.append(check(arr[i], spec.of, file, "%s[%d]" % [path, i], issues))
			return out
		"dict":
			if typeof(value) != TYPE_DICTIONARY:
				return _err(issues, file, path, "ожидался объект { … }")
			var d: Dictionary = {}
			for k in value:
				d[k] = check(value[k], spec.of, file, _join(path, str(k)), issues)
			return d
		"object":
			if typeof(value) != TYPE_DICTIONARY:
				return _err(issues, file, path, "ожидался объект { … }")
			var src: Dictionary = value
			var fields: Dictionary = spec.fields
			var out := {}
			for name in fields:
				var fs: Dictionary = fields[name]
				var p := _join(path, name)
				if not src.has(name):
					if fs.has("default"):
						out[name] = fs.default.duplicate(true) if typeof(fs.default) in [TYPE_ARRAY, TYPE_DICTIONARY] else fs.default
					elif not fs.get("optional", false):
						_err(issues, file, p, "обязательное поле")
					continue
				out[name] = check(src[name], fs, file, p, issues)
			for name in src:
				if not fields.has(name):
					issues.append({"level": "warning", "rule": "schema", "file": file, "where": _join(path, name), "message": "неизвестное поле «%s» — опечатка?" % name})
			return out
	push_error("Schema: неизвестный тип %s" % t)
	return value


static func _range(value: Variant, spec: Dictionary, file: String, path: String, issues: Array) -> Variant:
	if spec.has("min") and value < spec.min:
		return _err(issues, file, path, "не меньше %s" % str(spec.min))
	if spec.has("max") and value > spec.max:
		return _err(issues, file, path, "не больше %s" % str(spec.max))
	return value


static func _err(issues: Array, file: String, path: String, msg: String) -> Variant:
	issues.append({"level": "error", "rule": "schema", "file": file, "where": path if path != "" else "(весь файл)", "message": msg})
	return null


static func _join(path: String, name: String) -> String:
	return name if path == "" else "%s.%s" % [path, name]


# ——— Конструкторы схем, чтобы описания контента читались проще ———

static func s(pattern := "", msg := "") -> Dictionary:
	var d := {"type": "string"}
	if pattern != "":
		d["pattern"] = pattern
		d["msg"] = msg
	return d


static func id(prefix: String) -> Dictionary:
	return s("^%s_[a-z0-9_]+$" % prefix, "id должен начинаться с «%s_»: латиница в нижнем регистре, цифры и «_»" % prefix)


static func i(min_v: Variant = null, max_v: Variant = null) -> Dictionary:
	var d := {"type": "int"}
	if min_v != null:
		d["min"] = min_v
	if max_v != null:
		d["max"] = max_v
	return d


static func n(min_v: Variant = null, max_v: Variant = null) -> Dictionary:
	var d := {"type": "number"}
	if min_v != null:
		d["min"] = min_v
	if max_v != null:
		d["max"] = max_v
	return d


static func e(values: Array) -> Dictionary:
	return {"type": "enum", "values": values}


static func arr(of: Dictionary, min_v := -1) -> Dictionary:
	var d := {"type": "array", "of": of}
	if min_v >= 0:
		d["min"] = min_v
	return d


static func obj(fields: Dictionary) -> Dictionary:
	return {"type": "object", "fields": fields}


## Сделать поле необязательным (с значением по умолчанию, если оно передано).
static func opt(spec: Dictionary, default_value: Variant = null) -> Dictionary:
	var d := spec.duplicate(true)
	if default_value != null:
		d["default"] = default_value
	else:
		d["optional"] = true
	return d


static func nullable(spec: Dictionary) -> Dictionary:
	var d := spec.duplicate(true)
	d["nullable"] = true
	return d
