class_name Cipher
## Шифроузел «Фиалка» (М-125): чистые функции над состоянием и контентом.
##  · ключевой блокнот: ключ роторов и контрольная группа на каждую неделю (детерминированы);
##  · директивы Центра: расшифровка (read_cable) и сверка контрольной группы (verify_cable);
##  · ночная шифрограмма: факты недели из журнала, по каждому — «как есть / приукрасить /
##    умолчать»; по выбору движок определяет вид донесения (truth / embellished / silence);
##  · запросы в Центр: решение зависит от Доверия Центра в момент отправки (порог виден игроку).

## 30 контактов ротора: кириллица без Ё, Й, Ъ.
const LETTERS := "АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЩЫЬЭЮЯ"
const ROTORS := 10
const CHOICES := ["as_is", "embellish", "omit"]
const REPORTS := ["truth", "embellished", "silence"]


# ——— Ключевой блокнот ———

static func _stream(seed: int, n: int) -> Array:
	var out: Array = []
	var st := seed & Rng.MASK
	for i in n:
		var r := Rng.next(st)
		st = r[1]
		out.append(r[0])
	return out


static func _seed(act: int, week: int, salt: int) -> int:
	return 1985 + act * 7919 + week * 104729 + salt


## Ключ роторов на неделю: 10 букв.
static func week_key(act: int, week: int) -> String:
	var out := ""
	for x in _stream(_seed(act, week, 11), ROTORS):
		out += LETTERS[int(floor(x * LETTERS.length()))]
	return out


## Контрольная группа недели по блокноту: 5 цифр.
static func week_group(act: int, week: int) -> String:
	var out := ""
	for x in _stream(_seed(act, week, 29), 5):
		out += str(int(floor(x * 10)))
	return out


## Контрольная группа, пришедшая с директивой. У подложной — две цифры переставлены
## (или одна изменена, если перестановка ничего не меняет).
static func received_group(cable: Dictionary) -> String:
	var g := week_group(cable.act, cable.week)
	if not cable.get("forged", false):
		return g
	for i in [2, 3, 1, 0]:
		if g[i] != g[i + 1]:
			return g.substr(0, i) + g[i + 1] + g[i] + g.substr(i + 2)
	return g.substr(0, 4) + str((int(g[4]) + 1) % 10)


static func _hash(text: String) -> int:
	var h := 7
	for i in text.length():
		h = (h * 31 + text.unicode_at(i)) & Rng.MASK
	return h


## Шифротекст для ленты: пятизначные группы (по длине открытого текста, не больше 40).
static func cipher_groups(cable: Dictionary) -> Array:
	var n := clampi(int(String(cable.body.ru).length() / 12.0), 12, 40)
	var xs := _stream(_hash(cable.cable_id), n * 5)
	var out: Array = []
	for i in n:
		var g := ""
		for k in 5:
			g += str(int(floor(xs[i * 5 + k] * 10)))
		out.append(g)
	return out


## Положение роторов до установки ключа: случайные буквы, свои у каждой директивы.
static func idle_rotors(cable: Dictionary) -> String:
	var out := ""
	for x in _stream(_hash(cable.cable_id) + 3, ROTORS):
		out += LETTERS[int(floor(x * LETTERS.length()))]
	return out


# ——— Директивы ———

static func directives(s: Dictionary, content: Dictionary) -> Array:
	return content.cables.filter(func(c): return c.kind == "directive" and s.delivered_cables.has(c.cable_id))


## Состояние директивы: encrypted → decrypted (прочитана) → accept / query (решение принято).
static func directive_status(s: Dictionary, cable_id: String) -> String:
	if s.verified.has(cable_id):
		return s.verified[cable_id]
	return "decrypted" if s.read_cables.has(cable_id) else "encrypted"


## Директивы, ждущие резидента (не расшифрованы или без решения) — значок на машине.
static func pending_directives(s: Dictionary, content: Dictionary) -> Array:
	return directives(s, content).filter(func(c): return not s.verified.has(c.cable_id))


## Непрочитанная почта лотка (директивы идут через шифроузел, а не через лоток).
static func unread_mail(s: Dictionary, content: Dictionary) -> Array:
	return Campaign.unread_cables(s).filter(func(id): return Campaign.cable_by_id(content, id).get("kind", "") != "directive")


