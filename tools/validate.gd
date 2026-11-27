extends SceneTree
## Проверка контента:  godot --headless --script res://tools/validate.gd [-- --dir=путь] [-- --en] [-- --words]
## --words — подробный отчёт об объёме текста по разделам и веткам решений.
## (или tools/validate.sh). Код возврата 1, если есть ошибки; предупреждения сборку не ломают.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := ContentLoader.DEFAULT_DIR
	for a in args:
		if a.begins_with("--dir="):
			dir = a.trim_prefix("--dir=")
	var r := ContentLoader.read_dir(dir)
	var ui := {}
	var ur := Util.read_json("res://i18n/ru.json")
	if ur.ok and typeof(ur.data) == TYPE_DICTIONARY:
		ui = ur.data
	var report := ContentLoader.validate(r.entries, {"translation": args.has("--en"), "ui": ui})
	print("Проверка контента: %s\n" % ProjectSettings.globalize_path(dir))
	if report.content != null:
		var c: Dictionary = report.content
		print("Акты: %d · цели: %d · улики: %d · депеши: %d · операции: %d · экзамены: %d · запросы в Центр: %d · беседы: %d · точки карты: %d\n" % [
			c.campaign.acts.size(), c.targets.size(), c.clues.size(), c.cables.size(), c.ops.size(), c.polygraph.size(), c.requests.size(), c.dialogs.size(), c.map.sites.size()])
		var wr := WordCount.report(c, ui)
		var tb: Dictionary = c.balance.text_budget
		print("Объём текста: %d слов (цель %d–%d)%s\n" % [wr.total, tb.target_min_words, tb.max_words,
			"" if args.has("--words") else " · подробно: tools/validate.sh --words"])
		if args.has("--words"):
			for g in WordCount.GROUPS:
				if wr.groups.has(g):
					print("  %-13s %6d" % [g, wr.groups[g]])
			print("\nВетки решений (текст, который видят только при этом выборе):")
			for br in WordCount.branches(c):
				print("  %s / %s: %d слов" % [br.decision_id, br.option_id, br.words])
			print("")
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
