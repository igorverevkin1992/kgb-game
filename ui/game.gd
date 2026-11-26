extends Node
## Глобальное состояние (автозагрузка Game): контент, кампания, настройки и состояние интерфейса.
## Любое изменение испускает `changed` — главная сцена перестраивает экран.
## Отладка из командной строки: godot -- --new (начать заново), --act=3 (стол как в акте 3).

signal changed

const VIEWS := ["map", "mice", "cipher", "finance", "dialog", "counterintel", "inbox"]
const SETTINGS_SLOT := "settings"
const TEXT_SCALES := [1.0, 1.15, 1.3]

var content: Dictionary = {}
var state: Dictionary = {}
var storage = null
## Отладка: стол как в акте N (на сам движок не влияет).
var debug_act := 0
var settings := {"text_scale": 1.0}

## Открытый модуль/лоток или "" — виден весь стол.
var view := ""
var analyst_open := false
var service_open := false
var last_events: Array = []
var last_error := ""
var saved_at := 0
## Открытый документ в лотке входящих.
var inbox_selected := ""
## Черновик маршрута (день): {op_id, stops}.
var map_draft := {"op_id": "", "stops": []}
## Идущий выезд (вечер): {op_id, step, verdict, marks, result} или пустой словарь.
var sdr_run := {}


func _ready() -> void:
	content = ContentLoader.game_content()
	if content.is_empty():
		return
	if storage == null:
		storage = Saves.FileStorage.new()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--act="):
			debug_act = clampi(int(a.trim_prefix("--act=")), 1, 4)
	_load_settings()
	if not args.has("--new"):
		var loaded := Saves.load_slot(storage, Saves.AUTOSAVE, content)
		if loaded.ok:
			state = loaded.state
			return
		if loaded.error != "Слот пуст":
			push_warning("[сохранение] %s. Начинаем новую кампанию." % loaded.error)
	state = Campaign.new_campaign(content).state
	Saves.persist(storage, null, state, content)


## Для тестов интерфейса: чистое хранилище в памяти и заданное состояние.
func reset_for_test(new_state: Dictionary = {}, mem_storage = null) -> void:
	storage = mem_storage if mem_storage != null else Saves.MemoryStorage.new()
	state = new_state if not new_state.is_empty() else Campaign.new_campaign(content).state
	Saves.persist(storage, null, state, content)
	debug_act = 0
	settings = {"text_scale": 1.0}
	Style.text_scale = 1.0
	_clear_ui()
	saved_at = 0
	changed.emit()


func act() -> int:
	return debug_act if debug_act > 0 else state.act


func dispatch(action: Dictionary) -> void:
	var prev := state
	var r := Campaign.dispatch(prev, content, action)
	if r.error != "":
		last_error = r.error
		changed.emit()
		return
	Saves.persist(storage, prev, r.state, content)
	state = r.state
	last_events = r.events
	last_error = ""
	saved_at = Time.get_ticks_msec()
	changed.emit()


func new_game(ironman := false) -> void:
	var r := Campaign.new_campaign(content)
	if ironman:
		r.state.flags.append(Campaign.IRONMAN_FLAG)
	Saves.persist(storage, null, r.state, content)
	state = r.state
	last_events = r.events
	_clear_ui()
	saved_at = Time.get_ticks_msec()
	changed.emit()


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


func open(v: String) -> void:
	if is_unlocked(v):
		view = v
		analyst_open = false
		service_open = false
		changed.emit()


func close() -> void:
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


func set_text_scale(scale: float) -> void:
	settings.text_scale = scale
	Style.text_scale = scale
	storage.write(SETTINGS_SLOT, JSON.stringify(settings))
	changed.emit()


## Открыть документ в лотке; непрочитанный отмечается прочитанным.
func select_document(cable_id: String) -> void:
	inbox_selected = cable_id
	if not state.read_cables.has(cable_id):
		dispatch({"type": "read_cable", "cable_id": cable_id})
	else:
		changed.emit()


func set_map_draft(op_id: String, stops: Array) -> void:
	map_draft = {"op_id": op_id, "stops": stops}
	changed.emit()


func set_sdr_run(run: Dictionary) -> void:
	sdr_run = run
	changed.emit()


func _clear_ui() -> void:
	view = ""
	analyst_open = false
	service_open = false
	last_error = ""
	inbox_selected = ""
	map_draft = {"op_id": "", "stops": []}
	sdr_run = {}


func _load_settings() -> void:
	var r := Util.parse_json(storage.read(SETTINGS_SLOT))
	if r.ok and typeof(r.data) == TYPE_DICTIONARY:
		var sc: float = r.data.get("text_scale", 1.0)
		if TEXT_SCALES.any(func(x): return is_equal_approx(x, sc)):
			settings.text_scale = sc
	Style.text_scale = settings.text_scale
