extends TestCase
## Полиграф ЦРУ: вызов заранее (с источником) или в последний момент, подготовка, допрос по
## методу контрольных вопросов, пик и объяснение волнения, формулы, репетиция, итоги.

const CAL := "tar_caldwell_arthur"
const JEN := "tar_jenkins_clara"
const MEN := "tar_mendoza_sofia"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


## Ночь перед неделей `week` четвёртой фазы → утро этой недели.
func _at(week: int, agents: Array) -> Dictionary:
	var s := H.act4_state(agents)
	s.week = week - 1
	s.phase = "night"
	return H.play(self, s, [H.report("truth")]).state


func _answers(ids: Array) -> Array:
	return ids.map(func(id): return {"type": "polygraph_answer", "choice_id": id})


func test_notice_with_and_without_source() -> void:
	var w := _at(44, [CAL, JEN])
	ok(w.polygraph != null and w.polygraph.source, "с Дженкинс — за две недели")
	eq(w.polygraph.slots, 4)
	var n := _at(44, [CAL])
	ok(n.polygraph == null, "без источника на неделе 44 ещё ничего не известно")
	n = _at(45, [CAL])
	eq([n.polygraph.source, n.polygraph.slots], [false, 2], "три дня и два пункта подготовки")


func test_prep_rules() -> void:
	var s := _at(44, [CAL, JEN])
	has_text(_do(s, {"type": "polygraph_prep", "prep_id": "prep_legend"}).error, "банковским контуром")
	s = H.play(self, s, [{"type": "polygraph_prep", "prep_id": "prep_strategy_friendly"}]).state
	has_text(_do(s, {"type": "polygraph_prep", "prep_id": "prep_strategy_formal"}).error, "уже выбрана")
	has_text(_do(s, {"type": "polygraph_start", "rehearsal": false}).error, "неделю 45")
	var m := _at(44, [CAL, JEN, MEN])
	ok(_do(m, {"type": "polygraph_prep", "prep_id": "prep_legend"}).error == "", "с Мендосой легенда есть")


func test_formula() -> void:
	ok(Polygraph.formula("control_peak >= relevant_peak - 5 AND rapport >= 65", {"control_peak": 45, "relevant_peak": 50, "rapport": 70, "skepticism": 0}))
	ok(not Polygraph.formula("control_peak >= relevant_peak - 5 AND rapport >= 65", {"control_peak": 45, "relevant_peak": 51, "rapport": 70, "skepticism": 0}))
	ok(Polygraph.formula("skepticism < 60 OR rapport > 90", {"control_peak": 0, "relevant_peak": 0, "rapport": 95, "skepticism": 70}))


func test_rehearsal_then_pass() -> void:
	var s := _at(44, [CAL, JEN, MEN])
	s.agents[CAL].lifestyle = 90  # траты бросаются в глаза: без легенды финансовый вопрос опасен
	s = H.play(self, s, [{"type": "polygraph_prep", "prep_id": "prep_sleep_order"}, {"type": "polygraph_prep", "prep_id": "prep_ban_pills"},
		{"type": "polygraph_prep", "prep_id": "prep_strategy_friendly"}, {"type": "polygraph_prep", "prep_id": "prep_legend"}]).state
	var mh: int = s.risks.mole_hunt
	var ideal := _answers(["joke", "plain", "limited_hangout", "calm_no", "apples", "legend_no", "defector"])
	var r: Dictionary = H.play(self, s, [{"type": "polygraph_start", "rehearsal": true}] + ideal).state
	eq([r.polygraph.exam.verdict, r.polygraph.result, r.risks.mole_hunt], ["pass", "", mh], "репетиция без последствий")
	ok(not r.polygraph.exam.lines.any(func(l): return l.spike), "после подготовки пиков на значимых нет")
	r = H.play(self, r, [H.NEXT, H.NEXT, H.NEXT, H.report("truth")]).state
	eq(r.week, 45)
	has_text(_do(r, {"type": "advance_phase"}).error + _do(H.play(self, r, [H.NEXT, H.NEXT, H.NEXT]).state, H.report("truth")).error, "полиграфе")
	var res := H.play(self, r, [{"type": "polygraph_start", "rehearsal": false}] + ideal)
	r = res.state
	eq(r.polygraph.result, "pass")
	ok(r.flags.has("polygraph_passed") and r.flags.has("polygraph_done"))
	ok(r.goal_reached, "окно закрыто и проверка пройдена — задача фазы выполнена")
	var end: Dictionary = H.play(self, r, [H.NEXT, H.NEXT, H.NEXT, H.report("truth")]).state
	eq([end.ending, end.act, end.week], [null, 5, 47], "после полиграфа — пятая фаза «Рим»")


func test_spike_needs_rationalization() -> void:
	var s := _at(45, [CAL])
	s.agents[CAL].lifestyle = 90
	s = H.play(self, s, [{"type": "polygraph_start", "rehearsal": false}] + _answers(["plain", "plain", "rigid_denial", "angry_no"])).state
	ok(s.polygraph.exam.pending, "пик на значимом вопросе")
	has_text(_do(s, {"type": "polygraph_answer", "choice_id": "apples"}).error, "объясните волнение")
	s = H.play(self, s, [{"type": "polygraph_rationalize", "option_id": "silence"}] + _answers(["never", "calm_no"])).state
	s = H.play(self, s, [{"type": "polygraph_rationalize", "option_id": "witch_hunt"}] + _answers(["dry"])).state
	ok(["inconclusive", "fail"].has(s.polygraph.result), "без подготовки и с ошибками — не пройдено: %s" % s.polygraph.result)
	ok(s.flags.has("polygraph_done"))
