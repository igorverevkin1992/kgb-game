extends UiTest
## Четвёртая фаза «Список»: пульт обстановки — картотека, меры по делам с последствиями,
## предупреждение о каскаде, квоты Центра; «притормозить» траты «Кроноса».

const CAL := "tar_caldwell_arthur"


func _act(card: String, action: String) -> Dictionary:
	return {"type": "list_action", "card_id": card, "action": action}


func scene_console() -> void:
	Game.reset_for_test(H.run(H.act4_state(), [_act("card_colonel", "arrest"), _act("card_pvo", "arrest"), _act("card_sfera", "arrest")]))
	await frames(3)
	await key(KEY_6)
	ok(exists("list-grid"), "картотека")
	has_text("list-tonight", "без «Ховарда»: 2")
	has_text("list-quota", "к неделе 32")
	await press("card-card_major")
	has_text("card-detail", "Перебежчик о нём не знал")
	has_text("card-action-arrest", "каскад")
	has_text("card-action-natural", "+2")
	await shot("counterintel-list")
	await press("card-action-natural")
	has_text("card-status", "ГОТОВИТСЯ ПРОВАЛ")
	ok(exists("list-contest"), "квоту можно оспорить")


func scene_dangle_warning() -> void:
	Game.reset_for_test(H.act4_state([CAL], ["dangle_accepted"]))
	await frames(3)
	await key(KEY_6)
	has_text("list-dangle-warning", "дезинформацией")


func scene_restrain() -> void:
	var s := H.act4_state()
	s.agents[CAL].lifestyle = 80
	Game.reset_for_test(s)
	await frames(3)
	await key(KEY_4)
	ok(exists("restrain-" + CAL), "кнопка «притормозить»")
	await shot("finance-restrain")
	await press("restrain-" + CAL)
	eq(Game.state.agents[CAL].lifestyle, 60)
	ok(not exists("restrain-" + CAL), "раз в неделю")
