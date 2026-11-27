extends TestCase
## Движок кампании: три недели разными стилями игры, правила фаз, ложь, проверочный маршрут.

const NEXT := H.NEXT


func test_new_campaign() -> void:
	var s := H.fresh()
	eq([s.act, s.week, s.phase, s.centre_trust, s.fund_usd], [1, 1, "morning", 50, 40000])
	eq(s.risks, {"sog_heat": 10, "mole_hunt": 0, "treasury": 0, "moscow_pressure": 20})
	var cables: Array = s.delivered_cables.duplicate()
	cables.sort()
	eq(cables, ["cable_a1_w1_directive", "cable_a1_w1_file_vargas", "cable_a1_w1_post_clipping", "cable_a1_w1_press_campaign", "cable_a1_w1_staff"])
	eq(s.clues, [], "улики из документов игрок снимает сам")
	eq(Campaign.untaken_chunks(s, H.content(), "cable_a1_w1_file_vargas").size(), 1)
	eq(Campaign.unread_cables(s).size(), 5)
	eq(Campaign.available_ops(s, H.content()), [])


func test_cautious_resident() -> void:
	var s := H.fresh()
	s = H.play(self, s, H.quiet_week()).state
	eq([s.week, s.phase, s.centre_trust, s.risks.sog_heat], [2, "morning", 52, 6], "неделя 1")
	s = H.play(self, s, [NEXT, H.plan("op_a1_recon_first_virginia"), NEXT, H.resolve("op_a1_recon_first_virginia", "abort"), NEXT, H.report("truth")]).state
	eq([s.op_results.op_a1_recon_first_virginia, s.centre_trust, s.risks.moscow_pressure, s.risks.sog_heat], ["aborted", 47, 28, 6], "неделя 2")
	s = H.play(self, s, [NEXT, H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), NEXT,
		H.resolve("op_a1_recon_first_virginia"), H.resolve("op_a1_recon_potomac_cellar")]).state
	eq(s.op_results.op_a1_recon_first_virginia, "clean", "повторный выход чистый")
	eq(s.risks.sog_heat, 6, "свёрнутый выход не считается посещением")
	ok(s.targets.tar_vargas_ellen.unlocked and s.targets.tar_calloway_martin.unlocked, "обе цели установлены")
	var axes: Array = s.targets.tar_calloway_martin.discovered_axes.duplicate()
	axes.sort()
	eq(axes, ["ego", "money"], "мотивы Кэллоуэя вскрыты уликами")
	var no_board := Campaign.dispatch(s, H.content(), {"type": "recruitment", "target_id": "tar_calloway_martin", "result": "success"})
	has_text(no_board.error, "доска мотивов")
	s = H.approve(self, s, "tar_calloway_martin")
	var end := H.play(self, s, [{"type": "recruitment", "target_id": "tar_calloway_martin", "result": "success"}, H.pay("tar_calloway_martin"), NEXT, H.report("truth")])
	ok(end.state.targets.tar_calloway_martin.recruited)
	ok(end.events.any(func(e): return e.type == "act_completed" and e.act == 1), "акт завершён")
	eq(end.state.ending, null, "кампания продолжается")
	eq([end.state.act, end.state.week, end.state.phase], [2, 7, "morning"], "вторая фаза операции, январь 1985 года")
	eq(end.state.risks.moscow_pressure, 3)


func test_reckless_resident() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week()).state
	s = H.play(self, s, [NEXT, H.plan("op_a1_recon_first_virginia"), NEXT, H.resolve("op_a1_recon_first_virginia")]).state
	eq(s.op_results.op_a1_recon_first_virginia, "tail_missed")
	eq(s.risks.sog_heat, 31)
	ok(s.flags.has("fbi_noted_arlington_bank_visit"))
	s = H.approve(self, s, "tar_vargas_ellen")
	var premature := Campaign.dispatch(s, H.content(), {"type": "recruitment", "target_id": "tar_vargas_ellen", "result": "success"})
	has_text(premature.error, "компромат")
	ok(premature.state == s, "состояние не меняется")
	s = H.play(self, s, [{"type": "recruitment", "target_id": "tar_vargas_ellen", "result": "failed"}, NEXT, H.report("embellished")]).state
	ok(s.targets.tar_vargas_ellen.lost)
	eq([s.risks.sog_heat, s.centre_trust], [46, 58])
	eq(s.lies, [{"week": 2, "kind": "embellished"}])
	s = H.play(self, s, [NEXT, H.plan("op_a1_recon_potomac_cellar"), NEXT, H.resolve("op_a1_recon_potomac_cellar")]).state
	s = H.approve(self, s, "tar_calloway_martin")
	s = H.play(self, s, [{"type": "recruitment", "target_id": "tar_calloway_martin", "result": "success"}, H.pay("tar_calloway_martin"), NEXT, H.report("silence")]).state
	ok(s.targets.tar_calloway_martin.recruited)
	eq(s.lies.size(), 1, "умолчание без сбоев — не ложь")
	eq(s.act, 2, "началась вторая фаза операции")


