extends UiTest
## Стабильность для долгой сессии: экран перестраивается целиком на каждое действие, поэтому
## проверяем, что узлы и объекты не копятся (замена 60-минутного теста памяти), и «застрял здесь».

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]


func _counts() -> Array:
	return [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))]


func scene_no_leaks_on_rebuilds() -> void:
	await start(QUIET + QUIET + [NEXT])
	for v in Game.VIEWS:
		Game.open(v)
		await frames(2)
	Game.close()
	await frames(6)
	var before := _counts()
	for i in 40:
		for v in Game.VIEWS:
			if Game.is_unlocked(v):
				Game.open(v)
				await frames(1)
	Game.close()
	await frames(6)
	var after := _counts()
	ok(after[0] - before[0] <= 5, "узлы не копятся: было %d, стало %d" % [before[0], after[0]])
	ok(after[1] - before[1] <= 200, "объекты не копятся: было %d, стало %d" % [before[1], after[1]])


func scene_stuck_marker() -> void:
	await start()
	await key(KEY_F8)
	has_text("notice", "выключен")
	Game.telemetry.enabled = true
	await key(KEY_F8)
	has_text("notice", "записана")
	var lines := FileAccess.get_file_as_string(Game.telemetry.path).split("\n", false)
	ok(lines[-1].contains("\"stuck\""), "отметка в журнале")
	Game.telemetry.enabled = false
	await key(KEY_ESCAPE)
	await press("service-tab-settings")
	has_text("build-info", "0.10.0")
	await shot("service-settings-playtest")
	await press("service-tab-saves")
	await key(KEY_ESCAPE)
