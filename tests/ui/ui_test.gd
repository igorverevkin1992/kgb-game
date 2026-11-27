class_name UiTest
extends RefCounted
## База сценариев интерфейса: поиск узлов по имени (как data-testid), нажатия, клавиши, кадры,
## тексты и скриншоты. Сценарии — методы scene_* в tests/ui/scenes_*.gd.

var tree: SceneTree
var main: Control
var failures: Array[String] = []
## Папку можно сменить переменной окружения UI_SHOTS_DIR (кадры для магазина — tools/store-shots.sh).
var shots_dir := OS.get_environment("UI_SHOTS_DIR") if OS.get_environment("UI_SHOTS_DIR") != "" else "res://build/screens"


func setup(p_tree: SceneTree, p_main: Control) -> void:
	tree = p_tree
	main = p_main


func node(name: String) -> Node:
	return main.find_child(name, true, false)


func exists(name: String) -> bool:
	return node(name) != null


func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame


func press(name: String) -> void:
	var b := node(name) as BaseButton
	if b == null:
		failures.append("нет кнопки «%s»" % name)
		return
	if b.disabled:
		failures.append("кнопка «%s» недоступна" % name)
		return
	b.pressed.emit()
	await frames()


## Настоящий клик мышью по центру узла (проверяет, что его ничего не перекрывает).
func click(name: String) -> void:
	var c := node(name) as Control
	if c == null:
		failures.append("нет узла «%s» для клика" % name)
		return
	var pos := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		Input.parse_input_event(e)
		await frames(1)
	await frames()


func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
	await frames()


## Все тексты внутри узла (Label, Button, RichTextLabel) одной строкой.
func text_of(name: String) -> String:
	var n := node(name)
	if n == null:
		return ""
	var parts: Array = []
	_collect(n, parts)
	return " ".join(parts)


func _collect(n: Node, parts: Array) -> void:
	if n is Label or n is Button:
		parts.append(n.text)
	elif n is RichTextLabel:
		parts.append(n.get_parsed_text())
	for c in n.get_children():
		_collect(c, parts)


func eq(actual: Variant, expected: Variant, msg := "") -> void:
	if str(actual) != str(expected):
		failures.append("%sожидалось %s, получено %s" % [(msg + ": ") if msg != "" else "", str(expected), str(actual)])


func ok(cond: bool, msg := "") -> void:
	if not cond:
		failures.append(msg if msg != "" else "условие не выполнено")


func has_text(name: String, part: String) -> void:
	var t := text_of(name)
	if not t.contains(part):
		failures.append("в «%s» нет «%s» (есть: %s)" % [name, part, t.substr(0, 300)])


func enabled(name: String) -> bool:
	var b := node(name) as BaseButton
	return b != null and not b.disabled


## Трейлер (tools/trailer.gd) подменяет снимок: на этом кадре сцена показывается в записи.
var on_shot := Callable()


func shot(file: String) -> void:
	if on_shot.is_valid():
		await on_shot.call(file)
		return
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return  # без рендера (headless) скриншотов нет — проверки всё равно идут
	DirAccess.make_dir_recursive_absolute(shots_dir)
	img.save_png(shots_dir.path_join(file + ".png"))


## Игра с заданного момента кампании (состояние собирает движок, как в unit-тестах).
## collect: снимать улики-фрагменты из пришедших документов, как внимательный игрок.
func seed_state(actions: Array, collect := true) -> Dictionary:
	var s: Dictionary = Campaign.new_campaign(Game.content).state
	if collect:
		s = _collect_docs(s)
	for a in actions:
		if a.type == "submit_report":
			s = H.auto_decide(s)
		var r := Campaign.dispatch(s, Game.content, a)
		if r.error != "":
			failures.append("подготовка: %s — %s" % [JSON.stringify(a), r.error])
			break
		s = r.state
		if collect:
			s = _collect_docs(s)
	return s


func _collect_docs(s: Dictionary) -> Dictionary:
	for cable_id in s.delivered_cables:
		for clue in Campaign.untaken_chunks(s, Game.content, cable_id):
			s = Campaign.dispatch(s, Game.content, {"type": "take_clue", "clue_id": clue.clue_id}).state
	return s


func start(actions: Array = [], collect := true) -> void:
	Game.reset_for_test(seed_state(actions, collect) if not actions.is_empty() else {})
	await frames(3)
