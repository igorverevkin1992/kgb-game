class_name Style
## Палитра «Контейнера» (GDD, Блок 5), шрифты и фабрики элементов интерфейса.
## Масштаб текста из настроек (100–130 %) применяется ко всем «текстовым» размерам через fs().

const VENEER_DARK := Color("#17110c")
const VENEER := Color("#3a2a1d")
const VENEER_LIGHT := Color("#523b28")
const WALL := Color("#2c3027")
const WALL_DARK := Color("#1c1f19")
const OLIVE := Color("#4f5640")
const OLIVE_DARK := Color("#343a2b")
const OCHRE := Color("#b8955a")
const OCHRE_DARK := Color("#8a6a3b")
const PAPER := Color("#d9d4c5")
const PAPER_LIGHT := Color("#e6e1d3")
const INK := Color("#2a2620")
const NEWSPRINT := Color("#eee7d6")
const STAMP_RED := Color("#8e2b22")
const THREAD_RED := Color("#b3271c")
const US_BLUE := Color("#2f5f9e")
const DIM := Color(1, 1, 1, 0.65)

## Масштаб текста (1.0 / 1.15 / 1.3), задаётся из настроек.
static var text_scale := 1.0
static var _fonts := {}


static func _font(family: String) -> Font:
	if _fonts.has(family):
		return _fonts[family]
	var files := {
		"mono": ["pt-mono-cyrillic-400-normal", "pt-mono-latin-400-normal"],
		"serif": ["pt-serif-cyrillic-400-normal", "pt-serif-latin-400-normal"],
		"serif_bold": ["pt-serif-cyrillic-700-normal", "pt-serif-latin-700-normal"],
		"serif_italic": ["pt-serif-cyrillic-400-italic", "pt-serif-latin-400-italic"],
		"form": ["pt-sans-narrow-cyrillic-400-normal", "pt-sans-narrow-latin-400-normal"],
		"form_bold": ["pt-sans-narrow-cyrillic-700-normal", "pt-sans-narrow-latin-700-normal"],
	}
	var pair: Array = files[family]
	# В кириллическом файле нет цифр и знаков — их берём из латинского (fallback).
	var main: FontFile = load("res://assets/fonts/%s.woff2" % pair[0]).duplicate()
	main.fallbacks = [load("res://assets/fonts/%s.woff2" % pair[1])]
	_fonts[family] = main
	return main


## Машинопись «Ятрань» — советские документы.
static func mono() -> Font:
	return _font("mono")


## Американская пресса.
static func serif(bold := false, italic := false) -> Font:
	return _font("serif_bold" if bold else ("serif_italic" if italic else "serif"))


## ГОСТ-бланки, ярлыки, таблички.
static func form(bold := false) -> Font:
	return _font("form_bold" if bold else "form")


## Размер шрифта с учётом настройки «Размер текста».
static func fs(size: int) -> int:
	return int(round(size * text_scale))


static func label(text: String, font: Font = null, size := 16, color := PAPER, scalable := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else form())
	l.add_theme_font_size_override("font_size", fs(size) if scalable else size)
	l.add_theme_color_override("font_color", color)
	return l


## Текст с переносом по ширине.
static func para(text: String, width: float, font: Font = null, size := 16, color := PAPER) -> Label:
	var l := label(text, font, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func box(bg: Color, border := Color(0, 0, 0, 0), border_w := 0, radius := 0, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func panel(bg: Color, pad := 16, border := Color(0, 0, 0, 0), border_w := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, border_w, 0, pad))
	return p


## Кнопка в стиле стола: рамка, моноширинный шрифт.
static func button(text: String, name := "", fg := PAPER, bg := Color(0, 0, 0, 0.25), border := Color(PAPER, 0.55), size := 14) -> Button:
	var b := Button.new()
	b.text = text
	if name != "":
		b.name = name
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", mono())
	b.add_theme_font_size_override("font_size", fs(size))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.35))
	b.add_theme_stylebox_override("normal", box(bg, border, 1, 0, 8))
	b.add_theme_stylebox_override("hover", box(Color(bg.lightened(0.15), maxf(bg.a, 0.35)), border, 1, 0, 8))
	b.add_theme_stylebox_override("pressed", box(Color(fg, 0.25), border, 1, 0, 8))
	b.add_theme_stylebox_override("disabled", box(Color(bg, bg.a * 0.4), Color(border, 0.3), 1, 0, 8))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## Тёмная кнопка на светлой бумаге.
static func paper_button(text: String, name := "") -> Button:
	return button(text, name, INK, Color(0, 0, 0, 0), INK)


static func texture(name: String) -> Texture2D:
	return load("res://assets/art/%s.svg" % name)


## Текстура, вписанная в прямоугольник с сохранением пропорций.
static func art(name: String, rect: Rect2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = texture(name)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.position = rect.position
	tr.size = rect.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func rect(color: Color, r: Rect2) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Вертикальный градиент на весь прямоугольник.
static func gradient(top: Color, bottom: Color, r: Rect2) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = r.position
	tr.size = r.size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Штамп: текст в рамке, повёрнутый на угол.
static func stamp(text: String, color := STAMP_RED, size := 14, angle := -4.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0), color, 2, 0, 5))
	p.add_child(label(text.to_upper(), form(true), size, color))
	p.rotation_degrees = angle
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Горизонтальная линия для контейнеров.
static func hline(color: Color, thickness := 1) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, thickness)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
