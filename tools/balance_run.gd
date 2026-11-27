extends SceneTree
## Балансный прогон: автоигрок проходит кампанию каждой стратегией и печатает сводку.
## Запуск: tools/balance.sh

func _init() -> void:
	var c := ContentLoader.game_content()
	for st in Autoplay.STRATEGIES:
		var r := Autoplay.run(c, st)
		var s: Dictionary = r.state
		print("━━ Стратегия «%s» → концовка: %s" % [st, r.ending])
		for act in r.weeks:
			print("   фаза %d: недели %d–%d" % [act, r.weeks[act][0], r.weeks[act][1]])
		var rec: Array = s.targets.keys().filter(func(id): return s.targets[id].recruited and not s.targets[id].lost)
		print("   завербованы: %s" % ", ".join(rec))
		print("   риски: наружка %d · охота на «крота» %d · финансовый след %d · давление Центра %d · доверие %d · фонд %d" % [
			s.risks.sog_heat, s.risks.mole_hunt, s.risks.treasury, s.risks.moscow_pressure, s.centre_trust, s.fund_usd])
		if s.get("list") != null:
			print("   «Список»: реализовано %d, арестовано %d; флаги: %s" % [ArrestWindow.realized(s, c), ArrestWindow.arrests(s, c),
				", ".join(s.flags.filter(func(f): return not f.begins_with("mode_")))])
		if s.get("polygraph") != null:
			print("   полиграф: %s (подготовка: %s)" % [s.polygraph.result, ", ".join(s.polygraph.prep)])
		for e in r.errors:
			print("   ! " + e)
	quit()
