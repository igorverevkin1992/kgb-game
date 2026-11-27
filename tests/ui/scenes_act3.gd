extends UiTest
## Третья фаза «Кронос»: «слепое окно» на карте, ужин в Джорджтауне, пробный пакет
## с листом проверки по трём каналам.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const CAL := "tar_caldwell_arthur"


## Неделя 18, утро: Колдуэлл установлен, заключение по делу утверждено.
func _week18(agents: Array) -> Dictionary:
	var s := H.run(H.act3_state(agents), QUIET)
	var c := H.content()
	for clue in ["clue_caldwell_post", "clue_caldwell_divorce", "clue_caldwell_snobs"]:
		var cl := Campaign.clue_by_id(c, clue)
		var axis: String = cl.reveals[0].axis if not cl.reveals.is_empty() else ""
		s = H.run(s, [{"type": "pin_clue", "clue_id": clue, "target_id": CAL, "axis": axis}])
	var t := Campaign.target_by_id(c, CAL)
	return H.run(s, [{"type": "submit_analysis", "target_id": CAL, "axis": t.analysis.leading_axis, "access": t.analysis.correct_access, "channel": t.approach.flag_mode}])


func _recruited(agents: Array) -> Dictionary:
	return H.run(_week18(agents), [NEXT, H.plan("op_a3_dinner_georgetown"), NEXT, H.resolve("op_a3_dinner_georgetown"),
		{"type": "start_meeting", "target_id": CAL},
		{"type": "meeting_turn", "tone": "pragmatic"}, {"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "ego", "clue_id": "clue_caldwell_snobs"}, {"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "empathy"}, {"type": "meeting_turn", "tone": "pragmatic", "clue_id": "clue_caldwell_divorce"},
		{"type": "meeting_offer"}, H.pay(CAL), NEXT, {"type": "submit_report", "report": "truth"}])


func scene_blind_window() -> void:
	Game.reset_for_test(H.run(_week18(["tar_hales_robert"]), [NEXT]))
	await frames(3)
	await key(KEY_1)
	has_text("op-op_a3_dinner_georgetown", "Слепое окно")
	await press("op-op_a3_dinner_georgetown")
	await shot("map-blind-window")


func scene_dinner_dialog() -> void:
	Game.reset_for_test(H.run(_week18(["tar_hales_robert"]), [NEXT, H.plan("op_a3_dinner_georgetown"), NEXT,
		H.resolve("op_a3_dinner_georgetown"), {"type": "start_meeting", "target_id": CAL},
		{"type": "meeting_turn", "tone": "pragmatic"}, {"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "ego", "clue_id": "clue_caldwell_snobs"}]))
	await frames(3)
	await key(KEY_5)
	has_text("module-panel-dialog", "Ужин в Джорджтауне")
	await shot("dialog-caldwell")


func scene_package_check() -> void:
	var s := H.run(_recruited(["tar_hales_robert", "tar_jenkins_clara"]), [NEXT, H.plan("op_a3_drop_package"), NEXT, H.resolve("op_a3_drop_package")])
	Game.reset_for_test(s)
	await frames(3)
	await key(KEY_7)
	ok(exists("package-item"), "пакет в лотке")
	await press("package-item")
	has_text("package-check-drop", "РАСХОЖДЕНИЕ")
	has_text("package-rule", "подменён")
	await press("package-check-archive-btn")
	has_text("package-check-archive", "не совпадают")
	has_text("package-verdict", "Расхождений: 2")
	ok(exists("package-reject"), "можно потребовать личную передачу")
	await shot("package-check")
	await press("package-reject")
	has_text("package", "ПАКЕТ ОТКЛОНЁН")
