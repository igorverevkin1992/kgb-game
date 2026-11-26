extends TestCase
## Процедурные звуки-заглушки: каждый синтезируется, не пустой, фон комнаты — петля.


func test_synth_all() -> void:
	for name in SoundBank.NAMES + ["room"]:
		var w := SoundBank.synth(name)
		ok(w is AudioStreamWAV, name)
		ok(w.data.size() > 1000, "%s: есть данные" % name)
	eq(SoundBank.synth("room").loop_mode, AudioStreamWAV.LOOP_FORWARD, "фон зациклен")
	eq(SoundBank.synth("click").loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_synth_is_deterministic() -> void:
	eq(SoundBank.synth("rotor").data, SoundBank.synth("rotor").data, "одинаково от запуска к запуску")
