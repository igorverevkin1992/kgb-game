class_name Saves
## Сохранения (правило дизайна №3): автосейв после каждого действия, чекпоинты на старте каждого
## акта и игрового месяца (до 12), три ручных слота. «Железный занавес» (флаг mode_ironman) —
## только автосейв. Хранилище — объект с методами read(slot)->String, write(slot, text), remove(slot):
## FileStorage (user://saves) в игре, MemoryStorage в тестах.

const FORMAT := "liniya-kr-save"
## v3: первая версия на Godot. v4 (шаг 5): доска мотивов — pinned, analysis.
## v5 (шаг 6): шифроузел — verified, requests. v6 (шаг 7): беседы — meeting, tapes.
## v7 (шаг 8): финансы — agents, payments. Сохранения v4–v6 переносятся автоматически.
const VERSION := 7
const AUTOSAVE := "autosave"
const MANUAL_SLOTS := ["manual-1", "manual-2", "manual-3"]
const MAX_CHECKPOINTS := 12
const CHECKPOINT_INDEX := "checkpoints"


class MemoryStorage:
	var data := {}
	func read(slot: String) -> String:
		return data.get(slot, "")
	func write(slot: String, text: String) -> void:
		data[slot] = text
	func remove(slot: String) -> void:
		data.erase(slot)


class FileStorage:
	var dir: String
	func _init(path := "user://saves") -> void:
		dir = path
		DirAccess.make_dir_recursive_absolute(dir)
	func read(slot: String) -> String:
		var f := FileAccess.open(dir.path_join(slot + ".json"), FileAccess.READ)
		return f.get_as_text() if f != null else ""
	func write(slot: String, text: String) -> void:
		var f := FileAccess.open(dir.path_join(slot + ".json"), FileAccess.WRITE)
		if f != null:
			f.store_string(text)
	func remove(slot: String) -> void:
		DirAccess.remove_absolute(dir.path_join(slot + ".json"))


static func serialize(state: Dictionary, saved_at := "") -> String:
	var at := saved_at if saved_at != "" else Time.get_datetime_string_from_system(true)
	return JSON.stringify({"format": FORMAT, "version": VERSION, "saved_at": at, "state": state})


## Загрузка с проверкой: повреждённый файл или сохранение от другой версии контента
## не должны молча сломать игру. {ok, state, saved_at} или {ok=false, error}.
static func deserialize(text: String, content: Dictionary) -> Dictionary:
	if text == "":
		return {"ok": false, "error": "Слот пуст"}
	var r := Util.parse_json(text)
	if not r.ok:
		return {"ok": false, "error": "Сохранение повреждено: это не JSON"}
	var data = r.data
	if typeof(data) != TYPE_DICTIONARY or data.get("format") != FORMAT:
		return {"ok": false, "error": "Это не сохранение игры «Год шпионов»"}
	if data.get("version") == 4 and typeof(data.get("state")) == TYPE_DICTIONARY:
		data.state["verified"] = {}
		data.state["requests"] = []
		data["version"] = 5
	if data.get("version") == 5 and typeof(data.get("state")) == TYPE_DICTIONARY:
		data.state["meeting"] = null
		data.state["tapes"] = []
		data["version"] = 6
	if data.get("version") == 6 and typeof(data.get("state")) == TYPE_DICTIONARY:
		var agents := {}
		var targets = data.state.get("targets", {})
		if typeof(targets) == TYPE_DICTIONARY:
			for id in targets:
				if typeof(targets[id]) == TYPE_DICTIONARY and targets[id].get("recruited", false):
					agents[id] = {"loyalty": targets[id].get("rapport", 50), "paid_usd": 0, "lifestyle": 0, "trace": 0,
						"since_week": data.state.get("week", 1), "promise_kept": true}
		data.state["agents"] = agents
		data.state["payments"] = []
		data["version"] = VERSION
	if data.get("version") != VERSION:
		return {"ok": false, "error": "Сохранение от другой версии игры (формат %s)" % str(data.get("version"))}
	var issues: Array = []
	var state = Schema.check(data.get("state"), _state_spec(), "", "state", issues)
	var errors: Array = issues.filter(func(x): return x.level == "error")
	if not errors.is_empty():
		return {"ok": false, "error": "Сохранение не подходит к этой версии игры (%s: %s)" % [errors[0].where, errors[0].message]}
	var known := {}
	for t in content.targets:
		known[t.target_id] = true
	for c in content.clues:
		known[c.clue_id] = true
	for c in content.cables:
		known[c.cable_id] = true
	for o in content.ops:
		known[o.op_id] = true
	for q in content.requests:
		known[q.request_id] = true
	for d in content.dialogs:
		known[d.dialog_id] = true
	var missing := {}
	for id in state.targets.keys() + state.clues + state.delivered_cables + state.planned_ops + state.op_results.keys() + state.verified.keys() + state.requests.map(func(q): return q.request_id) + state.tapes.map(func(t): return t.dialog_id) + ([] if state.meeting == null else [state.meeting.dialog_id]):
		if not known.has(id):
			missing[id] = true
	if not missing.is_empty():
		return {"ok": false, "error": "Сохранение ссылается на удалённый контент: %s" % ", ".join(missing.keys())}
	# Цели, добавленные в контент после сохранения, получают стартовое состояние.
	for t in content.targets:
		if not state.targets.has(t.target_id):
			state.targets[t.target_id] = Campaign.initial_target_state(t)
	return {"ok": true, "state": state, "saved_at": data.get("saved_at", "")}


