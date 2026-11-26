class_name Fmt
## Форматирование для русской версии.

const MONTHS_GEN := ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]


## Русское склонение после числа: 1 доллар, 2 доллара, 5 долларов.
static func plural(n: int, one: String, few: String, many: String) -> String:
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return one
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return few
	return many


## 40000 → «40 000» (неразрывный пробел между тысячами).
static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Сумма словами: «40 000 долларов».
static func usd(n: int) -> String:
	return "%s %s" % [thousands(n), plural(absi(n), "доллар", "доллара", "долларов")]


## {year, month, day} → «1 октября 1984 г.»
static func date(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	return "%d %s %d г." % [d.day, MONTHS_GEN[d.month - 1], d.year]


## Фазы операции вместо актов: 1 → «первая», в нужном падеже.
const ORD_NOM := ["первая", "вторая", "третья", "четвёртая"]
const ORD_GEN := ["первой", "второй", "третьей", "четвёртой"]


## «Первая фаза операции».
static func op_phase(n: int) -> String:
	var w: String = ORD_NOM[clampi(n, 1, 4) - 1]
	return "%s фаза операции" % (w.substr(0, 1).to_upper() + w.substr(1))


## «первой фазы операции» (задача первой фазы операции).
static func op_phase_gen(n: int) -> String:
	return "%s фазы операции" % ORD_GEN[clampi(n, 1, 4) - 1]


## «во второй фазе операции» (откроется во второй фазе операции).
static func op_phase_in(n: int) -> String:
	var w: String = ORD_GEN[clampi(n, 1, 4) - 1]
	return "%s %s фазе операции" % ["во" if w.begins_with("в") else "в", w]
