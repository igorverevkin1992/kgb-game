extends TestCase
## Все символы, которые видит игрок, есть в шрифтах игры. В веб-версии и на чужих компьютерах
## нет системных шрифтов-заменителей — недостающий символ превращается в пустой прямоугольник.


func _missing(font: Font, text: String, found: Dictionary) -> void:
	for ch in text:
		var code := ch.unicode_at(0)
		if code <= 32 or found.has(ch):
			continue
		var ok_any := font.has_char(code)
		if not ok_any:
			for fb in font.fallbacks:
				if fb.has_char(code):
					ok_any = true
					break
		if not ok_any:
			found[ch] = true


func _all_texts() -> String:
	var parts: Array = []
	for k in T.keys():
		parts.append(T.t(k))
	var walk := func(self_ref: Callable, v: Variant) -> void:
		if typeof(v) == TYPE_ARRAY:
			for x in v:
				self_ref.call(self_ref, x)
		elif typeof(v) == TYPE_DICTIONARY:
			if v.has("ru") and typeof(v.ru) == TYPE_STRING:
				parts.append(v.ru)
				return
			for x in v.values():
				self_ref.call(self_ref, x)
	walk.call(walk, H.content())
	return "".join(parts) + "0123456789%«»—–№·•[]"


func test_all_glyphs_present() -> void:
	var text := _all_texts()
	for f in [Style.mono(), Style.form(), Style.form(true), Style.serif(), Style.serif(true)]:
		var found := {}
		_missing(f, text, found)
		eq(found.keys(), [], "нет символов в %s" % f.get_font_name())
