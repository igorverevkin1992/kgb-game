extends UiTest
## Возможности из грантовой стратегии: «Архив 1985» и эпилог «факт и вымысел», письма из дома.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const C := "tar_calloway_martin"


func _pin(clue: String, axis: String) -> Dictionary:
	return {"type": "pin_clue", "clue_id": clue, "target_id": C, "axis": axis}


func scene_archive_reference() -> void:
	await start()
	ok(enabled("desk-object-archive"), "архив на стене")
	await key(KEY_8)
	ok(exists("module-panel-archive"), "архив открыт")
	ok(not enabled("archive-entry-arc_epilogue_real"), "эпилог закрыт до конца фазы")
	await press("archive-entry-arc_fialka")
	has_text("archive-text", "десять дисков")
	eq(node("archive-text").get_meta("status"), "fact")
	await shot("archive")


func scene_letter_from_home() -> void:
	await start(QUIET)
	await click("desk-object-inbox")
	await press("inbox-item-cable_a1_w2_letter_home")
	eq(node("document").get_meta("kind"), "letter")
	has_text("document", "Наташа")
	await shot("letter")


func scene_epilogue_after_phase_one() -> void:
	await start(QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"},
		_pin("clue_calloway_post_review", "ego"), _pin("clue_calloway_bar_regulars", "ego"), _pin("clue_calloway_vgu_profile", "ego"),
		{"type": "submit_analysis", "target_id": C, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"},
		{"type": "recruitment", "target_id": C, "result": "success"},
		{"type": "pay_agent", "target_id": C, "amount": 4800, "instrument": "cash", "parts": 1}, NEXT,
		{"type": "submit_report", "report": "truth"}])
	# Финал всей операции (после последней фазы) — ставим его прямо, без прохождения второй фазы.
	Game.state.ending = "clean_triumph"
	Game.phase_card = 0
	Game.changed.emit()
	await frames()
	eq(node("ending").get_meta("ending"), "clean_triumph")
	has_text("ending", "ЧИСТЫЙ ТРИУМФ")
	has_text("ending-checklist", "Условия «Чистого триумфа»")
	has_text("ending-stats", "реализовано дел")
	await shot("ending-clean-triumph")
	# Эпилог: хроника своей концовки, затем документальная хроника дела Эймса.
	await press("ending-epilogue")
	eq(node("epilogue").get_meta("page"), 0)
	has_text("epilogue", "чистая партия")
	await press("epilogue-next")
	has_text("epilogue", "16 апреля 1985")
	for i in 2:
		await press("epilogue-next")
	has_text("epilogue", "Черкашин")
	await shot("epilogue-cherkashin")
	while exists("epilogue-next"):
		await press("epilogue-next")
	has_text("epilogue", "Лист 6 из 6")
	await press("epilogue-close")
	ok(exists("ending"), "назад к итогу")
	await press("ending-archive")
	ok(exists("module-panel-archive"), "эпилог в архиве")
	eq(node("archive-text").get_meta("entry"), "arc_epilogue_fiction")
	has_text("archive-text", "вымышлены")
	await shot("archive-epilogue")
	await key(KEY_ESCAPE)
	ok(exists("ending"), "назад к итогу")
