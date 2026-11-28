extends Control
## Главная сцена: перестраивает экран при каждом изменении Game (это миллисекунды) и
## обрабатывает клавиши: 1–7 — модули и почта (без меню), Esc — закрыть открытое,
## на чистом столе — служебная папка (сохранения и настройки).


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.changed.connect(_render)
	_render()


func _render() -> void:
	var scrolls := _scroll_positions()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if Game.content.is_empty():
		add_child(Style.label("Контент игры содержит ошибки — запустите tools/validate.sh", Style.form(true), 24, Style.STAMP_RED))
		return
	add_child(DeskView.build())
	if Game.menu_open:
		add_child(MainMenu.build())
		if Game.settings.get("crt", true):
			add_child(_crt())
		if not scrolls.is_empty():
			_restore_scrolls.call_deferred(scrolls)
		return
	if Game.view != "":
		add_child(ModuleView.build(Game.view))
	if Game.analyst_open:
		add_child(Overlays.analyst())
	if Game.service_open:
		add_child(Overlays.service())
	if Game.phase_card > 0 and Game.state.ending == null:
		add_child(Overlays.phase_card(Game.phase_card))
	elif Game.epilogue_page >= 0:
		add_child(EpilogueView.build())
	elif Game.state.ending != null and not Game.service_open and Game.view != "archive":
		add_child(Overlays.ending())
	# Обучение: памятка модуля поверх всего, иначе — записка наставника и подсветка.
	var overlay_open: bool = Game.service_open or Game.analyst_open or Game.phase_card > 0 or Game.epilogue_page >= 0 or Game.state.ending != null
	if Game.help_open != "":
		add_child(TutorialView.help_card(Game.help_open))
	elif not overlay_open:
		var step := Game.tutorial_step()
		if not step.is_empty():
			add_child(TutorialView.note(step))
			if step.highlight != "":
				_highlight.call_deferred(step.highlight)
	if Game.notice != "" and Time.get_ticks_msec() - Game.notice_at < 2500:
		add_child(_notice())
	if Game.settings.get("crt", true):
		add_child(_crt())
	# Списки не прыгают наверх после каждого действия: прокрутка восстанавливается, когда
	# контейнеры разложат содержимое (отложенный вызов идёт после их раскладки).
	if not scrolls.is_empty():
		_restore_scrolls.call_deferred(scrolls)


## Подсветка после раскладки: рамка поверх найденного узла, если он виден.
func _highlight(name: String) -> void:
	var n := find_child(name, true, false)
	if n is Control and n.is_visible_in_tree() and not n.is_queued_for_deletion():
		var hl := TutorialView.highlight(n)
		add_child(hl)
		var crt := get_node_or_null("crt")
		if crt != null:
			move_child(hl, crt.get_index())


## Позиции прокрутки всех списков на экране: {ключ: [по вертикали, по горизонтали]}.
func _scroll_positions() -> Dictionary:
	var out := {}
	for sc in find_children("*", "ScrollContainer", true, false):
		if sc.is_queued_for_deletion():
			continue
		out[_scroll_key(sc)] = [sc.scroll_vertical, sc.scroll_horizontal]
	return out


func _restore_scrolls(saved: Dictionary) -> void:
	for sc in find_children("*", "ScrollContainer", true, false):
		var k := _scroll_key(sc)
		if k != "" and saved.has(k):
			sc.scroll_vertical = saved[k][0]
			sc.scroll_horizontal = saved[k][1]


## Ключ списка — путь от главной сцены: имена узлов, а у безымянных — тип и номер. Список,
## который при смене выбора должен начинаться сверху (текст документа), задаёт свой ключ
## через meta "scroll_key"; пустой ключ — список прокручивает себя сам (стенограмма).
func _scroll_key(n: Node) -> String:
	if n.has_meta("scroll_key"):
		return String(n.get_meta("scroll_key"))
	var parts: Array = []
	while n != null and n != self:
		parts.push_front(n.get_class() + str(n.get_index()) if String(n.name).begins_with("@") else String(n.name))
		n = n.get_parent()
	return "/".join(parts)


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
	if Game.menu_open:
		# В меню: Esc закрывает открытый пункт; клавиши модулей не действуют.
		if key == KEY_ESCAPE and Game.menu_page != "":
			Game.set_menu_page("")
			get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE:
		if Game.view != "" or Game.analyst_open or Game.service_open or Game.epilogue_page >= 0:
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
	if key >= KEY_1 and key <= KEY_9:
		var v := Modules.by_hotkey(key - KEY_0)
		if v != "":
			Game.open(v)
			get_viewport().set_input_as_handled()
