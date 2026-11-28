extends TestCase
## Письма домой: ответ меняет «Отношения с семьёй», молчание после срока — штраф, кризис по
## порогу, итог в финале; старые сохранения без ответов не штрафуются.

const L := "cable_a1_w2_letter_home"


func _do(s: Dictionary, a: Dictionary) -> Dictionary:
	return Campaign.dispatch(s, H.content(), a)


func _week2() -> Dictionary:
	return H.play(self, H.fresh(), H.quiet_week()).state


func test_reply_changes_family() -> void:
	var s := _week2()
	eq(int(s.family), 60)
	ok(Family.waiting(s, H.content()).any(func(c): return c.cable_id == L), "письмо ждёт ответа")
	var r := _do(s, {"type": "reply_letter", "cable_id": L, "option_id": "honest"})
	eq(r.error, "")
	eq(int(r.state.family), 68)
	eq(r.state.centre_trust, s.centre_trust - 2, "слишком откровенно — почту читают")
	eq(_do(r.state, {"type": "reply_letter", "cable_id": L, "option_id": "warm"}).error, "Ответ уже отправлен")


func test_silence_after_due() -> void:
	var s: Dictionary = H.play(self, _week2(), H.quiet_week() + H.quiet_week() + H.quiet_week()).state
	eq(s.replies.get(L, ""), "none", "срок — воскресенье недели 4")
	ok(int(s.family) < 60)


func test_crisis_and_final_flags() -> void:
	var s := _week2()
	s.family = 26
	var r := _do(s, {"type": "reply_letter", "cable_id": L, "option_id": "short"})
	ok(not r.state.flags.has(Family.CRISIS_FLAG))
	s.replies = {}
	s.family = 24
	s.delivered_cables.append("cable_a1_w4_letter_home")
	r = _do(s, {"type": "reply_letter", "cable_id": "cable_a1_w4_letter_home", "option_id": "short"})
	ok(r.state.flags.has(Family.CRISIS_FLAG), "ниже порога — кризис")
	ok(Decisions.pending(r.state, H.content()).any(func(d): return d.decision_id == "dec_fam_crisis"), "«Письмо, которого боялся» в любой фазе")
	s.family = 75
	eq(Family.final_flag(s, H.content()), "family_close")
	s.family = 10
	eq(Family.final_flag(s, H.content()), "family_lost")
	var chk: Array = Endings.checklist(s, H.content()).filter(func(x): return x.id == "family")
	ok(not chk[0].ok, "без семьи триумф не «чистый»")


func test_old_save_letters_not_punished() -> void:
	var s := _week2()
	s.erase("replies")
	s.erase("family")
	var r := Saves.deserialize(Saves.serialize(s), H.content())
	ok(r.ok)
	eq(r.state.replies.get(L, ""), "old", "письма до обновления — без штрафа")
	eq(int(r.state.family), 60)
