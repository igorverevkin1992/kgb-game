extends UiTest
## Магнитофон «Тембр-2М»: встреча с индикаторами и козырями, предложение, срыв по Тревоге,
## «Прервать контакт», разбор катушки (перемотка, оговорка на доску).

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const C := "tar_calloway_martin"
const V := "tar_vargas_ellen"


func _pin(clue: String, target: String, axis: String) -> Dictionary:
	return {"type": "pin_clue", "clue_id": clue, "target_id": target, "axis": axis}


## 3-я неделя, вечер: оба выезда сделаны, заключения по обоим досье утверждены.
func _evening() -> Array:
	return QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "continue"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"},
		_pin("clue_calloway_post_review", C, "ego"), _pin("clue_calloway_bar_regulars", C, "ego"),
		_pin("clue_calloway_vgu_profile", C, "ego"), _pin("clue_calloway_rent_call", C, "money"),
		{"type": "submit_analysis", "target_id": C, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"},
		_pin("clue_vargas_clinic_debt", V, "money"), _pin("clue_vargas_hospital_calls", V, "money"),
		_pin("clue_vargas_bank_position", V, ""),
		{"type": "submit_analysis", "target_id": V, "axis": "money", "access": "cia_staff_accounts", "channel": "false_flag"}]


func scene_meeting_with_trumps_recruits() -> void:
	await start(_evening())
	has_text("dialog-ready", "2")
	await key(KEY_5)
	ok(exists("candidates"), "кому назначить встречу")
	await press("meet-" + C)
	ok(exists("meeting"), "встреча идёт")
	ok(exists("recording"), "магнитофон пишет")
	eq(node("meeting-rapport").get_meta("value"), 10)
	ok(not enabled("meeting-offer"), "предлагать рано")
	await press("tone-ego")
	eq(node("meeting-rapport").get_meta("value"), 22)
	await press("trump-clue_calloway_post_review")
	has_text("meeting", "Предъявить сведения")
	await press("tone-ego")
	eq(node("meeting-rapport").get_meta("value"), 48)
	has_text("transcript", "сведения подействовали")
	await press("trump-clue_calloway_vgu_profile")
	await press("tone-ego")
	ok(enabled("meeting-offer"), "Раппорт выше порога")
	await shot("dialog-meeting")
	await press("meeting-offer")
	ok(exists("tape-review"), "после встречи — её катушка")
	has_text("tape-review", "завербован")
	ok(Game.state.targets[C].recruited)


func scene_early_blackmail_breaks_contact() -> void:
	await start(_evening())
	await key(KEY_5)
	await press("meet-" + C)
	await press("trump-clue_calloway_rent_call")
	await press("tone-pressure")
	has_text("transcript", "сведения предъявлены рано")
	for i in 3:
		if exists("tone-pressure"):
			await press("tone-pressure")
	ok(not exists("meeting"), "собеседник ушёл")
	has_text("tape-review", "подход не удался")
	ok(Game.state.targets[C].lost)


func scene_abort_and_tape_slip() -> void:
	await start(_evening())
	await key(KEY_5)
	await press("meet-" + V)
	for tone in ["pragmatic", "pragmatic", "empathy"]:
		await press("tone-" + tone)
	ok(exists("meeting-abort"))
	await press("meeting-abort")
	has_text("tape-review", "контакт прерван")
	has_text("tape-review", "Неотмеченных оговорок: 1")
	eq(Game.state.targets[V].rapport, 30, "Раппорт сохранён")
	await key(KEY_SPACE)
	var cur := -1
	for i in 30:
		var l := node("line-%d" % i)
		if l != null and l.has_meta("cursor"):
			cur = i
	ok(cur > 0, "головка на оговорке")
	await shot("dialog-tape")
	var rich: Array = node("line-%d" % cur).find_children("*", "RichTextLabel", true, false)
	ok(not rich.is_empty(), "реплика с оговоркой")
	if not rich.is_empty():
		rich[0].meta_clicked.emit("clue_vargas_slip_cash")
		await frames()
	ok(Game.state.clues.has("clue_vargas_slip_cash"), "оговорка снята на доску")
	has_text("tape-review", "Неотмеченных оговорок: 0")
	await key(KEY_LEFT)
	eq(Game.tape_cursor, cur - 1, "перемотка назад")
	await key(KEY_ESCAPE)
	ok(exists("board-new"), "новая улика в стопке")
