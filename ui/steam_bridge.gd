class_name SteamBridge
extends Node
## Связь со Steam через GodotSteam: Windows-сборка собирается на шаблоне Godot со встроенным
## Steam (tools/get-godotsteam.sh). Если Steam в сборке нет (веб, редактор, тесты) или он не
## запущен — игра работает как обычно, без достижений и оверлея. Вызовы идут через call():
## код компилируется и без GodotSteam.
##
## Для проверки без своей страницы в Steam рядом с .exe лежит steam_appid.txt с 480
## (тестовое приложение Valve «Spacewar»).

## available — расширение загружено; connected — Steam запущен и инициализирован.
var available := false
var connected := false
var status := "absent"   # absent | not_running | connected
var overlay_open := false
var _steam: Object = null


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	available = true
	status = "not_running"
	var res = null
	if _steam.has_method("steamInitEx"):
		res = _steam.call("steamInitEx")
	elif _steam.has_method("steamInit"):
		res = _steam.call("steamInit")
	# steamInitEx → {status: 0 — успех, verbal}; старый steamInit → {status: 1 — успех}.
	if typeof(res) == TYPE_DICTIONARY:
		var code := int(res.get("status", -1))
		connected = code == 0 if _steam.has_method("steamInitEx") else code == 1
	elif typeof(res) == TYPE_BOOL:
		connected = res
	if not connected:
		push_warning("[Steam] не запущен или нет steam_appid.txt: %s" % str(res))
		return
	status = "connected"
	if _steam.has_signal("overlay_toggled"):
		_steam.connect("overlay_toggled", _on_overlay)


func _process(_delta: float) -> void:
	if connected and _steam.has_method("run_callbacks"):
		_steam.call("run_callbacks")


func _on_overlay(active: bool, _user_initiated := false, _app_id := 0) -> void:
	overlay_open = active


## Открыть достижение (повторный вызов безопасен).
func unlock(id: String) -> void:
	if not connected:
		return
	if _steam.has_method("setAchievement"):
		_steam.call("setAchievement", id)
	if _steam.has_method("storeStats"):
		_steam.call("storeStats")
