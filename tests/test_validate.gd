extends TestCase
## Валидатор контента: каждое правило ловит поломку настоящего контента.


func test_real_content_passes() -> void:
	var r := ContentLoader.validate(H.entries())
	eq(r.errors.map(ContentLoader.format_issue), [])
	ok(r.content.targets.size() >= 2)


func test_broken_clue_unknown_op() -> void:
	var e := H.entries()
	H.clue(e, "clue_vargas_mortgage_desk").source.from = "op_a1_recon_nowhere"
	var errs := H.errors(e)
	has_issue(errs, "refs", "op_a1_recon_nowhere")
	eq(errs.filter(func(x): return x.rule == "refs")[0].file, "clues/vargas.json")


func test_schema_error_in_russian_with_path() -> void:
	var e := H.entries()
	H.clue(e, "clue_vargas_hospital_calls").source.channel = "telepathy"
	var err: Dictionary = H.errors(e)[0]
	eq(err.rule, "schema")
	eq(err.file, "clues/vargas.json")
	ok(String(err.where).ends_with(".source.channel"), "где: " + str(err.where))
	has_text(err.message, "допустимо")


func test_unknown_field_is_warning() -> void:
	var e := H.entries()
	(H.file(e, "targets/tar_vargas_ellen.json") as Dictionary)["unlok"] = {}
	var r := ContentLoader.validate(e)
	ok(r.warnings.any(func(w): return String(w.message).contains("unlok")), "нет предупреждения об опечатке")


func test_three_clue_two_sources() -> void:
	var e := H.entries()
	H.file(e, "targets/tar_vargas_ellen.json").unlock.clue_ids = ["clue_vargas_bank_position", "clue_vargas_mortgage_desk"]
	has_issue(H.errors(e), "three-clue")


func test_three_clue_dead_end_without_one_source() -> void:
	var e := H.entries()
	H.file(e, "targets/tar_vargas_ellen.json").unlock.clues_required = 3
	eq(H.errors(e).filter(func(x): return x.rule == "three-clue").size(), 3)


func test_key_axis_needs_three_clues() -> void:
	var e := H.entries()
	H.clue(e, "clue_calloway_vgu_profile").reveals = []
	has_issue(H.errors(e), "mice-three-clue", "Самолюбие")


func test_softlock_goal_unreachable() -> void:
	var e := H.entries()
	var ghost: Dictionary = H.file(e, "targets/tar_vargas_ellen.json").duplicate(true)
	ghost.target_id = "tar_ghost"
	ghost.unlock.clue_ids = ["clue_vargas_bank_position", "clue_vargas_mortgage_desk", "clue_vargas_closing_recount"]
	ghost.unlock.clues_required = 3
	e.append({"path": "targets/tar_ghost.json", "data": ghost})
	H.file(e, "campaign.json").acts[0].goal.recruit_any_of = ["tar_ghost"]
	has_issue(H.errors(e), "softlock")


func test_robustness_one_branch_failure() -> void:
	var e := H.entries()
	for id in ["clue_calloway_rent_call", "clue_calloway_eviction_notice"]:
		H.clue(e, id).reveals = []
	H.file(e, "campaign.json").acts[0].goal.recruit_any_of = ["tar_calloway_martin"]
	has_issue(H.errors(e), "robustness", "tar_vargas_ellen")


func test_sdr_ambient_shared_by_two_stops() -> void:
	var e := H.entries()
	for s in H.file(e, "map/sites.json").sites:
		if s.site_id == "site_wisconsin_bookshop":
			s.ambient_tags = ["mailman_cart"]
	has_issue(H.errors(e), "sdr", "mailman_cart")


func test_sdr_same_cue_text() -> void:
	var e := H.entries()
	for c in H.file(e, "map/cues.json"):
		if c.tag == "dark_blue_ford_ltd":
			c.text.ru = "Светло-синий седан «Форд ЛТД»"
	has_issue(H.errors(e), "sdr", "ложный повтор")


func test_sdr_tail_cue_must_be_tail_kind() -> void:
	var e := H.entries()
	H.file(e, "ops/op_a1_recon_first_virginia.json").sdr.repeating_cue = "red_buick"
	has_issue(H.errors(e), "sdr")


func test_sdr_target_must_be_target_role() -> void:
	var e := H.entries()
	H.file(e, "ops/op_a1_recon_potomac_cellar.json").location.site_id = "site_safeway_clarendon"
	has_issue(H.errors(e), "sdr")


func test_sdr_good_route_must_exist() -> void:
	var e := H.entries()
	for s in H.file(e, "map/sites.json").sites:
		if s.role == "stop":
			s.district = "georgetown" if s.pos.x > 30 else "arlington"
	has_issue(H.errors(e), "sdr", "правильный проверочный маршрут")


func test_unknown_site() -> void:
	var e := H.entries()
	H.file(e, "ops/op_a1_recon_potomac_cellar.json").location.site_id = "site_nowhere"
	has_issue(H.errors(e), "refs")


func test_document_too_long() -> void:
	var e := H.entries()
	H.clue(e, "clue_vargas_drawer_memo").text.ru = "слово ".repeat(151)
	has_issue(H.errors(e), "text-length")


func test_duplicate_id() -> void:
	var e := H.entries()
	H.clue(e, "clue_calloway_rent_call").clue_id = "clue_vargas_drawer_memo"
	has_issue(H.errors(e), "duplicate")


func test_week_outside_act() -> void:
	var e := H.entries()
	H.file(e, "ops/op_a1_recon_potomac_cellar.json").week = 12
	has_issue(H.errors(e), "weeks")


func test_polygraph_unknown_variable() -> void:
	var e := H.entries()
	H.file(e, "polygraph/exam_cia_may_1986.json").question_sequence[1].pass_formula = "luck >= 50"
	has_issue(H.errors(e), "polygraph")


func test_perfect_player_act1() -> void:
	var c := H.content()
	var res := ContentSim.run(c, {"max_act": 1})
	var rec: Array = res.recruited.keys()
	rec.sort()
	eq(rec, ["tar_calloway_martin", "tar_vargas_ellen"])
	eq(res.clues.size(), c.clues.filter(func(x): return x.source.channel != "agent" or int(x.get("act", 1)) <= 1).size() - c.clues.filter(func(x): return x.source.channel in ["document", "field", "meeting"] and _act_of(c, x) > 1).size())
	var full := ContentSim.run(c, {"max_act": 2})
	eq(full.clues.size(), c.clues.size(), "во второй фазе находятся все сведения")
	ok(full.recruited.has("tar_hales_robert") and full.recruited.has("tar_jenkins_clara"), "второй эшелон достижим")


func _act_of(c: Dictionary, clue: Dictionary) -> int:
	var from: String = clue.source.from
	for k in ["cables", "ops", "dialogs"]:
		for x in c[k]:
			if x.get("cable_id", x.get("op_id", x.get("dialog_id", ""))) == from:
				if k == "dialogs":
					return Campaign.target_by_id(c, x.target_id).act
				return int(x.act)
	return 1
	var without_vargas := ContentSim.run(c, {"max_act": 1, "failed_targets": ["tar_vargas_ellen"]})
	ok(without_vargas.recruited.has("tar_calloway_martin"), "Кэллоуэй достижим без Варгас")
