extends Node
## Черновой трейлер для страницы в магазине: титры и настоящие экраны игры, записанные Movie
## Maker Godot с постоянной частотой кадров. Экраны готовят сценарии интерфейса (tests/ui):
## на кадре shot(<имя>) сцена показывается с медленным наездом камеры. Пока сцена готовится,
## на экране титр. Запуск: tools/trailer.sh → build/store/trailer.mp4 (без звука: музыку и
## дикторский текст накладывают при монтаже).

const FPS := 30
const HOLD := 3.6          # секунды на экран
const CARD_MIN := 2.3      # титр не короче
const FADE := 0.4

## [подпись над титром, титр, файл сценария, сценарий, кадр]. Правьте тексты и порядок здесь.
const SHOTS := [
	["Вашингтон · 1984", "Резидентура КГБ СССР.\nЛиния контрразведки.", "scenes_art.gd", "scene_crt_and_sound_settings", "desk-crt"],
	["Оперативная карта", "Каждый выход в город —\nпроверочный маршрут", "scenes_map.gd", "scene_evening_tail_twice_then_verdict", "map-sdr-verdict"],
	["Доска мотивов", "Каждый человек —\nденьги, идеология, компромат, самолюбие", "scenes_board.gd", "scene_analysis_near_hints_approve_and_meet", "board-analysis"],
	["Шифрпункт «Фиалка»", "Каждая шифртелеграмма —\nвыбор между правдой и карьерой", "scenes_cipher.gd", "scene_acceptance_full_week", "acceptance-ciphergram"],
	["Магнитофон «Тембр-2М»", "Каждая беседа —\nшаг по краю", "scenes_act3.gd", "scene_dinner_dialog", "dialog-caldwell"],
	["Финансовый журнал", "Деньги всегда\nоставляют след", "scenes_finance.gd", "scene_vargas_full_branch_closes_act", "finance-tranche"],
	["Пульт обстановки", "Восемнадцать дел.\nОдно окно арестов.", "scenes_act4.gd", "scene_console", "counterintel-list"],
	["Полиграф ЦРУ", "И один человек,\nкоторый должен его пройти", "scenes_polygraph.gd", "scene_spike_and_verdict", "polygraph-spike"],
]
const FINAL := ["Резидентура КГБ СССР в Вашингтоне · 1984–1986", "ГОД ШПИОНОВ", "Скоро — в Steam и VK Play"]

var main: Control
var card: Control
var card_kicker: Label
var card_title: Label
var card_shown_at := 0
var frame := 0
var _want := ""
var _next := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)  # звуки нажатий за титрами в запись не идут
	main = load("res://ui/main.tscn").instantiate()
	add_child(main)
	_build_card()
	await _wait(1)
	for i in SHOTS.size():
		var x: Array = SHOTS[i]
		if i == 0:
			_show_card(x[0], x[1])
			await _fade_card(0.0, 1.0)
		_want = x[4]
		_next = i + 1
		var script: GDScript = load("res://tests/ui/" + x[2])
		var t: UiTest = script.new()
		t.setup(get_tree(), main)
		t.on_shot = _on_shot
		await t.call(x[3])
		if _want != "":
			push_warning("трейлер: сцена %s не дошла до кадра %s" % [x[3], x[4]])
	# Финальный титр.
	await _fade_card(card.modulate.a, 1.0)
	await _wait(int(4.0 * FPS))
	main.visible = false  # затемнение в чёрное, а не в последний экран
	await _fade_card(1.0, 0.0, true)
	get_tree().quit()


func _process(_d: float) -> void:
	frame += 1


func _on_shot(file: String) -> void:
	if file != _want:
		return
	_want = ""
	# Титр держится не меньше CARD_MIN, затем уходит, и открывается экран с наездом.
	await _wait(maxi(0, int(CARD_MIN * FPS) - (frame - card_shown_at)))
	await _fade_card(1.0, 0.0)
	main.pivot_offset = main.size / 2
	var n := int(HOLD * FPS)
	for i in n:
		main.scale = Vector2.ONE * lerpf(1.0, 1.04, float(i) / n)
		await get_tree().process_frame
	if _next < SHOTS.size():
		_show_card(SHOTS[_next][0], SHOTS[_next][1])
	else:
		_show_card(FINAL[0], FINAL[1] + "\n\n" + FINAL[2])
		card_title.add_theme_font_size_override("font_size", 64)
	await _fade_card(0.0, 1.0)
	main.scale = Vector2.ONE


func _build_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	card = ColorRect.new()
	(card as ColorRect).color = Color("#0b0907")
	card.size = Vector2(1600, 900)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var v := VBoxContainer.new()
	v.size = card.size
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	card.add_child(v)
	card_kicker = _label(Style.mono(), 22, Style.THREAD_RED)
	card_title = _label(Style.form(true), 54, Style.PAPER_LIGHT)
	v.add_child(card_kicker)
	v.add_child(card_title)
	card.modulate.a = 0.0


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _show_card(kicker: String, title: String) -> void:
	card_kicker.text = kicker.to_upper()
	card_title.text = title
	card_title.add_theme_font_size_override("font_size", 54)
	card_shown_at = frame


func _fade_card(from: float, to: float, whole := false) -> void:
	var n := int(FADE * FPS * (2 if whole else 1))
	for i in n + 1:
		card.modulate.a = lerpf(from, to, float(i) / n)
		await get_tree().process_frame


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
