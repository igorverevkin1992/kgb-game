extends TestCase
## Вторая фаза операции: смена фаз, кандидаты второго эшелона, поручения подчинённым,
## тайник для бесконтактного агента, решения резидента, ориентировки о приёмах наружки.

const C := "tar_calloway_martin"
const HALES := "tar_hales_robert"
const JENKINS := "tar_jenkins_clara"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


## Первая фаза пройдена быстрым путём: Кэллоуэй завербован и получил обещанное → неделя 7.
func _act2() -> Dictionary:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), H.NEXT,
		H.resolve("op_a1_recon_first_virginia", "abort"), H.resolve("op_a1_recon_potomac_cellar")]).state
	s = H.approve(self, s, C)
	s = H.play(self, s, [{"type": "recruitment", "target_id": C, "result": "success"}, H.pay(C)]).state
	s.agents[C].loyalty = 70  # быстрый путь без беседы: агент лоялен и приносит донесения
	return H.play(self, s, [H.NEXT, H.report("truth")]).state


func test_phase_transition() -> void:
	var s := _act2()
	eq([s.act, s.week, s.phase, s.ending], [2, 7, "morning", null])
	for id in ["cable_a2_w7_directive", "cable_a2_w7_relay", "cable_a2_w7_anonymous_letter", "cable_a2_w7_post_letters"]:
		ok(s.delivered_cables.has(id), id)
	ok(s.targets[HALES].unlocked, "Хэйлс установлен: анонимное письмо и донесение Кэллоуэя")
	ok(not s.targets[JENKINS].unlocked, "Дженкинс — ещё нет")
	var w8: Dictionary = H.play(self, s, H.quiet_week()).state
	ok(w8.clues.has("clue_hales_named_by_calloway") and w8.clues.has("clue_vargas_named_by_calloway"), "агент приносит и старые, и новые донесения — по одному в неделю")


func test_reports_gated_by_phase() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_potomac_cellar"), H.NEXT, H.resolve("op_a1_recon_potomac_cellar")]).state
	s = H.approve(self, s, C)
	s = _do(s, {"type": "recruitment", "target_id": C, "result": "success"}).state
	s = H.play(self, s, [H.NEXT, H.report("truth"), H.NEXT, H.NEXT, H.NEXT, H.report("truth")]).state
	eq(s.act, 1)
	ok(not s.clues.has("clue_hales_named_by_calloway"), "в первой фазе агент о ФБР не сообщает")


func test_delegation() -> void:
	var s := _act2()
	var c: Dictionary = H.content().duplicate(true)
	ok(not Delegation.unlocked(s, c), "пока только два личных выхода")
	s = H.play(self, s, [H.NEXT, H.plan("op_a2_recon_fbi_cafe"), H.NEXT, H.resolve("op_a2_recon_fbi_cafe")]).state
	ok(Delegation.unlocked(s, c), "три личных выхода — можно поручать")
	# Подчинённый с хвостом: заметил — ушёл, не заметил — как пропущенный хвост.
	var w8: Dictionary = H.play(self, s, [H.NEXT, H.report("truth"), H.NEXT]).state
	eq([w8.week, w8.phase], [8, "day"])
	var locked := w8.duplicate(true)
	locked.personal_ops = 0
	has_text(Campaign.dispatch(locked, c, {"type": "plan_op", "op_id": "op_a2_rally_lafayette", "route": H.GOOD_ROUTE, "operative": "op_technician"}).error, "личных выходов")
	for chance in [1.0, 0.0]:
		for o in c.operatives:
			o.notice_chance = chance
		var r := Campaign.dispatch(w8, c, {"type": "plan_op", "op_id": "op_a2_rally_lafayette", "route": H.GOOD_ROUTE, "operative": "op_technician"})
		eq(r.error, "")
		has_text(Campaign.dispatch(r.state, c, {"type": "plan_op", "op_id": "op_a2_drop_ellis", "route": H.GOOD_ROUTE, "operative": "op_technician"}).error, "недоступно")
		var ev: Dictionary = Campaign.dispatch(r.state, c, H.NEXT).state
		var res := Campaign.dispatch(ev, c, {"type": "resolve_op", "op_id": "op_a2_rally_lafayette"})
		eq(res.state.op_results.op_a2_rally_lafayette, "aborted" if chance == 1.0 else "tail_missed")
		ok(res.events.any(func(e): return e.type == "operative_report" and e.noticed == (chance == 1.0)))
		eq(res.state.personal_ops, ev.personal_ops, "поручение не считается личным выходом")
	eq(Delegation.notice_chance(H.content(), "op_technician", ["site_georgetown_post_office", "site_wisconsin_bookshop", "site_m_street_tobacconist"]), 0.4, "точки в одном районе — заметить труднее")


