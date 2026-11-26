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
	if Game.notice != "" and Time.get_ticks_msec() - Game.notice_at < 2500:
		add_child(_notice())
	if Game.settings.get("crt", true):
		add_child(_crt())


## Короткое уведомление вверху по центру; само бледнеет.
func _notice() -> Control:
	var p := Style.panel(Color(0.08, 0.06, 0.04, 0.9), 12, Color(Style.PAPER, 0.5), 1)
	p.name = "notice"
	p.add_child(Style.label(Game.notice, Style.form(true), 16, Style.PAPER_LIGHT, false))
	p.position = Vector2(800 - p.get_combined_minimum_size().x / 2, 10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := p.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	return p


## ЭЛТ-эффект поверх всего (отключается в настройках).
static var _crt_material: ShaderMaterial = null


func _crt() -> Control:
	if _crt_material == null:
		_crt_material = ShaderMaterial.new()
		_crt_material.shader = load("res://ui/crt.gdshader")
	var r := ColorRect.new()
	r.name = "crt"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = _crt_material
	return r


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	# F8 — «застрял здесь»: отметка в журнале плейтеста (для «Пути мысли»).
	if key == KEY_F8:
		Game.mark_stuck()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE:
		if Game.view != "" or Game.analyst_open or Game.service_open:
			Game.close()
		else:
			Game.open_service()
		get_viewport().set_input_as_handled()
		return
	if Game.service_open or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	# Катушка на «Тембр-2М»: ← → — перемотка по строкам, пробел — к следующей оговорке.
	if Game.view == "dialog" and Game.state.meeting == null and Game.tape_selected >= 0:
		if key == KEY_LEFT or key == KEY_RIGHT:
			Game.tape_seek(-1 if key == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()
			return
		if key == KEY_SPACE:
			Game.tape_next_slip()
			get_viewport().set_input_as_handled()
			return
	if key >= KEY_1 and key <= KEY_7:
		var v := Modules.by_hotkey(key - KEY_0)
		if v != "":
			Game.open(v)
			get_viewport().set_input_as_handled()
