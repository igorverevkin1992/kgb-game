extends Node
## Быстрая проверка: все скрипты проекта компилируются. Скрипт с ошибкой в сцене заставляет
## Godot молча висеть, поэтому test.sh и ui-test.sh запускают эту проверку первой.
## Запускается как сцена (а не --script), чтобы была доступна автозагрузка Game.

func _ready() -> void:
	var bad: Array = []
	var count := 0
	for dir in ["res://engine", "res://ui", "res://tests", "res://tests/ui", "res://tools"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in ["check_scripts.gd", "validate.gd"]:
				continue
			count += 1
			var path: String = String(dir).path_join(f)
			var script: GDScript = load(path)
			if script == null or not script.can_instantiate():
				bad.append(path)
	if bad.is_empty():
		print("✔ Скрипты компилируются: %d" % count)
	else:
		print("✖ Не компилируются (подробности — SCRIPT ERROR выше):\n  " + "\n  ".join(bad))
	get_tree().quit(1 if not bad.is_empty() else 0)
