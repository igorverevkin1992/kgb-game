extends Node
## Глобальное состояние (автозагрузка Game): контент, кампания, настройки и состояние интерфейса.
## Любое изменение испускает `changed` — главная сцена перестраивает экран.
## Отладка из командной строки: godot -- --new (начать заново), --act=3 (стол как в акте 3).

signal changed

const VIEWS := ["map", "mice", "cipher", "finance", "dialog", "counterintel", "inbox", "archive"]
const SETTINGS_SLOT := "settings"
const TEXT_SCALES := [1.0, 1.15, 1.3]

var content: Dictionary = {}
var state: Dictionary = {}
var storage = null
## Отладка: стол как в акте N (на сам движок не влияет).
var debug_act := 0
const DEFAULT_SETTINGS := {"text_scale": 1.0, "instant_text": false, "crt": true, "vol_master": 80, "vol_sfx": 80, "vol_ambient": 50, "telemetry": true}
const VOLUME_STEPS := [0, 25, 50, 80, 100]
var settings := DEFAULT_SETTINGS.duplicate()
## Звук стола (нет в консольных инструментах).
var sound: SoundBank = null
## Сборка демоверсии (экспорт «Windows Demo» с признаком demo); тесты задают сами.
var demo_build := OS.has_feature("demo")
## Steam (GodotSteam в Windows-сборке; без него — заглушка) и журнал плейтеста.
var steam: SteamBridge = null
var telemetry: Telemetry = null
## Короткое уведомление поверх стола (например, «отметка записана»): текст и момент показа.
var notice := ""
var notice_at := 0

## Открытый модуль/лоток или "" — виден весь стол.
var view := ""
var analyst_open := false
var service_open := false
var last_events: Array = []
var last_error := ""
var saved_at := 0
## Открытый документ в лотке входящих.
var inbox_selected := ""
## Доска мотивов: выбранная улика из стопки, открытое заключение и его черновик.
var board_selected := ""
var board_analysis := ""
var board_form := {}
## Черновик маршрута (день): {op_id, stops}.
var map_draft := {"op_id": "", "stops": []}
## Идущий выезд (вечер): {op_id, step, verdict, marks, result} или пустой словарь.
var sdr_run := {}
## Шифроузел: вкладка (incoming / outgoing), выбранная директива, директива с выставленным
## ключом, идущая расшифровка {cable_id, start} и черновик шифрограммы {week, choices, request}.
const DECODE_SECONDS := 1.6
var cipher_tab := "incoming"
var cipher_selected := ""
var cipher_key_set := ""
var cipher_anim := {}
var cipher_draft := {"week": 0, "choices": {}, "request": ""}
## Беседа: выбранный козырь, открытая катушка (номер в state.tapes, -1 — нет) и головка.
var meeting_trump := ""
## Финансовый журнал: выбранный агент и черновики траншей {target_id: {amount, instrument, parts}}.
var finance_agent := ""
## «Архив 1985»: открытая запись.
var archive_selected := ""
## Пульт обстановки: выбранное дело «Списка» и вкладка (картотека / полиграф).
var card_selected := ""
var console_tab := "list"
## Документальный эпилог после финала: открытый лист (-1 — закрыт).
var epilogue_page := -1
## Карточка смены фаз операции: номер завершённой фазы (0 — не показывать).
var phase_card := 0
var finance_forms := {}
var tape_selected := -1
var tape_cursor := 0


func _ready() -> void:
	# Консольные инструменты (validate, unit-тесты) запускаются через --script: игре там делать нечего.
	if OS.get_cmdline_args().has("--script"):
		return
	content = ContentLoader.game_content()
	if content.is_empty():
		return
	if storage == null:
		storage = Saves.FileStorage.new()
	sound = SoundBank.new()
	add_child(sound)
	steam = SteamBridge.new()
	add_child(steam)
	telemetry = Telemetry.new()
	add_child(telemetry)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--act="):
			debug_act = clampi(int(a.trim_prefix("--act=")), 1, 4)
	_load_settings()
	sound.start_ambient()
	if not args.has("--new"):
		var loaded := Saves.load_slot(storage, Saves.AUTOSAVE, content)
		if loaded.ok:
			state = loaded.state
			_start_telemetry()
			return
		if loaded.error != "Слот пуст":
			push_warning("[сохранение] %s. Начинаем новую кампанию." % loaded.error)
	state = Campaign.new_campaign(content).state
	Saves.persist(storage, null, state, content)
	_start_telemetry()


