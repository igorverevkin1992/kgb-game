class_name DialogView
## Магнитофон «Тембр-2М» и вербовочная беседа. Слева — магнитофон и катушки с записями встреч;
## справа — идущая встреча (индикаторы Раппорт и Тревога с видимыми порогами, стенограмма,
## козыри из досье, тоны ответа, «Сделать предложение» и «Прервать контакт»), разбор катушки
## (таймкоды, перемотка ← →, пробел — к следующей оговорке; оговорки снимаются на доску)
## или список целей, с которыми можно встретиться.

const LEFT_W := 440.0
const RIGHT_X := 500.0
const RIGHT_W := 1008.0
const TOP := 76.0
const H := 660.0
const TAPE_BG := Color("#efe9d6")


static func build() -> Control:
	var s: Dictionary = Game.state
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var note := T.t("dialog.note")
	if s.meeting != null:
		var t := Campaign.target_by_id(Game.content, s.meeting.target_id)
		if not t.is_empty():
			note = T.t("dialog.cover", {"cover": T.loc(t.approach.cover), "flag": T.t("board.channel." + t.approach.flag_mode)})
	root.add_child(ModuleView.header(T.t("module.dialog.name"), note))
	root.add_child(_left(s))
	if s.meeting != null:
		# Встреча целиком в прокрутке: при любом числе сведений кнопки тонов достижимы.
		var ms := ScrollContainer.new()
		ms.name = "meeting-scroll"
		ms.position = Vector2(RIGHT_X, TOP)
		ms.size = Vector2(RIGHT_W + 16, H)
		ms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var mv := _meeting(s)
		mv.position = Vector2.ZERO
		ms.add_child(mv)
		root.add_child(ms)
	elif Game.tape_selected >= 0 and Game.tape_selected < s.tapes.size():
		root.add_child(_review(s, s.tapes[Game.tape_selected]))
	else:
		root.add_child(_candidates(s))
	return root


# ——— Магнитофон и катушки ———

