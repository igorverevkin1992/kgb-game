class_name MainMenu
## Главное меню при запуске: «Продолжить», «Новая игра», «Загрузить игру», «Настройки»,
## «Об игре», «Выйти». Фон — затемнённый кабинет резидента. Справа — бумага с открытым пунктом
## (новая игра, загрузка, настройки, об игре). Esc в пункте — назад, в меню — ничего.

const LEFT_X := 120.0
const PAPER_X := 640.0
const PAPER_W := 840.0


static func build() -> Control:
	var root := Control.new()
	root.name = "main-menu"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.02, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	# Заголовок и пункты меню слева.
	var v := Style.vbox(10)
	v.position = Vector2(LEFT_X, 110)
	v.custom_minimum_size.x = 420
	v.add_child(Style.label(T.t("menu.kicker").to_upper(), Style.mono(), 15, Style.THREAD_RED, false))
	v.add_child(Style.label(T.t("game.title").to_upper(), Style.form(true), 64, Style.PAPER_LIGHT, false))
	v.add_child(Style.label(T.t("game.subtitle") + " · 1984–1986", Style.serif(false, true), 20, Color(Style.PAPER, 0.75), false))
	if Game.demo_build:
		v.add_child(Style.label(T.t("calendar.demo").to_upper(), Style.form(true), 16, Style.STAMP_RED, false))
	var gap := Control.new()
	gap.custom_minimum_size.y = 36
	v.add_child(gap)
	var info := Saves.slot_info(Game.storage, Saves.AUTOSAVE, Game.content)
	var can_continue: bool = Game.has_save() and Game.state.get("ending") == null
	if can_continue:
		v.add_child(_item("continue", T.t("menu.continue"), Game.menu_continue))
		if not info.is_empty():
			var sub := Style.label(Overlays._slot_label(info), Style.mono(), 13, Color(Style.PAPER, 0.6), false)
			sub.name = "menu-continue-info"
			v.add_child(sub)
	v.add_child(_item("new", T.t("menu.new"), Game.set_menu_page.bind("new")))
	v.add_child(_item("load", T.t("menu.load"), Game.set_menu_page.bind("load")))
	v.add_child(_item("settings", T.t("menu.settings"), Game.set_menu_page.bind("settings")))
	v.add_child(_item("about", T.t("menu.about"), Game.set_menu_page.bind("about")))
	v.add_child(_item("quit", T.t("menu.quit"), Game.quit_game))
	root.add_child(v)
	var ver := Style.label(T.t("menu.version", {"v": ProjectSettings.get_setting("application/config/version", "")}), Style.mono(), 12, Color(Style.PAPER, 0.4), false)
	ver.position = Vector2(LEFT_X, 860)
	root.add_child(ver)

	if Game.menu_page != "":
		root.add_child(_page(Game.menu_page))
	return root


## Пункт меню: крупная надпись, при наведении — красная черта слева.
static func _item(id: String, text: String, action: Callable) -> Button:
	var b := Style.button(text, "menu-" + id, Style.PAPER_LIGHT, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 26)
	var on: bool = Game.menu_page == id
	var sb := Style.box(Color(Style.PAPER, 0.1) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 10)
	sb.border_width_left = 4
	sb.border_color = Style.STAMP_RED if on else Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.border_color = Style.STAMP_RED
	hov.bg_color = Color(Style.PAPER, 0.08)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_font_override("font", Style.form(true))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 0)
	b.pressed.connect(action)
	return b


static func _page(page: String) -> Control:
	var sb := Style.box(Style.PAPER, Color(0, 0, 0, 0), 0, 0, 40)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	var p := PanelContainer.new()
	p.name = "menu-page"
	p.add_theme_stylebox_override("panel", sb)
	var v := Style.vbox(10)
	v.custom_minimum_size.x = PAPER_W - 96
	Overlays._title(v, T.t("menu.page." + page), T.t("menu.stamp"))
	match page:
		"new":
			_new_page(v)
		"load":
			_load_page(v)
		"settings":
			Overlays._settings_tab(v)
		"about":
			v.add_child(Style.para(T.t("menu.aboutText", {"key": "[F8]"}), PAPER_W - 96, Style.serif(), 17, Style.INK))
	var back := Style.paper_button("%s  [Esc]" % T.t("menu.back"), "menu-back")
	back.pressed.connect(Game.set_menu_page.bind(""))
	v.add_child(back)
	p.add_child(v)
	# Длинный пункт (настройки, загрузка) прокручивается.
	var sc := ScrollContainer.new()
	sc.name = "menu-page-scroll"
	sc.position = Vector2(PAPER_X, 60)
	sc.size = Vector2(PAPER_W + 16, 780)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(p)
	return sc


static func _new_page(v: VBoxContainer) -> void:
	v.add_child(Style.para(T.t("menu.newText"), PAPER_W - 96, Style.serif(), 17, Style.INK))
	if Game.has_save():
		var warn := Style.para(T.t("menu.newWarn"), PAPER_W - 96, Style.mono(), 14, Style.STAMP_RED)
		warn.name = "menu-new-warn"
		v.add_child(warn)
	var normal := Style.paper_button(T.t("menu.newNormal"), "menu-new-normal")
	normal.pressed.connect(Game.menu_new_game.bind(false))
	v.add_child(normal)
	v.add_child(Style.para(T.t("menu.newNormalHint"), PAPER_W - 96, Style.mono(), 13, Color(Style.INK, 0.7)))
	var iron := Style.paper_button(T.t("menu.newIronman"), "menu-new-ironman")
	iron.pressed.connect(Game.menu_new_game.bind(true))
	v.add_child(iron)
	v.add_child(Style.para(T.t("saves.ironmanHint"), PAPER_W - 96, Style.mono(), 13, Color(Style.INK, 0.7)))


static func _load_page(v: VBoxContainer) -> void:
	var st = Game.storage
	var any := false
	v.add_child(Overlays._h3(T.t("saves.manual")))
	for i in Saves.MANUAL_SLOTS.size():
		var slot: String = Saves.MANUAL_SLOTS[i]
		var info := Saves.slot_info(st, slot, Game.content)
		if info.is_empty():
			continue
		any = true
		v.add_child(_load_row(slot, "%s   %s" % [T.t("saves.slot", {"n": i + 1}), Overlays._slot_label(info)]))
	var list := Saves.list_checkpoints(st)
	list.reverse()
	var cps: Array = list.filter(func(x): return not Saves.slot_info(st, x, Game.content).is_empty())
	v.add_child(Overlays._h3(T.t("saves.checkpoints")))
	for slot in cps:
		any = true
		v.add_child(_load_row(slot, Overlays._slot_label(Saves.slot_info(st, slot, Game.content))))
	if not any:
		v.add_child(Style.label(T.t("menu.noSaves"), Style.mono(), 14, Style.INK))
	if Game.menu_error != "":
		v.add_child(Style.label(Game.menu_error, Style.mono(), 14, Style.STAMP_RED))


static func _load_row(slot: String, text: String) -> Control:
	var row := Style.hbox(12)
	var l := Style.label(text, Style.mono(), 14, Style.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := Style.paper_button(T.t("saves.load"), "menu-load-" + slot)
	b.pressed.connect(Game.menu_load.bind(slot))
	row.add_child(b)
	return row
