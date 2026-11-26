class_name Telemetry
extends Node
## Журнал плейтеста (только на компьютере игрока, в сеть ничего не уходит): каждая сессия —
## файл user://telemetry/session-<дата>.jsonl, по строке JSON на запись:
##   session (версия, начало) · action (тип действия, отказ движка) · event (заметные события)
##   · view (открыт модуль) · idle (между действиями прошло больше IDLE_SECONDS) · stuck (F8).
## У каждой записи: t — секунды с начала сессии, ctx — фаза операции, неделя, время суток, модуль.
## Сводку строит tools/telemetry-report.sh (engine/telemetry_summary.gd).

const DIR := "user://telemetry"
const IDLE_SECONDS := 120
## События, которые стоит видеть в отчёте о плейтесте.
const NOTABLE := ["target_unlocked", "analysis_approved", "analysis_rejected", "target_recruited", "target_lost",
	"op_resolved", "act_completed", "game_over", "directive_verified", "promise_kept", "hint_used", "meeting_ended", "agent_broke"]

var enabled := true
var _file: FileAccess = null
var _start_ms := 0
var _last_ms := 0
var path := ""


func start_session(state: Dictionary, view: String) -> void:
	_start_ms = Time.get_ticks_msec()
	_last_ms = _start_ms
	write({"type": "session", "version": str(ProjectSettings.get_setting("application/config/version", "")),
		"os": OS.get_name(), "date": Time.get_datetime_string_from_system()}, state, view)


func write(entry: Dictionary, state: Dictionary, view: String) -> void:
	if not enabled:
		return
	if _file == null:
		DirAccess.make_dir_recursive_absolute(DIR)
		var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "-")
		path = DIR.path_join("session-%s.jsonl" % stamp)
		_file = FileAccess.open(path, FileAccess.WRITE)
		if _file == null:
			enabled = false
			return
	var e := entry.duplicate()
	e.t = int((Time.get_ticks_msec() - _start_ms) / 1000)
	if not state.is_empty():
		e.ctx = {"act": state.act, "week": state.week, "phase": state.phase, "view": view}
	_file.store_line(JSON.stringify(e))
	_file.flush()


## Действие игрока: простой перед ним, сам ход (с отказом движка, если был) и заметные события.
func action(a: Dictionary, error: String, events: Array, state: Dictionary, view: String) -> void:
	var now := Time.get_ticks_msec()
	var gap := int((now - _last_ms) / 1000)
	_last_ms = now
	if gap >= IDLE_SECONDS:
		write({"type": "idle", "seconds": gap}, state, view)
	var rec := {"type": "action", "a": a.get("type", "")}
	if error != "":
		rec.err = error
	write(rec, state, view)
	for ev in events:
		if NOTABLE.has(ev.type):
			var x := {"type": "event", "e": ev.type}
			for k in ["act", "ending", "outcome", "target_id", "op_id", "wrong", "level"]:
				if ev.has(k):
					x[k] = ev[k]
			write(x, state, view)


func view_opened(state: Dictionary, view: String) -> void:
	write({"type": "view"}, state, view)


func stuck(state: Dictionary, view: String) -> void:
	write({"type": "stuck"}, state, view)


func folder() -> String:
	return ProjectSettings.globalize_path(DIR)
