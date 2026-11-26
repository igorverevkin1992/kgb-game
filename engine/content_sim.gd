class_name ContentSim
## «Идеальный игрок»: находит всё, что вообще можно найти, повторяя шаги, пока что-то меняется.
## Улики открывают цели, завербованные цели дают новые улики. Если цель акта недостижима
## даже для идеального игрока — это тупик (софтлок).
##   opts: max_act, failed_targets (Array), failed_ops (Array)
## Результат: {clues, unlocked, recruited, ops} — словари-множества.


static func run(content: Dictionary, opts := {}) -> Dictionary:
	var max_act: int = opts.get("max_act", 4)
	var failed_targets: Array = opts.get("failed_targets", [])
	var failed_ops: Array = opts.get("failed_ops", [])

	var cables := {}
	for c in content.cables:
		if c.act <= max_act:
			cables[c.cable_id] = true
	var targets: Array = content.targets.filter(func(t): return t.act <= max_act)
	var ops: Array = content.ops.filter(func(o): return o.act <= max_act and not failed_ops.has(o.op_id))

	# Беседа: оговорки слышны на встрече с установленной целью; без беседы цель не завербовать.
	var dialog_target := {}
	for d in content.get("dialogs", []):
		dialog_target[d.dialog_id] = d.target_id
	var st := {"clues": {}, "unlocked": {}, "recruited": {}, "ops": {}}
	var changed := true
	while changed:
		changed = false
		for op in ops:
			if not st.ops.has(op.op_id) and op.requires_targets_unlocked.all(func(t): return st.unlocked.has(t)):
				st.ops[op.op_id] = true
				changed = true
		for clue in content.clues:
			if st.clues.has(clue.clue_id):
				continue
			var src: Dictionary = clue.source
			var ok: bool = (src.channel == "document" and cables.has(src.from)) \
				or (src.channel == "field" and st.ops.has(src.from)) \
				or (src.channel == "agent" and st.recruited.has(src.from) and int(clue.get("act", 1)) <= max_act) \
				or (src.channel == "meeting" and st.unlocked.has(dialog_target.get(src.from, "")))
			if ok:
				st.clues[clue.clue_id] = true
				changed = true
		for t in targets:
			if st.unlocked.has(t.target_id):
				continue
			var found: int = t.unlock.clue_ids.filter(func(id): return st.clues.has(id)).size()
			if found >= int(t.unlock.clues_required):
				st.unlocked[t.target_id] = true
				changed = true
		for t in targets:
			var contact_op := ops.any(func(o): return o.get("contact_target_id", "") == t.target_id and st.ops.has(o.op_id))
			if st.recruited.has(t.target_id) or not st.unlocked.has(t.target_id) or failed_targets.has(t.target_id) \
					or not (dialog_target.values().has(t.target_id) or contact_op):
				continue
			var known := true
			for axis in t.approach.key_axes:
				if not reveals_known(content, st.clues, t.target_id, axis):
					known = false
			if known:
				st.recruited[t.target_id] = true
				changed = true
	return st


static func reveals_known(content: Dictionary, clue_set: Dictionary, target_id: String, axis: String) -> bool:
	for c in content.clues:
		if clue_set.has(c.clue_id):
			for r in c.reveals:
				if r.target_id == target_id and r.axis == axis:
					return true
	return false
