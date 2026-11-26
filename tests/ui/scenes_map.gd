extends UiTest
## Оперативная карта: прокладка маршрута, предупреждения, выезд «Сбор» → «Вердикт», итог.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const TAIL := "light_blue_ford_ltd"


func _plan(op: String) -> Dictionary:
	return {"type": "plan_op", "op_id": op, "route": H.GOOD_ROUTE}


func _cues(container: String, tag: String) -> int:
	var n := 0
	var root := node(container)
	if root == null:
		return -1
	for c in root.find_children("*", "", true, false):
		if c.has_meta("cue") and c.get_meta("cue") == tag:
			n += 1
	return n


func scene_day_route_by_pins_and_list() -> void:
	await start(QUIET + [NEXT])
	await click("desk-object-map")
	ok(exists("map-canvas"), "карта")
	await press("op-op_a1_recon_first_virginia")
	await click("site-site_peoples_drug_connecticut")  # по булавке на карте
	await click("site-site_georgetown_post_office")
	await press("stop-site_lee_highway_cleaners")      # из списка
	has_text("route-builder", "Химчистка на Ли-хайвей")
	ok(not exists("route-warnings"), "правильный маршрут без предупреждений")
	await shot("map-planning")
	await press("confirm-route")
	has_text("planned-ops", "Осмотр отделения «Ферст Вирджиния бэнк»")
	has_text("planned-ops", "Аптека «Пиплс драг» — Почтовое отделение Джорджтауна — Химчистка на Ли-хайвей")


func scene_weak_route_warnings() -> void:
	await start(QUIET + [NEXT])
	await key(KEY_1)
	await press("op-op_a1_recon_first_virginia")
	for id in ["site_georgetown_post_office", "site_wisconsin_bookshop", "site_leesburg_antiques"]:
		await press("stop-" + id)
	has_text("route-warnings", "Точки только в 2 район")
	has_text("route-warnings", "за 25 милями")
	await shot("map-warnings")


func scene_evening_tail_twice_then_verdict() -> void:
	await start(QUIET + [NEXT, _plan("op_a1_recon_first_virginia"), NEXT])
	await key(KEY_1)
	await press("depart-op_a1_recon_first_virginia")
	ok(exists("sdr-stop-1"), "первая точка")
	await press("sdr-next")
	await press("sdr-next")
	ok(exists("sdr-stop-3"), "третья точка")
	eq(_cues("sdr-run", TAIL), 2, "хвост мелькнул")
	await shot("map-sdr-tail")
	await press("sdr-to-verdict")
	eq(_cues("sdr-notebook", TAIL), 2, "в блокноте")
	var first_name := ""
	for c in node("sdr-notebook").find_children("note-*", "Button", true, false):
		if c.get_meta("cue") == TAIL:
			first_name = c.name
			break
	await press(first_name)
	var marked = node(first_name)  # экран перестроен — ищем кнопку заново
	ok(marked != null and marked.get_meta("marked"), "примета обведена")
	await shot("map-sdr-verdict")
	await press("sdr-verdict-tail")
	eq(node("sdr-result").get_meta("result"), "aborted")
	await press("sdr-done")
	ok(not exists("sdr-run"), "вернулись к карте")


func scene_clean_run_brings_clues() -> void:
	await start(QUIET + QUIET + [NEXT, _plan("op_a1_recon_potomac_cellar"), NEXT])
	await key(KEY_1)
	await press("depart-op_a1_recon_potomac_cellar")
	await press("sdr-next")
	await press("sdr-next")
	await press("sdr-to-verdict")
	await press("sdr-verdict-clean")
	eq(node("sdr-result").get_meta("result"), "done")
	has_text("sdr-result", "«Они держат меня за официанта»")
	has_text("sdr-result", "Цель установлена: Мартин Кэллоуэй")
	await shot("map-sdr-result")
	await press("sdr-done")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	has_text("calendar-phase", "НОЧЬ")


func scene_abort_mid_route() -> void:
	await start(QUIET + [NEXT, _plan("op_a1_recon_first_virginia"), NEXT])
	await key(KEY_1)
	await press("depart-op_a1_recon_first_virginia")
	await press("sdr-abort")
	eq(node("sdr-result").get_meta("result"), "aborted")
