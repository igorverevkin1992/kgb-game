extends TestCase
## Шифроузел «Фиалка»: ключевой блокнот, сверка директив (подлог), факты недели и вид
## донесения, предпросмотр последствий = то, что применит движок, запросы в Центр.

const W1 := "cable_a1_w1_directive"
const FORGED := "cable_a1_w4_directive_meeting"


func _do(s: Dictionary, action: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), action)


func _read(s: Dictionary, id: String) -> Dictionary:
	return _do(s, {"type": "read_cable", "cable_id": id}).state


## Ночь 3-й недели: один выезд свёрнут на маршруте (сбой недели), второй проведён.
func _night_with_abort() -> Dictionary:
	return H.auto_decide(H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), H.NEXT,
		H.resolve("op_a1_recon_first_virginia", "abort"), H.resolve("op_a1_recon_potomac_cellar"), H.NEXT]).state)


func test_key_notebook() -> void:
	var k := Cipher.week_key(1, 1)
	eq(k.length(), Cipher.ROTORS)
	for ch in k:
		ok(Cipher.LETTERS.contains(ch), "буква ротора «%s»" % ch)
	eq(Cipher.week_key(1, 1), k, "ключ детерминирован")
	ok(Cipher.week_key(1, 2) != k, "у каждой недели свой ключ")
	var g := Cipher.week_group(1, 4)
	eq(g.length(), 5)
	ok(g.is_valid_int())
	var genuine := Campaign.cable_by_id(H.content(), W1)
	eq(Cipher.received_group(genuine), Cipher.week_group(1, 1), "подлинная директива: группа по блокноту")
	var forged := Campaign.cable_by_id(H.content(), FORGED)
	ok(forged.forged)
	ok(Cipher.received_group(forged) != Cipher.week_group(1, 4), "подложная: группа не совпадает")
	eq(Cipher.received_group(forged).length(), 5)
	ok(Cipher.cipher_groups(forged).size() >= 12)


func test_directives_go_to_cipher_not_inbox() -> void:
	var s := H.fresh()
	ok(not Cipher.unread_mail(s, H.content()).has(W1), "директива не в лотке")
	ok(Cipher.unread_mail(s, H.content()).has("cable_a1_w1_file_vargas"))
	eq(Cipher.pending_directives(s, H.content()).map(func(c): return c.cable_id), [W1])
	eq(Cipher.directive_status(s, W1), "encrypted")
	s = _read(s, W1)
	eq(Cipher.directive_status(s, W1), "decrypted")


func test_verify_genuine() -> void:
	var s := H.fresh()
	has_text(_do(s, {"type": "verify_cable", "cable_id": W1, "decision": "accept"}).error, "расшифруйте")
	has_text(_do(s, {"type": "verify_cable", "cable_id": "cable_a1_w1_file_vargas", "decision": "accept"}).error, "не поступало")
	s = _read(s, W1)
	var r := _do(s, {"type": "verify_cable", "cable_id": W1, "decision": "accept"})
	eq(r.error, "")
	eq(r.state.verified, {W1: "accept"})
	eq(r.state.risks, s.risks, "подлинная директива принята — без последствий")
	eq(r.state.centre_trust, s.centre_trust)
	eq(Cipher.pending_directives(r.state, H.content()), [])
	has_text(_do(r.state, {"type": "verify_cable", "cable_id": W1, "decision": "query"}).error, "уже принято")
	# Лишний запрос подтверждения раздражает Центр.
	var q := _do(s, {"type": "verify_cable", "cable_id": W1, "decision": "query"})
	var b: Dictionary = H.content().balance.cipher
	eq(q.state.centre_trust, s.centre_trust + b.query_genuine_trust)
	eq(q.state.risks.moscow_pressure, s.risks.moscow_pressure + b.query_genuine_pressure)
	eq(q.events[0].outcome, "confirmed")


func test_forged_directive() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.weeks(3, H.quiet_week())).state
	eq(s.week, 4)
	ok(s.delivered_cables.has(FORGED))
	s = _read(s, FORGED)
	var b: Dictionary = H.content().balance.cipher
	var acc := _do(s, {"type": "verify_cable", "cable_id": FORGED, "decision": "accept"})
	eq(acc.state.risks.sog_heat, s.risks.sog_heat + b.accept_forged_sog_heat, "ловушка ФБР — наружка растёт")
	ok(acc.state.flags.has(b.accept_forged_flag))
	var q := _do(s, {"type": "verify_cable", "cable_id": FORGED, "decision": "query"})
	eq(q.state.centre_trust, s.centre_trust + b.query_forged_trust, "раскрытый подлог — Центр доволен")
	eq(q.state.risks, s.risks)
	ok(Cipher.week_facts(q.state).any(func(f): return f.type == "directive_exposed"), "подлог попадает в факты недели")


