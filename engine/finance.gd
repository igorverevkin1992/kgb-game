class_name Finance
## Финансовый журнал: спецфонд, транши агентам и банковский контроль США. Чистые функции.
##  · Наличные через тайник: агент сам несёт деньги в банк. Вклад свыше порога (10 000
##    долларов) — банк подаёт отчёт о валютной операции (форма 4789): растёт финансовый след.
##    Дробление на части по неделям до Закона о борьбе с отмыванием денег (1986) законно, после —
##    само становится уликой. Наличные заметны в образе жизни агента.
##  · Эскроу-счёт в Москве: следа в США нет, но агент не может тратить деньги сразу — лояльность
##    растёт меньше, и инструмент доступен только при высокой лояльности.
## `plan()` считает транш заранее (части, отчёты 4789, след, образ жизни, лояльность); движок
## применяет ровно эти числа — предпросмотр в журнале совпадает с итогом.
##
## Агент (state.agents[target_id]): {loyalty, paid_usd, lifestyle, trace, since_week, promise_kept}.
## Части в пути (state.payments): {target_id, week, amount, instrument, ctr, structuring,
##   treasury, lifestyle, loyalty, completes_promise}.

const INSTRUMENTS := ["cash", "escrow"]
const DEFAULT_SALARY := 30000


static func new_agent(s: Dictionary, content: Dictionary, target_id: String, coerced := false) -> Dictionary:
	var loyalty := int(s.targets[target_id].rapport) - (int(content.balance.finance.coerced_loyalty_penalty) if coerced else 0)
	return {"loyalty": clampi(loyalty, 1, 100), "paid_usd": 0, "lifestyle": 0, "trace": 0,
		"since_week": int(s.week), "promise_kept": promised(content, target_id) == 0, "coerced": coerced}


static func profile(content: Dictionary, target_id: String) -> Dictionary:
	var t := Campaign.target_by_id(content, target_id)
	return t.get("finance", {}) if not t.is_empty() and t.get("finance") != null else {}


static func promised(content: Dictionary, target_id: String) -> int:
	return int(profile(content, target_id).get("promised_usd", 0))


static func salary(content: Dictionary, target_id: String) -> int:
	return int(profile(content, target_id).get("salary_usd", DEFAULT_SALARY))


## Сколько уже отправлено частями, но ещё не дошло.
static func in_transit(s: Dictionary, target_id: String) -> int:
	var n := 0
	for p in s.payments:
		if p.target_id == target_id:
			n += int(p.amount)
	return n


## Сколько обещанного ещё не выплачено и не отправлено.
static func promise_left(s: Dictionary, content: Dictionary, target_id: String) -> int:
	if not s.agents.has(target_id):
		return 0
	return maxi(0, promised(content, target_id) - int(s.agents[target_id].paid_usd) - in_transit(s, target_id))


## Наступил ли режим Закона о борьбе с отмыванием денег (дата недели не раньше mlca_date).
static func mlca_in_force(s: Dictionary, content: Dictionary, week: int = -1) -> bool:
	var d := Campaign.week_date(content, s.act, s.week if week < 0 else week)
	if d.is_empty():
		return false
	var parts: PackedStringArray = String(content.balance.finance.mlca_date).split("-")
	var now: int = d.year * 10000 + d.month * 100 + d.day
	return now >= int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])


## Расчёт транша: {error, parts, total: {treasury, lifestyle, loyalty, ctr, structuring}}.
static func plan(s: Dictionary, content: Dictionary, target_id: String, amount: int, instrument: String, parts: int) -> Dictionary:
	var b: Dictionary = content.balance.finance
	var out := {"error": "", "parts": [], "total": {"treasury": 0, "lifestyle": 0, "loyalty": 0, "ctr": 0, "structuring": false}}
	var ag = s.agents.get(target_id)
	if ag == null or s.targets[target_id].lost:
		out.error = "Выплаты — только завербованным агентам"
	elif not INSTRUMENTS.has(instrument):
		out.error = "Выберите инструмент выплаты"
	elif amount <= 0:
		out.error = "Сумма должна быть больше нуля"
	elif amount > int(s.fund_usd):
		out.error = "В валютных средствах только %d долларов" % s.fund_usd
	elif parts < 1 or parts > int(b.max_parts) or (instrument == "escrow" and parts != 1):
		out.error = "Депонирование — одним переводом; наличные — от 1 до %d частей" % b.max_parts
	elif instrument == "escrow" and int(ag.loyalty) < int(b.escrow_min_loyalty):
		out.error = "На депонирование агент согласится только при лояльности от %d%%" % b.escrow_min_loyalty
	if out.error != "":
		return out
	var left_before := promise_left(s, content, target_id)
	var base := amount / parts
	var paid_so_far := 0
	var promise_done := false
	for i in parts:
		var part := base + (amount - base * parts if i == 0 else 0)
		var p := {"target_id": target_id, "week": int(s.week) + i, "amount": part, "instrument": instrument,
			"ctr": false, "structuring": false, "treasury": 0, "lifestyle": 0, "loyalty": 0, "completes_promise": false}
		if instrument == "cash":
			p.lifestyle = int(round(part * 100.0 / salary(content, target_id) * float(b.lifestyle_factor)))
			if part > int(b.ctr_threshold_usd):
				p.ctr = true
				p.treasury += int(b.ctr_treasury)
			if parts > 1 and i == 0 and mlca_in_force(s, content):
				p.structuring = true
				p.treasury += int(b.structuring_treasury)
		# Лояльность: за выполненное обещание (по инструменту) и за каждую тысячу сверх него.
		var before := paid_so_far
		paid_so_far += part
		if left_before > 0 and not promise_done and paid_so_far >= left_before:
			promise_done = true
			p.completes_promise = true
			p.loyalty += int(b.loyalty_promise_cash if instrument == "cash" else b.loyalty_promise_escrow)
		var extra := paid_so_far - maxi(before, left_before)
		if extra > 0:
			p.loyalty += int(floor(extra / 1000.0 * float(b.loyalty_per_1000_extra) * (1.0 if instrument == "cash" else 0.5)))
		out.parts.append(p)
		out.total.treasury += p.treasury
		out.total.lifestyle += p.lifestyle
		out.total.loyalty += p.loyalty
		out.total.ctr += 1 if p.ctr else 0
		out.total.structuring = out.total.structuring or p.structuring
	return out


## Агенты, которым можно платить (завербованы и не потеряны).
static func agents(s: Dictionary) -> Array:
	return s.agents.keys().filter(func(id): return s.targets.has(id) and not s.targets[id].lost)
