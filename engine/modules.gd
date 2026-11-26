class_name Modules
## Модули рабочего стола и с какого акта они доступны (GDD, Блок 3 + риск №2):
## в первые 45 минут игрок видит только карту, шифроузел и доску мотивов.

const UNLOCK := {"map": 1, "mice": 1, "cipher": 1, "finance": 2, "dialog": 2, "counterintel": 3, "inbox": 1}
## Порядок на краю стола и горячие клавиши 1–7.
const ORDER := ["map", "mice", "cipher", "finance", "dialog", "counterintel", "inbox"]


static func unlock_act(view: String) -> int:
	return UNLOCK.get(view, 1)


static func hotkey(view: String) -> int:
	return ORDER.find(view) + 1


static func by_hotkey(key: int) -> String:
	return ORDER[key - 1] if key >= 1 and key <= ORDER.size() else ""
