extends UiTest
## Шифроузел «Фиалка»: ритуал расшифровки, сверка контрольной группы (подлог ФБР), печать
## ленты и «Мгновенный вывод текста», ночная шифрограмма из фактов недели, приёмка этапа.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const W1 := "cable_a1_w1_directive"
const FORGED := "cable_a1_w4_directive_meeting"
const C := "tar_calloway_martin"


func _plan(op: String) -> Dictionary:
	return {"type": "plan_op", "op_id": op, "route": H.GOOD_ROUTE}


func _decode(id: String) -> void:
	await press("cipher-item-" + id)
	await press("cipher-set-key")
	await press("cipher-decode")


## Номер факта в шифрограмме: первый со сбоем (negative) или без.
func _fact(negative: bool) -> int:
	for i in 10:
		var f := node("fact-%d" % i)
		if f == null:
			break
		if f.get_meta("negative") == negative:
			return i
	failures.append("нет факта negative=%s" % negative)
	return -1


func scene_cipher_ritual_and_genuine_directive() -> void:
	await start()
	await click("desk-object-cipher")
	ok(exists("module-panel-cipher"), "шифроузел открыт")
	has_text("cipher-item-" + W1, "не расшифрована")
	ok(not enabled("cipher-decode"), "без ключа шифрограмму не принять")
	var key_letters := Cipher.week_key(1, 1)
	ok(node("cipher-rotors").get_meta("letters") != key_letters, "роторы в случайном положении")
	has_text("cipher-step", "Шаг 1")
	await shot("cipher-encrypted")
	await press("cipher-set-key")
	eq(node("cipher-rotors").get_meta("letters"), key_letters, "роторы по блокноту")
	has_text("cipher-step", "Шаг 2")
	await press("cipher-decode")
	has_text("cipher-plain", "РЕЗИДЕНТУ")
	eq(node("received-group").get_meta("group"), node("notebook-group").text, "группа совпала с блокнотом")
	await shot("cipher-directive")
	await press("cipher-accept")
	eq(node("cipher-verdict").get_meta("outcome"), "accepted")
	await key(KEY_ESCAPE)
	ok(not exists("cipher-pending"), "на машине больше нет значка")


func scene_decode_animation_and_instant_text() -> void:
	await start()
	Game.settings.instant_text = false
	await key(KEY_3)
	await press("cipher-set-key")
	await press("cipher-decode")
	var tape := node("cipher-plain")
	ok(tape != null and tape.has_meta("typing"), "лента печатает")
	ok((node("doc-body") as RichTextLabel).visible_ratio < 1.0, "текст выводится не сразу")
	await click("cipher-plain")
	ok(not node("cipher-plain").has_meta("typing"), "клик по ленте — сразу весь текст")
	eq((node("doc-body") as RichTextLabel).visible_ratio, 1.0)
	await key(KEY_ESCAPE)
	await key(KEY_ESCAPE)
	await press("service-tab-settings")
	has_text("instant-text-toggle", "Выключено")
	await press("instant-text-toggle")
	has_text("instant-text-toggle", "Включено")
	eq(Util.parse_json(Game.storage.read(Game.SETTINGS_SLOT)).data.instant_text, true, "настройка сохранена")
	await press("service-tab-saves")  # следующие сценарии ждут папку на вкладке сохранений
	await key(KEY_ESCAPE)


func scene_forged_directive_exposed() -> void:
	await start(QUIET + QUIET + QUIET)
	await key(KEY_3)
	has_text("cipher-tab-incoming", "(3)")
	await _decode(FORGED)
	has_text("key-notebook", "недели 4")
	ok(node("received-group").get_meta("group") != node("notebook-group").text, "группа не совпала")
	has_text("cipher-verify", "наружка +15")
	await shot("cipher-forged")
	var trust: int = Game.state.centre_trust
	await press("cipher-query")
	eq(node("cipher-verdict").get_meta("outcome"), "exposed")
	eq(Game.state.centre_trust, trust + 5, "Центр доволен")