## Фон комнаты: до раскрытия «Монополии» под ним едва слышный низкий гул — работы под зданием.
func _sync_ambient() -> void:
	if sound != null and not state.is_empty():
		sound.set_tunnel(not state.flags.has("monopoly_known"))


func close_phase_card() -> void:
	phase_card = 0
	sfx("paper")
	changed.emit()


func _start_telemetry() -> void:
	_sync_ambient()
	telemetry.enabled = bool(settings.telemetry)
	telemetry.start_session(state, view)


## Для тестов интерфейса: чистое хранилище в памяти и заданное состояние.
func reset_for_test(new_state: Dictionary = {}, mem_storage = null) -> void:
	storage = mem_storage if mem_storage != null else Saves.MemoryStorage.new()
	state = new_state if not new_state.is_empty() else Campaign.new_campaign(content).state
	Saves.persist(storage, null, state, content)
	debug_act = 0
	demo_build = false
	settings = DEFAULT_SETTINGS.duplicate()
	settings.instant_text = true
	settings.telemetry = false  # тесты не пишут журнал плейтеста
	if telemetry != null:
		telemetry.enabled = false
	notice = ""
	_apply_volumes()
	Style.text_scale = 1.0
	_clear_ui()
	saved_at = 0
	changed.emit()


func act() -> int:
	return debug_act if debug_act > 0 else state.act


func dispatch(action: Dictionary) -> void:
	var prev := state
	var r := Campaign.dispatch(prev, content, action)
	if telemetry != null:
		telemetry.action(action, r.error, r.events, r.state, view)
	if r.error != "":
		last_error = r.error
		changed.emit()
		return
	if steam != null:
		for id in Achievements.unlocked_by(content, r.events):
			steam.unlock(id)
	Saves.persist(storage, prev, r.state, content)
	state = r.state
	_event_sound(r.events)
	if state.ending == null:
		for e in r.events:
			if e.type == "act_completed":
				phase_card = int(e.act)
	_sync_ambient()
	# Встреча закончилась — на магнитофоне сразу её катушка, головка на последней строке.
	if prev.meeting != null and state.meeting == null:
		meeting_trump = ""
		tape_selected = state.tapes.size() - 1
		tape_cursor = state.tapes[-1].lines.size() - 1
	last_events = r.events
	last_error = ""
	saved_at = Time.get_ticks_msec()
	changed.emit()


## Один звук на действие — по самому заметному событию.
const EVENT_SOUNDS := [
	["target_recruited", "stamp"], ["analysis_approved", "stamp"], ["directive_verified", "stamp"],
	["report_submitted", "teletype"], ["meeting_started", "reel"], ["tranche_sent", "paper"],
	["clue_found", "pencil"], ["clue_pinned", "pencil"], ["phase_changed", "click"],
]


func _event_sound(events: Array) -> void:
	for pair in EVENT_SOUNDS:
		if events.any(func(e): return e.type == pair[0]):
			sfx(pair[1])
			return


func new_game(ironman := false) -> void:
	var r := Campaign.new_campaign(content)
	if ironman:
		r.state.flags.append(Campaign.IRONMAN_FLAG)
	if demo_build and Campaign.demo_last_act(content) > 0:
		r.state.flags.append(Campaign.DEMO_FLAG)
	Saves.persist(storage, null, r.state, content)
	state = r.state
	last_events = r.events
	_clear_ui()
	saved_at = Time.get_ticks_msec()
	changed.emit()


