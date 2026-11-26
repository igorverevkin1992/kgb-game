extends TestCase
## Вербовочная беседа: условия встречи, тоны и козыри (рано / вовремя), срыв по Тревоге,
## «Прервать контакт», предложение и вербовка, оговорки на катушке, проверки валидатора.

const V := "tar_vargas_ellen"
const C := "tar_calloway_martin"


func _do(s: Dictionary, action: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), action)


func _turn(tone: String, clue := "") -> Dictionary:
	return {"type": "meeting_turn", "tone": tone, "clue_id": clue}


## 3-я неделя, вечер: обе цели установлены, заключения утверждены (все улики приколоты).
func _evening() -> Dictionary:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), H.NEXT,
		H.resolve("op_a1_recon_first_virginia"), H.resolve("op_a1_recon_potomac_cellar")]).state
	s = H.approve(self, s, C)
	return H.approve(self, s, V)


func test_meet_conditions() -> void:
	var s := _evening()
	eq(Meeting.meet_error(s, H.content(), C), "")
	has_text(Meeting.meet_error(H.fresh(), H.content(), C), "не установлен")
	var day: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT]).state
	has_text(_do(day, {"type": "start_meeting", "target_id": C}).error, "не установлен")
	var r := _do(s, {"type": "start_meeting", "target_id": C})
	eq(r.error, "")
	eq(r.state.meeting.rapport, 10, "стартовый Раппорт — из досье")
	eq(r.state.meeting.anxiety, 20)
	has_text(_do(r.state, {"type": "start_meeting", "target_id": V}).error, "уже идёт")
	has_text(_do(r.state, H.NEXT).error, "Идёт встреча")


func test_winning_line_recruits() -> void:
	var s: Dictionary = _do(_evening(), {"type": "start_meeting", "target_id": C}).state
	has_text(_do(s, {"type": "meeting_offer"}).error, "Рано")
	s = _do(s, _turn("ego")).state
	eq([s.meeting.rapport, s.meeting.anxiety], [22, 20])
	var r := _do(s, _turn("ego", "clue_calloway_post_review"))
	eq(r.error, "")
	eq(r.state.meeting.rapport, 48, "тон + козырь вовремя")
	has_text(_do(r.state, _turn("ego", "clue_calloway_post_review")).error, "не предъявить")
	s = _do(r.state, _turn("ego", "clue_calloway_vgu_profile")).state
	ok(Meeting.can_offer(Meeting.dialog_for(H.content(), C), s.meeting))
	r = _do(s, {"type": "meeting_offer"})
	eq(r.error, "")
	ok(r.state.targets[C].recruited, "завербован")
	ok(not r.state.goal_reached, "задача акта — только после выплаты обещанного")
	ok(_do(r.state, H.pay(C)).state.goal_reached, "обещание выполнено — цель акта")
	eq(r.state.meeting, null)
	eq(r.state.tapes.size(), 1)
	eq(r.state.tapes[0].outcome, "recruited")
	eq(r.state.tapes[0].lines[-1], {"kind": "end", "outcome": "recruited"})


func test_early_trump_and_failure() -> void:
	var s: Dictionary = _do(_evening(), {"type": "start_meeting", "target_id": C}).state
	var d := Meeting.dialog_for(H.content(), C)
	var fx := Meeting.turn_effects(d, s.meeting, "pressure", "clue_calloway_rent_call")
	eq(fx, {"dr": -5, "da": 40, "ready": false}, "компромат о деньгах на старте — всплеск Тревоги")
	var sog: int = s.risks.sog_heat
	for a in [_turn("pressure"), _turn("pressure", "clue_calloway_rent_call"), _turn("pressure"), _turn("pressure")]:
		var r := _do(s, a)
		if r.error != "":
			failures.append(r.error)
			break
		s = r.state
	eq(s.meeting, null, "собеседник ушёл")
	ok(s.targets[C].lost, "подход не удался")
	eq(s.risks.sog_heat, sog + int(H.content().balance.sog_heat.failed_recruitment))
	eq(s.tapes[-1].outcome, "failed")


