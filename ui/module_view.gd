class_name ModuleView
## Открытый модуль: предмет «приближен» и занимает стол, по нижнему краю — кромка стола с
## остальными предметами (переход одним кликом или клавишей 1–7), Esc — к столу. Без меню.

const FRAME := Rect2(32, 24, 1536, 756)
const MINI := {"map": "map", "mice": "corkboard_mini", "cipher": "fialka", "finance": "ledger", "dialog": "recorder", "counterintel": "console", "inbox": "inbox_full"}
const BG := {
	"map": Color("#3b2d20"), "mice": Color("#4a3421"), "cipher": Color("#1d1e1b"), "finance": Color("#8a6a3b"),
	"dialog": Color("#454b38"), "counterintel": Color("#3b3f35"), "inbox": Color("#2a2119"),
}


static func build(view: String) -> Control:
	var root := Control.new()
	root.name = "module-view"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(Style.rect(Color(0.03, 0.02, 0.016, 0.78), Rect2(0, 0, 1600, 900)))
	# Перехватываем клики, чтобы они не проваливались на стол под рамкой.
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(blocker)

	var frame := Panel.new()
	frame.name = "module-panel-" + view
	frame.position = FRAME.position
	frame.size = FRAME.size
	frame.clip_contents = true
	var sb := Style.box(BG[view])
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 30
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(_content(view))
	root.add_child(frame)
	root.add_child(_edge(view))
	return root


static func _content(view: String) -> Control:
	match view:
		"map":
			return MapModule.build()
		"mice":
			return BoardView.build()
		"inbox":
			return InboxView.build()
		"cipher":
			return CipherView.build()
		"finance":
			return FinanceView.build()
		"dialog":
			return DialogView.build()
		_:
			return Shells.counterintel()


## Заголовок модуля: название слева, подпись справа.
static func header(title: String, note: String) -> Control:
	var h := Style.hbox(24)
	h.position = Vector2(28, 16)
	h.size = Vector2(FRAME.size.x - 56, 40)
	h.add_child(Style.label(title.to_upper(), Style.form(true), 30, Style.PAPER_LIGHT, false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)
	var n := Style.label(note, Style.form(), 15, Color(Style.PAPER, 0.7))
	n.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(n)
	return h


static func _edge(current: String) -> Control:
	var edge := Control.new()
	edge.name = "desk-edge"
	edge.position = Vector2(0, 796)
	edge.size = Vector2(1600, 104)
	edge.add_child(Style.gradient(Color("#4a3624"), Style.VENEER_DARK, Rect2(Vector2.ZERO, edge.size)))
	edge.add_child(Style.rect(Color("#6b4f35"), Rect2(0, 0, 1600, 4)))
	var row := Style.hbox(8)
	row.position = Vector2(32, 10)
	row.size = Vector2(1536, 82)
	var back := Style.button("%s\n[Esc]" % T.t("desk.back"), "module-close", Style.PAPER, Color(0, 0, 0, 0.2), Color(Style.PAPER, 0.4), 14)
	back.custom_minimum_size = Vector2(150, 82)
	back.pressed.connect(Game.close)
	row.add_child(back)
	for v in Modules.ORDER:
		var unlocked := Game.is_unlocked(v)
		var b := Button.new()
		b.name = "edge-" + v
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not unlocked
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 82)
		var cur: bool = v == current
		b.add_theme_stylebox_override("normal", Style.box(Color(Style.PAPER, 0.12) if cur else Color(0, 0, 0, 0), Style.STAMP_RED if cur else Color(0, 0, 0, 0), 0, 4, 6))
		if cur:
			(b.get_theme_stylebox("normal") as StyleBoxFlat).border_width_bottom = 3
		b.add_theme_stylebox_override("hover", Style.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 4, 6))
		b.add_theme_stylebox_override("pressed", Style.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 4, 6))
		b.add_theme_stylebox_override("disabled", Style.box(Color(0, 0, 0, 0)))
		b.set_meta("current", cur)
		b.pressed.connect(Game.open.bind(v))
		var h := Style.hbox(10)
		h.position = Vector2(8, 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := Style.art(MINI[v], Rect2(0, 0, 72, 64))
		tex.custom_minimum_size = Vector2(72, 64)
		h.add_child(tex)
		var name_key: String = "inbox.name" if v == "inbox" else "module.%s.name" % v
		var lbl := Style.para(T.t(name_key) + ("\n[%d]" % Modules.hotkey(v) if unlocked else ""), 110, Style.form(), 15, Style.PAPER)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(lbl)
		b.add_child(h)
		b.modulate = Color(1, 1, 1, 1.0 if cur else (0.8 if unlocked else 0.25))
		row.add_child(b)
	edge.add_child(row)
	return edge
