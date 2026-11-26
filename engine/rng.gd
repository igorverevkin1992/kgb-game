class_name Rng
## Детерминированный генератор случайных чисел (mulberry32). Его состояние хранится в сохранении,
## поэтому после загрузки игра ведёт себя так же, как без перезапуска, а тесты воспроизводимы.

const MASK := 0xFFFFFFFF


static func _imul(a: int, b: int) -> int:
	# 64-битное умножение может переполниться, но младшие 32 бита остаются верными.
	return (a * b) & MASK


## Возвращает [значение 0..1, следующее зерно].
static func next(seed: int) -> Array:
	var nxt := (seed + 0x6D2B79F5) & MASK
	var t := nxt
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & MASK)) & MASK
	var value := float((t ^ (t >> 14)) & MASK) / 4294967296.0
	return [value, nxt]
