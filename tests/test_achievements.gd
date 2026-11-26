extends TestCase
## Достижения Steam: какие события их открывают; валидатор ловит неизвестное событие.


func test_unlocked_by_events() -> void:
	var c := H.content()
	eq(Achievements.unlocked_by(c, [{"type": "op_resolved", "outcome": "clean"}]), [])
	eq(Achievements.unlocked_by(c, [{"type": "op_resolved", "outcome": "aborted"}]), ["ACH_ONCE_IS_CHANCE"])
	eq(Achievements.unlocked_by(c, [{"type": "act_completed", "act": 1}, {"type": "promise_kept", "target_id": "x"}]), ["ACH_PROMISE", "ACH_PHASE_ONE"])
	# Полный путь движком: первая установленная цель даёт достижение.
	var r := H.play(self, H.fresh(), H.quiet_week() + H.quiet_week() + [H.NEXT, H.plan("op_a1_recon_potomac_cellar"), H.NEXT, H.resolve("op_a1_recon_potomac_cellar")])
	ok(Achievements.unlocked_by(c, r.events).has("ACH_FIRST_CANDIDATE"))


func test_validator_unknown_event() -> void:
	var e := H.entries()
	var a: Array = H.file(e, "achievements/steam.json")
	a[0].event = "nonexistent_event"
	has_issue(H.errors(e), "achievements", "Неизвестное событие")
