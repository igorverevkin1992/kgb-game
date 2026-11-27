extends TestCase
## Демоверсия: кампания с отметкой mode_demo заканчивается после фазы campaign.demo.last_act
## итогом demo_complete; в полной игре то же сохранение продолжается со следующей фазы.


## Конец второй фазы: ночь недели 16, задача выполнена.
func _act2_end(demo: bool) -> Dictionary:
	var c := H.content()
	var s := H.fresh()
	if demo:
		s.flags.append(Campaign.DEMO_FLAG)
	for d in c.decisions:
		if int(d.act) < 3:
			s.decisions[d.decision_id] = d.options[0].option_id
	s.act = 2
	s.week = 16
	s.phase = "night"
	s.goal_reached = true
	return H.auto_decide(s)


func test_demo_ends_after_last_act() -> void:
	eq(Campaign.demo_last_act(H.content()), 2, "демоверсия — первые две фазы")
	var r := Campaign.dispatch(_act2_end(true), H.content(), H.report("truth"))
	eq(r.error, "")
	eq(r.state.ending, Campaign.DEMO_END)
	ok(r.events.any(func(e): return e.type == "act_completed" and e.act == 2), "вторая фаза засчитана")
	ok(not Endings.is_final(r.state.ending), "это не концовка кампании")


func test_full_game_continues() -> void:
	var r := Campaign.dispatch(_act2_end(false), H.content(), H.report("truth"))
	eq([r.state.ending, r.state.act], [null, 3], "без отметки демоверсии кампания идёт дальше")


func test_continue_full_from_demo_save() -> void:
	var c := H.content()
	var ended: Dictionary = Campaign.dispatch(_act2_end(true), c, H.report("truth")).state
	var fund := int(ended.fund_usd)
	var r := Campaign.continue_full(ended, c)
	eq(r.error, "")
	eq([r.state.ending, r.state.act, r.state.week, r.state.phase], [null, 3, 17, "morning"])
	ok(not Campaign.is_demo(r.state), "отметка демоверсии снята")
	eq(int(r.state.fund_usd), fund + int(Campaign.next_act_def(ended, c).get("fund_usd", 0)), "перевод Центра на третью фазу")
	ok(r.state.delivered_cables.any(func(id): return id.begins_with("cable_a3")), "почта третьей фазы пришла")
	eq(ended.ending, Campaign.DEMO_END, "исходное состояние не изменилось")
	eq(Campaign.continue_full(r.state, c).error, "Продолжить можно только сохранение демоверсии")


func test_demo_save_roundtrip() -> void:
	var ended: Dictionary = Campaign.dispatch(_act2_end(true), H.content(), H.report("truth")).state
	var r := Saves.deserialize(Saves.serialize(ended), H.content())
	ok(r.ok, "сохранение демоверсии загружается: %s" % r.get("error", ""))
