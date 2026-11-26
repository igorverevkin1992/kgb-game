extends TestCase
## Русская версия: никакой латиницы в том, что видит игрок (кроме плейсхолдеров {x} и римских цифр).


func _latin(text: String) -> Array:
	var cleaned := RegEx.create_from_string("\\{\\w+\\}").sub(text, "", true)
	cleaned = RegEx.create_from_string("\\b[IVX]+\\b").sub(cleaned, "", true)
	return RegEx.create_from_string("[A-Za-z]+").search_all(cleaned).map(func(m): return m.get_string())


func test_ui_strings() -> void:
	var bad: Array = []
	for k in T.keys():
		if not _latin(T.t(k)).is_empty():
			bad.append("%s: %s" % [k, T.t(k)])
	eq(bad, [])


func test_content_texts() -> void:
	var bad: Array = []
	_walk(H.content(), "content", bad)
	eq(bad, [])


func _walk(v: Variant, path: String, bad: Array) -> void:
	if typeof(v) == TYPE_ARRAY:
		for i in v.size():
			_walk(v[i], "%s[%d]" % [path, i], bad)
	elif typeof(v) == TYPE_DICTIONARY:
		if v.has("ru") and typeof(v.ru) == TYPE_STRING:
			if not _latin(v.ru).is_empty():
				bad.append("%s: %s" % [path, v.ru])
			return
		for k in v:
			_walk(v[k], "%s.%s" % [path, k], bad)


func test_engine_errors() -> void:
	var s := H.fresh()
	for a in [H.plan("op_a1_recon_first_virginia", []), {"type": "recruitment", "target_id": "tar_vargas_ellen", "result": "success"},
			H.report("truth"), {"type": "read_cable", "cable_id": "cable_a1_w3_intercept"}]:
		var err: String = Campaign.dispatch(s, H.content(), a).error
		ok(err != "")
		eq(_latin(err), [], err)


func test_money_and_dates() -> void:
	eq(Fmt.usd(40000), "40 000 долларов")
	eq(Fmt.usd(21), "21 доллар")
	eq(Fmt.usd(3), "3 доллара")
	eq(Fmt.usd(12), "12 долларов")
	eq(Fmt.date(Campaign.week_date(H.content(), 1, 1)), "1 октября 1984 г.")
	eq(Fmt.date(Campaign.week_date(H.content(), 1, 6)), "5 ноября 1984 г.")
	eq(T.t("desk.locked", {"act": 2}), "Откроется в акте 2")