func test_idle_recall() -> void:
	var s := H.fresh()
	var guard := 0
	while s.ending == null and guard < 40:
		s = H.play(self, s, H.quiet_week()).state
		guard += 1
	eq([s.ending, s.week, s.risks.moscow_pressure, s.risks.sog_heat], ["recalled", 12, 100, 0])


func test_phase_rules_reject_without_change() -> void:
	var s := H.fresh()
	for a in [H.plan("op_a1_recon_first_virginia"), H.report("truth"), {"type": "recruitment", "target_id": "tar_vargas_ellen", "result": "success"}]:
		var r := Campaign.dispatch(s, H.content(), a)
		ok(r.error != "", "отклонено: " + a.type)
		ok(r.state == s and r.events.is_empty())


func test_evening_requires_resolved_ops() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [NEXT, H.plan("op_a1_recon_first_virginia"), NEXT]).state
	has_text(Campaign.dispatch(s, H.content(), NEXT).error, "Не проведены выходы")


func test_ops_per_week_limit() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [NEXT]).state
	var ops := Campaign.available_ops(s, H.content())
	ok(ops.size() >= 2)
	s = H.play(self, s, [H.plan(ops[0].op_id), H.plan(ops[1].op_id)]).state
	eq(s.planned_ops.size(), H.content().balance.ops.per_week)


func test_state_not_mutated() -> void:
	var s := H.fresh()
	var snap := s.duplicate(true)
	H.play(self, s, H.quiet_week())
	eq(s, snap)


func test_lies_deterministic() -> void:
	var run := func():
		var s := H.fresh()
		for i in 8:
			if s.ending != null:
				break
			s = H.play(self, s, H.quiet_week("embellished")).state
		return s
	var a: Dictionary = run.call()
	var b: Dictionary = run.call()
	eq(a, b)
	ok(a.lies.size() <= 1)


func test_sdr_double_sighting_on_good_route() -> void:
	var base: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [NEXT]).state
	for seed in range(1, 26):
		var s0 := base.duplicate(true)
		s0.rng = seed
		var s: Dictionary = H.play(self, s0, [H.plan("op_a1_recon_first_virginia")]).state
		var counts := _counts(s.routes.op_a1_recon_first_virginia.observations)
		eq(counts.get("light_blue_ford_ltd", 0), 2, "зерно %d" % seed)
		for tag in counts:
			if tag != "light_blue_ford_ltd":
				eq(counts[tag], 1, "%s, зерно %d" % [tag, seed])


func test_sdr_single_sighting_in_one_district() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [NEXT, H.plan("op_a1_recon_first_virginia", ["site_georgetown_post_office", "site_wisconsin_bookshop", "site_m_street_tobacconist"])]).state
	eq(_counts(s.routes.op_a1_recon_first_virginia.observations).get("light_blue_ford_ltd", 0), 1)


func test_sdr_no_tail_no_repeats() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [NEXT, H.plan("op_a1_recon_potomac_cellar")]).state
	for tag in _counts(s.routes.op_a1_recon_potomac_cellar.observations).values():
		eq(tag, 1)


func test_sdr_bad_routes_rejected() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [NEXT]).state
	var g := H.GOOD_ROUTE
	for route in [g.slice(0, 2), [g[0], g[0], g[1]], [g[0], g[1], "site_potomac_cellar"], [g[0], g[1], "site_nowhere"]]:
		has_text(Campaign.dispatch(s, H.content(), H.plan("op_a1_recon_first_virginia", route)).error, "Проверочный маршрут")


func test_sdr_outside_zone_raises_heat_even_if_aborted() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [NEXT]).state
	var before: int = s.risks.sog_heat
	s = H.play(self, s, [H.plan("op_a1_recon_first_virginia", ["site_leesburg_antiques", "site_georgetown_post_office", "site_lee_highway_cleaners"]), NEXT, H.resolve("op_a1_recon_first_virginia", "abort")]).state
	eq(s.risks.sog_heat, before + H.content().balance.sog_heat.outside_25_mile_zone)
	eq(s.routes, {})


func test_site_reuse_raises_heat() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [
		NEXT, H.plan("op_a1_recon_first_virginia"), NEXT, H.resolve("op_a1_recon_first_virginia", "abort"), NEXT, H.report("truth"),
		NEXT, H.plan("op_a1_recon_first_virginia"), NEXT, H.resolve("op_a1_recon_first_virginia"), NEXT, H.report("truth"),
		NEXT, H.plan("op_a1_closing_time_vargas"), NEXT]).state
	var before: int = s.risks.sog_heat
	s = H.play(self, s, [H.resolve("op_a1_closing_time_vargas")]).state
	eq(s.risks.sog_heat, before + H.content().balance.sog_heat.site_reuse_per_use)


func _counts(obs: Array) -> Dictionary:
	var m := {}
	for stop in obs:
		var seen := {}
		for tag in stop:
			seen[tag] = true
		for tag in seen:
			m[tag] = m.get(tag, 0) + 1
	return m
