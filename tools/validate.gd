extends SceneTree
## Проверка контента:  godot --headless --script res://tools/validate.gd [-- --dir=путь] [-- --en]
## (или tools/validate.sh). Код возврата 1, если есть ошибки; предупреждения сборку не ломают.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := ContentLoader.DEFAULT_DIR
	for a in args:
		if a.begins_with("--dir="):
			dir = a.trim_prefix("--dir=")
	var r := ContentLoader.read_dir(dir)
	var report := ContentLoader.validate(r.entries, {"translation": args.has("--en")})
	print("Проверка контента: %s\n" % ProjectSettings.globalize_path(dir))
	if report.content != null:
		var c: Dictionary = report.content
		print("Акты: %d · цели: %d · улики: %d · депеши: %d · операции: %d · экзамены: %d · запросы в Центр: %d · беседы: %d · точки карты: %d\n" % [
			c.campaign.acts.size(), c.targets.size(), c.clues.size(), c.cables.size(), c.ops.size(), c.polygraph.size(), c.requests.size(), c.dialogs.size(), c.map.sites.size()])
	var errors: Array = r.broken.map(func(b): return "%s: файл не читается — %s [файл]" % [b.path, b.message])
	errors.append_array(report.errors.map(ContentLoader.format_issue))
	if not errors.is_empty():
		print("✖ Ошибки (%d):" % errors.size())
		for e in errors:
			print("  • " + e)
		print("")
	if not report.warnings.is_empty():
		print("⚠ Предупреждения (%d):" % report.warnings.size())
		for w in report.warnings:
			print("  • " + ContentLoader.format_issue(w))
		print("")
	if errors.is_empty():
		print("✔ Контент в порядке: тупиков нет, «Правило трёх улик» соблюдено.")
	quit(1 if not errors.is_empty() else 0)
