extends TestCase
## Задания Центра: приходят по графику, ответ проверяется по делу и по документам, срок,
## снятие с контроля при смене фазы, совместимость сохранений.

const V := "tar_vargas_ellen"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


func _week2() -> Dictionary:
	return H.play(self, H.with_tasks(), H.quiet_week()).state


func test_arrives_with_due() -> void:
	var s: Dictionary = _week2()
	ok(s.tasks.has("task_a1_zone"), "задание о порядке выездов пришло во вторую неделю")
	eq([s.tasks.task_a1_zone.status, s.tasks.task_a1_zone.due], ["open", 3])
	ok(not s.tasks.has("task_a1_vargas"), "характеристика — только на завербованного агента")


func test_needs_material_and_all_answers() -> void:
	var s: Dictionary = _week2()
	var a := {"type": "answer_task", "task_id": "task_a1_zone", "answers": {"zone": "m25", "sign": "repeat"}}
	has_text(_do(s, a).error, "изучите материалы")
	s = _do(s, {"type": "read_cable", "cable_id": "cable_a1_w2_surveillance_summary"}).state
	has_text(_do(s, {"type": "answer_task", "task_id": "task_a1_zone", "answers": {"zone": "m25"}}).error, "все пункты")
	var r := _do(s, a)
	eq(r.error, "")
	eq(r.state.tasks.task_a1_zone.status, "done")
	eq(r.state.centre_trust, s.centre_trust + 3, "всё верно — Доверие +3")
	eq(_do(r.state, a).error, "Задание уже закрыто")


func test_wrong_answer_partial() -> void:
	var s: Dictionary = _do(_week2(), {"type": "read_cable", "cable_id": "cable_a1_w2_surveillance_summary"}).state
	var r := _do(s, {"type": "answer_task", "task_id": "task_a1_zone", "answers": {"zone": "m50", "sign": "repeat"}})
	eq([r.state.tasks.task_a1_zone.status, r.state.tasks.task_a1_zone.wrong], ["partial", 1])
	eq(r.state.centre_trust, s.centre_trust - 1)
	eq(r.state.risks.moscow_pressure, s.risks.moscow_pressure + 3)


func test_overdue_matches_preview() -> void:
	var s: Dictionary = H.play(self, _week2(), H.quiet_week() + [H.NEXT, H.NEXT, H.NEXT]).state
	eq([s.week, s.phase], [3, "night"])
	var fx := Cipher.report_effects(s, H.content(), "truth")
	eq(fx.overdue_tasks, 1, "предпросмотр доклада знает о сорванном задании")
	var r := _do(s, H.report("truth"))
	eq(r.state.tasks.task_a1_zone.status, "failed")
	eq(r.state.centre_trust, s.centre_trust + fx.trust, "доверие как в предпросмотре")


func test_characterization_checked_by_dossier() -> void:
	var c := H.content()
	var t := CentreTasks.by_id(c, "task_a1_vargas")
	var s := H.with_tasks()
	s.targets[V].recruited = true
	s.agents[V] = Finance.new_agent(s, c, V)
	s.agents[V].loyalty = 70
	eq(CentreTasks.correct(s, c, t.questions[0]), "money", "основа — по досье")
	eq(CentreTasks.correct(s, c, t.questions[1]), "stable", "лоялен — устойчив")
	s.agents[V].coerced = true
	eq(CentreTasks.correct(s, c, t.questions[1]), "unstable", "по принуждению — неустойчив")
	eq(CentreTasks.correct(s, c, t.questions[2]), "", "у предложения верного ответа нет")


func test_withdrawn_on_act_change() -> void:
	var s := H.act3_state()
	for id in s.tasks:
		ok(s.tasks[id].status != "open", "задания прошлых фаз не висят открытыми")


func test_save_roundtrip_with_tasks() -> void:
	var s: Dictionary = _week2()
	var r := Saves.deserialize(Saves.serialize(s), H.content())
	ok(r.ok)
	eq(JSON.stringify(r.state.tasks), JSON.stringify(s.tasks))


func test_old_save_without_tasks_loads() -> void:
	var s: Dictionary = _week2()
	s.erase("tasks")
	var r := Saves.deserialize(Saves.serialize(s), H.content())
	ok(r.ok, "сохранение без заданий (до обновления) загружается")
	eq(r.state.tasks, {})
	var next: Dictionary = H.play(self, r.state, [H.NEXT]).state
	ok(next.has("tasks"))