## Сохранение демоверсии в полной игре: следующая фаза операции.
func continue_full() -> void:
	var prev := state
	var r := Campaign.continue_full(prev, content)
	if r.error != "":
		last_error = r.error
		changed.emit()
		return
	Saves.persist(storage, prev, r.state, content)
	state = r.state
	last_events = r.events
	_clear_ui()
	phase_card = int(prev.act)
	saved_at = Time.get_ticks_msec()
	changed.emit()


## Демоверсия: страница полной игры в магазине (оверлей Steam или браузер).
func open_store() -> void:
	if steam != null:
		steam.open_store(int(ProjectSettings.get_setting("steam/full_app_id", 0)))


## Загрузить слот; возвращает текст ошибки или "".
func load_game(slot: String) -> String:
	var r := Saves.load_slot(storage, slot, content)
	if not r.ok:
		return r.error
	storage.write(Saves.AUTOSAVE, Saves.serialize(r.state))
	state = r.state
	last_events = []
	_clear_ui()
	saved_at = Time.get_ticks_msec()
	changed.emit()
	return ""


func save_to_slot(slot: String) -> bool:
	var ok := Saves.save_manual(storage, slot, state)
	if ok:
		saved_at = Time.get_ticks_msec()
		changed.emit()
	return ok


func is_unlocked(v: String) -> bool:
	return v == "inbox" or act() >= Modules.unlock_act(v)


const OPEN_SOUNDS := {"archive": "paper", "map": "paper", "mice": "paper", "inbox": "paper", "finance": "paper", "cipher": "click", "dialog": "reel", "counterintel": "click"}


func open(v: String) -> void:
	if is_unlocked(v):
		if v != view:
			sfx(OPEN_SOUNDS.get(v, "click"))
			if telemetry != null:
				telemetry.view_opened(state, v)
		view = v
		analyst_open = false
		service_open = false
		changed.emit()


func close() -> void:
	epilogue_page = -1
	phase_card = 0
	view = ""
	analyst_open = false
	service_open = false
	changed.emit()


func toggle_analyst() -> void:
	analyst_open = not analyst_open
	changed.emit()


func open_service() -> void:
	service_open = true
	analyst_open = false
	changed.emit()


## Короткий звук стола (если звук есть).
func sfx(name: String) -> void:
	if sound != null:
		sound.play(name)


## F8: «застрял здесь» — отметка в журнале плейтеста с местом в игре.
func mark_stuck() -> void:
	if telemetry == null:
		return
	telemetry.stuck(state, view)
	show_notice(T.t("telemetry.marked") if telemetry.enabled else T.t("telemetry.off"))


func show_notice(text: String) -> void:
	notice = text
	notice_at = Time.get_ticks_msec()
	changed.emit()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "telemetry" and telemetry != null:
		telemetry.enabled = bool(value)
	storage.write(SETTINGS_SLOT, JSON.stringify(settings))
	_apply_volumes()
	sfx("click")
	changed.emit()


func _apply_volumes() -> void:
	if sound == null:
		return
	sound.set_volume("Master", int(settings.vol_master))
	sound.set_volume("SFX", int(settings.vol_sfx))
	sound.set_volume("Ambient", int(settings.vol_ambient))


func set_text_scale(scale: float) -> void:
	settings.text_scale = scale
	Style.text_scale = scale
	storage.write(SETTINGS_SLOT, JSON.stringify(settings))
	changed.emit()


## «Мгновенный вывод текста»: расшифровка без анимации ленты.
func set_instant_text(on: bool) -> void:
	settings.instant_text = on
	storage.write(SETTINGS_SLOT, JSON.stringify(settings))
	changed.emit()


## Открыть документ в лотке; непрочитанный отмечается прочитанным.
func select_document(cable_id: String) -> void:
	inbox_selected = cable_id
	if cable_id.begins_with("dec_") or cable_id == PackageView.ITEM:
		changed.emit()
		return
	if not state.read_cables.has(cable_id):
		dispatch({"type": "read_cable", "cable_id": cable_id})
	else:
		changed.emit()


