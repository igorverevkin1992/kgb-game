extends UiTest
## Встреча на связи на магнитофоне: список встреч у агента со ставками, кнопка «Договориться»,
## итог на катушке.

const V := "tar_vargas_ellen"


func _evening() -> Dictionary:
	var s := H.fresh()
	s.targets[V].unlocked = true
	s.targets[V].recruited = true
	s.agents[V] = Finance.new_agent(s, H.content(), V)
	s.agents[V].loyalty = 55
	s.agents[V].promise_kept = true
	return H.run(s, [H.NEXT, H.NEXT])


func scene_handling_meeting() -> void:
	Game.reset_for_test(_evening())
	await frames(3)
	await key(KEY_5)
	has_text("candidate-" + V, "Встречи на связи: проведено 0 из 5")
	has_text("candidate-" + V, "донесений сразу: 1")
	await press("handle-dlg_h_vargas_1")
	ok(exists("meeting"), "встреча идёт")
	has_text("meeting-stakes", "лояльность +10")
	has_text("meeting-offer", "Договориться")
	var d := Meeting.dialog_by_id(Game.content, "dlg_h_vargas_1")
	var path := Autoplay.meeting_path(d, int(Game.state.meeting.rapport), int(Game.state.meeting.anxiety), [])
	for i in path.size():
		await press("tone-" + path[i][0])
		if i == 1:
			await shot("dialog-handling")
	await press("meeting-offer")
	eq(Game.state.handled.get("dlg_h_vargas_1"), "agreed")
	has_text("tape-0", "договорились")
