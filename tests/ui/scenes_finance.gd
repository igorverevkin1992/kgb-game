extends UiTest
## Финансовый журнал: спецфонд и записи, папка правил, калькулятор транша (отчёт 4789,
## дробление, эскроу) и приёмка этапа — полная ветка Элен Варгас до конца Акта I.

const NEXT := {"type": "advance_phase"}
const QUIET := [NEXT, NEXT, NEXT, {"type": "submit_report", "report": "truth"}]
const V := "tar_vargas_ellen"


func _pin(clue: String, axis: String) -> Dictionary:
	return {"type": "pin_clue", "clue_id": clue, "target_id": V, "axis": axis}


## 3-я неделя, вечер: выезды сделаны, заключение по Варгас утверждено.
func _evening() -> Array:
	return QUIET + QUIET + [NEXT,
		{"type": "plan_op", "op_id": "op_a1_recon_first_virginia", "route": H.GOOD_ROUTE},
		{"type": "plan_op", "op_id": "op_a1_recon_potomac_cellar", "route": H.GOOD_ROUTE}, NEXT,
		{"type": "resolve_op", "op_id": "op_a1_recon_first_virginia", "decision": "continue"},
		{"type": "resolve_op", "op_id": "op_a1_recon_potomac_cellar", "decision": "continue"},
		_pin("clue_vargas_clinic_debt", "money"), _pin("clue_vargas_hospital_calls", "money"), _pin("clue_vargas_bank_position", ""),
		{"type": "submit_analysis", "target_id": V, "axis": "money", "access": "cia_staff_accounts", "channel": "false_flag"}]


func scene_ledger_and_rules() -> void:
	await start(_evening())
	await key(KEY_4)
	ok(exists("module-panel-finance"), "журнал открыт")
	has_text("fund-balance", Fmt.usd(39000))
	has_text("ledger-rows", "Оперативные расходы")
	has_text("rules", "форма 4789")
	has_text("rules", "27 октября 1986 г.")
	has_text("agents", "Агентов пока нет")


## Приёмка этапа (шаг 8): Акт I замкнут от вводной до вербовки — ветка Варгас целиком.
func scene_vargas_full_branch_closes_act() -> void:
	await start(_evening())
	# Встреча: деловой тон, эмпатия, и в конце — козырь «долг клинике».
	await key(KEY_5)
	await press("meet-" + V)
	for tone in ["pragmatic", "pragmatic", "empathy"]:
		await press("tone-" + tone)
	await press("trump-clue_vargas_clinic_debt")
	await press("tone-empathy")
	await press("meeting-offer")
	ok(Game.state.targets[V].recruited, "Варгас завербована")
	# Финансы: обещанные 11 400 одним вкладом — банк подаст форму 4789.
	await key(KEY_4)
	has_text("promise-" + V, Fmt.usd(11400))
	eq(node("tranche-preview").get_meta("ctr"), 1, "вклад свыше порога")
	has_text("tranche-preview", "форму 4789")
	await press("parts-2")
	eq(node("tranche-preview").get_meta("ctr"), 0, "две части по 5 700 — без отчёта")
	has_text("tranche-preview", "Отчётов 4789 не будет")
	await shot("finance-tranche")
	await press("tranche-send")
	has_text("promise-" + V, "в пути: " + Fmt.usd(5700))
	await key(KEY_ESCAPE)
	await press("advance-phase")
	await press("report-truth")
	# Утро 4-й недели: вторая часть дошла, обещание выполнено — задача акта.
	ok(Game.state.goal_reached, "обещание выполнено")
	eq(Game.state.risks.treasury, 0, "финансового следа нет")
	await key(KEY_4)
	has_text("promise-" + V, "Обещание выполнено")
	await key(KEY_ESCAPE)
	for i in 3:
		await press("advance-phase")
	await press("report-truth")
	ok(exists("phase-card"), "первая фаза операции пройдена")
	has_text("phase-card", "ПЕРВАЯ ФАЗА ОПЕРАЦИИ ЗАВЕРШЕНА")
	await press("phase-card-continue")
	has_text("calendar-week", "Неделя 7")
	await shot("act1-phase-card")
