class_name ContentSchemas
## Схемы всех файлов контента (`content/`). Описание полей — в docs/content-guide.md.

static var _cache: Dictionary = {}


static func get_spec(name: String) -> Dictionary:
	if _cache.is_empty():
		_build()
	return _cache[name]


static func _build() -> void:
	var text := {"type": "text"}
	var act := Schema.i(1, 5)
	var week := Schema.i(1, 80)
	var scale := Schema.i(0, 100)
	var flag := Schema.s("^[a-z0-9_]+$", "флаг: латиница в нижнем регистре, цифры и «_»")
	var tag := Schema.s("^[a-z0-9_]+$", "примета: латиница в нижнем регистре, цифры и «_»")
	var axis := Schema.e(["money", "ideology", "compromise", "ego"])
	var delta := Schema.i(-100, 100)
	var chance := Schema.n(0, 1)

	var mice_entry := Schema.obj({
		"true_value": scale,
		"trigger": Schema.nullable(flag),
		"backfire_risk": Schema.opt(Schema.n(0, 1)),
	})
	_cache["target"] = Schema.obj({
		"target_id": Schema.id("tar"),
		"codename_kgb": Schema.opt(Schema.s()),
		"tier": Schema.i(1, 3),
		"act": act,
		"name": text,
		"role": text,
		"affiliation": Schema.s(),
		"access_tags": Schema.opt(Schema.arr(Schema.s()), []),
		"unlock": Schema.obj({"clues_required": Schema.i(1), "clue_ids": Schema.arr(Schema.id("clue"), 1)}),
		"mice_profile": Schema.obj({"money": mice_entry, "ideology": mice_entry, "compromise": mice_entry, "ego": mice_entry}),
		"approach": Schema.obj({
			"flag_mode": Schema.e(["false_flag", "true_flag", "contactless", "indirect"]),
			"cover": text,
			"key_axes": Schema.arr(axis, 1),
		}),
		# Что даёт агент после вербовки: sog_schedule — графики наружки ФБР на карте (и «слепое окно»
		# на выходах с sdr.blind_window), legend — легендированный перевод через третью страну.
		"perks": Schema.opt(Schema.arr(Schema.e(["sog_schedule", "legend"])), []),
		# Правильное заключение по досье (доска мотивов): ведущий мотив, доступ, подсказка-намёк.
		# Канал подхода сверяется с approach.flag_mode.
		"analysis": Schema.obj({
			"leading_axis": axis,
			"access_options": Schema.arr(Schema.obj({"id": Schema.s("^[a-z0-9_]+$", "id варианта: латиница, цифры и «_»"), "text": text}), 2),
			"correct_access": Schema.s(),
			"hint": text,
		}),
		# Финансы агента после вербовки: зарплата (для образа жизни) и обещанный первый транш.
		"finance": Schema.opt(Schema.obj({
			"salary_usd": Schema.i(1),
			"promised_usd": Schema.i(0),
			"promise": text,
			# Сколько агент сам тратит каждую неделю (образ жизни растёт без выплат).
			"spending_per_week": Schema.opt(Schema.i(0, 50), 0),
		})),
		"initial_state": Schema.obj({
			"rapport": scale,
			"paranoia": scale,
			"lifestyle_spending_index": Schema.opt(scale, 0),
			"cover_story_strength": Schema.opt(scale, 0),
			"polygraph_scheduled_week": Schema.opt(week),
		}),
	})

	_cache["clue"] = Schema.obj({
		"clue_id": Schema.id("clue"),
		"source": Schema.obj({"channel": Schema.e(["agent", "document", "field", "meeting"]), "from": Schema.s("^(tar|cable|op|dlg)_[a-z0-9_]+$", "источник: id цели (tar_), депеши (cable_), операции (op_) или беседы (dlg_)")}),
		"title": text,
		"text": text,
		"reveals": Schema.opt(Schema.arr(Schema.obj({"target_id": Schema.id("tar"), "axis": axis})), []),
		# Для донесений агентов: с какой фазы операции агент может это сообщить.
		"act": Schema.opt(Schema.i(1, 5), 1),
		# Для улик из документов и оговорок на встречах: фраза из текста, которую игрок «снимает» кликом.
		"chunk": Schema.opt(Schema.s()),
	})

	_cache["cable"] = Schema.obj({
		"cable_id": Schema.id("cable"),
		"act": act,
		"week": week,
		"kind": Schema.e(["directive", "vgu_note", "press_clipping", "agent_report", "intercept", "personnel_file", "letter", "anonymous"]),
		"sender": text,
		"subject": text,
		"body": text,
		# Подложная директива (шифроузел): контрольная группа не совпадёт с ключевым блокнотом.
		"forged": Schema.opt({"type": "bool"}, false),
		# Ориентировка о новом приёме наружки ФБР: приём появляется на маршрутах только после неё.
		"teaches": Schema.opt(Schema.e(["", "relay", "clothes", "aircraft"]), ""),
		# Документ сюжетной линии: приходит, только когда поставлены эти флаги (и не раньше недели).
		"requires_flags": Schema.opt(Schema.arr(flag), []),
	})

	# Вербовочная беседа (магнитофон «Тембр-2М»): реплики по тонам и козыри из досье.
	var fx := Schema.obj({"rapport": delta, "anxiety": delta, "reply": text})
	var tone_fx := Schema.obj({"line": text, "rapport": delta, "anxiety": delta, "reply": text})
	_cache["dialog"] = Schema.obj({
		"dialog_id": Schema.id("dlg"),
		# Кандидат или агент; у разговора (kind: conversation) — пусто, вместо него person.
		"target_id": Schema.opt(Schema.s(), ""),
		"person": Schema.opt(text),
		# Встреча назначается выходом на карте: беседа доступна после этого мероприятия.
		"requires_op": Schema.opt(Schema.s(), ""),
		# recruitment — вербовочная беседа (одна на кандидата); handling — встреча на связи с уже
		# завербованным агентом (вторая, третья… — по порядку order).
		"kind": Schema.opt(Schema.e(["recruitment", "handling", "conversation"]), "recruitment"),
		"order": Schema.opt(Schema.i(1, 9), 1),
		# Условия встречи на связи: не раньше фазы, флаги, вызов «крота» на полиграф.
		"requires": Schema.opt(Schema.obj({
			"act": Schema.opt(Schema.i(1, 5), 1),
			"flags": Schema.opt(Schema.arr(flag), []),
			"polygraph": Schema.opt({"type": "bool"}, false),
			"week": Schema.opt(Schema.i(0, 80), 0),
		}), {"act": 1, "flags": [], "polygraph": false, "week": 0}),
		# Разговор: контакт в начале (у встречи на связи — лояльность агента).
		"start_rapport": Schema.opt(scale, 40),
		# Настороженность агента в начале встречи на связи (контакт — его лояльность).
		"start_anxiety": Schema.opt(scale, 20),
		# Итог встречи на связи: договорились / сорвалось.
		"success": Schema.opt(Schema.obj({
			"text": text,
			"loyalty": Schema.opt(delta, 0), "lifestyle": Schema.opt(delta, 0),
			"sog_heat": Schema.opt(delta, 0), "mole_hunt": Schema.opt(delta, 0), "centre_trust": Schema.opt(delta, 0),
			"clue_ids": Schema.opt(Schema.arr(Schema.id("clue")), []),
			"flag_set": Schema.opt(Schema.s(), ""),
			"polygraph_slots": Schema.opt(Schema.i(0, 3), 0),
			"moscow_pressure": Schema.opt(delta, 0), "fund_usd": Schema.opt(Schema.i(-1000000, 1000000), 0),
			"loyalty_target": Schema.opt(Schema.s(), ""),
		})),
		"failure": Schema.opt(Schema.obj({"text": text, "loyalty": Schema.opt(delta, 0),
			"flag_set": Schema.opt(Schema.s(), ""), "sog_heat": Schema.opt(delta, 0), "mole_hunt": Schema.opt(delta, 0),
			"centre_trust": Schema.opt(delta, 0), "moscow_pressure": Schema.opt(delta, 0)})),
		"title": text,
		"setting": text,
		"offer_rapport": Schema.i(1, 100),
		"max_anxiety": Schema.opt(Schema.i(1, 100), 100),
		"offer": Schema.obj({"line": text, "reply": text}),
		"beats": Schema.arr(Schema.obj({
			"prompt": text,
			"tones": Schema.obj({"empathy": tone_fx, "pragmatic": tone_fx, "pressure": tone_fx, "ego": tone_fx}),
		}), 1),
		"trumps": Schema.opt(Schema.arr(Schema.obj({
			"clue_id": Schema.id("clue"),
			"line": text,
			"min_rapport": scale,
			"ready": fx,
			"early": fx,
		})), []),
	})

	# Дело из «Списка»: агент ЦРУ в Москве. Ущерб, привязка к перебежчику-«Ховарду», способ
	# обосновать арест «естественным провалом» и пригодность к оперативной игре.
	_cache["list_card"] = Schema.obj({
		"card_id": Schema.s("^card_[a-z0-9_]+$", "id дела: card_ и латиница, цифры, «_»"),
		"name": text,
		"role": text,
		"agency": Schema.e(["gru", "kgb", "research", "mfa", "defence", "other"]),
		"damage": Schema.e(["critical", "high", "medium"]),
		"howard": {"type": "bool"},
		# seventh — 7-е управление (наружное наблюдение), spy_dust — «шпионская пыль» (метка),
		# srac — ошибка с передатчиком; "" — естественный провал не обосновать.
		"natural": Schema.e(["", "seventh", "spy_dust", "srac"]),
		"game": {"type": "bool"},
		# Дезинформация ЦРУ — если пробный пакет принят подставой.
		"dangle": Schema.opt({"type": "bool"}, false),
		"text": text,
	})

	# «Архив эпохи: 1985» — справочник: техника, история, законы и эпилог «факт и вымысел».
	_cache["archive"] = Schema.obj({
		"id": Schema.s("^arc_[a-z0-9_]+$", "id записи архива: arc_ и латиница, цифры, «_»"),
		"section": Schema.e(["history", "technique", "law", "fiction", "epilogue"]),
		"status": Schema.e(["fact", "fiction", "mixed"]),
		"title": text,
		"text": text,
		# Событие движка, после которого запись открывается (пусто — открыта сразу),
		# или «ending:<концовка>» — открывается в этом финале (эпилог).
		"unlock": Schema.opt(Schema.s(), ""),
	})

	# Достижения Steam: какое событие движка (и с какими полями) их открывает.
	_cache["achievement"] = Schema.obj({
		"id": Schema.s("^ACH_[A-Z0-9_]+$", "id достижения: ACH_ и заглавная латиница, цифры, «_»"),
		"title": text,
		"description": text,
		"event": Schema.s(),
		"match": Schema.opt({"type": "dict", "of": {"type": "any"}}, {}),
	})

	# Подчинённые оперработники резидентуры: им можно поручить выход в город.
	_cache["operative"] = Schema.obj({
		"operative_id": Schema.s("^op_[a-z0-9_]+$", "id оперработника: op_ и латиница"),
		"name": text,
		"bio": text,
		"notice_chance": Schema.n(0, 1),
	})

	# Решение резидента: документ с вариантами, видимыми последствиями и условием появления.
	var fx_dec := Schema.obj({
		"sog_heat": Schema.opt(delta, 0), "mole_hunt": Schema.opt(delta, 0), "treasury": Schema.opt(delta, 0),
		"moscow_pressure": Schema.opt(delta, 0), "centre_trust": Schema.opt(delta, 0), "fund_usd": Schema.opt(Schema.i(-1000000, 1000000), 0),
		"flag_set": Schema.opt(Schema.s(), ""), "operative_out": Schema.opt(Schema.s(), ""),
		# Каждую ночь до конца кампании (оперативная игра с дезинформацией).
		"weekly_sog_heat": Schema.opt(delta, 0),
		# Лояльность агента (loyalty_target) после решения.
		"loyalty": Schema.opt(delta, 0), "loyalty_target": Schema.opt(Schema.s(), ""),
	})
	_cache["decision"] = Schema.obj({
		"decision_id": Schema.s("^dec_[a-z0-9_]+$", "id решения: dec_ и латиница"),
		"act": act,
		"trigger": Schema.obj({"week": Schema.opt(Schema.i(0, 80), 0), "clue_id": Schema.opt(Schema.s(), ""), "flag": Schema.opt(Schema.s(), "")}),
		"sender": text,
		"title": text,
		"text": text,
		"options": Schema.arr(Schema.obj({
			"option_id": Schema.s("^[a-z0-9_]+$"),
			"label": text,
			"outcome": text,
			"effects": fx_dec,
		}), 2),
	})

	# Запросы в Центр, которые резидент может приложить к ночной шифрограмме.
	_cache["request"] = Schema.obj({
		"request_id": Schema.id("req"),
		"act": act,
		"title": text,
		"phrase": text,
		"min_trust": scale,
		# Запрос на сверку пробного пакета по учётам Центра: доступен, пока пакет ждёт проверки.
		"package_check": Schema.opt({"type": "bool"}, false),
		"granted": Schema.obj({
			"fund_usd": Schema.opt(Schema.i(0, 1000000), 0),
			"centre_trust": Schema.opt(delta, 0),
			"moscow_pressure": Schema.opt(delta, 0),
			"extend_act_weeks": Schema.opt(Schema.i(0, 6), 0),
		}),
		"refused": Schema.obj({
			"centre_trust": Schema.opt(delta, 0),
			"moscow_pressure": Schema.opt(delta, 0),
		}),
	})

	_cache["op"] = Schema.obj({
		"op_id": Schema.id("op"),
		"act": act,
		"week": week,
		"type": Schema.e(["recon", "dead_drop_load", "dead_drop_clear", "signal_check", "personal_meeting"]),
		"title": text,
		"operative_id": Schema.opt(Schema.s("^op_[a-z0-9_]+$", "id оперработника"), "op_resident_player"),
		"requires_targets_unlocked": Schema.opt(Schema.arr(Schema.id("tar")), []),
		# Выход доступен, когда агенты завербованы, флаги поставлены и решения приняты.
		"requires_recruited": Schema.opt(Schema.arr(Schema.id("tar")), []),
		"requires_flags": Schema.opt(Schema.arr(flag), []),
		"requires_decisions": Schema.opt(Schema.arr(Schema.s()), []),
		# Ключевое мероприятие сюжета: после отмены его можно повторить, валидатор не ищет
		# обходной путь на случай его «срыва».
		"essential": Schema.opt({"type": "bool"}, false),
		# Флаг, который ставит чисто проведённый выход (для сюжетных линий).
		"success_flag": Schema.opt(Schema.s(), ""),
		"location": Schema.obj({
			"site_id": Schema.id("site"),
			"codename": Schema.opt(Schema.s()),
			"signal_site": Schema.opt(Schema.s()),
			"signal_type": Schema.opt(Schema.s()),
			"container_type": Schema.opt(Schema.s()),
		}),
		"sdr": Schema.obj({
			"surveillance_present": {"type": "bool"},
			"repeating_cue": Schema.nullable(Schema.s()),
			"abort_penalty_days": Schema.opt(Schema.i(0), 2),
			"ignore_consequence": Schema.opt(Schema.obj({"sog_heat_delta": Schema.i(0, 100), "flag_set": Schema.opt(flag)})),
			# Приём наружки: relay — эстафета машин (повторяется человек), clothes — смена одежды,
			# aircraft — наблюдение с самолёта.
			"technique": Schema.opt(Schema.e(["", "relay", "clothes", "aircraft"]), ""),
			# «Слепое окно»: агент с графиками наружки (perk sog_schedule) — хвоста нет.
			"blind_window": Schema.opt({"type": "bool"}, false),
		}),
		# Тайник: связь с бесконтактным агентом. Чистая закладка устанавливает контакт (вербовка).
		"contact_target_id": Schema.opt(Schema.s(), ""),
		"drop": Schema.opt(Schema.obj({"codename": Schema.s(), "signal": text, "container": text})),
		"payload": Schema.opt(Schema.obj({
			"cash_usd": Schema.opt(Schema.i(0), 0),
			"diamonds_usd": Schema.opt(Schema.i(0), 0),
			"escrow_moscow_usd": Schema.opt(Schema.i(0), 0),
			"ctr_4789_trigger_if_deposited_lump": Schema.opt({"type": "bool"}, false),
			"mlca_1986_structuring_risk": Schema.opt(Schema.n(0, 1), 0),
		})),
	})

	# Полиграф ЦРУ: подготовка «крота» и допрос по методу контрольных вопросов.
	var pfx := Schema.obj({
		"rapport": Schema.opt(Schema.i(), 0), "skepticism": Schema.opt(Schema.i(), 0),
		"control_peak": Schema.opt(Schema.i(), 0), "relevant_peak": Schema.opt(Schema.i(), 0),
	})
	_cache["polygraph"] = Schema.obj({
		"exam_id": Schema.id("exam"),
		"act": act,
		# Неделя экзамена; кого проверяют; чей агент заранее узнаёт дату и профиль экзаменатора.
		"week": week,
		"subject": Schema.id("tar"),
		"source_agent": Schema.id("tar"),
		"title": text,
		"notice": Schema.obj({
			"weeks_with_source": Schema.i(0, 4),
			"prep_slots_with_source": Schema.i(1, 6),
			"prep_slots_without": Schema.i(0, 6),
			"text_with_source": text,
			"text_without": text,
		}),
		"examiner_profile": Schema.obj({
			"name": text,
			"archetype": Schema.e(["chummy_veteran", "rigid_formalist"]),
			"description": text,
			"rapport_threshold_pass": scale,
			"skepticism_fail_limit": scale,
		}),
		"start": Schema.obj({"rapport": scale, "skepticism": scale}),
		# Финансовый вопрос без прикрытия: насколько выше пик (легенда или скромный образ жизни снимают).
		"finance_stress": Schema.i(0, 100),
		"prep_options": Schema.arr(Schema.obj({
			"prep_id": Schema.s("^prep_[a-z0-9_]+$", "id подготовки: prep_ и латиница"),
			"kind": Schema.e(["sleep", "sedatives", "strategy", "legend"]),
			"label": text,
			"text": text,
			# Для стратегии: под какого экзаменатора она подходит.
			"archetype": Schema.opt(Schema.e(["", "chummy_veteran", "rigid_formalist"]), ""),
			"stability": Schema.opt(Schema.i(-50, 50), 0),
			"rapport": Schema.opt(Schema.i(-50, 50), 0),
			"skepticism": Schema.opt(Schema.i(-50, 50), 0),
		}), 1),
		"question_sequence": Schema.arr(Schema.obj({
			"q_id": Schema.s("^q_[a-z0-9_]+$", "q_id должен начинаться с «q_»"),
			"category": Schema.e(["neutral", "control_comparison", "relevant_critical"]),
			"text": text,
			# Значимый вопрос: исходный пик реакции и касается ли он денег.
			"base_peak": Schema.opt(Schema.i(0, 100), 0),
			"finance": Schema.opt({"type": "bool"}, false),
			"choices": Schema.arr(Schema.obj({
				"choice_id": Schema.s("^[a-z0-9_]+$"),
				"label": text,
				"effects": pfx,
				"requires_prep": Schema.opt(Schema.s(), ""),
			}), 1),
			"pass_formula": Schema.opt(Schema.s()),
		}), 1),
		# Если на значимом вопросе проскочил пик — объяснение волнения.
		"rationalizations": Schema.arr(Schema.obj({
			"option_id": Schema.s("^[a-z0-9_]+$"),
			"label": text,
			"effects": pfx,
		}), 1),
		# Итоги проверки: последствия для охоты на «крота».
		"outcomes": Schema.obj({
			"pass": Schema.obj({"mole_hunt": delta, "text": text}),
			"inconclusive": Schema.obj({"mole_hunt": delta, "text": text}),
			"fail": Schema.obj({"mole_hunt": delta, "text": text}),
		}),
	})

	# Вещественное доказательство: стороны с деталями; верная деталь — сведения и/или флаг.
	_cache["evidence_item"] = Schema.obj({
		"item_id": Schema.s("^ev_[a-z0-9_]+$", "id вещдока вида ev_…"),
		"act": act,
		"week": Schema.i(1, 80),
		"requires_flags": Schema.opt(Schema.arr(flag), []),
		"kind": Schema.e(["card", "gift", "photo", "note", "ticket", "book"]),
		"title": text,
		"source": text,
		"sides": Schema.arr(Schema.obj({
			"title": text,
			"text": text,
			"details": Schema.arr(Schema.obj({
				"detail_id": Schema.s("^[a-z0-9_]+$"),
				"label": text,
				"correct": Schema.opt({"type": "bool"}, false),
				"note": text,
				"clue_id": Schema.opt(Schema.s(), ""),
				"flag_set": Schema.opt(Schema.s(), ""),
			}), 1),
		}), 1),
	})

	# Задание Центра: приходит в неделю week фазы act, срок — due_weeks; вопросы с вариантами.
	_cache["centre_task"] = Schema.obj({
		"task_id": Schema.s("^task_[a-z0-9_]+$", "id задания вида task_…"),
		"act": act,
		"week": Schema.i(1, 80),
		"due_weeks": Schema.i(1, 8),
		"title": text,
		"text": text,
		"requires_recruited": Schema.opt(Schema.s(), ""),
		"requires_flags": Schema.opt(Schema.arr(flag), []),
		# Документы, которые надо прочитать перед ответом (сведения для проверки — в них).
		"needs_cables": Schema.opt(Schema.arr(Schema.s()), []),
		"questions": Schema.arr(Schema.obj({
			"q_id": Schema.s("^[a-z0-9_]+$"),
			"prompt": text,
			# auto: "axis:<цель>" — мотив по досье, "stability:<цель>" — устойчивость агента.
			"auto": Schema.opt(Schema.s("^(axis|stability):tar_[a-z0-9_]+$", "axis:tar_… или stability:tar_…"), ""),
			"options": Schema.opt(Schema.arr(Schema.obj({
				"id": Schema.s("^[a-z0-9_]+$"),
				"label": text,
				"correct": Schema.opt({"type": "bool"}, false),
				"effects": Schema.opt(fx_dec, null),
			})), []),
		}), 1),
	})

	# Обучение: шаг наставника — текст, подсвеченный предмет (имя узла) и условие закрытия.
	_cache["tutorial_step"] = Schema.obj({
		"step_id": Schema.s("^tut_[a-z0-9_]+$", "id шага вида tut_…"),
		"text": text,
		"highlight": Schema.opt(Schema.s(), ""),
		"done": Schema.e(Tutorial.CONDITIONS),
	})
	# Памятка модуля: показывается при первом открытии и по кнопке «Памятка».
	_cache["help"] = Schema.obj({
		"view": Schema.e(["map", "mice", "cipher", "finance", "dialog", "counterintel", "inbox", "archive", "evidence"]),
		"title": text,
		"text": text,
	})

	_cache["campaign"] = Schema.obj({
		"acts": Schema.arr(Schema.obj({
			"act": act,
			"title": text,
			"weeks": Schema.obj({"from": week, "to": week}),
			"start_date": Schema.s("^\\d{4}-\\d{2}-\\d{2}$", "дата в формате ГГГГ-ММ-ДД"),
			"goal": Schema.obj({
				"recruit_any_of": Schema.arr(Schema.id("tar"), 1),
				# Задача выполнена, только когда завербованному агенту выплачено обещанное.
				"settle_promise": Schema.opt({"type": "bool"}, false),
				# …и добыты все эти сведения (например, «Список»).
				"clues_all": Schema.opt(Schema.arr(Schema.id("clue")), []),
				# …и поставлены флаги (например, «окно арестов закрыто»).
				"flags_all": Schema.opt(Schema.arr(flag), []),
			}),
			# Валютные средства, которые Центр переводит резидентуре в начале фазы.
			"fund_usd": Schema.opt(Schema.i(0, 1000000), 0),
			# Сколько дней в одном ходе-«неделе» (четвёртая фаза идёт по две недели за ход).
			"days_per_week": Schema.opt(Schema.i(1, 31), 7),
			# «Окно арестов» (четвёртая фаза): недели графика и квоты Центра (нарастающим итогом).
			"arrest_window": Schema.opt(Schema.obj({
				"from": week,
				"to": week,
				"quotas": Schema.arr(Schema.obj({
					"by_week": week,
					# Сколько арестов к этой неделе: всего или только критических дел.
					"arrests": Schema.i(1, 18),
					"damage": Schema.opt(Schema.e(["", "critical"]), ""),
					"text": text,
				})),
			})),
			# Пробный пакет «крота» и его проверка на подставу (третья фаза).
			"package": Schema.opt(Schema.obj({
				"agent": Schema.id("tar"),
				"title": text,
				"text": text,
				"drop_op": Schema.id("op"),
				"handover_op": Schema.id("op"),
				"archive_agent": Schema.id("tar"),
				"request_id": Schema.id("req"),
				# Ошибки подхода (флаги), при которых пакет из тайника окажется подставой ФБР.
				"mistake_flags": Schema.opt(Schema.arr(flag), []),
			})),
			# Варианты фазы по итогам прошлых: первый, у которого есть все флаги, заменяет
			# название, вводную и итог (например, «Рим» или «Эвакуация» после полиграфа).
			"variants": Schema.opt(Schema.arr(Schema.obj({
				"flags_all": Schema.arr(flag, 1),
				"title": Schema.opt(text), "intro": Schema.opt(text), "outro": Schema.opt(text),
			})), []),
			# Вводная и итог фазы — показываются при смене фаз операции.
			"intro": Schema.opt(text),
			"outro": Schema.opt(text),
		}), 1),
		# Демоверсия: после какой фазы операции она заканчивается (0 — демоверсии нет).
		# Сохранение демоверсии продолжается в полной игре со следующей фазы.
		"demo": Schema.opt(Schema.obj({"last_act": Schema.i(0, 4)}), {"last_act": 0}),
	})

	_cache["balance"] = Schema.obj({
		"start": Schema.obj({
			"fund_usd": Schema.i(0),
			"centre_trust": scale,
			"risks": Schema.obj({"sog_heat": scale, "mole_hunt": scale, "treasury": scale, "moscow_pressure": scale}),
			"seed": Schema.opt(Schema.i(0), 1985),
		}),
		"ops": Schema.obj({"per_week": Schema.i(1, 5)}),
		"sdr": Schema.obj({"embassy_site": Schema.s(), "zone_radius_miles": Schema.n(0.1), "min_districts_for_double_sighting": Schema.i(1, 3)}),
		"sog_heat": Schema.obj({
			"missed_tail_default": delta, "outside_25_mile_zone": delta, "site_reuse_per_use": delta,
			"quiet_week": delta, "failed_recruitment": delta,
		}),
		"moscow_pressure": Schema.obj({
			"grace_weeks": Schema.i(0), "recall_after_overdue_weeks": Schema.opt(Schema.i(1, 30), 8), "per_week_without_goal": delta, "per_week_overdue": delta, "act_goal_reached": delta,
			"report_truth_with_failures": delta, "report_embellished": delta, "lie_uncovered": delta,
		}),
		"centre_trust": Schema.obj({
			"report_truth": delta, "report_truth_with_failures": delta, "report_embellished": delta,
			"report_silence": delta, "lie_uncovered": delta,
		}),
		"lies": Schema.obj({"check_every_weeks": Schema.i(1), "uncover_chance_embellished": chance, "uncover_chance_silence": chance}),
		"treasury": Schema.obj({"audit_mole_hunt_multiplier": Schema.n(1, 5)}),
		"thresholds": Schema.obj({"warning": scale, "danger": scale}),
		"meeting": Schema.obj({"anxiety_cooldown": Schema.i(0, 100), "coercion_threshold": Schema.i(1, 20),
			# Личная встреча на связи заметна для наружки ФБР (при любом исходе).
			"handling_sog_heat": Schema.opt(Schema.i(0, 50), 2)}),
		"delegation": Schema.obj({"unlock_after_personal_ops": Schema.i(0, 20), "few_districts_penalty": Schema.n(0, 1)}),
		"finance": Schema.obj({
			"ctr_threshold_usd": Schema.i(1), "ctr_treasury": delta, "structuring_treasury": delta,
			"mlca_date": Schema.s("^\\d{4}-\\d{2}-\\d{2}$", "дата в формате ГГГГ-ММ-ДД"),
			"op_expense_usd": Schema.i(0), "max_parts": Schema.i(1, 5),
			"lifestyle_factor": Schema.n(0, 5), "lifestyle_decay": Schema.i(0, 100), "lifestyle_danger_treasury": delta,
			"loyalty_unpaid_week": Schema.i(0, 100), "loyalty_promise_cash": delta, "loyalty_promise_escrow": delta,
			"loyalty_per_1000_extra": Schema.n(0, 10), "escrow_min_loyalty": scale, "reports_min_loyalty": scale,
			"coerced_loyalty_penalty": Schema.i(0, 100), "loyalty_coerced_week": Schema.i(0, 100),
		}),
		# Задания Центра: Доверие за верный ответ, штрафы за ошибку и просрочку.
		"tasks": Schema.opt(Schema.obj({
			"done_trust": delta, "wrong_trust": delta, "wrong_pressure": delta,
			"overdue_trust": delta, "overdue_pressure": delta,
		}), {"done_trust": 3, "wrong_trust": 1, "wrong_pressure": 3, "overdue_trust": 3, "overdue_pressure": 5}),
		# Контроль объёма текста (шаг 16): потолок слов, целевой минимум и доля текста одной ветки.
		"text_budget": Schema.obj({
			"max_words": Schema.i(1000, 500000), "target_min_words": Schema.i(0, 500000), "branch_share_max": Schema.n(0, 1),
		}),
		# Пороги четырёх концовок кампании.
		"endings": Schema.obj({
			"triumph_realized": Schema.i(0, 18), "triumph_mole_hunt_below": scale, "control_below": scale,
			"double_bottom_trust_below": scale, "inspector_trust_below": Schema.opt(scale, 35),
		}),
		# «Окно арестов» и образ жизни «крота» (четвёртая фаза).
		"list": Schema.obj({
			"howard_mole_hunt": delta, "natural_mole_hunt": delta, "plain_mole_hunt": delta,
			"cascade_after": Schema.i(0, 18), "cascade_mole_hunt": delta,
			"game_mole_hunt": delta, "game_pressure": delta, "game_critical_pressure": delta,
			"natural_prep_weeks": Schema.i(1, 4),
			"quota_failed_pressure": delta, "quota_failed_trust": delta, "quota_met_trust": delta, "quota_met_pressure": delta,
			"contest_trust_cost": Schema.i(0, 100), "contest_min_trust": scale, "contest_panic_mole_hunt": scale, "contest_refused_pressure": delta,
			"anlace_mole_hunt": scale, "anlace_weekly_sog": delta, "fake_trust": delta,
			"lifestyle_mole_hunt": delta, "restrain_lifestyle": delta, "restrain_loyalty": delta,
		}),
		"cipher": Schema.obj({
			"accept_forged_sog_heat": delta, "accept_forged_flag": flag,
			"query_genuine_pressure": delta, "query_genuine_trust": delta, "query_forged_trust": delta,
		}),
	})

	_cache["map"] = Schema.obj({
		"districts": {"type": "dict", "of": text},
		"sites": Schema.arr(Schema.obj({
			"site_id": Schema.id("site"),
			"name": text,
			"kind": Schema.e(["embassy", "fbi", "cia", "bank", "bar", "park", "pharmacy", "post_office", "bookshop", "tobacconist", "cleaners", "grocery", "gas_station", "hardware", "antiques", "cafe", "restaurant", "car_dealer", "mission"]),
			"role": Schema.e(["stop", "target", "landmark"]),
			"district": Schema.s("^[a-z_]+$", "район: латиница в нижнем регистре и «_»"),
			"pos": Schema.obj({"x": Schema.n(0, 60), "y": Schema.n(0, 40)}),
			"cover_reason": Schema.opt(text),
			"ambient_tags": Schema.opt(Schema.arr(tag), []),
		}), 1),
	})

	# variants — разные описания одной приметы на разных точках (смена одежды).
	_cache["cues"] = Schema.arr(Schema.obj({"tag": tag, "kind": Schema.e(["tail", "noise", "ambient"]), "text": text,
		"variants": Schema.opt(Schema.arr({"type": "text"}), [])}))