static var _spec := {}


static func _state_spec() -> Dictionary:
	if not _spec.is_empty():
		return _spec
	var pct := Schema.i(0, 100)
	var strs := Schema.arr(Schema.s())
	_spec = Schema.obj({
		"act": Schema.i(1, 4), "week": Schema.i(1), "phase": Schema.e(Campaign.PHASES),
		"risks": Schema.obj({"sog_heat": pct, "mole_hunt": pct, "treasury": pct, "moscow_pressure": pct}),
		"centre_trust": pct, "fund_usd": Schema.i(), "flags": strs,
		"delivered_cables": strs, "read_cables": strs, "clues": strs,
		"targets": {"type": "dict", "of": Schema.obj({
			"unlocked": {"type": "bool"}, "recruited": {"type": "bool"}, "lost": {"type": "bool"},
			"discovered_axes": strs, "rapport": pct, "paranoia": pct, "reports_delivered": Schema.i(0),
		})},
		"planned_ops": strs,
		"routes": {"type": "dict", "of": Schema.obj({"stops": strs, "observations": Schema.arr(strs), "operative": Schema.opt(Schema.s(), "op_resident_player")})},
		"decisions": Schema.opt({"type": "dict", "of": Schema.s()}, {}),
		"personal_ops": Schema.opt(Schema.i(0), 0),
		"package": Schema.opt(Schema.nullable(Schema.obj({
			"source": Schema.e(["drop", "handover"]), "week": Schema.i(1), "dangle": {"type": "bool"},
			"archive": Schema.e(["", "ok", "mismatch"]), "centre": Schema.e(["", "ok", "mismatch"]),
			"accepted": {"type": "bool"}, "rejected": {"type": "bool"},
		})), null),
		"op_results": {"type": "dict", "of": Schema.e(["clean", "tail_missed", "aborted"])},
		"site_visits": {"type": "dict", "of": Schema.i(0)},
		"week_failures": Schema.i(0), "week_field_activity": {"type": "bool"},
		"lies": Schema.arr(Schema.obj({"week": Schema.i(), "kind": Schema.e(["embellished", "silence"])})),
		"goal_reached": {"type": "bool"}, "rng": Schema.i(0),
		"pinned": Schema.arr(Schema.obj({"clue_id": Schema.s(), "target_id": Schema.s(), "axis": Schema.s()})),
		"analysis": {"type": "dict", "of": Schema.obj({"approved": {"type": "bool"}, "attempts": Schema.i(0), "wrong": Schema.i(-1, 3), "hint_level": Schema.i(0, 3)})},
		"verified": {"type": "dict", "of": Schema.e(["accept", "query"])},
		"requests": Schema.arr(Schema.obj({"request_id": Schema.s(), "act": Schema.i(1, 4), "week": Schema.i(1), "granted": {"type": "bool"}})),
		"meeting": Schema.nullable(Schema.obj({
			"target_id": Schema.s(), "dialog_id": Schema.s(), "beat": Schema.i(0), "rapport": pct, "anxiety": pct,
			"used": strs, "lines": Schema.arr({"type": "dict", "of": {"type": "any"}}), "coercion": Schema.opt(Schema.i(0), 0),
		})),
		"agents": {"type": "dict", "of": Schema.obj({
			"loyalty": pct, "paid_usd": Schema.i(0), "lifestyle": pct, "trace": pct, "since_week": Schema.i(1), "promise_kept": {"type": "bool"},
			"coerced": Schema.opt({"type": "bool"}, false),
		})},
		"payments": Schema.arr(Schema.obj({
			"target_id": Schema.s(), "week": Schema.i(1), "amount": Schema.i(1), "instrument": Schema.e(Finance.INSTRUMENTS),
			"ctr": {"type": "bool"}, "structuring": {"type": "bool"}, "treasury": Schema.i(0), "lifestyle": Schema.i(0),
			"loyalty": Schema.i(), "completes_promise": {"type": "bool"},
		})),
		"tapes": Schema.arr(Schema.obj({
			"target_id": Schema.s(), "dialog_id": Schema.s(), "week": Schema.i(1),
			"outcome": Schema.e(["recruited", "failed", "aborted"]), "lines": Schema.arr({"type": "dict", "of": {"type": "any"}}),
		})),
		"ending": Schema.nullable(Schema.e(["persona_non_grata", "recalled", "mole_arrested", "campaign_complete"])),
		"log": Schema.arr({"type": "dict", "of": {"type": "any"}}),
	})
	return _spec


