class_name ContentSim
## «Идеальный игрок»: находит всё, что вообще можно найти, повторяя шаги, пока что-то меняется.
## Улики открывают цели, завербованные цели дают новые улики, выходы ставят флаги, решения
## принимаются любым вариантом, пробный пакет можно и принять, и отклонить. Если цель акта
## недостижима даже для идеального игрока — это тупик (софтлок).
##   opts: max_act, failed_targets (Array), failed_ops (Array)
## Результат: {clues, unlocked, recruited, ops, flags, decisions} — словари-множества.


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
	var decisions: Array = content.get("decisions", []).filter(func(d): return d.act <= max_act)
	var package_ops := Dangle.package_ops(content)

	# Беседа: оговорки слышны на встрече с установленной целью; без беседы цель не завербовать.
	var dialog_target := {}
	var dialog_op := {}
	for d in content.get("dialogs", []):
		dialog_target[d.dialog_id] = d.target_id
		dialog_op[d.target_id] = d.get("requires_op", "")
	var st := {"clues": {}, "unlocked": {}, "recruited": {}, "ops": {}, "flags": {}, "decisions": {}}
	# «Окно арестов» закрывается само по графику.
	var aw := ArrestWindow.act_of(content)
	if aw > 0 and aw <= max_act:
		st.flags[ArrestWindow.WINDOW_CLOSED_FLAG] = true
	# Проверка на полиграфе завершается при любом исходе.
	var pe := Polygraph.exam_def(content)
	if not pe.is_empty() and int(pe.act) <= max_act:
		st.flags[Polygraph.DONE_FLAG] = true
	var changed := true
	while changed:
		changed = false
		for op in ops:
			if st.ops.has(op.op_id):
				continue
			if op.requires_targets_unlocked.all(func(t): return st.unlocked.has(t)) \
					and op.get("requires_recruited", []).all(func(t): return st.recruited.has(t)) \
					and op.get("requires_flags", []).all(func(f): return st.flags.has(f)) \
					and op.get("requires_decisions", []).all(func(d): return st.decisions.has(d)):
				st.ops[op.op_id] = true
				if package_ops.has(op.op_id):
					st.flags[Dangle.ACCEPTED_FLAG] = true
					st.flags[Dangle.REJECTED_FLAG] = true
				changed = true
		for d in decisions:
			if st.decisions.has(d.decision_id):
				continue
			var tr: Dictionary = d.trigger
			if (tr.clue_id == "" or st.clues.has(tr.clue_id)) and (tr.flag == "" or st.flags.has(tr.flag)):
				st.decisions[d.decision_id] = true
				for o in d.options:
					if o.effects.get("flag_set", "") != "":
						st.flags[o.effects.flag_set] = true
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
			var talk: bool = dialog_target.values().has(t.target_id) and (dialog_op.get(t.target_id, "") == "" or st.ops.has(dialog_op[t.target_id]))
			if st.recruited.has(t.target_id) or not st.unlocked.has(t.target_id) or failed_targets.has(t.target_id) \
					or not (talk or contact_op):
				continue
			var known := true
			for axis in t.approach.key_axes:
				if not reveals_known(content, st.clues, t.target_id, axis):
					known = false
			if known:
				st.recruited[t.target_id] = true
				changed = true
	return st


## Цель акта достигнута в прогоне: кто-то из списка завербован и все нужные сведения добыты.
static func goal_met(act: Dictionary, st: Dictionary, failed_targets := []) -> bool:
	if not act.goal.get("clues_all", []).all(func(c): return st.clues.has(c)):
		return false
	if not act.goal.get("flags_all", []).all(func(f): return st.flags.has(f)):
		return false
	return act.goal.recruit_any_of.any(func(id): return not failed_targets.has(id) and st.recruited.has(id))


static func reveals_known(content: Dictionary, clue_set: Dictionary, target_id: String, axis: String) -> bool:
	for c in content.clues:
		if clue_set.has(c.clue_id):
			for r in c.reveals:
				if r.target_id == target_id and r.axis == axis:
					return true
	return false
