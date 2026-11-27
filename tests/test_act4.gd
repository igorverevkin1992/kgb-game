extends TestCase
## Четвёртая фаза «Список»: «Окно арестов» — меры по делам, флаг «Ховард», каскад тревоги,
## естественный провал, оперативная игра, квоты Центра и их оспаривание, подделки при
## принятой подставе, закрытие окна; траты «Кроноса» и «притормозить».

const CAL := "tar_caldwell_arthur"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


func _act(card: String, action: String) -> Dictionary:
	return {"type": "list_action", "card_id": card, "action": action}


func _night() -> Array:
	return [H.NEXT, H.NEXT, H.NEXT, H.report("truth")]


func test_phase_start() -> void:
	var s := H.act4_state()
	eq([s.act, s.week, s.phase], [4, 31, "morning"])
	eq(s.list.cards.size(), 18)
	ok(ArrestWindow.open(s, H.content()))
	eq(Campaign.week_date(H.content(), 4, 32), {"year": 1985, "month": 10, "day": 21}, "ход — две недели")
	eq(ArrestWindow.next_quota(s, H.content()).by_week, 32)


func test_howard_and_cascade() -> void:
	var c := H.content()
	var s := H.act4_state()
	var mh: int = s.risks.mole_hunt
	s = H.play(self, s, [_act("card_sfera", "arrest"), _act("card_colonel", "arrest"), _act("card_pvo", "arrest")]).state
	ok(ArrestWindow.preview(H.play(self, H.act4_state(), [_act("card_colonel", "arrest")]).state, c, "card_pvo", "arrest").cascade == false, "два ареста без «Ховарда» — ещё не каскад")
	ok(ArrestWindow.preview(s, c, "card_major", "arrest").cascade, "третий — каскад, предупреждение заранее")
	eq(ArrestWindow.preview(s, c, "card_k_officer", "natural").mole_hunt, 2)
	s = H.play(self, s, [_act("card_major", "arrest")]).state
	eq(ArrestWindow.plain_tonight(s, c), 3)
	var r := H.play(self, s, _night())
	s = r.state
	ok(r.events.any(func(e): return e.type == "list_cascade"), "каскад: три ареста без «Ховарда» за неделю")
	ok(s.flags.has("draconian_measures") and s.flags.has("anlace"))
	eq(s.risks.mole_hunt, mini(100, mh + 1 + 6 * 3 + 25), "Ховард +1, три ареста по +6, каскад +25")
	eq(ArrestWindow.status(s, "card_sfera"), "arrested")


func test_natural_and_game() -> void:
	var s := H.act4_state()
	var mh: int = s.risks.mole_hunt
	var mp: int = s.risks.moscow_pressure
	s = H.play(self, s, [_act("card_k_officer", "natural"), _act("card_sredmash", "game")] + _night()).state
	eq(ArrestWindow.status(s, "card_k_officer"), "prep", "подготовка — неделя")
	eq(ArrestWindow.status(s, "card_sredmash"), "game")
	ok(s.risks.moscow_pressure >= mp + 8 - 0, "игра по критическому делу — Центр недоволен")
	s = H.play(self, s, _night()).state
	eq(ArrestWindow.status(s, "card_k_officer"), "natural")
	has_text(_do(H.act4_state(), _act("card_general", "natural")).error, "не обосновать")
	has_text(_do(H.act4_state(), _act("card_colonel", "game")).error, "не годится")
	ok(s.risks.mole_hunt <= mh + 2, "естественный провал почти не тревожит Лэнгли")


func test_quota_failed_and_contest() -> void:
	var s := H.act4_state()
	var mp: int = s.risks.moscow_pressure
	var r := H.play(self, s, _night() + _night())
	ok(r.events.any(func(e): return e.type == "quota_checked" and not e.met), "квота к неделе 32 не выполнена")
	eq(r.state.list.quotas["32"], "failed")
	# Оспорить квоту: Доверие Центра выше порога — согласие.
	s.centre_trust = 60
	r = H.play(self, s, [{"type": "contest_quota"}] + _night() + _night())
	eq(r.state.list.quotas["32"], "contested")
	eq(H.play(self, s, [{"type": "contest_quota"}]).state.centre_trust, 60 - 8, "оспаривание стоит Доверия Центра")
	var low := H.act4_state()
	low.centre_trust = 10
	var lr := H.play(self, low, [{"type": "contest_quota"}])
	ok(lr.events.any(func(e): return e.type == "quota_contested" and not e.granted), "при низком доверии Центр отказывает")
	ok(lr.state.risks.moscow_pressure > low.risks.moscow_pressure)
	has_text(_do(lr.state, {"type": "contest_quota"}).error, "уже оспаривали")


func test_dangle_cards() -> void:
	var s := H.act4_state([CAL], ["dangle_accepted"])
	var trust: int = s.centre_trust
	s = H.play(self, s, [_act("card_iki", "arrest"), _act("card_captain", "game"), _act("card_apn", "natural")] + _night() + _night()).state
	eq(ArrestWindow.status(s, "card_iki"), "fake_arrested")
	ok(s.flags.has("vgu_methods_exposed"), "арест подделки вскрыл методы ВГУ")
	eq(ArrestWindow.status(s, "card_captain"), "fake")
	eq(ArrestWindow.status(s, "card_apn"), "fake", "подготовка провала выявила подделку")
	ok(s.centre_trust < trust)
	var clean: Dictionary = H.play(self, H.act4_state(), [_act("card_iki", "arrest")] + _night()).state
	eq(ArrestWindow.status(clean, "card_iki"), "arrested", "без подставы дело настоящее")


func test_window_closes_and_campaign_completes() -> void:
	var s := H.act4_state()
	var r := H.play(self, s, H.weeks(8, _night()))
	ok(r.events.any(func(e): return e.type == "list_window_closed"))
	ok(r.state.flags.has("arrest_window_closed"))
	ok(r.events.any(func(e): return e.type == "act_completed" and e.act == 4), "четвёртая фаза завершена")


func test_kronos_spending_and_restrain() -> void:
	var s := H.act4_state()
	s.agents[CAL].lifestyle = 40
	var n: Dictionary = H.play(self, s, _night()).state
	eq(n.agents[CAL].lifestyle, 40 + 8 - 5, "траты «Кроноса» +8, остывание −5")
	var r: Dictionary = H.play(self, s, [{"type": "restrain_agent", "target_id": CAL}]).state
	eq([r.agents[CAL].lifestyle, r.agents[CAL].loyalty], [20, s.agents[CAL].loyalty - 6])
	has_text(_do(r, {"type": "restrain_agent", "target_id": CAL}).error, "уже говорили")
