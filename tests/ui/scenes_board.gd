extends UiTest
## Доска мотивов: фрагменты-улики в документах, прикалывание кликом и перетаскиванием,
## подтверждение тремя уликами, заключение тройкой, подсказки, встреча и конец Акта I.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const C := "tar_calloway_martin"


## 3-я неделя, вечер: оба выезда сделаны, обе цели установлены.
func _week3_evening() -> Array:
	return QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "continue"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"}]


func _pin(clue: String, axis: String) -> Dictionary:
	return {"type": "pin_clue", "clue_id": clue, "target_id": C, "axis": axis}


func scene_document_chunk_goes_to_board() -> void:
	await start()
	await click("desk-object-inbox")
	await press("inbox-item-cable_a1_w1_file_vargas")
	has_text("intuition", "ещё не отмечено сведений — 1")
	await shot("doc-chunk")
	(node("doc-body") as RichTextLabel).meta_clicked.emit("clue_vargas_bank_position")
	await frames()
	has_text("intuition", "всё ценное из документа отмечено")
	await key(KEY_ESCAPE)
	has_text("board-new", "1")


func scene_pin_by_click_and_drag_confirms_motive() -> void:
	await start(_week3_evening())
	await key(KEY_2)
	ok(exists("clue-clue_calloway_post_review"), "улика в стопке")
	# Клик по карточке → клик по ячейке «С» (самолюбие).
	await click("clue-clue_calloway_post_review")
	await click("drop-%s-ego" % C)
	eq(node("drop-%s-ego" % C).get_meta("knowledge"), "hypothesis")
	# Промах: улика об аренде ничего не говорит о самолюбии.
	await click("clue-clue_calloway_rent_call")
	await click("drop-%s-ego" % C)
	has_text("board-message", "ничего не говорят об этом мотиве")
	# Перетаскивание (drop) ещё двух улик — мотив подтверждён, видна истинная цифра.
	node("drop-%s-ego" % C)._drop_data(Vector2.ZERO, {"clue_id": "clue_calloway_vgu_profile"})
	await frames()
	node("drop-%s-ego" % C)._drop_data(Vector2.ZERO, {"clue_id": "clue_calloway_bar_regulars"})
	await frames()
	eq(node("drop-%s-ego" % C).get_meta("knowledge"), "confirmed")
	has_text("drop-%s-ego" % C, "подтверждено: 80")
	await shot("board")


func scene_analysis_near_hints_approve_and_meet() -> void:
	await start(_week3_evening() + [_pin("clue_calloway_post_review", "ego"), _pin("clue_calloway_bar_regulars", "ego"), _pin("clue_calloway_vgu_profile", "ego")])
	await key(KEY_2)
	await press("analysis-" + C)
	ok(exists("analysis-panel"), "форма заключения")
	await press("form-axis-ideology")
	await press("form-access-se_division_habits")
	await press("form-channel-false_flag")
	await press("analysis-submit")
	has_text("analysis-result", "Почти")
	for i in 3:
		await press("analysis-hint")
	has_text("analysis-hints", "Почему он читает лекции")
	has_text("analysis-hints", "Перечитайте сведения")
	has_text("analysis-hints", "Основа вербовки — Самолюбие")
	await shot("board-analysis")
	await press("form-axis-ego")
	await press("analysis-submit")
	ok(not exists("analysis-panel"), "форма закрылась")
	ok(exists("stamp-approved"), "штамп «В разработку»")
	await press("meet-" + C)
	ok(exists("module-panel-dialog"), "встреча на «Тембр-2М»")
	await press("tone-ego")
	await press("trump-clue_calloway_post_review")
	await press("tone-ego")
	await press("trump-clue_calloway_vgu_profile")
	await press("tone-ego")
	await press("meeting-offer")
	await key(KEY_4)
	await press("tranche-send")  # обещанное Кэллоуэю — аренда бара
	await key(KEY_2)
	has_text("dossier-" + C, "ЗАВЕРБОВАН")
	await shot("board-recruited")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	await press("report-truth")
	eq(node("ending").get_meta("ending"), "campaign_complete", "Акт I пройден")
