class_name Archive
## «Архив эпохи: 1985»: какие записи уже открыты (по событиям в журнале кампании).

const SECTIONS := ["history", "technique", "law", "fiction"]


static func is_open(s: Dictionary, entry: Dictionary) -> bool:
	if entry.get("unlock", "") == "":
		return true
	return s.log.any(func(x): return x.event.type == entry.unlock)


static func entry_by_id(content: Dictionary, id: String) -> Dictionary:
	for a in content.get("archive", []):
		if a.id == id:
			return a
	return {}
