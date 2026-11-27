extends TestCase
## Балансный прогон автоигроком (Autoplay) через настоящий движок: каждая стратегия
## приводит к своей концовке. Если правка контента или баланса это меняет — тест подскажет.

func test_careful_reaches_clean_triumph() -> void:
	var r := Autoplay.run(H.content(), "careful")
	eq(r.errors, [])
	eq(r.ending, "clean_triumph", "осторожная игра — «Чистый триумф»")
	eq(r.weeks.keys(), [1, 2, 3, 4], "пройдены все четыре фазы")


func test_rush_in_finale_burns_the_mole() -> void:
	var r := Autoplay.run(H.content(), "rush")
	eq(r.ending, "mole_arrested", "все аресты в одну ночь — каскад и арест «крота»")
	ok(r.state.flags.has("draconian_measures"))


func test_hasty_gets_expelled() -> void:
	eq(Autoplay.run(H.content(), "hasty").ending, "persona_non_grata", "игнорировать хвосты — высылка")


func test_meeting_path() -> void:
	var c := H.content()
	var d := Meeting.dialog_by_id(c, "dlg_a3_caldwell")
	var trumps: Array = d.trumps.filter(func(t): return ["clue_caldwell_snobs", "clue_caldwell_by_vargas"].has(t.clue_id))
	var path := Autoplay.meeting_path(d, 20, 40, trumps)
	ok(not path.is_empty(), "с козырями «самолюбие» и «долг» беседа выигрывается")
	ok(Autoplay.meeting_path(d, 20, 40, []).is_empty(), "без козырей — нет")
