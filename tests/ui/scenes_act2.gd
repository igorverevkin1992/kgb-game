extends UiTest
## Вторая фаза операции: карточка смены фаз, поручение подчинённому, решение резидента,
## смена одежды у наружки (разные описания одной приметы).

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const C := "tar_calloway_martin"


func _pin(clue: String, axis: String) -> Dictionary:
	return {"type": "pin_clue", "clue_id": clue, "target_id": C, "axis": axis}


## Первая фаза пройдена: Кэллоуэй завербован и получил обещанное (два личных выхода).
func _phase1() -> Array:
	return QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "abort"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"},
		_pin("clue_calloway_post_review", "ego"), _pin("clue_calloway_bar_regulars", "ego"), _pin("clue_calloway_vgu_profile", "ego"),
		{"type": "submit_analysis", "target_id": C, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"},
		{"type": "recruitment", "target_id": C, "result": "success"},
		{"type": "pay_agent", "target_id": C, "amount": 4800, "instrument": "cash", "parts": 1}, NEXT,
		{"type": "submit_report", "report": "truth"}]


func scene_phase_card() -> void:
	await start(_phase1())
	Game.phase_card = 1
	Game.changed.emit()
	await frames()
	has_text("phase-card", "ПЕРВАЯ ФАЗА ОПЕРАЦИИ ЗАВЕРШЕНА")
	has_text("phase-card", "Вторая фаза операции «Периферия»")
	has_text("phase-card", "14 января 1985 г.")
	await shot("phase-card")
	await press("phase-card-continue")
	ok(not exists("phase-card"))
	has_text("act", "Вторая фаза операции")


func scene_delegated_op() -> void:
	await start(_phase1() + [NEXT,
		{"type": "plan_op", "op_id": "op_a2_recon_fbi_cafe", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a2_recon_fbi_cafe", "decision": "continue"}, NEXT,
		{"type": "submit_report", "report": "truth"}, NEXT])
	has_text("calendar-week", "Неделя 8")
	await key(KEY_1)
	await press("op-op_a2_rally_lafayette")
	for st in H.GOOD_ROUTE:
		await press("stop-" + st)
	has_text("executor", "заметит наружку с вероятностью 70%")
	await press("executor-op_technician")
	await shot("map-delegation")
	await press("confirm-route")
	has_text("planned-ops", "Поручено")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	await key(KEY_1)
	await press("report-op_a2_rally_lafayette")
	ok(exists("sdr-result"), "доклад подчинённого")
	has_text("sdr-result", "доложил")


func scene_decision_in_inbox() -> void:
	var actions := _phase1()
	for i in 5:
		actions += QUIET
	await start(actions)
	has_text("calendar-week", "Неделя 12")
	await click("desk-object-inbox")
	ok(exists("decision-item-dec_a2_colleague"), "решение в почте")
	await press("decision-item-dec_a2_colleague")
	has_text("decision", "Наружка ФБР +12")
	await shot("decision")
	await press("decide-dec_a2_colleague-protect")
	eq(node("decision").get_meta("chosen"), "protect")
	has_text("decision-outcome", "человек цел")


func scene_clothes_change_variants() -> void:
	await start()
	ok(MapModule._cue_text("woman_auburn_bob", 0).contains("бежевом плаще"))
	ok(MapModule._cue_text("woman_auburn_bob", 1).contains("синей куртке"), "одна примета — разная одежда")
