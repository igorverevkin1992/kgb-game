extends TestCase
## Доска мотивов: улики-фрагменты из документов, прикалывание к ячейкам мотивов, «Правило трёх
## улик» на доске, заключение тройкой с мягкой подсказкой, подсказки в три уровня.

const VARGAS := "tar_vargas_ellen"
const CALLOWAY := "tar_calloway_martin"


## 3-я неделя, вечер: оба выезда сделаны, все документы сняты — обе цели установлены.
func _week3_evening() -> Dictionary:
	return H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), H.NEXT,
		H.resolve("op_a1_recon_first_virginia"), H.resolve("op_a1_recon_potomac_cellar")]).state


func _pin(s: Dictionary, clue: String, target: String, axis := "") -> Dictionary:
	return Campaign.dispatch(s, H.content(), {"type": "pin_clue", "clue_id": clue, "target_id": target, "axis": axis})


func test_take_clue_from_document() -> void:
	var s := H.fresh()
	var r := Campaign.dispatch(s, H.content(), {"type": "take_clue", "clue_id": "clue_vargas_bank_position"})
	eq(r.error, "")
	ok(r.state.clues.has("clue_vargas_bank_position"))
	eq(Campaign.untaken_chunks(r.state, H.content(), "cable_a1_w1_file_vargas"), [])
	has_text(Campaign.dispatch(r.state, H.content(), {"type": "take_clue", "clue_id": "clue_vargas_bank_position"}).error, "уже снята")
	has_text(Campaign.dispatch(s, H.content(), {"type": "take_clue", "clue_id": "clue_vargas_clinic_debt"}).error, "не поступал")
	has_text(Campaign.dispatch(s, H.content(), {"type": "take_clue", "clue_id": "clue_vargas_mortgage_desk"}).error, "нельзя взять")


func test_unlock_needs_taken_clues() -> void:
	# Без снятых фрагментов из документов одной полевой улики мало: Варгас не установлена.
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [H.NEXT, H.plan("op_a1_recon_first_virginia"), H.NEXT, H.resolve("op_a1_recon_first_virginia")], false).state
	ok(not s.targets[VARGAS].unlocked, "без документа — не установлена")
	s = Campaign.dispatch(s, H.content(), {"type": "take_clue", "clue_id": "clue_vargas_bank_position"}).state
	ok(s.targets[VARGAS].unlocked, "сняли фрагмент — установлена")


func test_pin_rules() -> void:
	var s := _week3_evening()
	eq(_pin(s, "clue_vargas_hospital_calls", VARGAS, "money").error, "")
	has_text(_pin(s, "clue_vargas_hospital_calls", VARGAS, "ego").error, "ничего не говорит об этом мотиве")
	has_text(_pin(s, "clue_vargas_hospital_calls", CALLOWAY, "money").error, "не относится к этой цели")
	eq(_pin(s, "clue_vargas_bank_position", VARGAS, "").error, "", "общее поле досье")
	has_text(_pin(s, "clue_vargas_closing_recount", VARGAS, "compromise").error, "ещё не найдена")
	var s2: Dictionary = _pin(s, "clue_vargas_hospital_calls", VARGAS, "money").state
	has_text(_pin(s2, "clue_vargas_hospital_calls", VARGAS, "money").error, "уже приколота")


func test_board_knowledge_grows_with_pins() -> void:
	var s := _week3_evening()
	var c := H.content()
	eq(Campaign.axis_knowledge(s, c, CALLOWAY, "ego"), "unknown", "без прикалывания — туман")
	for clue in ["clue_calloway_post_review", "clue_calloway_bar_regulars"]:
		s = _pin(s, clue, CALLOWAY, "ego").state
	eq(Campaign.axis_knowledge(s, c, CALLOWAY, "ego"), "hypothesis")
	s = _pin(s, "clue_calloway_vgu_profile", CALLOWAY, "ego").state
	eq(Campaign.axis_knowledge(s, c, CALLOWAY, "ego"), "confirmed")
	eq(Campaign.unpinned_clues(s, c).filter(func(x): return x.clue_id == "clue_calloway_vgu_profile"), [])


func test_analysis_needs_three_pins() -> void:
	var s := _week3_evening()
	s = _pin(s, "clue_calloway_post_review", CALLOWAY, "ego").state
	has_text(Campaign.dispatch(s, H.content(), {"type": "submit_analysis", "target_id": CALLOWAY, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"}).error, "минимум три")


func test_analysis_soft_hint_and_approval() -> void:
	var s := _week3_evening()
	for clue in ["clue_calloway_post_review", "clue_calloway_bar_regulars", "clue_calloway_vgu_profile"]:
		s = _pin(s, clue, CALLOWAY, "ego").state
	var near := Campaign.dispatch(s, H.content(), {"type": "submit_analysis", "target_id": CALLOWAY, "axis": "ideology", "access": "se_division_habits", "channel": "false_flag"})
	ok(near.events.any(func(e): return e.type == "analysis_rejected" and e.wrong == 1), "неверен 1 пункт")
	s = near.state
	var all_wrong := Campaign.dispatch(s, H.content(), {"type": "submit_analysis", "target_id": CALLOWAY, "axis": "money", "access": "wine_imports", "channel": "true_flag"})
	ok(all_wrong.events.any(func(e): return e.type == "analysis_rejected" and e.wrong == 3))
	var good := Campaign.dispatch(all_wrong.state, H.content(), {"type": "submit_analysis", "target_id": CALLOWAY, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"})
	ok(good.events.any(func(e): return e.type == "analysis_approved"))
	eq(Campaign.analysis_state(good.state, CALLOWAY), {"approved": true, "attempts": 3, "wrong": 0, "hint_level": 0})
	has_text(Campaign.dispatch(good.state, H.content(), {"type": "submit_analysis", "target_id": CALLOWAY, "axis": "ego", "access": "se_division_habits", "channel": "false_flag"}).error, "уже утверждено")


func test_hints_three_levels() -> void:
	var s := _week3_evening()
	for i in 3:
		s = Campaign.dispatch(s, H.content(), {"type": "use_hint", "target_id": VARGAS}).state
	eq(Campaign.analysis_state(s, VARGAS).hint_level, 3)
	has_text(Campaign.dispatch(s, H.content(), {"type": "use_hint", "target_id": VARGAS}).error, "больше нет")


func test_validator_chunk_must_be_in_document() -> void:
	var e := H.entries()
	H.clue(e, "clue_vargas_clinic_debt").chunk = "фразы, которой нет в документе"
	has_issue(H.errors(e), "board", "нет в тексте документа")
	var e2 := H.entries()
	H.clue(e2, "clue_vargas_clinic_debt").erase("chunk")
	has_issue(H.errors(e2), "board", "без фрагмента")


func test_validator_analysis_consistency() -> void:
	var e := H.entries()
	H.file(e, "targets/tar_vargas_ellen.json").analysis.leading_axis = "ideology"
	has_issue(H.errors(e), "board", "ведущие мотивы")
	var e2 := H.entries()
	H.file(e2, "targets/tar_vargas_ellen.json").analysis.correct_access = "nowhere"
	has_issue(H.errors(e2), "board", "access_options")
