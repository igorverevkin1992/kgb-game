extends UiTest
## Сюжетные линии: разговор не с кандидатом (инициативник у ворот), документ по условию,
## карточка смены фаз перед пятой фазой «Рим».

const NEXT := {"type": "advance_phase"}


func scene_walkin_conversation() -> void:
	var s := H.run(H.fresh(), [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}])
	s = H.run(s, [{"type": "decide", "decision_id": "dec_wi_gate", "option_id": "receive"}, NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}, NEXT])
	Game.reset_for_test(s)
	await frames(3)
	ok(s.delivered_cables.has("cable_wi_w3_report"), "рапорт о посетителе пришёл по условию")
	ok(not s.delivered_cables.has("cable_wi_w3_radio"), "сводка о всплеске — только если отказали")
	await key(KEY_5)
	ok(exists("conversation-dlg_c_walkin_1"), "разговор ждёт")
	await press("converse-dlg_c_walkin_1")
	has_text("meeting", "Гэри Уолш")
	has_text("meeting-offer", "Договориться")
	await press("tone-pragmatic")
	await shot("dialog-walkin")


func scene_rome_phase_card() -> void:
	var s := H.act4_state()
	s.act = 4
	s.week = 45
	s.phase = "night"
	s.goal_reached = true
	s = H.run(s, [{"type": "submit_report", "report": "truth"}])
	Game.reset_for_test(s)
	Game.phase_card = 4
	Game.changed.emit()
	await frames()
	has_text("phase-card", "Пятая фаза операции «Рим»")
	await shot("phase-card-rome")
	await press("phase-card-continue")
	has_text("act", "Пятая фаза операции")
