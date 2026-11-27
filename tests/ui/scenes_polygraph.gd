extends UiTest
## Полиграф ЦРУ на пульте обстановки: карта предтестового состояния, репетиция, лента с тремя
## кривыми, пик на значимом вопросе и объяснение волнения, итог проверки.

const CAL := "tar_caldwell_arthur"


func _at(week: int, agents: Array) -> Dictionary:
	var s := H.act4_state(agents)
	s.week = week - 1
	s.phase = "night"
	return H.run(s, [H.report("truth")])


func scene_prep_and_rehearsal() -> void:
	Game.reset_for_test(_at(44, [CAL, "tar_jenkins_clara"]))
	await frames(3)
	await key(KEY_6)
	await press("console-tab-polygraph")
	has_text("polygraph-examiner", "Хэллман")
	has_text("polygraph-slots", "0 из 4")
	await press("prep-do-prep_sleep_order")
	await press("prep-do-prep_strategy_friendly")
	has_text("polygraph-summary", "устойчивость 15")
	ok(not exists("polygraph-begin"), "проверка — на следующей неделе")
	await press("polygraph-rehearse")
	await press("answer-fishing")
	await press("answer-joke")
	await press("answer-plain")
	await press("answer-limited_hangout")
	has_text("answer-calm_no", "пик реакции 45")
	await press("answer-calm_no")
	await shot("polygraph-rehearsal")


func scene_spike_and_verdict() -> void:
	var s := _at(45, [CAL])
	s.agents[CAL].lifestyle = 90
	Game.reset_for_test(s)
	await frames(3)
	await key(KEY_6)
	await press("console-tab-polygraph")
	has_text("polygraph-examiner", "неизвестен")
	await press("polygraph-begin")
	for id in ["settle", "joke", "plain", "limited_hangout", "angry_no"]:
		await press("answer-" + id)
	has_text("polygraph-question", "объяснить волнение")
	await shot("polygraph-spike")
	await press("rationalize-defector")
	for id in ["apples", "calm_no"]:
		await press("answer-" + id)
	await press("rationalize-witch_hunt")
	await press("answer-defector")
	ok(Game.state.polygraph.result != "", "итог записан")
	ok(exists("polygraph-outcome"), "итог проверки на ленте")
	await shot("polygraph-verdict")