func scene_ciphergram_from_week_facts() -> void:
	await start(QUIET + QUIET + [NEXT, _plan("op_a1_recon_first_virginia"), _plan("op_a1_recon_potomac_cellar"), NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "abort"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"}, NEXT])
	ok(exists("report-truth") and exists("report-compose"), "ночью: как есть или шифрограмма")
	await press("report-compose")
	ok(exists("ciphergram"), "шифрограмма")
	eq(node("report-summary").get_meta("report"), "truth")
	var bad := _fact(true)
	has_text("fact-text-%d" % bad, "свёрнута")
	await press("fact-%d-omit" % bad)
	eq(node("report-summary").get_meta("report"), "silence")
	has_text("report-summary", "сверке донесений на 4-й неделе")
	var good := _fact(false)
	await press("fact-%d-embellish" % good)
	eq(node("report-summary").get_meta("report"), "embellished")
	has_text("report-summary", "35%")
	await press("request-req_a1_fund")
	has_text("request-cond-req_a1_fund", "откажут")
	await shot("cipher-ciphergram")
	await press("cipher-send")
	eq(Game.state.week, 4, "неделя закончилась")
	eq(Game.state.lies.size(), 1, "ложь записана")
	eq(Game.state.requests[0].granted, false, "в деньгах отказали")


## Приёмка этапа (шаг 6): одна полная неделя — директива → проверочный маршрут с хвостом →
## две открытые оси на доске мотивов → шифрограмма в Центр.
func scene_acceptance_full_week() -> void:
	await start(QUIET + QUIET)
	has_text("calendar-week", "Неделя 3")
	# Утро: директива с прошлой недели на «Фиалке».
	await key(KEY_3)
	await _decode("cable_a1_w2_directive")
	has_text("cipher-plain", "МАШИНА, ЗАМЕЧЕННАЯ ДВАЖДЫ")
	await press("cipher-accept")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	# День: два выезда по проверочному маршруту.
	await key(KEY_1)
	for op in ["op_a1_recon_first_virginia", "op_a1_recon_potomac_cellar"]:
		await press("op-" + op)
		for st in H.GOOD_ROUTE:
			await press("stop-" + st)
		await press("confirm-route")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	# Вечер: на первом маршруте хвост — сворачиваем; второй чистый.
	await key(KEY_1)
	await press("depart-op_a1_recon_first_virginia")
	await press("sdr-next")
	await press("sdr-next")
	await press("sdr-to-verdict")
	await press("sdr-verdict-tail")
	eq(node("sdr-result").get_meta("result"), "aborted")
	await press("sdr-done")
	await press("depart-op_a1_recon_potomac_cellar")
	await press("sdr-next")
	await press("sdr-next")
	await press("sdr-to-verdict")
	await press("sdr-verdict-clean")
	await press("sdr-done")
	# Доска мотивов: две оси Кэллоуэя открыты.
	await key(KEY_2)
	await click("clue-clue_calloway_post_review")
	await click("drop-%s-ego" % C)
	await click("clue-clue_calloway_rent_call")
	await click("drop-%s-money" % C)
	eq(node("drop-%s-ego" % C).get_meta("knowledge"), "hypothesis")
	eq(node("drop-%s-money" % C).get_meta("knowledge"), "hypothesis")
	await shot("acceptance-board")
	await key(KEY_ESCAPE)
	await press("advance-phase")
	# Ночь: шифрограмма — о сбое доложено как есть.
	await press("report-compose")
	eq(node("report-summary").get_meta("report"), "truth")
	has_text("ciphergram", "свёрнута")
	has_text("ciphergram", "Установлен кандидат: Мартин Кэллоуэй")
	await shot("acceptance-ciphergram")
	await press("cipher-send")
	eq(Game.state.week, 4)
	eq(Game.state.phase, "morning")
	eq(Campaign.axis_knowledge(Game.state, Game.content, C, "ego"), "hypothesis")
	eq(Campaign.axis_knowledge(Game.state, Game.content, C, "money"), "hypothesis")
