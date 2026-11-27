extends UiTest
## Обучение: записка заместителя ведёт по первой неделе и подсвечивает нужный предмет; шаг
## закрывается сам; памятка модуля — при первом открытии и по кнопке; выключатель.


func _on() -> void:
	Game.settings.tutorial = true
	Game.settings.tutorial_ack = []
	Game.settings.help_seen = []
	Game.changed.emit()
	await frames(3)


func scene_first_steps() -> void:
	Game.reset_for_test()
	await _on()
	ok(exists("tutorial-note"), "записка наставника на столе")
	has_text("tutorial-note", "Входящие")
	ok(exists("tutorial-highlight"), "лоток подсвечен")
	await shot("tutorial-desk")
	await key(KEY_7)
	ok(exists("help-card"), "памятка при первом входе в модуль")
	has_text("help-card", "Входящие")
	await shot("tutorial-help")
	await press("help-ok")
	ok(not exists("help-card"), "памятка закрыта")
	ok(Game.settings.help_seen.has("inbox"), "больше сама не откроется")
	has_text("tutorial-note", "Выделенные цветом")
	await press("help-button")
	ok(exists("help-card"), "памятка по кнопке")
	await press("help-ok")


func scene_skip_and_off() -> void:
	Game.reset_for_test()
	await _on()
	await press("tutorial-skip")
	ok(Game.settings.tutorial_ack.has("tut_inbox"), "шаг пропущен")
	await press("tutorial-off")
	ok(not exists("tutorial-note"), "обучение выключено")


func scene_later_save_skips_done_steps() -> void:
	Game.reset_for_test(H.act3_state(["tar_vargas_ellen"]))
	await _on()
	has_text("tutorial-note", "Дальше — сами")
	await press("tutorial-ack")
	ok(not exists("tutorial-note"), "обучение пройдено")