func test_abort_keeps_rapport_and_cools_down() -> void:
	var s: Dictionary = _do(_evening(), {"type": "start_meeting", "target_id": C}).state
	s = _do(s, _turn("ego")).state
	s = _do(s, _turn("pressure")).state
	eq([s.meeting.rapport, s.meeting.anxiety], [22, 30])
	var r := _do(s, {"type": "meeting_abort"})
	eq(r.error, "")
	eq(r.state.targets[C].rapport, 22, "Раппорт сохранён")
	eq(r.state.targets[C].paranoia, 30 - int(H.content().balance.meeting.anxiety_cooldown), "Тревога спала")
	ok(not r.state.targets[C].lost)
	has_text(_do(r.state, {"type": "start_meeting", "target_id": C}).error, "другой день")


func test_slip_becomes_clue() -> void:
	var s: Dictionary = _do(_evening(), {"type": "start_meeting", "target_id": V}).state
	var take := {"type": "take_clue", "clue_id": "clue_vargas_slip_cash"}
	has_text(_do(s, take).error, "не прозвучала")
	for tone in ["pragmatic", "pragmatic", "empathy"]:
		s = _do(s, _turn(tone)).state
	var r := _do(s, take)
	eq(r.error, "", "оговорка прозвучала — улику можно снять с катушки")
	ok(r.state.clues.has("clue_vargas_slip_cash"))


func test_validator_dialog_rules() -> void:
	var e := H.entries()
	var d: Dictionary = H.file(e, "dialogs/dlg_a1_calloway.json")
	d.trumps[0].clue_id = "clue_vargas_clinic_debt"
	var dv: Dictionary = H.file(e, "dialogs/dlg_a1_vargas.json")
	dv.trumps = []  # без козырей Варгас не уговорить
	var vc: Array = H.file(e, "clues/vargas.json")
	for c in vc:
		if c.clue_id == "clue_vargas_slip_cash":
			c.chunk = "этой фразы в беседе нет"
	var errs := H.errors(e)
	has_issue(errs, "dialog", "невозможно выиграть")
	has_issue(errs, "dialog", "не относится к цели")
	has_issue(errs, "board", "в репликах собеседника")


func test_no_dialog_is_softlock() -> void:
	var e := H.entries()
	e = e.filter(func(x): return not String(x.path).begins_with("dialogs/"))
	has_issue(H.errors(e), "softlock")


func test_save_v5_migrates() -> void:
	var old := H.fresh().duplicate(true)
	old.erase("meeting")
	old.erase("tapes")
	var r := Saves.deserialize(JSON.stringify({"format": Saves.FORMAT, "version": 5, "saved_at": "", "state": old}), H.content())
	ok(r.ok, r.get("error", ""))
	eq(r.state.tapes, [])


func test_coercion_makes_unstable_agent() -> void:
	var c := H.content()
	eq(Meeting.is_coercive(c, V, "pressure", ""), 1)
	eq(Meeting.is_coercive(c, V, "empathy", "clue_vargas_drawer_memo"), 1, "компромат — принуждение")
	eq(Meeting.is_coercive(c, V, "empathy", "clue_vargas_clinic_debt"), 0)
	# Кэллоуэй: эго и деньги без нажима — чистая вербовка.
	var s: Dictionary = _do(_evening(), {"type": "start_meeting", "target_id": C}).state
	for a in [_turn("ego"), _turn("ego", "clue_calloway_post_review"), _turn("ego", "clue_calloway_vgu_profile")]:
		s = _do(s, a).state
	var clean := _do(s, {"type": "meeting_offer"})
	eq(clean.state.agents[C].coerced, false)
	ok(clean.events.any(func(e): return e.type == "target_recruited" and e.coerced == false))
	# Тот же путь, но дважды нажимом (ставим счётчик, как после двух ответов нажимом).
	s.meeting.coercion = 2
	var forced := _do(s, {"type": "meeting_offer"})
	eq(forced.state.agents[C].coerced, true)
	eq(forced.state.agents[C].loyalty, clean.state.agents[C].loyalty - int(c.balance.finance.coerced_loyalty_penalty))
	# Неделя: лояльность принуждённого падает, на нуле агент рвёт связь.
	var st: Dictionary = forced.state.duplicate(true)
	st.agents[C].promise_kept = true
	var night: Dictionary = H.play(self, st, [H.NEXT, H.report("truth")]).state
	eq(night.agents[C].loyalty, forced.state.agents[C].loyalty - int(c.balance.finance.loyalty_coerced_week))
	st.agents[C].loyalty = 2
	var gone := H.play(self, st, [H.NEXT, H.report("truth")])
	ok(gone.state.targets[C].lost, "агент порвал связь")
	ok(gone.events.any(func(e): return e.type == "agent_broke"))
