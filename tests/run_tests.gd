extends SceneTree
## Запуск unit-тестов:  godot --headless --path . --script res://tests/run_tests.gd [-- фильтр]
## (или tools/test.sh). Код возврата 1, если хоть один тест упал.

func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var files: Array = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	var passed := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: не компилируется (см. SCRIPT ERROR выше)" % f)
			print("  ✗ %s: не компилируется" % f)
			continue
		var methods: Array = script.get_script_method_list().map(func(m): return m.name).filter(func(n): return n.begins_with("test_"))
		for m in methods:
			if filter != "" and not ("%s.%s" % [f, m]).contains(filter):
				continue
			var t = script.new()
			t.call(m)
			if t.failures.is_empty():
				passed += 1
				print("  ✓ %s · %s" % [f.trim_suffix(".gd"), m])
			else:
				failed.append("%s · %s\n      %s" % [f.trim_suffix(".gd"), m, "\n      ".join(t.failures)])
				print("  ✗ %s · %s" % [f.trim_suffix(".gd"), m])
	print("")
	for x in failed:
		print("✗ " + x)
	print("\nТесты: %d прошли, %d упали (%.1f с)" % [passed, failed.size(), (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if not failed.is_empty() else 0)