static func _left(s: Dictionary) -> Control:
	var v := Style.vbox(10)
	v.position = Vector2(28, TOP)
	v.custom_minimum_size = Vector2(LEFT_W, 0)
	var deck := Control.new()
	deck.custom_minimum_size = Vector2(LEFT_W, 250)
	deck.add_child(Style.art("recorder", Rect2(0, 0, LEFT_W, 250)))
	if s.meeting != null:
		var rec := Style.panel(Style.STAMP_RED, 6)
		rec.name = "recording"
		rec.position = Vector2(16, 12)
		rec.add_child(Style.label(T.t("dialog.recording"), Style.form(true), 14, Style.PAPER_LIGHT, false))
		deck.add_child(rec)
	v.add_child(deck)
	v.add_child(Style.label(T.t("dialog.tapes").to_upper(), Style.form(true), 16, Style.PAPER))
	if s.tapes.is_empty():
		v.add_child(Style.para(T.t("dialog.noTapes"), LEFT_W, Style.mono(), 13, Color(Style.PAPER, 0.6)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LEFT_W, 300)
	var list := Style.vbox(6)
	list.custom_minimum_size.x = LEFT_W - 12
	for i in range(s.tapes.size() - 1, -1, -1):
		var tape: Dictionary = s.tapes[i]
		var on: bool = Game.tape_selected == i and s.meeting == null
		var name := T.loc(Meeting.person_name(Game.content, Meeting.dialog_by_id(Game.content, tape.dialog_id)))
		var b := Style.button("%s · %s\n%s" % [T.t("calendar.week", {"week": tape.week}), name, T.t("dialog.outcome." + tape.outcome)],
			"tape-%d" % i, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 13)
		b.custom_minimum_size.x = LEFT_W - 12
		b.disabled = s.meeting != null
		b.pressed.connect(Game.select_tape.bind(i))
		list.add_child(b)
	scroll.add_child(list)
	v.add_child(scroll)
	return v


# ——— Идущая встреча ———

static func _meeting(s: Dictionary) -> Control:
	var m: Dictionary = s.meeting
	var c: Dictionary = Game.content
	var d := Meeting.dialog_by_id(c, m.dialog_id)
	var t := Campaign.target_by_id(c, m.target_id)
	var v := Style.vbox(10)
	v.name = "meeting"
	v.position = Vector2(RIGHT_X, TOP)
	v.custom_minimum_size = Vector2(RIGHT_W, 0)
	var head := Style.hbox(16)
	head.add_child(Style.label("%s · %s" % [T.loc(Meeting.person_name(c, d)), T.loc(d.title)], Style.form(true), 20, Style.PAPER))
	v.add_child(head)
	var bars := Style.hbox(24)
	bars.add_child(_bar("meeting-rapport", T.t("dialog.rapport"), m.rapport, int(d.offer_rapport), T.t("dialog.offerAt", {"n": d.offer_rapport}), Color("#7fae6e")))
	bars.add_child(_bar("meeting-anxiety", T.t("dialog.anxiety"), m.anxiety, Meeting.max_anxiety(d), T.t("dialog.breakAt", {"n": Meeting.max_anxiety(d)}), Color("#d0614c")))
	v.add_child(bars)
	if Meeting.is_agreement(d):
		var stakes := Style.para(_stakes(d), RIGHT_W, Style.mono(), 12, Color(Style.PAPER, 0.75))
		stakes.name = "meeting-stakes"
		v.add_child(stakes)
	var topics := Meeting.topics_left(d, m)
	var trumps := Meeting.available_trumps(s, c, m)
	# Много сведений из дела — стенограмма короче, чтобы тоны и кнопки остались на экране.
	var shown_trumps: int = trumps.size() if topics else 0
	var base_h := 250 if Meeting.is_agreement(d) else 270
	v.add_child(_transcript(d, m.lines, maxi(150, base_h - maxi(0, shown_trumps - 2) * 22), -1))

	if topics and not trumps.is_empty():
		v.add_child(Style.label(T.t("dialog.trumps"), Style.form(true), 14, Color(Style.PAPER, 0.85)))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 6)
		for tr in trumps:
			var clue := Campaign.clue_by_id(c, tr.clue_id)
			var on: bool = Game.meeting_trump == tr.clue_id
			var axes: Array = clue.reveals.filter(func(r): return r.target_id == m.target_id).map(func(r): return T.t("mice.axis.%s.short" % r.axis))
			var label := "%s%s · %s" % [("[%s] " % "/".join(axes)) if not axes.is_empty() else "", T.loc(clue.title), T.t("dialog.trumpReady", {"n": tr.min_rapport})]
			if Meeting.is_coercive(c, m.target_id, "", tr.clue_id) > 0:
				label += " · " + T.t("dialog.coerciveMark")
			var b := Style.button(label, "trump-" + tr.clue_id, Style.INK if on else Style.PAPER, Style.PAPER if on else Color(0, 0, 0, 0.25), Color(Style.PAPER, 0.5), 13)
			b.pressed.connect(Game.select_trump.bind(tr.clue_id))
			row.add_child(b)
		row.custom_minimum_size.x = RIGHT_W
		row.size.x = RIGHT_W
		v.add_child(row)
	if topics and not Meeting.is_agreement(d):
		var mb: Dictionary = c.balance
		var co := Style.para(T.t("dialog.coercion", {"n": int(m.get("coercion", 0)), "max": mb.meeting.coercion_threshold,
			"p": mb.finance.coerced_loyalty_penalty, "w": mb.finance.loyalty_coerced_week}), RIGHT_W, Style.mono(), 12,
			Color("#e2a27f") if int(m.get("coercion", 0)) >= int(mb.meeting.coercion_threshold) else Color(Style.PAPER, 0.65))
		co.name = "meeting-coercion"
		co.set_meta("value", int(m.get("coercion", 0)))
		v.add_child(co)
	if topics:
		v.add_child(Style.label(T.t("dialog.toneHint") if Game.meeting_trump == "" else T.t("dialog.toneWithTrump"), Style.form(true), 14, Color(Style.PAPER, 0.85)))
		var tones := Style.hbox(8)
		for tone in Meeting.TONES:
			var b := Style.button(T.t("dialog.tone." + tone), "tone-" + tone, Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 15)
			b.pressed.connect(Game.meeting_reply.bind(tone))
			tones.add_child(b)
		v.add_child(tones)
	else:
		v.add_child(Style.para(T.t("dialog.noTopics"), RIGHT_W, Style.mono(), 14, Color(Style.PAPER, 0.8)))

	var acts := Style.hbox(10)
	var handling := Meeting.is_agreement(d)
	var offer := Style.button(T.t("dialog.agree" if handling else "dialog.offer", {"n": d.offer_rapport}), "meeting-offer", Style.PAPER, Color("#3d5a32"), Color(Style.PAPER, 0.6), 15)
	offer.disabled = not Meeting.can_offer(d, m)
	offer.pressed.connect(Game.dispatch.bind({"type": "meeting_offer"}))
	acts.add_child(offer)
	var abort := Style.button(T.t("dialog.abort"), "meeting-abort", Style.PAPER, Color("#5a2a22"), Color(Style.PAPER, 0.6), 15)
	abort.tooltip_text = T.t("dialog.abortHint", {"n": c.balance.meeting.anxiety_cooldown})
	abort.pressed.connect(Game.dispatch.bind({"type": "meeting_abort"}))
	acts.add_child(abort)
	acts.add_child(Style.para(T.t("dialog.abortHint", {"n": c.balance.meeting.anxiety_cooldown}), 420, Style.mono(), 12, Color(Style.PAPER, 0.6)))
	v.add_child(acts)
	return v


