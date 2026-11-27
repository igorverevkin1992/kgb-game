extends TestCase
## Встречи на связи с завербованными агентами: порядок и условия, контакт — лояльность агента,
## договорённость (донесения, лояльность, образ жизни, подготовка к полиграфу), срыв без потери
## агента, «прервать» — можно повторить; валидатор.

const V := "tar_vargas_ellen"
const K := "tar_caldwell_arthur"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


## Первая фаза, вечер: Варгас завербована и лояльна.
func _vargas_evening() -> Dictionary:
	var s := H.fresh()
	s.targets[V].unlocked = true
	s.targets[V].recruited = true
	s.agents[V] = Finance.new_agent(s, H.content(), V)
	s.agents[V].loyalty = 55
	s.agents[V].promise_kept = true
	return H.play(self, s, [H.NEXT, H.NEXT]).state


func _win(s: Dictionary, did: String) -> Dictionary:
	var c := H.content()
	s = H.play(self, s, [{"type": "start_meeting", "dialog_id": did}]).state
	var d := Meeting.dialog_by_id(c, did)
	for mv in Autoplay.meeting_path(d, int(s.meeting.rapport), int(s.meeting.anxiety), []):
		s = H.play(self, s, [{"type": "meeting_turn", "tone": mv[0]}]).state
	return H.play(self, s, [{"type": "meeting_offer"}]).state


func test_order_and_conditions() -> void:
	var s := _vargas_evening()
	eq(Meeting.next_handling(s, H.content(), V).dialog_id, "dlg_h_vargas_1")
	eq(Meeting.handling_error(s, H.content(), "dlg_h_vargas_1"), "")
	has_text(Meeting.handling_error(s, H.content(), "dlg_h_vargas_2"), "по порядку")
	var day: Dictionary = H.play(self, H.fresh(), [H.NEXT]).state
	day.targets[V].recruited = true
	day.agents[V] = Finance.new_agent(day, H.content(), V)
	has_text(Meeting.handling_error(day, H.content(), "dlg_h_vargas_1"), "вечер")
	has_text(Meeting.handling_error(H.fresh(), H.content(), "dlg_h_vargas_1"), "завербованным")


func test_agreement() -> void:
	var s := _vargas_evening()
	var sog: int = s.risks.sog_heat
	s = H.play(self, s, [{"type": "start_meeting", "dialog_id": "dlg_h_vargas_1"}]).state
	eq([s.meeting.rapport, s.meeting.anxiety], [55, 30], "контакт — лояльность агента")
	s = _win(H.play(self, s, [{"type": "meeting_abort"}]).state.merged({"tapes": []}, true), "dlg_h_vargas_1")
	eq(s.handled.get("dlg_h_vargas_1"), "agreed")
	ok(s.clues.has("clue_calloway_named_by_vargas"), "донесение передано на встрече")
	eq(s.agents[V].loyalty, 65)
	ok(s.risks.sog_heat >= sog + 2, "личная встреча заметна наружке")
	ok(not s.targets[V].lost)
	has_text(Meeting.handling_error(s, H.content(), "dlg_h_vargas_2"), "второй фазе")


func test_broken_off_keeps_agent() -> void:
	var s := _vargas_evening()
	s = H.play(self, s, [{"type": "start_meeting", "dialog_id": "dlg_h_vargas_1"}]).state
	s.meeting.anxiety = 90  # разговор и так на грани
	s = H.play(self, s, [{"type": "meeting_turn", "tone": "pressure"}]).state
	ok(s.meeting == null, "настороженность дошла до предела")
	eq(s.handled.get("dlg_h_vargas_1"), "broken_off")
	eq(s.tapes[-1].outcome, "broken_off")
	ok(s.targets[V].recruited and not s.targets[V].lost, "агент не потерян")
	eq(s.agents[V].loyalty, 55 - 12)


func test_kronos_polygraph_brief() -> void:
	var s := H.act4_state()
	s.week = 44
	s.phase = "night"
	s.agents[K].loyalty = 70
	s.decisions["dec_a4_rome"] = "hand_over"
	s = H.play(self, s, [H.report("truth")]).state
	s.handled = {"dlg_h_kronos_1": "agreed", "dlg_h_kronos_2": "agreed"}
	s = H.play(self, s, [H.NEXT, H.NEXT]).state
	ok(s.polygraph != null)
	var slots: int = s.polygraph.slots
	s = _win(s, "dlg_h_kronos_3")
	eq(s.polygraph.slots, slots + 1, "инструктаж даёт лишний пункт подготовки")


func test_validator() -> void:
	var e := H.entries()
	var d: Dictionary = H.file(e, "dialogs/dlg_h_vargas_2.json")
	d.order = 1
	has_issue(H.errors(e), "dialog", "две встречи")
	var e2 := H.entries()
	H.file(e2, "dialogs/dlg_h_vargas_1.json").target_id = "tar_hales_robert"
	has_issue(H.errors(e2), "dialog", "бесконтактная")
	var e3 := H.entries()
	H.file(e3, "dialogs/dlg_h_vargas_1.json").success.clue_ids = ["clue_caldwell_by_jenkins"]
	has_issue(H.errors(e3), "dialog", "своё донесение")
