extends TestCase
## Возрастная категория 16+: табак и алкоголь — предупреждение, мат — ошибка; без ложных срабатываний.


func _issues(text: String) -> Array:
	var e := H.entries()
	var cues: Array = H.file(e, "map/cues.json")
	cues[0].text.ru = text
	return ContentLoader.validate(e).issues.filter(func(i): return i.rule == "age16")


func test_tobacco_and_alcohol_warn() -> void:
	var w := _issues("Мужчина курит у входа")
	eq(w.size(), 1)
	eq(w[0].level, "warning")
	has_text(w[0].message, "табак")
	has_text(_issues("Агент выпил рюмку коньяка")[0].message, "алкоголя")


func test_obscene_is_error() -> void:
	var e := _issues("Ну и мудак же он")
	ok(e.any(func(i): return i.level == "error"), "мат — ошибка")


func test_no_false_positives() -> void:
	eq(_issues("Курьер принёс мудрое письмо о курсе валют; окурков нет, рядом старая пивоварня"), [])
	eq(ContentLoader.validate(H.entries()).issues.filter(func(i): return i.rule == "age16"), [], "текущий контент чист")
