class_name Archive
## «Архив эпохи: 1985»: какие записи уже открыты (по событиям в журнале кампании).

const SECTIONS := ["history", "technique", "law", "fiction", "epilogue"]
## campaign_complete — любая из четырёх концовок кампании (для листов эпилога, общих для всех).
const ENDINGS := ["persona_non_grata", "recalled", "mole_arrested", "campaign_complete",
	"clean_triumph", "pyrrhic_victory", "shadow_exchange", "double_bottom", "demo_complete"]


## Условие открытия: пусто — сразу; событие движка; «ending:<концовка>»; «flag:<флаг>»;
## несколько условий через «+» должны выполняться все (лист хроники о судьбе агента в финале).
static func is_open(s: Dictionary, entry: Dictionary) -> bool:
	var u: String = entry.get("unlock", "")
	if u == "":
		return true
	if u.contains("+"):
		for part in u.split("+"):
			if not is_open(s, {"unlock": part}):
				return false
		return true
	if u.begins_with("flag:"):
		return s.flags.has(u.trim_prefix("flag:"))
	if u.begins_with("ending:"):
		var want := u.trim_prefix("ending:")
		return s.ending == want or (want == "campaign_complete" and Endings.is_final(s.ending))
	return s.log.any(func(x): return x.event.type == u)


## Страницы документального эпилога для этой концовки (по порядку в файле).
static func epilogue(s: Dictionary, content: Dictionary) -> Array:
	return content.get("archive", []).filter(func(a): return a.section == "epilogue" and is_open(s, a))


static func entry_by_id(content: Dictionary, id: String) -> Dictionary:
	for a in content.get("archive", []):
		if a.id == id:
			return a
	return {}
