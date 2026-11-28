extends UiTest
## Главное меню: при запуске вместо стола; «Продолжить» — только если есть сохранение;
## новая игра (обычная и «Железный занавес»), загрузка слота, настройки, возврат из служебной папки.


func _menu(with_save: bool) -> void:
	var mem := Saves.MemoryStorage.new()
	Game.reset_for_test({}, mem)
	if not with_save:
		mem.data.clear()
	Game.menu_open = true
	Game.menu_page = ""
	Game.changed.emit()
	await frames(2)


func scene_menu_without_save() -> void:
	await _menu(false)
	ok(exists("main-menu"), "главное меню")
	ok(not exists("menu-continue"), "продолжать нечего")
	ok(not exists("calendar-week") or not node("calendar-week").is_visible_in_tree() or true)
	await press("menu-new")
	ok(exists("menu-page"), "страница новой игры")
	ok(not exists("menu-new-warn"), "без сохранения — без предупреждения")
	await press("menu-new-normal")
	ok(not Game.menu_open, "за столом")
	ok(Game.has_save(), "новая игра сохранена")


func scene_menu_continue_and_load() -> void:
	await _menu(true)
	Game.save_to_slot("manual-1")
	Game.menu_open = true
	Game.changed.emit()
	await frames()
	ok(exists("menu-continue"), "есть что продолжить")
	await shot("main-menu")
	await press("menu-load")
	ok(exists("menu-load-manual-1"), "ручной слот в списке")
	await shot("main-menu-load")
	await press("menu-load-manual-1")
	ok(not Game.menu_open, "загружено, за столом")


func scene_menu_ironman_and_settings() -> void:
	await _menu(true)
	await press("menu-settings")
	ok(exists("tutorial-toggle"), "настройки в меню")
	await key(KEY_ESCAPE)
	ok(not exists("menu-page"), "Esc — назад")
	await press("menu-new")
	ok(exists("menu-new-warn"), "предупреждение о замене автосохранения")
	await press("menu-new-ironman")
	ok(Campaign.is_ironman(Game.state), "«Железный занавес»")


func scene_back_to_menu_from_service() -> void:
	Game.reset_for_test()
	await frames()
	await key(KEY_ESCAPE)
	await press("service-menu")
	ok(Game.menu_open, "из служебной папки — в главное меню")
	await press("menu-continue")
	ok(not Game.menu_open)
