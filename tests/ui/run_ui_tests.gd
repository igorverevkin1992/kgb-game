extends Node
## Запуск сценариев интерфейса (нужен рендер):
##   xvfb-run godot --path . --rendering-driver opengl3 res://tests/ui/run_ui_tests.tscn [-- фильтр]
## или tools/ui-test.sh. Скриншоты — build/screens/. Код возврата 1 при ошибках.

func _ready() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var main: Control = load("res://ui/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var passed := 0
	var failed: Array[String] = []
	var files: Array = Array(DirAccess.get_files_at("res://tests/ui")).filter(func(f): return f.begins_with("scenes_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/ui/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: не компилируется" % f)
			continue
		for m in script.get_script_method_list().map(func(x): return x.name).filter(func(n): return n.begins_with("scene_")):
			if filter != "" and not ("%s.%s" % [f, m]).contains(filter):
				continue
			var t: UiTest = script.new()
			t.setup(get_tree(), main)
			await t.call(m)
			if t.failures.is_empty():
				passed += 1
				print("  ✓ %s · %s" % [f.trim_suffix(".gd"), m])
			else:
				failed.append("%s · %s\n      %s" % [f.trim_suffix(".gd"), m, "\n      ".join(t.failures)])
				print("  ✗ %s · %s" % [f.trim_suffix(".gd"), m])
	print("")
	for x in failed:
		print("✗ " + x)
	print("\nСценарии интерфейса: %d прошли, %d упали" % [passed, failed.size()])
	get_tree().quit(1 if not failed.is_empty() else 0)
