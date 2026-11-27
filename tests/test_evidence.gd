extends TestCase
## Вещдоки: предмет приходит по неделе, верная деталь даёт сведения и флаг, неверная — пометку,
## повторно деталь не осмотреть; линия «любовь или долг» открывается находками.


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


func test_arrival_and_inspect() -> void:
	var s := H.fresh()
	ok(Evidence.arrived(s, H.content()).is_empty(), "в первую неделю сейф пуст")
	s = H.play(self, s, H.quiet_week()).state
	ok(Evidence.arrived(s, H.content()).size() >= 2, "во вторую неделю — визитка и квитанция")
	var r := _do(s, {"type": "inspect_detail", "item_id": "ev_vargas_receipt", "detail_id": "vr_name"})
	eq(r.error, "")
	ok(r.events.any(func(e): return e.type == "evidence_nothing"), "ничего особенного")
	eq(_do(r.state, {"type": "inspect_detail", "item_id": "ev_vargas_receipt", "detail_id": "vr_name"}).error, "Эту деталь уже осматривали")
	r = _do(r.state, {"type": "inspect_detail", "item_id": "ev_vargas_receipt", "detail_id": "vr_stamp"})
	ok(r.state.clues.has("clue_vargas_clinic_debt"), "сведения на доску")
	eq(r.state.evidence.ev_vargas_receipt.found, ["vr_stamp"])


func test_love_flags() -> void:
	var s := H.fresh()
	s.act = 2
	s.week = 10
	var r := _do(s, {"type": "inspect_detail", "item_id": "ev_lv_photo", "detail_id": "ph_car"})
	eq(r.error, "")
	ok(r.state.flags.has("love_watched"), "машина наружки на фото — флаг линии")
	ok(Decisions.pending(r.state, H.content()).any(func(d): return d.decision_id == "dec_lv_watched"), "решение о наружке")


func test_save_roundtrip() -> void:
	var s: Dictionary = H.play(self, H.fresh(), H.quiet_week()).state
	s = _do(s, {"type": "inspect_detail", "item_id": "ev_vargas_receipt", "detail_id": "vr_stamp"}).state
	var r := Saves.deserialize(Saves.serialize(s), H.content())
	ok(r.ok)
	eq(JSON.stringify(r.state.evidence), JSON.stringify(s.evidence))
