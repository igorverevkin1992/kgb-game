extends Node
## Заглушки графики для страниц магазинов (Steam, VK Play): шрифтовые капсулы нужных размеров,
## нарисованные кодом — палитра и шрифты игры, без генеративного ИИ. Релизный арт — авторский
## (docs/store/assets.md); эти файлы держат место и показывают композицию.
## Запуск: tools/store-art.sh → build/store/art/<имя>.png

## [имя, ширина, высота, вид]: full — название и штамп; hero — только фон без текста (Steam
## запрещает текст на герое библиотеки); logo — название на прозрачном фоне; icon — значок.
const SIZES := [
	["steam_header_capsule", 920, 430, "full"],
	["steam_small_capsule", 462, 174, "full"],
	["steam_main_capsule", 1232, 706, "full"],
	["steam_vertical_capsule", 748, 896, "full"],
	["steam_library_capsule", 600, 900, "full"],
	["steam_library_header", 920, 430, "full"],
	["steam_library_hero", 3840, 1240, "hero"],
	["steam_library_logo", 1280, 720, "logo"],
	["steam_page_background", 1438, 810, "hero"],
	["steam_event_cover", 800, 450, "full"],
	["steam_event_header", 1920, 622, "full"],
	["steam_community_icon", 184, 184, "icon"],
	["vkplay_cover", 1280, 720, "full"],
	["vkplay_vertical", 600, 800, "full"],
]
const OUT := "res://build/store/art"
const BG := Color("#17110c")
const TITLE := "ГОД ШПИОНОВ"
const KICKER := "Резидентура КГБ СССР в Вашингтоне"
const YEAR := "1985"
const STAMP := "СОВЕРШЕННО СЕКРЕТНО"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var only := OS.get_cmdline_user_args()
	for x in SIZES:
		if not only.is_empty() and not only.has(x[0]):
			continue
		var vp := SubViewport.new()
		vp.size = Vector2i(x[1], x[2])
		vp.transparent_bg = x[3] == "logo"
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		vp.add_child(_compose(x[3], Vector2(x[1], x[2])))
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(OUT.path_join(x[0] + ".png"))
		print("%s: %d×%d" % [x[0], img.get_width(), img.get_height()])
		vp.queue_free()
	get_tree().quit()


func _compose(kind: String, size: Vector2) -> Control:
	var root := Control.new()
	root.size = size
	root.clip_contents = true
	if kind != "logo":
		_rect(root, Vector2.ZERO, size, BG)
		_map(root, size, kind == "hero")
	match kind:
		"full":
			_sheet(root, size)
		"logo":
			var t := _text(TITLE, Style.form(true), size.y * 0.24, Style.PAPER_LIGHT, size.x * 0.9)
			_center(root, t, Vector2(size.x / 2, size.y * 0.42))
			var k := _text(KICKER + " · " + YEAR, Style.form(), size.y * 0.065, Style.OCHRE)
			_center(root, k, Vector2(size.x / 2, size.y * 0.64))
		"icon":
			var s := _stamp_box(root, "ГШ", Style.form(true), size.y * 0.5, size.y * 0.06)
			s.position = (size - s.size) / 2
	return root


