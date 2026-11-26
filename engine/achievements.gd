class_name Achievements
## Достижения (Steam): какие события движка их открывают. Описание — content/achievements/*.json:
##   {id: "ACH_…", title, description, event: тип события, match: {поле: значение}}.
## Чистая функция: по списку событий одного действия — id открытых достижений.

## События движка, на которые можно повесить достижение (проверяет валидатор).
const EVENTS := ["target_unlocked", "target_recruited", "target_lost", "op_resolved", "act_completed",
	"directive_verified", "promise_kept", "analysis_approved", "meeting_ended", "lie_uncovered",
	"game_over", "request_answered", "ctr_filed", "clue_found"]


static func unlocked_by(content: Dictionary, events: Array) -> Array:
	var out: Array = []
	for a in content.get("achievements", []):
		if out.has(a.id):
			continue
		for e in events:
			if e.type == a.event and _matches(e, a.match):
				out.append(a.id)
				break
	return out


static func _matches(e: Dictionary, m: Dictionary) -> bool:
	for k in m:
		if not e.has(k) or str(e[k]) != str(m[k]):
			return false
	return true