## Снять улику-фрагмент из документа (клик по подсвеченной фразе).
func take_clue(clue_id: String) -> void:
	dispatch({"type": "take_clue", "clue_id": clue_id})


func select_board_clue(clue_id: String) -> void:
	board_selected = "" if board_selected == clue_id else clue_id
	changed.emit()


## Приколоть улику (выбранную или перетащенную) к досье: axis "" — общее поле.
func pin_clue(clue_id: String, target_id: String, axis: String) -> void:
	if clue_id == "":
		return
	board_selected = ""
	dispatch({"type": "pin_clue", "clue_id": clue_id, "target_id": target_id, "axis": axis})


func open_analysis(target_id: String) -> void:
	board_analysis = target_id
	board_form = {}
	changed.emit()


func set_board_form(field: String, value: String) -> void:
	board_form[field] = value
	changed.emit()


func set_map_draft(op_id: String, stops: Array) -> void:
	var who: String = map_draft.get("operative", Delegation.RESIDENT) if map_draft.get("op_id", "") == op_id else Delegation.RESIDENT
	map_draft = {"op_id": op_id, "stops": stops, "operative": who}
	changed.emit()


## Кому поручить выход: резидент сам или подчинённый.
func set_map_operative(id: String) -> void:
	map_draft["operative"] = id
	changed.emit()


func set_sdr_run(run: Dictionary) -> void:
	sdr_run = run
	changed.emit()


# ——— Финансовый журнал ———

func select_finance_agent(id: String) -> void:
	finance_agent = id
	changed.emit()


## Черновик транша: по умолчанию — остаток обещанного наличными одной частью.
func finance_form_for(id: String) -> Dictionary:
	if not finance_forms.has(id):
		var left := Finance.promise_left(state, content, id)
		finance_forms[id] = {"amount": left if left > 0 else 1000, "instrument": "cash", "parts": 1}
	return finance_forms[id]


func set_finance_form(id: String, field: String, value: Variant) -> void:
	finance_form_for(id)[field] = value
	changed.emit()


func send_tranche(id: String) -> void:
	var f := finance_form_for(id)
	finance_forms.erase(id)
	dispatch({"type": "pay_agent", "target_id": id, "amount": int(f.amount), "instrument": f.instrument,
		"parts": int(f.parts) if f.instrument == "cash" else 1})


func open_archive(entry_id: String) -> void:
	archive_selected = entry_id
	open("archive")


func set_epilogue_page(i: int) -> void:
	epilogue_page = i
	sfx("paper")
	changed.emit()


func select_card(card_id: String) -> void:
	card_selected = card_id
	sfx("paper")
	changed.emit()


func set_console_tab(tab: String) -> void:
	console_tab = tab
	sfx("click")
	changed.emit()


func select_archive(entry_id: String) -> void:
	archive_selected = entry_id
	sfx("paper")
	changed.emit()


# ——— Беседа ———

func start_meeting(target_id: String, dialog_id := "") -> void:
	meeting_trump = ""
	tape_selected = -1
	view = "dialog"
	var a := {"type": "start_meeting", "target_id": target_id}
	if dialog_id != "":
		a.dialog_id = dialog_id
	dispatch(a)


func select_trump(clue_id: String) -> void:
	meeting_trump = "" if meeting_trump == clue_id else clue_id
	changed.emit()


## Ответ тоном (вместе с выбранным козырем, если он есть).
func meeting_reply(tone: String) -> void:
	var clue := meeting_trump
	meeting_trump = ""
	dispatch({"type": "meeting_turn", "tone": tone, "clue_id": clue})


func select_tape(i: int) -> void:
	tape_selected = i
	tape_cursor = 0
	changed.emit()


func tape_seek(delta: int) -> void:
	if tape_selected < 0 or tape_selected >= state.tapes.size():
		return
	tape_cursor = clampi(tape_cursor + delta, 0, state.tapes[tape_selected].lines.size() - 1)
	changed.emit()


