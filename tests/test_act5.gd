extends TestCase
## Пятая фаза: вариант зависит от итогов четвёртой — «Рим» (полиграф пройден), «Повторная
## проверка», «Эвакуация» (провал), «Пустой канал» («Кронос» потерян); слои по флагам каскада,
## подставы и справки Особого отдела; концовка учитывает исход пятой фазы.

const K := "tar_caldwell_arthur"


func _act5(flags: Array) -> Dictionary:
	var s := H.act4_state()
	s.act = 4
	s.week = 45
	s.phase = "night"
	s.goal_reached = true
	for f in flags + ["arrest_window_closed", "polygraph_done"]:
		if not s.flags.has(f):
			s.flags.append(f)
	return H.play(self, s, [H.report("truth")]).state


func _title(s: Dictionary) -> String:
	return T_loc(Campaign.act_text(s, Campaign.current_act_def(s, H.content()), "title"))


func T_loc(v) -> String:
	return String(v.ru)


func _to_week(s: Dictionary, week: int) -> Dictionary:
	while s.week < week and s.ending == null:
		s = H.play(self, s, H.quiet_week()).state
	return s


func test_rome_after_pass() -> void:
	var s := _act5(["polygraph_passed"])
	eq([s.act, s.week, _title(s)], [5, 47, "Рим"])
	ok(s.delivered_cables.has("cable_r_w47_directive") and not s.delivered_cables.has("cable_r_w47_evac_directive"))
	s.phase = "evening"
	s.handled = {"dlg_h_kronos_1": "agreed", "dlg_h_kronos_2": "agreed", "dlg_h_kronos_3": "agreed"}
	eq(Meeting.next_handling(s, H.content(), K).dialog_id, "dlg_h_caldwell_farewell")


func test_evacuation_after_fail() -> void:
	var s := _act5(["polygraph_failed"])
	eq(_title(s), "Эвакуация")
	ok(s.delivered_cables.has("cable_r_w47_evac_directive") and not s.delivered_cables.has("cable_r_w47_directive"), "свои документы")
	s = _to_week(s, 49)
	eq(Decisions.pending(s, H.content()).map(func(d): return d.decision_id), ["dec_r_evac"])
	s = H.play(self, s, [{"type": "decide", "decision_id": "dec_r_evac", "option_id": "exfil"}]).state
	s.handled = {"dlg_h_kronos_1": "agreed", "dlg_h_kronos_2": "agreed", "dlg_h_kronos_3": "agreed"}
	eq(Meeting.next_handling(s, H.content(), K).dialog_id, "dlg_h_caldwell_evac", "встреча «Последний сигнал»")
	s.flags.append("kronos_agreed_exfil")
	s = _to_week(s, 53)
	s = H.play(self, s, [{"type": "decide", "decision_id": "dec_r_evac_window", "option_id": "go"}]).state
	ok(s.flags.has("kronos_evacuated"))
	s = _to_week(s, 56)
	ok(s.flags.has("network_handed_over"), "сеть сдана — фаза завершена")
	eq(s.ending, "shadow_exchange")
	ok(Endings.notes(s).has("kronos_evacuated"), "итог помнит, что «Кронос» выведен")


func test_retest_branch() -> void:
	var s := _act5(["polygraph_inconclusive"])
	eq(_title(s), "Повторная проверка")
	ok(s.delivered_cables.has("cable_r_w47_retest"))
	s.flags.append("retest_passed")
	ok(Endings.checklist(s, H.content()).filter(func(x): return x.id == "polygraph")[0].ok, "пересдача засчитана")
	var f := s.duplicate(true)
	f.flags.append("retest_failed")
	eq(Endings.final(f, H.content()), "shadow_exchange", "проваленная пересдача — провал")


func test_absent_branch() -> void:
	var s := _act5(["kronos_absent"])
	eq(_title(s), "Пустой канал")
	s = _to_week(s, 56)
	ok(s.flags.has("network_handed_over") and Endings.is_final(s.ending), "без «Кроноса» фаза тоже завершается")


func test_layers() -> void:
	var s := _act5(["polygraph_passed", "draconian_measures", "dangle_accepted", "inspector_report_bad"])
	ok(s.delivered_cables.has("cable_r_w47_recall_layer"), "вызов в Особый отдел")
	s = _to_week(s, 49)
	ok(s.delivered_cables.has("cable_r_w48_anlace_layer") and s.delivered_cables.has("cable_r_w49_dangle_layer"))