## Итог сверки: accepted · accepted_forged · confirmed (зря запросили) · exposed (подлог раскрыт).
static func verify_outcome(cable: Dictionary, decision: String) -> String:
	if decision == "accept":
		return "accepted_forged" if cable.forged else "accepted"
	return "exposed" if cable.forged else "confirmed"


# ——— Ночная шифрограмма ———

## Факты текущей недели из журнала: [{key, type, ref, negative}]. Отрицательные факты — это
## сбои недели (свёрнутые операции, провальные подходы): о них можно умолчать.
static func week_facts(s: Dictionary) -> Array:
	var out: Array = []
	for entry in s.log:
		if entry.week != s.week:
			continue
		var e: Dictionary = entry.event
		match e.type:
			"op_resolved":
				var bad: bool = e.outcome == "aborted"
				out.append({"key": "op:" + e.op_id, "type": "op_aborted" if bad else "op_done", "ref": e.op_id, "negative": bad})
			"target_unlocked", "analysis_approved", "target_recruited":
				out.append({"key": "%s:%s" % [e.type, e.target_id], "type": e.type, "ref": e.target_id, "negative": false})
			"target_lost":
				out.append({"key": "target_lost:" + e.target_id, "type": "target_lost", "ref": e.target_id, "negative": true})
			"directive_verified":
				if e.outcome == "exposed":
					out.append({"key": "exposed:" + e.cable_id, "type": "directive_exposed", "ref": e.cable_id, "negative": false})
	if out.is_empty():
		out.append({"key": "quiet", "type": "quiet", "ref": "", "negative": false})
	return out


## Вид донесения по выбору игрока: хоть одно приукрашивание — приукрашенное; умолчание
## о сбое — с умолчанием; иначе — правдивое (умолчать об успехе — просто скромность).
static func classify(facts: Array, choices: Dictionary) -> String:
	var hidden := false
	for f in facts:
		var c: String = choices.get(f.key, "as_is")
		if c == "embellish":
			return "embellished"
		if c == "omit" and f.negative:
			hidden = true
	return "silence" if hidden else "truth"


## Последствия донесения — те же числа, что применит движок ночью:
## {trust, pressure, lie, lie_chance, check_week}.
static func report_effects(s: Dictionary, content: Dictionary, report: String) -> Dictionary:
	var b: Dictionary = content.balance
	var ct: Dictionary = b.centre_trust
	var mp: Dictionary = b.moscow_pressure
	var failures: bool = s.week_failures > 0
	var out := {"trust": 0, "pressure": 0, "lie": false, "lie_chance": 0.0}
	match report:
		"truth":
			out.trust = ct.report_truth_with_failures if failures else ct.report_truth
			out.pressure = mp.report_truth_with_failures if failures else 0
		"embellished":
			out.trust = ct.report_embellished
			out.pressure = mp.report_embellished
			out.lie = true
			out.lie_chance = b.lies.uncover_chance_embellished
		_:
			out.trust = ct.report_silence
			out.lie = failures
			out.lie_chance = b.lies.uncover_chance_silence if failures else 0.0
	var every := int(b.lies.check_every_weeks)
	out.check_week = int(ceil(float(s.week) / every)) * every
	return out


# ——— Запросы в Центр ———

static func request_by_id(content: Dictionary, id: String) -> Dictionary:
	for r in content.requests:
		if r.request_id == id:
			return r
	return {}


## Запросы, которые можно приложить к шифрограмме сейчас: свой акт, ещё не отправлялся.
static func available_requests(s: Dictionary, content: Dictionary) -> Array:
	return content.requests.filter(func(r): return r.act == s.act and not s.requests.any(func(x): return x.request_id == r.request_id))


## Будет ли запрос одобрен при текущем Доверии Центра.
static func would_grant(s: Dictionary, request: Dictionary) -> bool:
	return s.centre_trust >= int(request.min_trust)


## Срок задачи акта с учётом одобренных продлений.
static func act_deadline(s: Dictionary, content: Dictionary) -> int:
	var def := Campaign.current_act_def(s, content)
	if def.is_empty():
		return 0
	var extra := 0
	for x in s.requests:
		if x.granted and x.act == s.act:
			extra += int(request_by_id(content, x.request_id).get("granted", {}).get("extend_act_weeks", 0))
	return int(def.weeks.to) + extra
