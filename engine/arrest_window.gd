class_name ArrestWindow
## «Окно арестов» (четвёртая фаза): реализация «Списка» — 18 дел агентуры ЦРУ в Москве.
## По каждому делу резидент предлагает Центру меру, и она исполняется ночью этой недели:
##   · arrest — арест: дело с флагом «Ховард» почти не тревожит Лэнгли (виноват перебежчик),
##     без флага — заметно; больше cascade_after таких арестов за неделю — каскад: «драконовские
##     меры» в отделе СССР и Восточной Европы и опергруппа ФБР «Анлейс»;
##   · natural — «естественный провал»: неделя подготовки (7-е управление, «шпионская пыль»,
##     ошибка с передатчиком), затем арест без следа к «кроту»;
##   · game — оперативная игра: агента не арестуют, а используют для дезинформации ЦРУ —
##     Лэнгли спокойнее, но Центр недоволен, особенно по критическим делам.
## Квоты Центра — нарастающим итогом к неделе; квоту можно оспорить шифрограммой (тратит
## Доверие Центра; при панике в Лэнгли Центр соглашается всегда). Если пробный пакет был
## подставой, часть дел — дезинформация ЦРУ: арест такого дела вскрывает методы ВГУ, а
## подготовка естественного провала или игра выявляют подделку без потерь.
## Все последствия видны до решения (preview).
##
## state.list: {cards: {card_id: {status, week}}, quotas: {"<by_week>": "met"|"failed"|"contested"}}
## Статусы: pending · arrest (сегодня ночью) · prep (до week) · game_plan (сегодня ночью) ·
##          arrested · natural · game · fake (подделка выявлена) · fake_arrested.

const WINDOW_CLOSED_FLAG := "arrest_window_closed"
const CASCADE_FLAG := "draconian_measures"
const ANLACE_FLAG := "anlace"
const EXPOSED_FLAG := "vgu_methods_exposed"
const ACTIONS := ["arrest", "natural", "game", "cancel"]
## Флаги, которые ставит сам движок «Окна арестов» (валидатор знает о них).
const ENGINE_FLAGS := [WINDOW_CLOSED_FLAG, CASCADE_FLAG, ANLACE_FLAG, EXPOSED_FLAG,
	"polygraph_done", "polygraph_passed", "polygraph_inconclusive", "polygraph_failed", "kronos_absent"]
const DONE := ["arrested", "natural", "game", "fake", "fake_arrested"]


static func config(content: Dictionary) -> Dictionary:
	for a in content.campaign.acts:
		if a.get("arrest_window") != null:
			return a.arrest_window
	return {}


static func act_of(content: Dictionary) -> int:
	for a in content.campaign.acts:
		if a.get("arrest_window") != null:
			return int(a.act)
	return 0


static func card(content: Dictionary, id: String) -> Dictionary:
	for c in content.get("list", []):
		if c.card_id == id:
			return c
	return {}


static func new_state(content: Dictionary) -> Dictionary:
	var cards := {}
	for c in content.get("list", []):
		cards[c.card_id] = {"status": "pending", "week": 0}
	return {"cards": cards, "quotas": {}}


static func status(s: Dictionary, id: String) -> String:
	var l = s.get("list")
	if l == null or not l.cards.has(id):
		return "pending"
	return l.cards[id].status


## Окно открыто: идёт фаза с «Окном арестов», неделя в графике, окно не закрыто.
static func open(s: Dictionary, content: Dictionary) -> bool:
	var cfg := config(content)
	return not cfg.is_empty() and s.get("list") != null and int(s.act) == act_of(content) \
		and int(s.week) >= int(cfg.from) and int(s.week) <= int(cfg.to) and not s.flags.has(WINDOW_CLOSED_FLAG)


## Является ли дело дезинформацией (пробный пакет принят подставой).
static func is_fake(s: Dictionary, c: Dictionary) -> bool:
	return c.get("dangle", false) and s.flags.has(Dangle.DANGLE_FLAG)


## Почему нельзя (пустая строка — можно).
static func action_error(s: Dictionary, content: Dictionary, id: String, action: String) -> String:
	if not open(s, content):
		return "«Окно арестов» закрыто"
	if s.phase == "night":
		return "Ночью меры уже исполняются — решайте утром, днём или вечером"
	var c := card(content, id)
	if c.is_empty():
		return "Такого дела нет в «Списке»"
	var st := status(s, id)
	if not ACTIONS.has(action):
		return "Неизвестная мера"
	if action == "cancel":
		return "" if ["arrest", "prep", "game_plan"].has(st) else "Отменять нечего"
	if st != "pending":
		return "По этому делу мера уже выбрана"
	if action == "natural" and c.natural == "":
		return "Естественный провал здесь не обосновать"
	if action == "game" and not c.game:
		return "Для оперативной игры агент не годится"
	return ""


## Последствия меры (без изменения состояния): {mole_hunt, pressure, cascade, note}.
static func preview(s: Dictionary, content: Dictionary, id: String, action: String) -> Dictionary:
	var b: Dictionary = content.balance.list
	var c := card(content, id)
	var out := {"mole_hunt": 0, "pressure": 0, "cascade": false}
	match action:
		"arrest":
			out.mole_hunt = int(b.howard_mole_hunt) if c.howard else int(b.plain_mole_hunt)
			if not c.howard and plain_tonight(s, content) + 1 > int(b.cascade_after):
				out.cascade = true
				out.mole_hunt += int(b.cascade_mole_hunt)
		"natural":
			out.mole_hunt = int(b.natural_mole_hunt)
		"game":
			out.mole_hunt = int(b.game_mole_hunt)
			out.pressure = int(b.game_critical_pressure) if c.damage == "critical" else int(b.game_pressure)
	return out


## Сколько арестов без флага «Ховард» и без подготовки назначено на эту ночь.
static func plain_tonight(s: Dictionary, content: Dictionary) -> int:
	var n := 0
	for c in content.get("list", []):
		if status(s, c.card_id) == "arrest" and not c.howard:
			n += 1
	return n


## Арестовано (с естественным провалом или без), с фильтром по ущербу.
static func arrests(s: Dictionary, content: Dictionary, damage := "") -> int:
	var n := 0
	for c in content.get("list", []):
		if ["arrested", "natural"].has(status(s, c.card_id)) and (damage == "" or c.damage == damage):
			n += 1
	return n


## Реализовано дел: арестовано или переведено в оперативную игру (для итогов кампании).
static func realized(s: Dictionary, content: Dictionary) -> int:
	var n := 0
	for c in content.get("list", []):
		if ["arrested", "natural", "game"].has(status(s, c.card_id)):
			n += 1
	return n


## Ближайшая квота, по которой ещё нет итога, или {}.
static func next_quota(s: Dictionary, content: Dictionary) -> Dictionary:
	var cfg := config(content)
	if cfg.is_empty() or s.get("list") == null:
		return {}
	for q in cfg.quotas:
		if not s.list.quotas.has(str(q.by_week)):
			return q
	return {}


static func quota_progress(s: Dictionary, content: Dictionary, q: Dictionary) -> int:
	return arrests(s, content, q.get("damage", ""))


## Согласится ли Центр отменить квоту: по Доверию или при панике в Лэнгли (охота на «крота»).
static func contest_granted(s: Dictionary, content: Dictionary) -> bool:
	var b: Dictionary = content.balance.list
	return int(s.centre_trust) >= int(b.contest_min_trust) or int(s.risks.mole_hunt) >= int(b.contest_panic_mole_hunt)
