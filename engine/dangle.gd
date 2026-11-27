class_name Dangle
## Пробный пакет «крота» и проверка на подставу (третья фаза). Через неделю после вербовки
## главная цель закладывает в тайник пробный пакет. Прежде чем принять его и запросить санкцию
## Центра, резидент сверяет материалы по трём каналам:
##   · тайник — не было ли у закладки наружки ФБР (итог выхода на карте);
##   · архив — индексы и шрифты по картотеке агента в Управлении безопасности ЦРУ (archive_agent);
##   · Центр — запрос по учётам с ночной шифрограммой (request_id с package_check).
## Подстава определяется честно и заранее: пакет из тайника подменён, если у закладки был
## пропущен хвост или подход к цели засвечен (mistake_flags). Проверка вскрывает расхождения;
## принять пакет можно и без проверки — тогда последствия придут в четвёртой фазе.
## Отклонённый пакет можно один раз получить заново — личной передачей (handover_op).
##
## state.package: {source: "drop"|"handover", week, dangle, archive, centre, accepted, rejected}
## archive / centre: "" (не проверено) · "ok" · "mismatch".

const ACCEPTED_FLAG := "package_accepted"
const REJECTED_FLAG := "package_rejected"
const DANGLE_FLAG := "dangle_accepted"
const CHANNELS := ["drop", "archive", "centre"]


## Описание пакета из campaign.json (первая фаза, где он задан) или {}.
static func config(content: Dictionary) -> Dictionary:
	for a in content.campaign.acts:
		if a.get("package") != null:
			return a.package
	return {}


static func package_ops(content: Dictionary) -> Array:
	var c := config(content)
	return [] if c.is_empty() else [c.drop_op, c.handover_op]


## Новый пакет после выхода к тайнику или личной передачи.
static func received(content: Dictionary, s: Dictionary, op_id: String, outcome: String) -> Dictionary:
	var c := config(content)
	var from_drop: bool = op_id == c.drop_op
	var dangle := outcome == "tail_missed"
	if from_drop:
		for f in c.get("mistake_flags", []):
			if s.flags.has(f):
				dangle = true
	return {"source": "drop" if from_drop else "handover", "week": int(s.week), "dangle": dangle,
		"archive": "", "centre": "", "accepted": false, "rejected": false}


## Состояние трёх каналов: "ok" · "mismatch" · "pending" · "unavailable".
static func checks(s: Dictionary, content: Dictionary) -> Dictionary:
	var p = s.get("package")
	var out := {"drop": "pending", "archive": "pending", "centre": "pending"}
	if p == null:
		return out
	var c := config(content)
	var op_id: String = c.drop_op if p.source == "drop" else c.handover_op
	out.drop = "ok" if s.op_results.get(op_id, "") == "clean" else "mismatch"
	out.archive = p.archive if p.archive != "" else ("pending" if archive_available(s, content) else "unavailable")
	out.centre = p.centre if p.centre != "" else "pending"
	return out


static func count(s: Dictionary, content: Dictionary, status: String) -> int:
	return checks(s, content).values().filter(func(v): return v == status).size()


## Сверить с картотекой можно, если агент в Управлении безопасности ЦРУ завербован и лоялен.
static func archive_available(s: Dictionary, content: Dictionary) -> bool:
	var id: String = config(content).get("archive_agent", "")
	var ts = s.targets.get(id)
	if ts == null or not ts.recruited or ts.lost:
		return false
	return not s.agents.has(id) or int(s.agents[id].loyalty) >= int(content.balance.finance.reports_min_loyalty)


## Пакет ждёт решения резидента.
static func open(s: Dictionary) -> bool:
	var p = s.get("package")
	return p != null and not p.accepted and not p.rejected


## Отклонить можно пакет из тайника, пока личная передача ещё не проводилась.
static func can_reject(s: Dictionary, content: Dictionary) -> bool:
	return open(s) and s.package.source == "drop" and not s.op_results.has(config(content).handover_op)


## Ждёт ли пакет ответа Центра по учётам (можно приложить запрос к шифрограмме).
static func centre_waiting(s: Dictionary) -> bool:
	return open(s) and s.package.centre == ""


## Что покажет сверка: расхождения, если пакет подменён.
static func check_result(s: Dictionary) -> String:
	return "mismatch" if s.package.dangle else "ok"