## Пробел на катушке: к следующей строке с неснятой оговоркой (по кругу).
func tape_next_slip() -> void:
	if tape_selected < 0 or tape_selected >= state.tapes.size():
		return
	var tape: Dictionary = state.tapes[tape_selected]
	var slips := DialogView.slip_lines(state, Meeting.dialog_by_id(content, tape.dialog_id), tape.lines)
	if slips.is_empty():
		return
	var nxt: int = slips[0]
	for i in slips:
		if i > tape_cursor:
			nxt = i
			break
	tape_cursor = nxt
	changed.emit()


# ——— Шифроузел ———

func open_cipher(tab: String) -> void:
	cipher_tab = tab
	open("cipher")


func set_cipher_tab(tab: String) -> void:
	cipher_tab = tab
	changed.emit()


func select_directive(cable_id: String) -> void:
	cipher_tab = "incoming"
	cipher_selected = cable_id
	changed.emit()


## Выставить роторы по ключевому блокноту (первый шаг ритуала).
func set_cipher_key(cable_id: String) -> void:
	cipher_key_set = cable_id
	sfx("rotor")
	changed.emit()


## Принять шифрограмму: директива расшифрована (прочитана), лента печатает открытый текст.
func decode_directive(cable_id: String) -> void:
	cipher_anim = {} if settings.instant_text else {"cable_id": cable_id, "start": Time.get_ticks_msec()}
	sfx("teletype")
	dispatch({"type": "read_cable", "cable_id": cable_id})


## Пропустить печать ленты (клик по ленте) или закончить её.
func finish_decode() -> void:
	if not cipher_anim.is_empty():
		cipher_anim = {}
		changed.emit()


func verify_directive(cable_id: String, decision: String) -> void:
	dispatch({"type": "verify_cable", "cable_id": cable_id, "decision": decision})


## Черновик шифрограммы живёт до конца недели.
func report_draft() -> Dictionary:
	if cipher_draft.week != state.week:
		cipher_draft = {"week": state.week, "choices": {}, "request": ""}
	return cipher_draft


func set_report_choice(key: String, choice: String) -> void:
	report_draft().choices[key] = choice
	changed.emit()


func set_report_request(request_id: String) -> void:
	var d := report_draft()
	d.request = "" if d.request == request_id else request_id
	changed.emit()


func send_report() -> void:
	var d := report_draft()
	dispatch({"type": "submit_report", "choices": d.choices.duplicate(), "request": d.request})


func _clear_ui() -> void:
	view = ""
	analyst_open = false
	service_open = false
	last_error = ""
	inbox_selected = ""
	board_selected = ""
	board_analysis = ""
	board_form = {}
	map_draft = {"op_id": "", "stops": []}
	sdr_run = {}
	cipher_tab = "incoming"
	cipher_selected = ""
	cipher_key_set = ""
	cipher_anim = {}
	cipher_draft = {"week": 0, "choices": {}, "request": ""}
	meeting_trump = ""
	tape_selected = -1
	tape_cursor = 0
	finance_agent = ""
	finance_forms = {}
	archive_selected = ""
	card_selected = ""
	console_tab = "list"
	epilogue_page = -1
	phase_card = 0


func _load_settings() -> void:
	var r := Util.parse_json(storage.read(SETTINGS_SLOT))
	if r.ok and typeof(r.data) == TYPE_DICTIONARY:
		var sc: float = r.data.get("text_scale", 1.0)
		if TEXT_SCALES.any(func(x): return is_equal_approx(x, sc)):
			settings.text_scale = sc
		settings.instant_text = r.data.get("instant_text", false) == true
		settings.crt = r.data.get("crt", true) == true
		settings.telemetry = r.data.get("telemetry", true) == true
		for k in ["vol_master", "vol_sfx", "vol_ambient"]:
			var v = r.data.get(k, DEFAULT_SETTINGS[k])
			if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
				settings[k] = clampi(int(v), 0, 100)
	_apply_volumes()
	Style.text_scale = settings.text_scale