## Индикатор 0–100 с отметкой порога; значение и порог подписаны (никаких скрытых чисел).
static func _bar(id: String, title: String, value: int, mark: int, mark_text: String, color: Color) -> Control:
	var box := Style.vbox(4)
	box.name = id
	box.set_meta("value", value)
	box.add_child(Style.label("%s: %d%%  ·  %s" % [title, value, mark_text], Style.form(true), 15, Style.PAPER))
	box.add_child(Bar.new(value, mark, color))
	return box


# ——— Стенограмма ———

## Стенограмма с таймкодами. cursor >= 0 — подсвеченная строка при разборе катушки.
static func _transcript(d: Dictionary, lines: Array, height: float, cursor: int) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "transcript"
	scroll.set_meta("scroll_key", "")  # прокручивает себя сам — к последней реплике
	scroll.custom_minimum_size = Vector2(RIGHT_W, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := Style.panel(TAPE_BG, 18)
	var v := Style.vbox(8)
	v.custom_minimum_size.x = RIGHT_W - 52
	var codes := timecodes(d, lines)
	var target := Control.new()
	for i in lines.size():
		var row := _line(d, lines[i], codes[i], i == cursor)
		row.name = "line-%d" % i
		v.add_child(row)
		if i == cursor:
			target = row
	p.add_child(v)
	scroll.add_child(p)
	# Живая встреча — к последней реплике; разбор — к строке под головкой.
	# После раскладки строк (sort_children) позиции известны; прокрутку ставим отложенно,
	# когда ScrollContainer обновит свой диапазон.
	v.sort_children.connect(func():
		var y := 1000000 if cursor < 0 else maxi(0, int(target.position.y) - 60)
		scroll.set_deferred("scroll_vertical", y))
	return scroll


## Таймкоды строк: 3 секунды на реплику плюс время на чтение.
static func timecodes(d: Dictionary, lines: Array) -> Array:
	var out: Array = []
	var sec := 0
	for line in lines:
		out.append(sec)
		sec += 3 + int(String(Meeting.line_text(d, line).get("ru", "")).length() / 14.0)
	return out


static func _timecode(sec: int) -> String:
	return "%02d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]


static func _line(d: Dictionary, line: Dictionary, sec: int, current: bool) -> Control:
	var who := Meeting.speaker(line)
	# Строка под головкой подсвечена.
	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", Style.box(Color("#e9c46a55") if current else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 2))
	if current:
		wrap.set_meta("cursor", true)
	var row := Style.hbox(10)
	wrap.add_child(row)
	var code := Style.label(("» " if current else "  ") + _timecode(sec), Style.mono(), 12, Style.STAMP_RED if current else Color(Style.INK, 0.5))
	code.custom_minimum_size.x = 96
	row.add_child(code)
	var col := Style.vbox(2)
	var w := RIGHT_W - 52 - 110
	match who:
		"scene":
			var text := T.loc(Meeting.line_text(d, line)) if line.kind == "setting" else T.t("dialog.end." + line.outcome)
			col.add_child(Style.para(text, w, Style.serif(false, true), 15, Color(Style.INK, 0.75)))
		"me":
			var tag: String = T.t("dialog.me")
			if line.has("tone"):
				tag += " (%s)" % T.t("dialog.tone." + line.tone).to_lower()
			col.add_child(Style.label(tag.to_upper(), Style.form(true), 12, Color(Style.INK, 0.6)))
			col.add_child(Style.para(T.loc(Meeting.line_text(d, line)), w, Style.mono(), 15, Style.INK))
		_:
			col.add_child(Style.label(T.loc(Meeting.person_name(Game.content, d)).to_upper(), Style.form(true), 12, Style.STAMP_RED))
			col.add_child(_rich(d, line, w))
			if line.has("dr"):
				var fx := Style.label(T.t("dialog.fx", {"r": _signed(line.dr), "a": _signed(line.da)}) + ("" if not line.has("ready") else ("  ·  " + T.t("dialog.trumpOk" if line.ready else "dialog.trumpEarly"))),
					Style.form(), 12, Color(Style.INK, 0.6))
				col.add_child(fx)
	row.add_child(col)
	return wrap


## Реплика собеседника; оговорки (улики с канала «беседа») подсвечены и снимаются кликом.
static func _rich(d: Dictionary, line: Dictionary, w: float) -> RichTextLabel:
	var text := T.loc(Meeting.line_text(d, line))
	var out := text.replace("[", "[lb]")
	for clue in Game.content.clues:
		if clue.source.channel == "meeting" and clue.source.from == d.dialog_id and text.contains(clue.chunk):
			var piece: String = String(clue.chunk).replace("[", "[lb]")
			if Game.state.clues.has(clue.clue_id):
				out = out.replace(piece, "[u]%s[/u]" % piece)
			else:
				out = out.replace(piece, "[url=%s][bgcolor=#e9c46a99]%s[/bgcolor][/url]" % [clue.clue_id, piece])
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size.x = w
	r.add_theme_font_override("normal_font", Style.mono())
	r.add_theme_font_size_override("normal_font_size", Style.fs(15))
	r.add_theme_color_override("default_color", Style.INK)
	r.meta_underlined = false
	r.text = out
	r.meta_clicked.connect(func(meta): Game.take_clue(str(meta)))
	return r


# ——— Разбор катушки ———

static func _review(s: Dictionary, tape: Dictionary) -> Control:
	var d := Meeting.dialog_by_id(Game.content, tape.dialog_id)
	var tn := Meeting.person_name(Game.content, Meeting.dialog_by_id(Game.content, tape.dialog_id))
	var v := Style.vbox(10)
	v.name = "tape-review"
	v.position = Vector2(RIGHT_X, TOP)
	v.custom_minimum_size = Vector2(RIGHT_W, 0)
	v.add_child(Style.label(T.t("dialog.reviewTitle", {"week": tape.week, "name": T.loc(tn), "outcome": T.t("dialog.outcome." + tape.outcome)}), Style.form(true), 20, Style.PAPER))
	var slips := slip_lines(s, d, tape.lines)
	v.add_child(Style.para(T.t("dialog.reviewHint", {"n": slips.size()}), RIGHT_W, Style.mono(), 13, Color(Style.PAPER, 0.75)))
	var cursor := clampi(Game.tape_cursor, 0, tape.lines.size() - 1)
	v.add_child(_transcript(d, tape.lines, 470, cursor))
	var row := Style.hbox(8)
	for b in [["tape-back", "dialog.rewind", -1], ["tape-forward", "dialog.forward", 1]]:
		var btn := Style.button(T.t(b[1]), b[0], Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 14)
		btn.pressed.connect(Game.tape_seek.bind(b[2]))
		row.add_child(btn)
	var nx := Style.button(T.t("dialog.nextSlip"), "tape-next-slip", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 14)
	nx.disabled = slips.is_empty()
	nx.pressed.connect(Game.tape_next_slip)
	row.add_child(nx)
	var close := Style.button(T.t("dialog.closeTape"), "tape-close", Style.PAPER, Color(0, 0, 0, 0.3), Color(Style.PAPER, 0.6), 14)
	close.pressed.connect(Game.select_tape.bind(-1))
	row.add_child(close)
	v.add_child(row)
	return v


## Номера строк катушки, где есть ещё не снятая оговорка.
static func slip_lines(s: Dictionary, d: Dictionary, lines: Array) -> Array:
	var out: Array = []
	for i in lines.size():
		if Meeting.speaker(lines[i]) != "them":
			continue
		var text := String(Meeting.line_text(d, lines[i]).get("ru", ""))
		for clue in Game.content.clues:
			if clue.source.channel == "meeting" and clue.source.from == d.dialog_id and not s.clues.has(clue.clue_id) and text.contains(clue.chunk):
				out.append(i)
				break
	return out


# ——— Кому назначить встречу ———

static func _candidates(s: Dictionary) -> Control:
	var c: Dictionary = Game.content
	var v := Style.vbox(12)
	v.name = "candidates"
	v.position = Vector2(RIGHT_X, TOP)
	v.custom_minimum_size = Vector2(RIGHT_W, 0)
	v.add_child(Style.para(T.t("dialog.intro"), RIGHT_W, Style.mono(), 14, Color(Style.PAPER, 0.85)))
	# Разговоры, которых ждут сейчас (инициативник, подчинённый, инспектор, родные).
	for d in Meeting.conversations(s, c):
		var cp := Style.panel(Color(Style.STAMP_RED, 0.18), 14, Color(Style.PAPER, 0.3), 1)
		cp.name = "conversation-" + d.dialog_id
		var crow := Style.hbox(16)
		var cinfo := Style.vbox(4)
		cinfo.custom_minimum_size.x = 560
		cinfo.add_child(Style.label(T.loc(Meeting.person_name(c, d)), Style.form(true), 18, Style.PAPER))
		cinfo.add_child(Style.para(T.loc(d.title), 560, Style.mono(), 13, Color(Style.PAPER, 0.75)))
		crow.add_child(cinfo)
		var cv := Style.vbox(4)
		var cb := Style.button(T.t("dialog.converse"), "converse-" + d.dialog_id, Style.PAPER, Color("#3d5a32"), Color(Style.PAPER, 0.6), 15)
		cb.pressed.connect(Game.start_meeting.bind("", d.dialog_id))
		cv.add_child(cb)
		cv.add_child(Style.para(_stakes(d), 400, Style.mono(), 12, Color(Style.PAPER, 0.7)))
		crow.add_child(cv)
		cp.add_child(crow)
		v.add_child(cp)
	var any := false
	for t in c.targets:
		var ts: Dictionary = s.targets[t.target_id]
		if not ts.unlocked:
			continue
		any = true
		var p := Style.panel(Color(Style.PAPER, 0.1), 14, Color(Style.PAPER, 0.3), 1)
		p.name = "candidate-" + t.target_id
		var row := Style.hbox(16)
		var info := Style.vbox(4)
		info.add_child(Style.label(T.loc(t.name), Style.form(true), 18, Style.PAPER))
		var status := T.t("dialog.recruited") if ts.recruited else (T.t("dialog.lost") if ts.lost else T.t("dialog.state", {"r": ts.rapport, "a": ts.paranoia}))
		info.add_child(Style.label(status, Style.mono(), 13, Color(Style.PAPER, 0.75)))
		info.custom_minimum_size.x = 560
		row.add_child(info)
		if ts.recruited and not ts.lost:
			row.add_child(_handling_slot(s, c, t))
		if not ts.recruited and not ts.lost:
			var err := Meeting.meet_error(s, c, t.target_id)
			if err == "":
				var b := Style.button(T.t("dialog.meet"), "meet-" + t.target_id, Style.PAPER, Color("#3d5a32"), Color(Style.PAPER, 0.6), 15)
				b.pressed.connect(Game.start_meeting.bind(t.target_id))
				row.add_child(b)
			else:
				row.add_child(Style.para(err, 400, Style.mono(), 13, Color("#e2a27f")))
		p.add_child(row)
		v.add_child(p)
	if not any:
		v.add_child(Style.label(T.t("dialog.empty"), Style.mono(), 15, Color(Style.PAPER, 0.7)))
	return v


static func _signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)


