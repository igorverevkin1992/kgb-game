class_name Delegation
## Поручения подчинённым оперработникам: выход в город без резидента. Открывается после
## нескольких личных выходов (balance.delegation). Оперработник сам проходит проверочный
## маршрут: наружку он заметит с видимой вероятностью notice_chance (меньше — если точки в
## одном-двух районах); заметил — уходит на бытовое прикрытие, не заметил — как пропущенный хвост.

const RESIDENT := "op_resident_player"


static func operative(content: Dictionary, id: String) -> Dictionary:
	for o in content.get("operatives", []):
		if o.operative_id == id:
			return o
	return {}


static func unlocked(s: Dictionary, content: Dictionary) -> bool:
	return int(s.get("personal_ops", 0)) >= int(content.balance.delegation.unlock_after_personal_ops)


static func is_out(s: Dictionary, id: String) -> bool:
	return s.flags.has("out_" + id)


## Оперработники, которым можно поручить выход на этой неделе.
static func available(s: Dictionary, content: Dictionary) -> Array:
	var busy := {}
	for id in s.planned_ops:
		busy[str(s.routes.get(id, {}).get("operative", RESIDENT))] = true
	return content.get("operatives", []).filter(func(o): return not is_out(s, o.operative_id) and not busy.has(o.operative_id))


## Вероятность, что оперработник заметит наружку на этом маршруте.
static func notice_chance(content: Dictionary, operative_id: String, stops: Array) -> float:
	var o := operative(content, operative_id)
	if o.is_empty():
		return 0.0
	var districts := {}
	for id in stops:
		var st = MapGeo.site(content, id)
		if st != null:
			districts[st.district] = true
	var p := float(o.notice_chance)
	if districts.size() < int(content.balance.sdr.min_districts_for_double_sighting):
		p -= float(content.balance.delegation.few_districts_penalty)
	return clampf(p, 0.0, 1.0)
