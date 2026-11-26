class_name Shells
## Оболочки модулей. Каждая уже показывает живые данные кампании, а полноценная механика
## появится в своём шаге плана (номер шага — в подписи «в разработке»).

const PLAN_STEP := {"cipher": 6, "dialog": 7, "finance": 8, "counterintel": 13}


static func _shell(id: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.%s.name" % id), T.t("shell.wip", {"step": PLAN_STEP[id], "details": T.t("module.%s.details" % id)})))
	return root


## Шифроузел: последняя директива на телетайпной ленте.
static func cipher() -> Control:
	var root := _shell("cipher")
	var s: Dictionary = Game.state
	var last := {}
	for c in Game.content.cables:
		if c.kind == "directive" and s.delivered_cables.has(c.cable_id):
			last = c
	var tape := Style.panel(Style.PAPER_LIGHT, 28)
	tape.name = "teletype"
	tape.position = Vector2(28, 76)
	var v := Style.vbox(10)
	if last.is_empty():
		v.add_child(Style.label(T.t("cipher.empty"), Style.mono(), 17, Style.INK))
	else:
		v.add_child(Style.para("%s %s · %s" % [T.t("cipher.from"), T.loc(last.sender), T.loc(last.subject)], 760, Style.mono(), 14, Color(Style.INK, 0.7)))
		var body := Style.para(T.loc(last.body).to_upper(), 760, Style.mono(), 17, Style.INK)
		body.add_theme_constant_override("line_spacing", 8)
		v.add_child(body)
	tape.add_child(v)
	root.add_child(tape)
	var trust := Style.label(T.t("cipher.trust", {"trust": s.centre_trust}), Style.mono(), 15, Color(Style.PAPER, 0.8))
	trust.position = Vector2(900, 80)
	root.add_child(trust)
	return root


## Финансовый журнал: остаток спецфонда и порог отчёта о валютной операции.
static func finance() -> Control:
	var root := _shell("finance")
	var page := Style.panel(Style.PAPER_LIGHT, 40)
	page.name = "ledger"
	page.position = Vector2(28, 76)
	page.custom_minimum_size = Vector2(1480, 640)
	var v := Style.vbox(24)
	v.add_child(Style.label(T.t("finance.balance", {"usd": Fmt.usd(Game.state.fund_usd)}), Style.mono(), 22, Style.INK))
	v.add_child(Style.label(T.t("finance.threshold"), Style.mono(), 16, Color(Style.INK, 0.75)))
	page.add_child(v)
	root.add_child(page)
	return root


static func dialog() -> Control:
	var root := _shell("dialog")
	root.add_child(Style.art("recorder", Rect2(28, 76, 760, 640)))
	var note := Style.label(T.t("dialog.empty"), Style.mono(), 15, Color(Style.PAPER, 0.8))
	note.position = Vector2(830, 90)
	root.add_child(note)
	return root


static func counterintel() -> Control:
	var root := _shell("counterintel")
	var note := Style.label(T.t("counterintel.empty"), Style.mono(), 15, Color(Style.PAPER, 0.8))
	note.position = Vector2(28, 90)
	root.add_child(note)
	return root


## Пробковая фактура: случайные (но одинаковые от запуска к запуску) крапинки.
class CorkTexture extends Control:
	func _init(sz: Vector2) -> void:
		size = sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1985
		for i in 2600:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(0.8, 1.8), Color("#8b663e") if i % 2 == 0 else Color("#b8915f"))
