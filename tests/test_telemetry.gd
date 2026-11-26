extends TestCase
## Журнал плейтеста: запись сессии в файл и сводка «где застряли / где бросили / что не вышло».


func test_summary() -> void:
	var c1 := {"act": 1, "week": 3, "phase": "evening", "view": "map"}
	var c2 := {"act": 1, "week": 2, "phase": "day", "view": "mice"}
	var done := [{"type": "session", "t": 0}, {"type": "action", "a": "advance_phase", "t": 10, "ctx": c1},
		{"type": "event", "e": "act_completed", "act": 1, "t": 1800, "ctx": c1}]
	var quit := [{"type": "session", "t": 0}, {"type": "idle", "seconds": 300, "t": 400, "ctx": c2},
		{"type": "action", "a": "pin_clue", "err": "Не вяжется: сведения не относятся к этому кандидату", "t": 401, "ctx": c2},
		{"type": "stuck", "t": 420, "ctx": c2}, {"type": "action", "a": "use_hint", "t": 600, "ctx": c2}]
	var s := TelemetrySummary.summarize([done, quit])
	eq(s.sessions, 2)
	eq(s.completed, 1)
	eq(s.seconds, 2400)
	eq(s.hints, 1)
	var where := TelemetrySummary.place({"ctx": c2})
	eq(where, "фаза 1 · неделя 2 · день · доска мотивов")
	eq(s.stuck, {where: 1})
	eq(s.idle, {where: 300})
	eq(s.last_places, {where: 1}, "где бросил второй тестер")
	var text := TelemetrySummary.format(s)
	has_text(text, "Дошли до конца первой фазы операции: 1 из 2 (50%")
	has_text(text, "Не вяжется")


func test_file_written() -> void:
	var t := Telemetry.new()
	var s := H.fresh()
	t.start_session(s, "")
	t.action({"type": "advance_phase"}, "", [{"type": "phase_changed"}], s, "")
	t.action({"type": "plan_op"}, "Выходы в город готовят днём, а сейчас утро", [], s, "map")
	t.stuck(s, "map")
	var lines := FileAccess.get_file_as_string(t.path).split("\n", false)
	eq(lines.size(), 4)
	var last = JSON.parse_string(lines[-1])
	eq(last.type, "stuck")
	eq(last.ctx.view, "map")
	ok(String(JSON.parse_string(lines[2]).get("err", "")).contains("днём"))
	DirAccess.remove_absolute(t.path)
	t.free()
