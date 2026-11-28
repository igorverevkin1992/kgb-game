class_name Endings
## Четыре концовки кампании — итог после последней фазы (Concept Bible, «Четыре концовки»):
##  · double_bottom «Двойное дно» — принят непроверенный пакет-подстава, или связь с «Кроносом»
##    заморожена в кризис с перебежчиком и Доверие Центра упало ниже порога, или Особый отдел
##    рекомендовал отозвать резидента и Доверие Центра ниже inspector_trust_below;
##  · shadow_exchange «Обмен тенями» — «Кронос» не прошёл полиграф или сгорел на финансовом
##    следе (Минфин США на пределе);
##  · clean_triumph «Чистый триумф» — реализовано не меньше triumph_realized дел, охота на
##    «крота» ниже порога, полиграф пройден, наружка и финансовый след под контролем;
##  · pyrrhic_victory «Пиррова победа» — всё остальное: «Список» реализован, но ценой
##    (каскад тревоги, роскошь «Кроноса», полиграф «на грани», высокая охота на «крота»).
## Ранние провалы (персона нон грата, отзыв, арест «крота») — по шкалам риска, как раньше.
## Условия видны игроку: `checklist()` показывает, что выполнено для «Чистого триумфа».

const FINAL := ["clean_triumph", "pyrrhic_victory", "shadow_exchange", "double_bottom"]


static func final(s: Dictionary, content: Dictionary) -> String:
	var b: Dictionary = content.balance.endings
	if s.flags.has(Polygraph.FAIL_FLAG) or s.flags.has("retest_failed") or int(s.risks.treasury) >= 100:
		return "shadow_exchange"
	if s.flags.has(Dangle.DANGLE_FLAG) or (s.flags.has("kronos_frozen") and int(s.centre_trust) < int(b.double_bottom_trust_below)) \
			or (s.flags.has("inspector_report_bad") and int(s.centre_trust) < int(b.get("inspector_trust_below", 35))):
		return "double_bottom"
	if checklist(s, content).all(func(x): return x.ok):
		return "clean_triumph"
	return "pyrrhic_victory"


## Условия «Чистого триумфа» с текущими значениями: [{id, ok, value, need}].
static func checklist(s: Dictionary, content: Dictionary) -> Array:
	var b: Dictionary = content.balance.endings
	var realized := ArrestWindow.realized(s, content)
	return [
		{"id": "realized", "ok": realized >= int(b.triumph_realized), "value": realized, "need": int(b.triumph_realized)},
		{"id": "mole_hunt", "ok": int(s.risks.mole_hunt) < int(b.triumph_mole_hunt_below), "value": int(s.risks.mole_hunt), "need": int(b.triumph_mole_hunt_below)},
		{"id": "polygraph", "ok": s.flags.has(Polygraph.PASS_FLAG) or s.flags.has("retest_passed"), "value": 0, "need": 0},
		{"id": "sog_heat", "ok": int(s.risks.sog_heat) < int(b.control_below), "value": int(s.risks.sog_heat), "need": int(b.control_below)},
		{"id": "treasury", "ok": int(s.risks.treasury) < int(b.control_below), "value": int(s.risks.treasury), "need": int(b.control_below)},
		{"id": "no_cascade", "ok": not s.flags.has(ArrestWindow.CASCADE_FLAG), "value": 0, "need": 0},
		# Триумф не «чистый», если дома резидента уже не ждут.
		{"id": "family", "ok": int(s.get("family", 60)) >= int(Family.cfg(content).lost_below), "value": int(s.get("family", 60)), "need": int(Family.cfg(content).lost_below)},
	]


## Как закончилась пятая фаза — короткие строки для итогового экрана (по флагам).
const NOTES := ["kronos_evacuated", "kronos_taken", "kronos_refused_exfil", "kronos_cut", "kronos_deny", "retest_passed",
	"retest_failed", "kronos_farewell", "kronos_let_go", "network_frozen", "dangle_reported", "dangle_hidden",
	"inspector_report_bad", "successor_trained", "family_close", "family_lost"]


static func notes(s: Dictionary) -> Array:
	return NOTES.filter(func(f): return s.flags.has(f))


static func is_final(ending) -> bool:
	return ending != null and FINAL.has(ending)