func test_contactless_recruitment_by_drop() -> void:
	var s := _act2()
	s = H.play(self, s, H.quiet_week() + H.quiet_week() + [H.NEXT]).state
	eq(s.week, 9)
	ok(s.targets[HALES].unlocked, "Хэйлс установлен по письму и сообщению Кэллоуэя")
	ok(not Campaign.available_ops(s, H.content()).any(func(o): return o.op_id == "op_a2_drop_ellis"), "тайник — только по утверждённому заключению")
	s = H.approve(self, s, HALES)
	has_text(Meeting.meet_error(s, H.content(), HALES), "тайник")
	# Первый выход с самолётом над маршрутом — сворачиваем; второй — чисто, контакт установлен.
	s = H.play(self, s, [H.plan("op_a2_drop_ellis"), H.NEXT, H.resolve("op_a2_drop_ellis", "abort"), H.NEXT, H.report("truth"), H.NEXT, H.plan("op_a2_drop_ellis"), H.NEXT]).state
	var r := _do(s, H.resolve("op_a2_drop_ellis"))
	eq(r.state.op_results.op_a2_drop_ellis, "clean")
	ok(r.state.targets[HALES].recruited, "связь через тайник установлена")
	ok(r.events.any(func(e): return e.type == "contact_established"))


func test_decisions() -> void:
	var c := H.content()
	var s := _act2()
	eq(Decisions.pending(s, c), [])
	while s.week < 12:
		s = H.play(self, s, H.quiet_week()).state
	var pend := Decisions.pending(s, c)
	eq(pend.map(func(d): return d.decision_id).filter(func(id): return H.TESTED_DECISIONS.has(id)), ["dec_a2_colleague"])
	var night: Dictionary = H.play(self, s, [H.NEXT, H.NEXT, H.NEXT]).state
	has_text(_do(night, H.report("truth")).error, "Сначала примите решение")
	var r := _do(night, {"type": "decide", "decision_id": "dec_a2_colleague", "option_id": "proceed"})
	eq(r.error, "")
	ok(r.state.flags.has("out_op_diplomat"), "«Дипломат» выведен из работы")
	ok(not Delegation.available(r.state, c).any(func(o): return o.operative_id == "op_diplomat"))
	eq(_do(H.auto_decide(r.state), H.report("truth")).error, "")
	# Оперативная игра: наружки меньше каждую ночь.
	var g: Dictionary = r.state.duplicate(true)
	g.decisions["dec_a2_monopoly"] = "game"
	eq(Decisions.weekly_sog(g, c), -2)


func test_validator_technique_needs_memo() -> void:
	var e := H.entries()
	for x in H.file(e, "cables/act1.json"):
		if x.cable_id == "cable_a2_w8_aircraft":
			x.week = 9
	has_issue(H.errors(e), "technique", "наблюдение с воздуха")


## Сюжетные линии агента: вербовка ставит флаг recruited_<id>, документы линии приходят по нему.
func test_recruited_flag_gates_line() -> void:
	var s := _act2()
	ok(s.flags.has("recruited_" + C), "флаг вербовки Кэллоуэя")
	ok(not s.flags.has("recruited_tar_vargas_ellen"), "Варгас не завербована — флага нет")
	s = H.play(self, s, H.quiet_week() + H.quiet_week() + H.quiet_week() + H.quiet_week()).state
	ok(not s.delivered_cables.has("cable_au_w10_audit"), "слух о ревизии — только если Варгас работает на резидентуру")


## Чистый выход с success_flag ставит флаг линии.
func test_success_flag() -> void:
	var op: Dictionary = {}
	for o in H.content().ops:
		if o.op_id == "op_a2_illegal_drop":
			op = o
	eq(String(op.get("success_flag", "")), "illegal_supplied")