## Встреча на связи с агентом: ближайшая по порядку — кнопка или причина, почему нельзя.
static func _handling_slot(s: Dictionary, c: Dictionary, t: Dictionary) -> Control:
	var box := Style.vbox(4)
	box.custom_minimum_size.x = 400
	var all := Meeting.handling_dialogs(c, t.target_id)
	if all.is_empty():
		return box
	var done: int = all.filter(func(d): return s.get("handled", {}).has(d.dialog_id)).size()
	box.add_child(Style.label(T.t("dialog.handlingCount", {"n": done, "of": all.size()}), Style.form(), 13, Color(Style.PAPER, 0.75)))
	var nxt := Meeting.next_handling(s, c, t.target_id)
	if nxt.is_empty():
		return box
	var err := Meeting.handling_error(s, c, nxt.dialog_id)
	if err == "":
		var b := Style.button(T.t("dialog.handlingMeet", {"title": T.loc(nxt.title)}), "handle-" + nxt.dialog_id, Style.PAPER, Color("#3d5a32"), Color(Style.PAPER, 0.6), 14)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 400
		b.pressed.connect(Game.start_meeting.bind(t.target_id, nxt.dialog_id))
		box.add_child(b)
		box.add_child(Style.para(_stakes(nxt), 400, Style.mono(), 12, Color(Style.PAPER, 0.7)))
	else:
		box.add_child(Style.para("%s: %s" % [T.loc(nxt.title), err], 400, Style.mono(), 12, Color("#e2a27f")))
	return box


