extends UiTest
## Демоверсия: отметка на календаре, экран конца демоверсии, продолжение сохранения в полной игре.


func _demo_end() -> Dictionary:
	var s := H.fresh()
	s.flags.append(Campaign.DEMO_FLAG)
	for d in H.content().decisions:
		if int(d.act) < 3:
			s.decisions[d.decision_id] = d.options[0].option_id
	s.act = 2
	s.week = 16
	s.phase = "night"
	s.goal_reached = true
	return H.run(s, [{"type": "submit_report", "report": "truth"}])


func scene_demo_new_game_badge() -> void:
	Game.reset_for_test()
	Game.demo_build = true
	Game.new_game(false)
	await frames()
	ok(Campaign.is_demo(Game.state), "новая операция в демоверсии — с отметкой")
	has_text("calendar-demo", "Демоверсия")


func scene_demo_end_in_demo_build() -> void:
	Game.reset_for_test(_demo_end())
	Game.demo_build = true
	Game.changed.emit()
	await frames()
	has_text("ending", "КОНЕЦ ДЕМОВЕРСИИ")
	has_text("ending", "с третьей фазы")
	ok(not exists("ending-continue-full"), "в демоверсии продолжения нет")
	ok(not exists("ending-stats"), "итоги кампании — только в финале")
	await shot("demo-end")


func scene_demo_continue_in_full_game() -> void:
	Game.reset_for_test(_demo_end())
	await frames()
	await press("ending-continue-full")
	ok(Game.state.ending == null, "операция продолжается")
	eq(Game.state.act, 3)
	ok(not Campaign.is_demo(Game.state), "отметка демоверсии снята")
	has_text("phase-card", "Третья фаза операции")
	ok(not exists("calendar-demo"), "на календаре отметки больше нет")
