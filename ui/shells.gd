class_name Shells
## Оболочки модулей. Каждая уже показывает живые данные кампании, а полноценная механика
## появится в своём шаге плана (номер шага — в подписи «в разработке»).

const PLAN_STEP := {"dialog": 7, "finance": 8, "counterintel": 13}


static func _shell(id: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ModuleView.header(T.t("module.%s.name" % id), T.t("shell.wip", {"step": PLAN_STEP[id], "details": T.t("module.%s.details" % id)})))
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
