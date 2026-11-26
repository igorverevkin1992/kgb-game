extends TestCase
## Сохранения: формат, проверка при загрузке, чекпоинты, слоты, «Железный занавес».


func _weeks(n: int, start: Dictionary = {}) -> Array:
	var s: Dictionary = start if not start.is_empty() else H.fresh()
	var out := [s]
	for i in n:
		s = H.play(self, s, H.quiet_week()).state
		out.append(s)
	return out


func test_roundtrip_and_same_future() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week("embellished") + [H.NEXT, H.plan("op_a1_recon_first_virginia")]).state
	var st := Saves.MemoryStorage.new()
	st.write("autosave", Saves.serialize(s))
	var loaded := Saves.deserialize(st.read("autosave"), H.content())
	ok(loaded.ok, str(loaded.get("error")))
	eq(loaded.state, s)
	var rest := [H.NEXT, H.resolve("op_a1_recon_first_virginia"), H.NEXT, H.report("embellished")] + H.quiet_week("embellished") + H.quiet_week("embellished")
	eq(H.play(self, loaded.state, rest).state, H.play(self, s, rest).state)


func test_broken_saves_explain() -> void:
	has_text(Saves.deserialize("{не json", H.content()).error, "не JSON")
	var data: Dictionary = JSON.parse_string(Saves.serialize(H.fresh()))
	data.state.week = "вторник"
	has_text(Saves.deserialize(JSON.stringify(data), H.content()).error, "week")
	data = JSON.parse_string(Saves.serialize(H.fresh()))
	data.state.clues.append("clue_deleted_long_ago")
	has_text(Saves.deserialize(JSON.stringify(data), H.content()).error, "clue_deleted_long_ago")
	eq(Saves.deserialize("", H.content()).error, "Слот пуст")


func test_checkpoint_on_new_month() -> void:
	var w := _weeks(6)  # недели 1..7: 1, 8, 15, 22, 29 октября, 5 и 12 ноября
	var ids: Array = []
	for i in range(1, w.size()):
		var id := Saves.checkpoint_for(w[i - 1], w[i], H.content())
		if id != "":
			ids.append(id)
	eq(ids, ["checkpoint-a1-w6"])
	var s0 := H.fresh()
	eq(Saves.checkpoint_for(s0, Campaign.dispatch(s0, H.content(), H.NEXT).state, H.content()), "")


func test_checkpoint_limit() -> void:
	var st := Saves.MemoryStorage.new()
	var s := H.fresh()
	for i in Saves.MAX_CHECKPOINTS + 3:
		Saves.write_checkpoint(st, "checkpoint-test-%d" % i, s)
	var list := Saves.list_checkpoints(st)
	eq(list.size(), Saves.MAX_CHECKPOINTS)
	eq(list[0], "checkpoint-test-3")
	eq(st.read("checkpoint-test-0"), "")


func test_persist_autosave_and_checkpoints() -> void:
	var st := Saves.MemoryStorage.new()
	var w := _weeks(6)
	Saves.persist(st, null, w[0], H.content())
	for i in range(1, w.size()):
		Saves.persist(st, w[i - 1], w[i], H.content())
	eq(Saves.list_checkpoints(st).size(), 2, "старт + ноябрь")
	eq(Saves.slot_info(st, Saves.AUTOSAVE, H.content()).week, w[-1].week)


func test_manual_slot() -> void:
	var st := Saves.MemoryStorage.new()
	var s: Dictionary = _weeks(2)[-1]
	ok(Saves.save_manual(st, "manual-1", s))
	eq(Saves.load_slot(st, "manual-1", H.content()).state, s)
	var info := Saves.slot_info(st, "manual-1", H.content())
	eq([info.week, info.act, info.ironman], [s.week, 1, false])


func test_ironman() -> void:
	var st := Saves.MemoryStorage.new()
	var start := H.fresh()
	start.flags.append(Campaign.IRONMAN_FLAG)
	var w := _weeks(6, start)
	Saves.persist(st, null, w[0], H.content())
	for i in range(1, w.size()):
		Saves.persist(st, w[i - 1], w[i], H.content())
	eq(Saves.list_checkpoints(st), [])
	ok(not Saves.save_manual(st, "manual-1", w[-1]))
	ok(Saves.slot_info(st, Saves.AUTOSAVE, H.content()).ironman)
