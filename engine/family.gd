class_name Family
## Письма домой: на письмо семьи (документ с блоком reply) резидент отвечает одним из вариантов
## — у каждого видно, как изменятся «Отношения с семьёй» (и, если письмо слишком откровенное,
## Доверие Центра: почту читают). Не ответил до воскресенья недели «неделя письма + reply_weeks»
## — семья решает, что ответа не будет. Шкала ниже crisis_below — кризис (флаг family_crisis,
## решение «Письмо, которого боялся»). В финале — флаги family_close / family_kept / family_lost:
## хроника возвращения домой, строка итога и условие «Чистого триумфа».
##
## state.family — 0–100; state.replies {cable_id: option_id | "none" (не ответил) | "old"}.

const CRISIS_FLAG := "family_crisis"
const FINAL_FLAGS := ["family_close", "family_kept", "family_lost"]


static func cfg(content: Dictionary) -> Dictionary:
	return content.balance.family


## Письма, ждущие ответа.
static func waiting(s: Dictionary, content: Dictionary) -> Array:
	var out: Array = []
	for id in s.delivered_cables:
		var cab := Campaign.cable_by_id(content, id)
		if cab.get("reply") != null and not s.get("replies", {}).has(id):
			out.append(cab)
	return out


## Неделя, до воскресенья которой нужно ответить.
static func due_week(content: Dictionary, cab: Dictionary) -> int:
	return int(cab.week) + int(cfg(content).reply_weeks)


static func option(cab: Dictionary, option_id: String) -> Dictionary:
	if cab.get("reply") == null:
		return {}
	for o in cab.reply.options:
		if o.option_id == option_id:
			return o
	return {}


static func reply_error(s: Dictionary, content: Dictionary, cable_id: String, option_id: String) -> String:
	var cab := Campaign.cable_by_id(content, cable_id)
	if cab.is_empty() or cab.get("reply") == null or not s.delivered_cables.has(cable_id):
		return "На это письмо ответить нельзя"
	if s.get("replies", {}).has(cable_id):
		return "Ответ уже отправлен"
	if option(cab, option_id).is_empty():
		return "Выберите один из вариантов ответа"
	return ""


## Итог отношений в финале.
static func final_flag(s: Dictionary, content: Dictionary) -> String:
	var v := int(s.get("family", cfg(content).start))
	if v >= int(cfg(content).close_from):
		return "family_close"
	return "family_kept" if v >= int(cfg(content).lost_below) else "family_lost"
