extends TestCase
## Четыре концовки кампании: условия видны (checklist), приоритет — «Обмен тенями»,
## «Двойное дно», «Чистый триумф», иначе «Пиррова победа». Эпилог для каждой концовки.

func _final(mod: Callable) -> Dictionary:
	var s := H.act4_state()
	s.list = ArrestWindow.new_state(H.content())
	var n := 0
	for c in H.content().list:
		if not c.dangle and n < 14:
			s.list.cards[c.card_id].status = "natural"
			n += 1
	s.flags.append_array(["arrest_window_closed", "polygraph_done", "polygraph_passed"])
	s.risks = {"sog_heat": 30, "mole_hunt": 40, "treasury": 20, "moscow_pressure": 30}
	mod.call(s)
	return s


func test_clean_triumph() -> void:
	var s := _final(func(_s): pass)
	ok(Endings.checklist(s, H.content()).all(func(x): return x.ok))
	eq(Endings.final(s, H.content()), "clean_triumph")


func test_pyrrhic() -> void:
	eq(Endings.final(_final(func(s): s.risks.mole_hunt = 80), H.content()), "pyrrhic_victory", "охота на «крота» 80%")
	eq(Endings.final(_final(func(s): s.flags.append("draconian_measures")), H.content()), "pyrrhic_victory", "каскад тревоги")
	eq(Endings.final(_final(func(s): s.flags.erase("polygraph_passed")), H.content()), "pyrrhic_victory", "полиграф «на грани»")
	var few := _final(func(s): s.list.cards["card_sfera"].status = "pending")
	eq(Endings.final(few, H.content()), "pyrrhic_victory", "реализовано 13 из 18")
	ok(not Endings.checklist(few, H.content())[0].ok)


func test_shadow_exchange_and_double_bottom() -> void:
	eq(Endings.final(_final(func(s): s.flags.append("polygraph_failed")), H.content()), "shadow_exchange")
	eq(Endings.final(_final(func(s): s.risks.treasury = 100), H.content()), "shadow_exchange", "сгорел на финансовом следе")
	eq(Endings.final(_final(func(s): s.flags.append("dangle_accepted")), H.content()), "double_bottom")
	eq(Endings.final(_final(func(s): s.flags.append("kronos_frozen"); s.centre_trust = 10), H.content()), "double_bottom", "конфликт с Центром в кризис с перебежчиком")
	eq(Endings.final(_final(func(s): s.flags.append_array(["dangle_accepted", "polygraph_failed"])), H.content()), "shadow_exchange", "провал конспирации важнее")


func test_epilogue_per_ending() -> void:
	var c := H.content()
	for e in Endings.FINAL:
		var s := H.fresh()
		s.ending = e
		var pages: Array = Archive.epilogue(s, c)
		eq(pages[0].id, "arc_end_" + e, "первым — хроника своей концовки")
		ok(pages.any(func(p): return p.id == "arc_ames_result"), "и документальная хроника дела Эймса")
		ok(not pages.any(func(p): return p.id.begins_with("arc_end_") and p.id != "arc_end_" + e), "чужих хроник нет")
	var early := H.fresh()
	early.ending = "recalled"
	ok(Archive.epilogue(early, c).is_empty(), "при раннем провале эпилога нет")


func test_fate_pages_by_flags() -> void:
	var c := H.content()
	var s := H.fresh()
	s.ending = "clean_triumph"
	s.flags.append_array(["kronos_farewell", "vargas_handed", "family_kept"])
	var ids: Array = Archive.epilogue(s, c).map(func(p): return p.id)
	ok(ids.has("arc_fate_kronos_rome") and ids.has("arc_fate_vargas") and ids.has("arc_fate_home"), "судьбы — по флагам финала")
	ok(not ids.has("arc_fate_kronos_evacuated"), "чужих судеб нет")
	var mid := H.fresh()
	mid.flags.append("kronos_farewell")
	ok(not Archive.is_open(mid, Archive.entry_by_id(c, "arc_fate_kronos_rome")), "до финала лист закрыт")
