extends SceneTree
## Отчёт по журналам плейтеста: godot --headless --script res://tools/telemetry_report.gd -- --dir=папка
## (или tools/telemetry-report.sh папка). Папка — с файлами session-*.jsonl от тестеров
## (можно вложенные папки: по одной на тестера). Без --dir — журнал этой машины (user://telemetry).

func _init() -> void:
	var dir := Telemetry.DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.trim_prefix("--dir=")
	var sessions: Array = []
	_collect(dir, sessions)
	print("Журналы плейтеста: %s\n" % ProjectSettings.globalize_path(dir))
	if sessions.is_empty():
		print("Файлов session-*.jsonl не найдено.")
	else:
		print(TelemetrySummary.format(TelemetrySummary.summarize(sessions)))
	quit(0)


func _collect(dir: String, sessions: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir.path_join(sub), sessions)
	for f in d.get_files():
		if not (f.begins_with("session-") and f.ends_with(".jsonl")):
			continue
		var lines: Array = []
		for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n", false):
			var j = JSON.parse_string(line)
			if typeof(j) == TYPE_DICTIONARY:
				lines.append(j)
		sessions.append(lines)
