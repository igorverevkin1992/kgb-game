extends Control
## Главная сцена: перестраивает экран при каждом изменении Game (это миллисекунды) и
## обрабатывает клавиши: 1–7 — модули и почта (без меню), Esc — закрыть открытое,
## на чистом столе — служебная папка (сохранения и настройки).


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.changed.connect(_render)
	_render()


func _render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if Game.content.is_empty():
		add_child(Style.label("Контент игры содержит ошибки — запустите tools/validate.sh", Style.form(true), 24, Style.STAMP_RED))
		return
	add_child(DeskView.build())
	if Game.view != "":
		add_child(ModuleView.build(Game.view))
	if Game.analyst_open:
		add_child(Overlays.analyst())
	if Game.service_open:
		add_child(Overlays.service())
	if Game.state.ending != null and not Game.service_open:
		add_child(Overlays.ending())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		if Game.view != "" or Game.analyst_open or Game.service_open:
			Game.close()
		else:
			Game.open_service()
		get_viewport().set_input_as_handled()
		return
	if Game.service_open or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if key >= KEY_1 and key <= KEY_7:
		var v := Modules.by_hotkey(key - KEY_0)
		if v != "":
			Game.open(v)
			get_viewport().set_input_as_handled()
