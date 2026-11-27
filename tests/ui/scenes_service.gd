extends UiTest
## Служебная папка: сохранения, чекпоинты, «Железный занавес», размер текста.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]


func scene_esc_and_plaque_open_folder() -> void:
	await start()
	await key(KEY_ESCAPE)
	ok(exists("service-folder"), "Esc на столе")
	await shot("service-saves")
	await key(KEY_ESCAPE)
	ok(not exists("service-folder"), "Esc закрыл")
	await click("plaque")
	ok(exists("service-folder"), "по табличке")


func scene_manual_slot_save_and_load() -> void:
	await start()
	await key(KEY_ESCAPE)
	await press("save-manual-1")
	has_text("slot-manual-1", "Неделя 1")
	await key(KEY_ESCAPE)
	for i in 3:
		await press("advance-phase")
	await press("report-truth")
	has_text("calendar-week", "Неделя 2")
	await key(KEY_ESCAPE)
	await press("load-manual-1")
	ok(not exists("service-folder"), "папка закрылась")
	has_text("calendar-week", "Неделя 1")


func scene_month_checkpoint() -> void:
	await start(QUIET + QUIET + QUIET + QUIET + [NEXT, NEXT, NEXT])
	# Неделя 5: сначала решение резидента («Журналист просит интервью»), потом доклад.
	Game.dispatch({"type": "decide", "decision_id": "dec_a1_journalist", "option_id": "decline"})
	await frames()
	await press("report-truth")
	has_text("calendar-week", "Неделя 6")
	await key(KEY_ESCAPE)
	has_text("checkpoints", "Неделя 6")
	await press("load-checkpoint-a1-w6")
	has_text("calendar-week", "Неделя 6")
	has_text("calendar-phase", "ПОНЕДЕЛЬНИК")


func scene_ironman() -> void:
	await start()
	await key(KEY_ESCAPE)
	await press("new-campaign")
	var cb := node("ironman-toggle") as CheckBox
	cb.button_pressed = true
	await press("new-campaign-confirm")
	await key(KEY_ESCAPE)
	has_text("saves", "Железный занавес")
	ok(not enabled("save-manual-1"), "ручные сохранения недоступны")
	has_text("saves", "контрольных точек нет")


func scene_text_scale() -> void:
	await start()
	await key(KEY_ESCAPE)
	await press("service-tab-settings")
	ok(not exists("lang-en"), "переключателя языка пока нет")
	await press("text-scale-130")
	eq(Style.text_scale, 1.3)
	var r := Util.parse_json(Game.storage.read(Game.SETTINGS_SLOT))
	eq(r.data.text_scale, 1.3, "настройка сохранена")
	await shot("service-settings")
	await key(KEY_ESCAPE)
	await click("desk-object-inbox")
	await press("inbox-item-cable_a1_w1_file_vargas")
	await shot("doc-scaled-130")
	Game.set_text_scale(1.0)
