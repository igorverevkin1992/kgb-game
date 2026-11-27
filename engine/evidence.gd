class_name Evidence
## Вещественные доказательства (сейф на стене): визитки, подарки, фотографии, записки. Предмет
## приходит в фазу act с недели week (и после флагов requires_flags). У предмета стороны (лицо,
## оборот), на каждой — детали. Игрок указывает деталь, которая кажется важной: верная даёт
## сведения (clue_id — на доску мотивов) и/или флаг линии (flag_set); неверная — только пометку
## «ничего особенного», без штрафа. Состояние: state.evidence {item_id: {found: [], tried: []}}.


static func by_id(content: Dictionary, id: String) -> Dictionary:
	for it in content.get("evidence", []):
		if it.item_id == id:
			return it
	return {}


static func detail(item: Dictionary, detail_id: String) -> Dictionary:
	for side in item.sides:
		for d in side.details:
			if d.detail_id == detail_id:
				return d
	return {}


static func arrived(s: Dictionary, content: Dictionary) -> Array:
	return content.get("evidence", []).filter(func(it): return _has_arrived(s, it))


static func _has_arrived(s: Dictionary, it: Dictionary) -> bool:
	var in_time: bool = int(it.act) < int(s.act) or (int(it.act) == int(s.act) and int(it.week) <= int(s.week))
	return in_time and it.get("requires_flags", []).all(func(f): return s.flags.has(f))


static func record(s: Dictionary, item_id: String) -> Dictionary:
	return s.get("evidence", {}).get(item_id, {"found": [], "tried": []})


## Сколько верных деталей ещё не найдено (для значка на сейфе).
static func open_count(s: Dictionary, content: Dictionary) -> int:
	var n := 0
	for it in arrived(s, content):
		var r := record(s, it.item_id)
		for side in it.sides:
			for d in side.details:
				if d.correct and not r.found.has(d.detail_id):
					n += 1
	return n


static func inspect_error(s: Dictionary, content: Dictionary, item_id: String, detail_id: String) -> String:
	var it := by_id(content, item_id)
	if it.is_empty() or not arrived(s, content).has(it):
		return "Такого предмета в сейфе нет"
	if detail(it, detail_id).is_empty():
		return "Такой детали у предмета нет"
	if record(s, item_id).tried.has(detail_id):
		return "Эту деталь уже осматривали"
	return ""
