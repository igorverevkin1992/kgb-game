extends TestCase
## Третья фаза «Кронос»: перевод Центра, ужин в Джорджтауне («слепое окно» от агента в ФБР),
## беседа «эго → деньги», шантаж на старте, пробный пакет и проверка на подставу, перебежчик,
## «Список», легендированный перевод через Мендосу.

const CAL := "tar_caldwell_arthur"
const MEN := "tar_mendoza_sofia"
const HALES := "tar_hales_robert"
const JENKINS := "tar_jenkins_clara"
const DINNER := "op_a3_dinner_georgetown"
const DROP := "op_a3_drop_package"
const HANDOVER := "op_a3_handover"
const BIG := "op_a3_big_drop"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


func _act3(agents: Array = []) -> Dictionary:
	return H.play(self, H.act3_state(agents), []).state


## Неделя 18: Колдуэлл установлен, заключение утверждено, ужин подготовлен днём.
func _dinner_day(agents: Array = []) -> Dictionary:
	var s: Dictionary = H.play(self, _act3(agents), H.quiet_week()).state
	ok(s.targets[CAL].unlocked, "Колдуэлл установлен по справке и перехвату")
	s = H.approve(self, s, CAL)
	return H.play(self, s, [H.NEXT, H.plan(DINNER)]).state


