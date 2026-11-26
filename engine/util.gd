class_name Util
## Мелкие помощники движка: чтение JSON, нормализация чисел, работа с массивами.


## JSON в Godot отдаёт все числа как float. Целые значения (неделя 2.0) превращаем в int,
## иначе «Неделя 2.0» попадёт в интерфейс, а сравнения id/недель станут хрупкими.
static func normalize_numbers(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			if is_finite(f) and f == floor(f) and absf(f) < 9.0e15:
				return int(f)
			return f
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(normalize_numbers(x))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k in v:
				d[k] = normalize_numbers(v[k])
			return d
	return v


## Читает JSON-файл. Возвращает {ok, data} или {ok=false, error}.
static func read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "файл не открывается"}
	var text := f.get_as_text()
	return parse_json(text)


static func parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "error": "не JSON: строка %d — %s" % [json.get_error_line(), json.get_error_message()]}
	return {"ok": true, "data": normalize_numbers(json.data)}


static func clamp100(v: float) -> int:
	return int(clampf(roundf(v), 0, 100))


static func count_words(text: String) -> int:
	var n := 0
	for part in text.split(" ", false):
		for p in part.split("\n", false):
			if p.strip_edges() != "":
				n += 1
	return n


## Есть ли элемент в массиве (обёртка для читаемости правил).
static func has(arr: Array, item: Variant) -> bool:
	return arr.has(item)


static func without(arr: Array, item: Variant) -> Array:
	var out: Array = []
	for x in arr:
		if x != item:
			out.append(x)
	return out