# ——— Слоты и чекпоинты ———

static func slot_info(storage, slot: String, content: Dictionary) -> Dictionary:
	var r := deserialize(storage.read(slot), content)
	if not r.ok:
		return {}
	var s: Dictionary = r.state
	return {"slot": slot, "act": s.act, "week": s.week, "phase": s.phase, "saved_at": r.saved_at,
		"ironman": Campaign.is_ironman(s), "ended": s.ending != null}


static func load_slot(storage, slot: String, content: Dictionary) -> Dictionary:
	return deserialize(storage.read(slot), content)


static func list_checkpoints(storage) -> Array:
	var r := Util.parse_json(storage.read(CHECKPOINT_INDEX))
	if not r.ok or typeof(r.data) != TYPE_ARRAY:
		return []
	return r.data.filter(func(x): return typeof(x) == TYPE_STRING)


static func write_checkpoint(storage, id: String, state: Dictionary) -> void:
	storage.write(id, serialize(state))
	var list := list_checkpoints(storage).filter(func(x): return x != id)
	list.append(id)
	while list.size() > MAX_CHECKPOINTS:
		storage.remove(list.pop_front())
	storage.write(CHECKPOINT_INDEX, JSON.stringify(list))


## Нужен ли чекпоинт после перехода prev → next: началась неделя нового акта или месяца.
static func checkpoint_for(prev: Dictionary, next: Dictionary, content: Dictionary) -> String:
	if Campaign.is_ironman(next) or next.ending != null:
		return ""
	if prev.week == next.week and prev.act == next.act:
		return ""
	var a := Campaign.week_date(content, prev.act, prev.week)
	var b := Campaign.week_date(content, next.act, next.week)
	var new_month: bool = a.is_empty() or b.is_empty() or a.month != b.month or a.year != b.year
	return "checkpoint-a%d-w%d" % [next.act, next.week] if next.act != prev.act or new_month else ""


## После каждого действия: автосейв всегда, чекпоинт — когда начался новый месяц или акт.
static func persist(storage, prev, next: Dictionary, content: Dictionary) -> void:
	storage.write(AUTOSAVE, serialize(next))
	var id := ""
	if prev == null:
		id = "" if Campaign.is_ironman(next) else "checkpoint-a%d-w%d" % [next.act, next.week]
	else:
		id = checkpoint_for(prev, next, content)
	if id != "":
		write_checkpoint(storage, id, next)


## Ручное сохранение в слот. В режиме «Железный занавес» запрещено.
static func save_manual(storage, slot: String, state: Dictionary) -> bool:
	if Campaign.is_ironman(state):
		return false
	storage.write(slot, serialize(state))
	return true