func _win_meeting(s: Dictionary) -> Dictionary:
	return H.play(self, s, [
		{"type": "start_meeting", "target_id": CAL},
		{"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "ego", "clue_id": "clue_caldwell_snobs"},
		{"type": "meeting_turn", "tone": "pragmatic"},
		{"type": "meeting_turn", "tone": "empathy"},
		{"type": "meeting_turn", "tone": "pragmatic", "clue_id": "clue_caldwell_divorce"},
		{"type": "meeting_offer"},
	]).state


func test_phase_start() -> void:
	var before := H.fresh()
	var s := _act3()
	eq([s.act, s.week, s.phase], [3, 17, "morning"])
	eq(s.fund_usd, before.fund_usd + 50000, "Центр перевёл 50 000 долларов на фазу")
	ok(s.delivered_cables.has("cable_a3_w17_spravka"), "справка на Колдуэлла пришла")
	eq(Campaign.week_date(H.content(), 3, 17), {"year": 1985, "month": 4, "day": 22})


func test_dinner_needs_op_and_blind_window() -> void:
	var s := _dinner_day()
	has_text(Meeting.meet_error(s, H.content(), CAL), "Ужин в Джорджтауне")
	ok(Campaign.tail_present(s, Campaign.op_by_id(H.content(), DINNER), H.content()), "без агента в ФБР за ужином следят")
	var r: Dictionary = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state
	eq(r.op_results[DINNER], "tail_missed")
	ok(r.flags.has("fbi_photo_dinner"), "ФБР сфотографировало подход")
	# С Хэйлсом — «слепое окно» при пересменке бригад.
	var h := _dinner_day([HALES])
	ok(Campaign.blind_window(h, Campaign.op_by_id(H.content(), DINNER), H.content()), "слепое окно открыто")
	var hr: Dictionary = H.play(self, h, [H.NEXT, H.resolve(DINNER)]).state
	eq(hr.op_results[DINNER], "clean")
	ok(not hr.flags.has("fbi_photo_dinner"))


func test_blackmail_at_start_ends_meeting() -> void:
	var s := _dinner_day([JENKINS, HALES])
	s = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state
	s.clues.append("clue_caldwell_by_jenkins")  # донесение Дженкинс о взыскании
	# Приколоть компромат и сразу выложить его — Колдуэлл уходит писать рапорт.
	s = _do(s, {"type": "pin_clue", "clue_id": "clue_caldwell_by_jenkins", "target_id": CAL, "axis": "compromise"}).state
	var r: Dictionary = H.play(self, s, [{"type": "start_meeting", "target_id": CAL},
		{"type": "meeting_turn", "tone": "pressure", "clue_id": "clue_caldwell_by_jenkins"}]).state
	ok(r.meeting == null and r.targets[CAL].lost, "шантаж на старте — подход провален")


func test_ego_then_money_recruits() -> void:
	var s := _dinner_day([HALES])
	s = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state
	s = _win_meeting(s)
	ok(s.targets[CAL].recruited, "«деловое партнёрство» принято")
	eq(s.tapes[-1].outcome, "recruited")
	ok(s.clues.size() > 0 and Meeting.heard(s, H.content(), Campaign.clue_by_id(H.content(), "clue_mendoza_house")), "оговорка о Софии на катушке")


func test_package_dangle_and_list() -> void:
	var c := H.content()
	var s := _dinner_day([HALES, JENKINS])
	s = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state
	s = _win_meeting(s)
	s = H.play(self, s, [H.pay(CAL), H.NEXT, H.report("truth")]).state
	eq(s.week, 19)
	# Тайник: хвост пропущен — пакет подменён.
	s = H.play(self, s, [H.NEXT, H.plan(DROP), H.NEXT, H.resolve(DROP)]).state
	ok(s.package != null and s.package.dangle, "пакет из тайника под наблюдением — подстава")
	eq(Dangle.checks(s, c).drop, "mismatch")
	s = H.play(self, s, [{"type": "check_package", "channel": "archive"}]).state
	eq(s.package.archive, "mismatch", "картотека Дженкинс вскрывает расхождения")
	ok(Cipher.available_requests(s, c).any(func(r): return r.request_id == "req_a3_package"), "можно запросить сверку в Центре")
	s = H.play(self, s, [{"type": "reject_package"}, H.NEXT, H.report("truth")]).state
	# Личная передача: пакет настоящий, сверка в Центре — с шифрограммой.
	s = H.play(self, s, [H.NEXT, H.plan(HANDOVER), H.NEXT, H.resolve(HANDOVER), {"type": "check_package", "channel": "archive"},
		H.NEXT, {"type": "submit_report", "report": "truth", "request": "req_a3_package"}]).state
	eq([s.package.source, s.package.dangle, s.package.archive, s.package.centre], ["handover", false, "ok", "ok"])
	eq(Dangle.count(s, c, "ok"), 3, "все три канала чисты")
	has_text(_do(s, {"type": "reject_package"}).error, "Другого канала")
	var acc := H.play(self, s, [{"type": "accept_package"}])
	s = acc.state
	ok(s.flags.has("package_accepted") and not s.flags.has("dangle_accepted"))
	ok(acc.events.any(func(e): return e.type == "package_accepted" and e.checked == 3))
	eq(Decisions.pending(s, c).map(func(d): return d.decision_id), ["dec_a3_defector"], "перебежчик")
	ok(not Campaign.available_ops(s, c).any(func(o): return o.op_id == BIG), "большой сброс — после решения")
	var loy: int = s.agents[CAL].loyalty
	s = H.play(self, s, [{"type": "decide", "decision_id": "dec_a3_defector", "option_id": "calm"}]).state
	eq(s.agents[CAL].loyalty, mini(100, loy + 10), "встреча успокоила «Кроноса»")
	s = H.play(self, s, [H.NEXT, H.plan(BIG), H.NEXT, H.resolve(BIG, "abort"),
		H.NEXT, H.report("truth"), H.NEXT, H.plan(BIG), H.NEXT, H.resolve(BIG)]).state
	ok(s.clues.has("clue_caldwell_list"), "«Список» получен")
	ok(s.goal_reached, "задача фазы выполнена")


func test_accepting_dangle_sets_flag() -> void:
	var s := _dinner_day()
	s = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state  # хвост за ужином пропущен
	s = _win_meeting(s)
	s = H.play(self, s, [H.NEXT, H.report("truth"), H.NEXT, H.plan(DROP), H.NEXT, H.resolve(DROP, "abort"),
		H.NEXT, H.report("truth"), H.NEXT, H.plan(DROP), H.NEXT, H.resolve(DROP)]).state
	eq(s.op_results[DROP], "clean")
	ok(s.package.dangle, "подход засвечен — пакет в тайнике подменён, хотя у закладки чисто")
	eq(Dangle.checks(s, H.content()).archive, "unavailable", "без Дженкинс картотеки нет")
	s = _do(s, {"type": "accept_package"}).state
	ok(s.flags.has("dangle_accepted"), "принята подстава — последствия в четвёртой фазе")


func test_legend_transfer() -> void:
	var c := H.content()
	var s := _dinner_day([HALES, MEN])
	s = H.play(self, s, [H.NEXT, H.resolve(DINNER)]).state
	s = _win_meeting(s)
	ok(Finance.legend_available(s, c))
	var p := Finance.plan(s, c, CAL, 50000, "legend", 1)
	eq([p.error, p.total.ctr, p.total.treasury], ["", 0, 0], "перевод «наследства» без отчёта 4789")
	var cash := Finance.plan(s, c, CAL, 50000, "cash", 1)
	ok(cash.total.lifestyle > p.total.lifestyle and cash.total.ctr == 1)
	var no := s.duplicate(true)
	no.targets[MEN].recruited = false
	has_text(Finance.plan(no, c, CAL, 50000, "legend", 1).error, "банковским контуром")
