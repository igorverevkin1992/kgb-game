extends TestCase
## Контроль объёма (шаг 16): счётчик слов, отчёт по разделам, потолок слов, толстые ветки,
## бриллиантовое ветвление — при любом варианте решения задачи следующих фаз достижимы.

func test_words() -> void:
	eq(WordCount.words("Шифртелеграмма в две строки: сдать дела — и вылететь."), 8, "тире не слово")
	eq(WordCount.words("«Кронос» и 50 000 долларов"), 5)
	eq(WordCount.words("северо-запад"), 1, "слово через дефис — одно")


func test_report() -> void:
	var r := WordCount.report(H.content(), {"a": "Два слова", "b": 3})
	eq(r.groups.ui, 2)
	ok(r.groups.cables > 0 and r.groups.dialogs > 0)
	var sum := 0
	for g in r.groups:
		sum += r.groups[g]
	eq(r.total, sum)


func test_budget_ceiling() -> void:
	var e := H.entries()
	H.file(e, "balance.json").text_budget.max_words = 1000
	has_issue(H.errors(e), "volume", "больше потолка")


func test_fat_branch_warning() -> void:
	var e := H.entries()
	H.file(e, "balance.json").text_budget.branch_share_max = 0.0001
	var r := ContentLoader.validate(e)
	ok(r.warnings.any(func(w): return w.rule == "volume" and String(w.message).contains("слишком толстая")))


func test_diamond_must_converge() -> void:
	var e := H.entries()
	# Большой сброс доступен только после «заморозки» связи — при других вариантах ветка не сходится.
	H.file(e, "ops/op_a3_big_drop.json").requires_flags = ["package_accepted", "kronos_frozen"]
	has_issue(H.errors(e), "diamond", "calm")
