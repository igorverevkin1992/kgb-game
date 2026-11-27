extends UiTest
## Оформление и звук: ЭЛТ-эффект поверх стола (отключается), громкость шин, фразы о фазах операции.


func scene_crt_and_sound_settings() -> void:
	await start()
	ok(exists("crt"), "ЭЛТ-эффект включён по умолчанию")
	has_text("act", "Первая фаза операции")
	has_text("desk-object-counterintel", "Откроется в третьей фазе операции")
	has_text("advance-phase", "Далее — среда")
	await shot("desk-crt")
	await key(KEY_ESCAPE)
	await press("service-tab-settings")
	await press("crt-toggle")
	ok(not exists("crt"), "эффект выключен")
	await press("vol-sfx-25")
	ok(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) - linear_to_db(0.25)) < 0.01, "громкость звуков")
	await press("vol-ambient-0")
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambient")), "фон выключен")
	var saved: Dictionary = Util.parse_json(Game.storage.read(Game.SETTINGS_SLOT)).data
	eq([saved.crt, saved.vol_sfx, saved.vol_ambient], [false, 25, 0], "настройки сохранены")
	await shot("service-settings-sound")
	await press("crt-toggle")
	await press("service-tab-saves")
	await key(KEY_ESCAPE)