func test_week_facts_and_classify() -> void:
	var quiet := Cipher.week_facts(H.fresh())
	eq(quiet.map(func(f): return f.type), ["quiet"])
	var s := _night_with_abort()
	var facts := Cipher.week_facts(s)
	var types: Array = facts.map(func(f): return f.type)
	ok(types.has("op_aborted") and types.has("op_done"), "обе операции в фактах: %s" % [types])
	var bad: Dictionary = facts.filter(func(f): return f.negative)[0]
	var good: Dictionary = facts.filter(func(f): return not f.negative)[0]
	eq(Cipher.classify(facts, {}), "truth")
	eq(Cipher.classify(facts, {good.key: "omit"}), "truth", "умолчать об успехе — скромность")
	eq(Cipher.classify(facts, {bad.key: "omit"}), "silence")
	eq(Cipher.classify(facts, {good.key: "embellish"}), "embellished")
	eq(Cipher.classify(facts, {bad.key: "omit", good.key: "embellish"}), "embellished")


func test_composed_report_matches_preview() -> void:
	var s := _night_with_abort()
	var bad: Dictionary = Cipher.week_facts(s).filter(func(f): return f.negative)[0]
	for case in [[{}, "truth"], [{bad.key: "omit"}, "silence"], [{bad.key: "embellish"}, "embellished"]]:
		var fx := Cipher.report_effects(s, H.content(), case[1])
		var r := _do(s, {"type": "submit_report", "choices": case[0]})
		eq(r.error, "")
		var sent: Dictionary = r.events.filter(func(e): return e.type == "report_submitted")[0]
		eq(sent.report, case[1])
		eq(r.state.centre_trust, s.centre_trust + fx.trust, "доверие как в предпросмотре (%s)" % case[1])
		eq(r.state.lies.size(), 1 if fx.lie else 0, "ложь записана (%s)" % case[1])
	eq(Cipher.report_effects(s, H.content(), "silence").check_week, 4)
	has_text(_do(s, {"type": "submit_report", "choices": {bad.key: "переврать"}}).error, "как есть")


func test_requests() -> void:
	var c := H.content()
	var s: Dictionary = H.play(self, H.fresh(), [H.NEXT, H.NEXT, H.NEXT]).state
	eq(Cipher.available_requests(s, c).size(), 2)
	# Доверие 50 < 55: в деньгах откажут.
	var r := _do(s, {"type": "submit_report", "report": "truth", "request": "req_a1_fund"})
	eq(r.error, "")
	eq(r.state.fund_usd, s.fund_usd)
	eq(r.state.centre_trust, s.centre_trust - 3 + 2)
	eq(r.state.requests[0].granted, false)
	ok(not Cipher.available_requests(r.state, c).any(func(x): return x.request_id == "req_a1_fund"), "второй раз не отправить")
	# Доверие 60: деньги дают, продление тоже.
	var rich := s.duplicate(true)
	rich.centre_trust = 60
	r = _do(rich, {"type": "submit_report", "report": "truth", "request": "req_a1_fund"})
	eq(r.state.fund_usd, s.fund_usd + 10000)
	eq(r.state.risks.moscow_pressure, s.risks.moscow_pressure + 4)
	ok(r.events.any(func(e): return e.type == "fund_changed"))
	r = _do(rich, {"type": "submit_report", "report": "truth", "request": "req_a1_deadline"})
	eq(Cipher.act_deadline(r.state, c), int(c.campaign.acts[0].weeks.to) + 2)
	has_text(_do(s, {"type": "submit_report", "report": "truth", "request": "req_nope"}).error, "нельзя")


func test_validator_cipher_rules() -> void:
	var e := H.entries()
	var cables: Array = H.file(e, "cables/act1.json")
	for x in cables:
		if x.cable_id == "cable_a1_w1_file_vargas":
			x["forged"] = true
	var reqs: Array = H.file(e, "requests/act1.json")
	reqs[0]["act"] = 4
	var camp: Dictionary = H.file(e, "campaign.json")
	camp.acts = camp.acts.filter(func(a): return int(a.act) != 4)  # фазы 4 нет — запрос к ней висит
	var errs := H.errors(e)
	has_issue(errs, "cipher", "только директива")
	has_issue(errs, "cipher", "акту 4")


func test_save_v4_migrates() -> void:
	var s := H.fresh()
	var old := s.duplicate(true)
	old.erase("verified")
	old.erase("requests")
	var text := JSON.stringify({"format": Saves.FORMAT, "version": 4, "saved_at": "", "state": old})
	var r := Saves.deserialize(text, H.content())
	eq(r.get("error", ""), "")
	ok(r.ok)
	eq(r.state.verified, {})
	eq(r.state.requests, [])
