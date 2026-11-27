extends TestCase
## Финансовый журнал: транши наличными и через эскроу, отчёт 4789 при вкладе свыше порога,
## дробление (законно до 1986, после — улика), лояльность и обещание агенту, образ жизни,
## оперативные расходы, задача акта «завербовать и выплатить обещанное».

const V := "tar_vargas_ellen"


func _do(s: Dictionary, action: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), action)


## 3-я неделя, вечер: Варгас завербована (быстрый путь без беседы), лояльность 50.
func _agent() -> Dictionary:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT,
		H.plan("op_a1_recon_first_virginia"), H.plan("op_a1_recon_potomac_cellar"), H.NEXT,
		H.resolve("op_a1_recon_first_virginia"), H.resolve("op_a1_recon_potomac_cellar")]).state
	s = H.approve(self, s, V)
	s = _do(s, {"type": "recruitment", "target_id": V, "result": "success"}).state
	s.agents[V].loyalty = 50
	return s


func test_op_expense() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week() + [H.NEXT, H.plan("op_a1_recon_first_virginia"), H.NEXT]).state
	var r := _do(s, H.resolve("op_a1_recon_first_virginia", "abort"))
	eq(r.state.fund_usd, s.fund_usd - int(H.content().balance.finance.op_expense_usd), "даже свёрнутый выезд стоит денег")


func test_lump_cash_files_ctr() -> void:
	var s := _agent()
	ok(s.agents.has(V), "агент заведён при вербовке")
	ok(not s.goal_reached, "обещание ещё не выполнено")
	var plan := Finance.plan(s, H.content(), V, 11400, "cash", 1)
	eq(plan.error, "")
	eq([plan.total.ctr, plan.total.treasury, plan.total.lifestyle, plan.total.loyalty], [1, 25, 24, 15])
	var r := _do(s, H.pay(V))
	eq(r.error, "")
	eq(r.state.fund_usd, s.fund_usd - 11400)
	eq(r.state.risks.treasury, s.risks.treasury + 25, "форма 4789 — финансовый след")
	ok(r.events.any(func(e): return e.type == "ctr_filed"))
	eq(r.state.agents[V].loyalty, 65)
	eq(r.state.agents[V].lifestyle, 24)
	ok(r.state.agents[V].promise_kept)
	ok(r.state.goal_reached, "задача акта выполнена")


func test_split_cash_avoids_ctr_before_1986() -> void:
	var s := _agent()
	ok(not Finance.mlca_in_force(s, H.content()), "1984 год: дробление законно")
	var r := _do(s, H.pay(V, 11400, "cash", 2))
	eq(r.error, "")
	eq(r.state.risks.treasury, s.risks.treasury, "части по 5 700 — без отчёта 4789")
	eq(r.state.agents[V].paid_usd, 5700)
	eq(r.state.payments.size(), 1, "вторая часть в пути")
	eq(Finance.promise_left(r.state, H.content(), V), 0)
	ok(not r.state.goal_reached)
	s = H.play(self, r.state, [H.NEXT, H.report("truth")]).state
	eq(s.agents[V].paid_usd, 11400, "вторая часть дошла утром")
	ok(s.agents[V].promise_kept)
	eq(s.agents[V].loyalty, 65, "пока деньги в пути, агент не обижается")


func test_structuring_after_mlca() -> void:
	var c: Dictionary = H.content().duplicate(true)
	c.balance.finance.mlca_date = "1984-01-01"
	var s := _agent()
	ok(Finance.mlca_in_force(s, c))
	var plan := Finance.plan(s, c, V, 11400, "cash", 2)
	ok(plan.total.structuring, "после закона 1986 года дробление — само улика")
	eq(plan.total.treasury, int(c.balance.finance.structuring_treasury))


func test_escrow() -> void:
	var s := _agent()
	has_text(_do(s, H.pay(V, 11400, "escrow")).error, "от 60%")
	s.agents[V].loyalty = 70
	has_text(_do(s, H.pay(V, 11400, "escrow", 2)).error, "одной суммой")
	var r := _do(s, H.pay(V, 11400, "escrow"))
	eq(r.error, "")
	eq(r.state.risks.treasury, s.risks.treasury, "эскроу — без следа в США")
	eq(r.state.agents[V].lifestyle, 0)
	eq(r.state.agents[V].loyalty, 75, "деньги нельзя тратить сразу — лояльности меньше")


func test_rejections() -> void:
	var s := _agent()
	has_text(_do(s, H.pay("tar_calloway_martin")).error, "только завербованным")
	has_text(_do(s, H.pay(V, 999999)).error, "В валютных средствах только")
	has_text(_do(s, H.pay(V, 0)).error, "больше нуля")
	var night: Dictionary = _do(s, H.NEXT).state
	has_text(_do(night, H.pay(V)).error, "в среду или пятницу")


func test_unpaid_promise_and_reports() -> void:
	var s := _agent()
	s.agents[V].loyalty = 42
	s = H.play(self, s, [H.NEXT, H.report("truth")]).state
	eq(s.agents[V].loyalty, 42, "в неделю вербовки обещание не просрочено")
	ok(s.clues.has("clue_calloway_named_by_vargas"), "лояльный агент приносит донесение")
	s = H.play(self, s, [H.NEXT, H.NEXT, H.NEXT, H.report("truth")]).state
	eq(s.agents[V].loyalty, 37, "обещание не выполнено — лояльность падает")


func test_lifestyle_danger() -> void:
	var s := _agent()
	s.agents[V].lifestyle = 80
	s.agents[V].promise_kept = true
	s = H.play(self, s, [H.NEXT, H.report("truth")]).state
	eq(s.risks.treasury, int(H.content().balance.finance.lifestyle_danger_treasury), "образ жизни бросается в глаза")
	eq(s.agents[V].lifestyle, 75)


func test_save_v6_migrates() -> void:
	var old := H.fresh().duplicate(true)
	old.erase("agents")
	old.erase("payments")
	var r := Saves.deserialize(JSON.stringify({"format": Saves.FORMAT, "version": 6, "saved_at": "", "state": old}), H.content())
	ok(r.ok, r.get("error", ""))
	eq(r.state.agents, {})