## Ставки встречи на связи: что даст договорённость и что будет при срыве.
static func _stakes(d: Dictionary) -> String:
	var parts: Array = []
	var ok: Dictionary = d.get("success", {})
	if int(ok.get("loyalty", 0)) != 0:
		parts.append(T.t("dialog.stake.loyalty", {"n": _signed(int(ok.loyalty))}))
	if int(ok.get("lifestyle", 0)) != 0:
		parts.append(T.t("dialog.stake.lifestyle", {"n": _signed(int(ok.lifestyle))}))
	if not ok.get("clue_ids", []).is_empty():
		parts.append(T.t("dialog.stake.reports", {"n": ok.clue_ids.size()}))
	if int(ok.get("polygraph_slots", 0)) > 0:
		parts.append(T.t("dialog.stake.polygraph", {"n": ok.polygraph_slots}))
	if int(ok.get("sog_heat", 0)) != 0:
		parts.append(T.t("dialog.stake.sog", {"n": _signed(int(ok.sog_heat))}))
	if int(ok.get("mole_hunt", 0)) != 0:
		parts.append(T.t("dialog.stake.mole", {"n": _signed(int(ok.mole_hunt))}))
	if int(ok.get("centre_trust", 0)) != 0:
		parts.append(T.t("dialog.stake.trust", {"n": _signed(int(ok.centre_trust))}))
	if int(ok.get("moscow_pressure", 0)) != 0:
		parts.append(T.t("dialog.stake.pressure", {"n": _signed(int(ok.moscow_pressure))}))
	if Meeting.is_conversation(d):
		if parts.is_empty():
			return T.t("dialog.stakesTalkPlain", {"n": d.offer_rapport})
		return T.t("dialog.stakesTalk", {"n": d.offer_rapport, "ok": ", ".join(parts)})
	var fail = d.get("failure")
	return T.t("dialog.stakes", {"ok": ", ".join(parts), "fail": _signed(int(fail.loyalty)) if fail != null else "0",
		"sog": Game.content.balance.meeting.get("handling_sog_heat", 2), "n": d.offer_rapport})


## Полоса индикатора с отметкой порога.
class Bar extends Control:
	var value := 0
	var mark := 0
	var color := Color.WHITE
	func _init(v: int, m: int, c: Color) -> void:
		value = v
		mark = m
		color = c
		custom_minimum_size = Vector2(470, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		draw_rect(Rect2(0, 0, w, 18), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(0, 0, w * value / 100.0, 18), color)
		var x := w * mark / 100.0
		draw_line(Vector2(x, -3), Vector2(x, 21), Style.PAPER_LIGHT, 3)
