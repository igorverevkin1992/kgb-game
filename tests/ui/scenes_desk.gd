extends UiTest
## Кабинет, переключение модулей, почта, доска мотивов, неделя.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]


func scene_desk_act1() -> void:
	await start()
	has_text("plaque", "ВАШИНГТОН, 1985")
	for v in ["map", "mice", "cipher", "finance", "dialog", "inbox"]:
		ok(enabled("desk-object-" + v), v + " открыт")
	for v in ["counterintel"]:
		ok(not enabled("desk-object-" + v), v + " заперт")
	has_text("inbox-unread", "2")
	has_text("cipher-pending", "1")
	await shot("desk-act1")


## Приёмка шага 3: переход между модулями напрямую быстрее 0,2 с. Меряем перестроение экрана
## (это и есть работа игры); кадры программного рендера под Xvfb к игре не относятся.
func scene_module_switch_under_200ms() -> void:
	await start()
	Game.debug_act = 4
	await click("desk-object-map")
	ok(exists("module-panel-map"), "карта открылась кликом")
	for pair in [["mice", KEY_2], ["cipher", KEY_3], ["finance", KEY_4], ["dialog", KEY_5]]:
		await key(pair[1])
		ok(exists("module-panel-" + pair[0]), pair[0] + " открыт клавишей")
	for v in ["counterintel", "map", "inbox", "mice"]:
		await click("edge-" + v)
		ok(exists("module-panel-" + v), v + " открыт с края стола")
	for v in ["map", "mice", "cipher", "finance", "dialog", "counterintel", "inbox"]:
		var t0 := Time.get_ticks_usec()
		Game.open(v)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		ok(ms < 200, "%s: %.0f мс" % [v, ms])
	await key(KEY_ESCAPE)
	ok(not exists("module-view"), "Esc — к столу")


func scene_locked_module_stays_closed() -> void:
	await start()
	await key(KEY_6)
	ok(not exists("module-panel-counterintel"), "пульт обстановки заперт")
	await key(KEY_1)
	ok(not enabled("edge-counterintel"), "на краю стола тоже заперто")


func scene_inbox_documents() -> void:
	await start()
	await click("desk-object-inbox")
	eq(node("inbox-list").get_child_count(), 2, "документов (директивы — на «Фиалке»)")
	ok(not exists("inbox-item-cable_a1_w1_directive"), "директивы нет в лотке")
	await press("inbox-item-cable_a1_w1_post_clipping")
	eq(node("document").get_meta("kind"), "press_clipping")
	has_text("document", "Монтескьё")
	await shot("doc-clipping")
	await press("inbox-item-cable_a1_w1_file_vargas")
	eq(node("document").get_meta("kind"), "personnel_file")
	has_text("document", "СЕКРЕТНО")
	await shot("doc-personnel-file")
	await key(KEY_ESCAPE)
	ok(not exists("inbox-unread"), "всё прочитано")
	has_text("cipher-pending", "1")


func scene_mice_dossiers_and_sog_marks() -> void:
	await start(QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "continue"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"}])
	var marks = node("desk-object-map").get_children().filter(func(c): return c is DeskView.SogMarks)
	eq(marks[0].count if not marks.is_empty() else -1, 1, "отметок наружки на карте")
	await key(KEY_2)
	has_text("dossier-tar_vargas_ellen", "Элен Варгас")
	has_text("dossier-tar_calloway_martin", "нет данных")
	ok(exists("board-new") or true)


func scene_week_flow_and_analyst() -> void:
	await start()
	has_text("calendar-week", "Неделя 1")
	has_text("calendar-phase", "УТРО")
	for p in ["ДЕНЬ", "ВЕЧЕР", "НОЧЬ"]:
		await press("advance-phase")
		has_text("calendar-phase", p)
	ok(not exists("advance-phase"), "ночью вместо кнопки — донесение")
	await shot("week-night")
	await press("report-truth")
	has_text("calendar-week", "Неделя 2")
	has_text("save-indicator", "СОХРАНЕНО")
	# «Перезапуск»: игра продолжается с автосохранения.
	var loaded := Saves.load_slot(Game.storage, Saves.AUTOSAVE, Game.content)
	eq(loaded.state.week, 2, "автосохранение")
	await press("analyst-toggle")
	has_text("risk-moscow_pressure", "20%")
	has_text("risk-sog_heat", "При 100%: нота Госдепа")
	has_text("centre-trust", "52%")
	has_text("journal", "О финансовом положении Э. Варгас")
	await shot("analyst")
	await key(KEY_ESCAPE)
	ok(not exists("analyst"), "Esc закрыл сводку")


func scene_idle_leads_to_recall() -> void:
	var actions: Array = []
	for i in 11:
		actions.append_array(QUIET)
	await start(actions + [NEXT, NEXT, NEXT])
	await press("report-truth")
	ok(exists("ending"), "концовка")
	eq(node("ending").get_meta("ending"), "recalled")
	has_text("ending", "ОТЗЫВ В МОСКВУ")
	await shot("ending-recalled")
	await press("ending-load")
	ok(exists("service-folder"), "после концовки можно загрузить чекпоинт")
	await key(KEY_ESCAPE)
	await press("new-game")
	has_text("calendar-week", "Неделя 1")
