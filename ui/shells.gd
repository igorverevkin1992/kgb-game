class_name Shells
## Общие декоративные элементы модулей (пробковая фактура доски и предмета на столе).

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