## Лист бумаги с грифом, названием и красным штампом.
func _sheet(root: Control, size: Vector2) -> void:
	var tall := size.y > size.x
	var sheet_size := Vector2(size.x * (0.84 if tall else 0.72), size.y * (0.62 if tall else 0.74))
	var paper := Control.new()
	paper.size = sheet_size
	paper.position = (size - sheet_size) / 2 + Vector2(0, size.y * (0.04 if tall else 0.0))
	paper.pivot_offset = sheet_size / 2
	paper.rotation_degrees = -1.5
	root.add_child(paper)
	_rect(paper, Vector2(6, 8) * sheet_size.x / 600, sheet_size, Color(0, 0, 0, 0.45))
	_rect(paper, Vector2.ZERO, sheet_size, Style.PAPER)
	var pad := sheet_size.x * 0.06
	if size.y < 250:  # маленькая капсула: только крупное название, мелкое там не читается
		var t := _text(TITLE, Style.form(true), sheet_size.y * 0.5, Style.INK, sheet_size.x - 2 * pad)
		_center(paper, t, sheet_size / 2)
		return
	var unit := minf(sheet_size.x / (1.0 if tall else 1.6), sheet_size.y) / 10.0
	var kicker := _text(KICKER.to_upper(), Style.mono(), unit * 0.42, Color(Style.INK, 0.75), sheet_size.x - 2 * pad)
	kicker.position = Vector2(pad, pad * 0.8)
	paper.add_child(kicker)
	_rect(paper, Vector2(pad, pad * 0.8 + unit * 0.75), Vector2(sheet_size.x - 2 * pad, maxf(1.0, unit * 0.04)), Color(Style.INK, 0.6))
	var title := _text("ГОД\nШПИОНОВ" if tall else TITLE, Style.form(true), unit * (2.1 if tall else 1.9), Style.INK, sheet_size.x - 2 * pad)
	_center(paper, title, Vector2(sheet_size.x / 2, sheet_size.y * (0.42 if tall else 0.47)))
	var year := _text("Вашингтон · " + YEAR, Style.serif(false, true), unit * 0.62, Color(Style.INK, 0.8))
	year.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	year.position = Vector2(pad, sheet_size.y * (0.76 if tall else 0.74))
	paper.add_child(year)
	var stamp := _stamp_box(paper, STAMP, Style.form(true), unit * 0.5, unit * 0.07)
	stamp.pivot_offset = stamp.size / 2
	stamp.rotation_degrees = -9
	stamp.position = Vector2(sheet_size.x - stamp.size.x - pad * 0.7, sheet_size.y - stamp.size.y - pad * 0.7)


## Схема города: Потомак, дороги, красная 25-мильная граница — фон без текста.
func _map(root: Control, size: Vector2, strong: bool) -> void:
	var k := size.y / 900.0
	var a := 1.0 if strong else 0.55
	var river := Line2D.new()
	river.width = 38 * k
	river.default_color = Color(Style.US_BLUE, 0.35 * a)
	for p in [Vector2(-0.05, 0.12), Vector2(0.18, 0.2), Vector2(0.38, 0.34), Vector2(0.52, 0.5), Vector2(0.6, 0.72), Vector2(0.66, 1.1)]:
		river.add_point(Vector2(p.x * size.x, p.y * size.y))
	root.add_child(river)
	for road in [[Vector2(0, 0.6), Vector2(1, 0.45)], [Vector2(0.1, 1), Vector2(0.45, 0)], [Vector2(0.55, 1), Vector2(1, 0.2)], [Vector2(0, 0.3), Vector2(1, 0.85)]]:
		var l := Line2D.new()
		l.width = 6 * k
		l.default_color = Color(Style.OCHRE, 0.22 * a)
		l.add_point(road[0] * size)
		l.add_point(road[1] * size)
		root.add_child(l)
	var c := Vector2(size.x * 0.55, size.y * 0.5)
	var r := size.y * 0.62
	for i in 48:
		if i % 2 == 1:
			continue
		var seg := Line2D.new()
		seg.width = 5 * k
		seg.default_color = Color(Style.THREAD_RED, 0.5 * a)
		seg.add_point(c + Vector2.from_angle(TAU * i / 48.0) * r)
		seg.add_point(c + Vector2.from_angle(TAU * (i + 1) / 48.0) * r)
		root.add_child(seg)
	for p in [Vector2(0.47, 0.43), Vector2(0.6, 0.58), Vector2(0.36, 0.66)]:
		_rect(root, p * size - Vector2(10, 10) * k, Vector2(20, 20) * k, Color(Style.OCHRE, 0.7 * a))
	_rect(root, Vector2.ZERO, size, Color(0, 0, 0, 0.0 if strong else 0.25))


func _stamp_box(parent: Control, text: String, font: Font, px: float, border: float) -> Control:
	var l := _text(text, font, px, Style.STAMP_RED)
	var m := Vector2(px * 0.5, px * 0.25)
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Style.STAMP_RED
	sb.set_border_width_all(maxi(1, int(border)))
	box.add_theme_stylebox_override("panel", sb)
	box.size = l.size + m * 2
	l.position = m
	box.add_child(l)
	parent.add_child(box)
	return box


func _text(text: String, font: Font, px: float, color: Color, max_w := 0.0) -> Label:
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(px))
	if max_w > 0 and size.x > max_w:
		px *= max_w / size.x  # не влезает — уменьшить кегль
		size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(px))
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", maxi(6, int(px)))
	l.add_theme_color_override("font_color", color)
	l.size = size + Vector2(4, 0)
	return l


func _center(parent: Control, l: Label, at: Vector2) -> void:
	l.position = at - l.size / 2
	parent.add_child(l)


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r
