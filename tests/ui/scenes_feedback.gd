extends UiTest
## Отзыв плейтеста №1: списки не прыгают наверх, календарь не уходит за край, на встрече
## видны тоны при любом числе сведений, кнопки «Сохранить игру» и «Выйти из игры», ящики почты.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const V := "tar_vargas_ellen"


func _evening_vargas() -> Array:
	return QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "continue"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"},
		{"type": "pin_clue", "clue_id": "clue_vargas_clinic_debt", "target_id": V, "axis": "money"},
		{"type": "pin_clue", "clue_id": "clue_vargas_hospital_calls", "target_id": V, "axis": "money"},
		{"type": "pin_clue", "clue_id": "clue_vargas_bank_position", "target_id": V, "axis": ""},
		{"type": "submit_analysis", "target_id": V, "axis": "money", "access": "cia_staff_accounts", "channel": "false_flag"}]


func _inside(child: Control, box: Control) -> bool:
	return box.get_global_rect().encloses(child.get_global_rect())


func scene_calendar_fits_screen() -> void:
	await start(QUIET + [NEXT, NEXT, NEXT])
	for name in ["report-truth", "report-compose", "analyst-toggle", "save-game"]:
		var b: Control = node(name)
		ok(b != null and b.get_global_rect().end.x <= 1600, "%s не уходит за край" % name)
	await shot("calendar-night")


func scene_save_and_quit_buttons() -> void:
	await start([])
	await press("save-game")
	ok(Game.service_open, "служебная папка открылась")
	ok(exists("saves"), "сразу на вкладке сохранений")
	ok(exists("service-quit"), "кнопка выхода из игры")
	await shot("service-quit")


func scene_meeting_tones_visible() -> void:
	await start(_evening_vargas())
	await key(KEY_5)
	await press("meet-" + V)
	ok(exists("meeting"), "встреча идёт")
	var tone: Control = node("tone-" + Meeting.TONES[0])
	ok(tone != null and _inside(tone, node("meeting-scroll")), "тоны видны без прокрутки")
	ok(exists("meeting-offer") and _inside(node("meeting-offer"), node("meeting-scroll")), "кнопки встречи видны")
	await shot("dialog-meeting-vargas")


func scene_archive_scroll_kept() -> void:
	Game.reset_for_test(H.act4_state())
	await frames()
	await key(KEY_8)
	var list: ScrollContainer = node("archive-list").get_parent()
	list.scroll_vertical = 400
	await frames()
	var kept := list.scroll_vertical
	ok(kept > 0, "список прокручен")
	var entries: Array = node("archive-list").find_children("archive-entry-*", "", true, false)
	var open_entries: Array = entries.filter(func(b): return not b.disabled)
	var last: Control = open_entries[-1]
	await press(last.name)
	await frames(3)
	list = node("archive-list").get_parent()
	eq(list.scroll_vertical, kept, "после выбора листа список на месте")


func scene_inbox_folders() -> void:
	await start(QUIET + QUIET)
	await key(KEY_7)
	ok(exists("inbox-folder-letters"), "ящики почты")
	await press("inbox-folder-letters")
	var items: Array = node("inbox-list").find_children("inbox-item-*", "", true, false)
	ok(not items.is_empty(), "в ящике «Письма» есть письма")
	for it in items:
		var id := String(it.name).trim_prefix("inbox-item-")
		eq(Campaign.cable_by_id(Game.content, id).kind, "letter", "только письма")
	await press("inbox-folder-press")
	for it in node("inbox-list").find_children("inbox-item-*", "", true, false):
		eq(Campaign.cable_by_id(Game.content, String(it.name).trim_prefix("inbox-item-")).kind, "press_clipping")
	await shot("inbox-folders")


func scene_centre_task() -> void:
	var s := H.run(H.with_tasks(), QUIET)
	Game.reset_for_test(s)
	await frames()
	has_text("calendar", "Задание Центра")
	await key(KEY_7)
	await press("inbox-folder-tasks")
	await press("task-item-task_a1_zone")
	ok(exists("task"), "бланк задания")
	ok(not enabled("task-send"), "без материала и ответов не отправить")
	await press("task-material-cable_a1_w2_surveillance_summary")
	await press("task-item-task_a1_zone")
	await press("task-opt-zone-m25")
	await press("task-opt-sign-repeat")
	ok(enabled("task-send"), "можно отправить")
	await shot("centre-task")
	await press("task-send")
	eq(Game.state.tasks.task_a1_zone.status, "done")
	has_text("task", "БЕЗ ЗАМЕЧАНИЙ")
