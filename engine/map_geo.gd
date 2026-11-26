class_name MapGeo
## Геометрия карты: расстояния в милях, 25-мильная зона, разбор проверочного маршрута.


static func site(content: Dictionary, id: String) -> Variant:
	for s in content.map.sites:
		if s.site_id == id:
			return s
	return null


static func pos(s: Dictionary) -> Vector2:
	return Vector2(s.pos.x, s.pos.y)


static func distance_miles(a: Dictionary, b: Dictionary) -> float:
	return pos(a).distance_to(pos(b))


## Внутри ли точка 25-мильной зоны вокруг посольства (выезд дальше требует согласования с Госдепом).
static func within_zone(content: Dictionary, s: Dictionary) -> bool:
	var embassy = site(content, content.balance.sdr.embassy_site)
	if embassy == null:
		return true
	return distance_miles(embassy, s) <= float(content.balance.sdr.zone_radius_miles)


## Разбор маршрута: blocking — нельзя утвердить; warnings — маршрут слабый
## (в одном районе бригада наружки меняет машины, точка за 25 милями злит наружку).
static func analyze_route(content: Dictionary, stops: Array) -> Dictionary:
	var blocking: Array = []
	var warnings: Array = []
	if stops.size() != 3:
		blocking.append({"kind": "not_three"})
	var uniq := {}
	for s in stops:
		uniq[s] = true
	if uniq.size() != stops.size():
		blocking.append({"kind": "duplicate"})
	var sites: Array = []
	for id in stops:
		var s = site(content, id)
		if s == null or s.role != "stop":
			blocking.append({"kind": "not_a_stop", "site_id": id})
		else:
			sites.append(s)
	var districts := {}
	for s in sites:
		districts[s.district] = true
	if not sites.is_empty() and districts.size() < int(content.balance.sdr.min_districts_for_double_sighting):
		warnings.append({"kind": "few_districts", "districts": districts.size()})
	for s in sites:
		if not within_zone(content, s):
			warnings.append({"kind": "outside_zone", "site_id": s.site_id})
	return {"blocking": blocking, "warnings": warnings}
