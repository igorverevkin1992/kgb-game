# «Год шпионов» — заметки для Claude

Диегетический UI-симулятор офицера ПГУ КГБ в Вашингтоне 1984–1986: герой — заместитель резидента
по линии КР (полковник; над ним — резидент, генерал-майор Арефьев, наставник первых недель). Однопользовательская
кампания на 7–10 часов, 5 фаз (четыре по концепту и пятая — «Рим», с развилкой по итогам). Платформа: **только Windows x64** (Steam + VK Play),
macOS и Linux не делаем. Движок: **Godot 4.7 (GDScript, рендерер Compatibility)** — по
рекомендации концепта и исследования жанра.

## Документы
- `docs/plan.md`: утверждённый пошаговый план (шаги 0–19). Пользователь говорит
  «делаем шаг N», и ты сверяешься с этим файлом.
- `docs/concept/concept-bible.txt`: полный текст концепта. По нему проверяй механику, числа, имена, тон.
- `docs/best-practices.md`: что берём из исследования UI-детективов (правила дизайна по шагам).
- `docs/content-guide.md`: памятка пользователю по правке контента.
- `docs/game-bible.md`: библия игры — эпоха, персонажи, места, хронология, линии, механики,
  концовки. Разделы 1–13 правь вручную при каждом изменении сюжета (новая линия, персонаж,
  концовка, правило); приложение «Указатели» собирает `python3 tools/bible.py` — запускай после
  любой правки `content/`.

## Godot в облачном контейнере
Сайт Godot из контейнера недоступен. Workflow «Godot tools» кладёт официальную сборку
(`tools/godot-version.txt`) в релиз репозитория, `tools/get-godot.sh` скачивает её в `.godot-bin/`
через REST API (`gh release download` не работает — GraphQL закрыт). После добавления скриптов
с новым `class_name` нужен импорт: `"$(tools/get-godot.sh)" --headless --path . --import`.
Любой запуск Godot — только с `timeout`: скрипт с ошибкой компиляции может повиснуть.

```
tools/validate.sh            # проверка контента (--dir=путь, --en — напомнить о переводе, --words — объём текста)
tools/test.sh [фильтр]       # unit-тесты движка (tests/test_*.gd), headless
tools/ui-test.sh [фильтр]    # сценарии интерфейса под Xvfb + OpenGL, скриншоты в build/screens/
tools/export.sh windows|web|all   # build/windows/GodShpionov.exe (+ Steam), build/web/
tools/telemetry-report.sh [папка] # сводка журналов плейтеста (session-*.jsonl)
tools/balance.sh             # балансный прогон: автоигрок проходит кампанию тремя стратегиями
tools/store-shots.sh         # скриншоты для магазинов 1920×1080 → build/store/screenshots/
tools/store-art.sh [имя]     # заглушки капсул Steam и обложек VK Play → build/store/art/
tools/trailer.sh             # черновой трейлер (Movie Maker + ffmpeg) → build/store/trailer.mp4
```
Шаг готов, когда зелёные все три проверки и снят скриншот нового экрана. `test.sh` и `ui-test.sh`
сначала запускают `tools/check_scripts.tscn` — проверку, что все скрипты компилируются. Прогон, в выводе
которого есть `SCRIPT ERROR`, считается проваленным (скрипты это проверяют).

## Архитектура
- `content/`: игровые данные JSON (пользователь правит сам). `campaign.json`, `balance.json`,
  `map/sites.json`, `map/cues.json`, `targets/`, `clues/`, `cables/`, `ops/`, `polygraph/`, `requests/`, `dialogs/`.
- `engine/` — чистый GDScript без узлов и экрана, всё — `static func` над словарями:
  - `schema.gd` + `content_schemas.gd` — проверка схем (замена Zod): русские сообщения,
    значения по умолчанию, предупреждение о неизвестных полях (опечатки);
  - `content_loader.gd` — чтение `content/`, разбор, повторы id, `game_content()` (кэш);
  - `content_rules.gd` — ссылки, «Правило трёх улик», тупики, честность проверочного
    маршрута, недели, длина текстов, полиграф; `content_sim.gd` — «идеальный игрок»;
  - `campaign.gd` — `dispatch(state, content, action)` → `{state, events, error}`; исходное
    состояние не мутирует, error по-русски. Неделя: утро → день (`plan_op` с маршрутом) →
    вечер (`resolve_op`, `recruitment`) → ночь (`submit_report`). Наблюдения на маршруте —
    `_build_observations` при планировании, хранятся в `state.routes`. Доска мотивов (шаг 5):
    улики из документов игрок снимает сам (`take_clue`, поле `chunk`), прикалывает к досье
    (`pin_clue` с осью или "" — общее поле), утверждает заключение (`submit_analysis`: мотив,
    доступ, канал — проверка тройкой) и берёт подсказки (`use_hint`). Вербовка `success` требует
    утверждённого заключения. Знание о мотиве на доске — по приколотым уликам (`axis_knowledge`).
    Шифроузел (шаг 6): `verify_cable` (accept/query, `state.verified`), `submit_report` принимает
    `choices` по фактам недели и `request` — запрос в Центр (`state.requests`). Беседа (шаг 7):
    `start_meeting`, `meeting_turn {tone, clue_id}`, `meeting_offer`, `meeting_abort`;
    `state.meeting` — идущая встреча, `state.tapes` — катушки; `recruitment` — прямой исход для тестов;
  - `finance.gd` — транши: `plan()` (части по неделям, форма 4789, дробление после закона 1986,
    образ жизни, лояльность — те же числа, что применит движок), обещание агенту, `mlca_in_force`.
    В движке: `pay_agent`, `state.agents`, `state.payments` (части в пути доходят утром),
    оперативные расходы на выезд, задача акта с `settle_promise`;
  - `meeting.gd` — беседа: условия встречи, ход «тон + козырь» (ready/early), строки стенограммы
    как ссылки на контент, оговорки (`heard`), `winnable` — поиск для валидатора;
  - `cipher.gd` — ключевой блокнот (ключ и контрольная группа недели), подложные директивы
    (`forged`), факты недели из журнала, `classify` → truth/embellished/silence, `report_effects`
    (те же числа, что применит движок — для предпросмотра), запросы и срок акта с продлением;
  - `saves.gd` — формат v7 (… meeting, tapes, agents, payments; v4–v6 переносятся), проверка при загрузке, автосейв, чекпоинты месяц/акт (до 12),
    3 слота, «Железный занавес» (флаг `mode_ironman`); `FileStorage` (user://saves), `MemoryStorage`;
  - `map_geo.gd` — мили, 25-мильная зона, разбор маршрута; `rng.gd` — mulberry32; `util.gd` —
    JSON (числа из JSON приходят float — `normalize_numbers` делает целые int); `modules.gd`.
- `ui/` — интерфейс. Сцена 1600×900 (`project.godot`: stretch canvas_items + keep), координаты в
  пикселях сцены: стена 0–300, стол 300–900.
  - `game.gd` — автозагрузка `Game`: контент, состояние, настройки, состояние интерфейса
    (`view`, `analyst_open`, `service_open`, `map_draft`, `sdr_run`, `inbox_selected`); любое
    изменение → сигнал `changed`, `main.gd` перестраивает экран целиком (это миллисекунды).
  - Имена узлов = прежние testid: `desk-object-<view>`, `module-panel-<view>`, `edge-<view>`,
    `calendar-week`, `report-truth`, `site-<id>`, `stop-<id>` и т. д. Тесты ищут по ним.
  - `desk_view.gd` (кабинет), `calendar.gd`, `module_view.gd` (рамка + край стола, клавиши 1–7,
    Esc), `inbox_view.gd` + `document_view.gd` (бланк / вырезка / перехват), `shells.gd`
    (оболочки модулей), `board_view.gd` (доска мотивов: стопка улик, ячейки Д/И/К/С как
    DropZone с drag&drop и кликом, заключение тройкой, подсказки), `map_canvas.gd` + `map_module.gd` (карта, «Сбор» →
    «Вердикт»), `overlays.gd` (сводка аналитика, служебная папка, итог), `cipher_view.gd` (шифроузел:
    блокнот, роторы, лента, сверка, шифрограмма с плашкой последствий), `dialog_view.gd`
    («Тембр-2М»: встреча с индикаторами и козырями, катушки с таймкодами и оговорками),
    `finance_view.gd` (журнал: спецфонд, папка правил, шкалы агентов, калькулятор транша).
  - `steam_bridge.gd` — Steam через GodotSteam (`Game.steam`): Windows-сборка — на шаблоне Godot
    со встроенным Steam (`tools/get-godotsteam.sh`, зеркало в релизе репозитория, workflow «Godot
    tools»); без Steam — тихая заглушка. Достижения — `content/achievements/`, `engine/achievements.gd`;
  - `telemetry.gd` — журнал плейтеста (`Game.telemetry`, user://telemetry/session-*.jsonl, только
    локально; F8 — «застрял здесь»), сводка — `engine/telemetry_summary.gd`;
  - `sound_bank.gd` — звук стола (`Game.sound`, `Game.sfx(имя)`): шины SFX и Ambient, процедурные
    заглушки, замена файлом `assets/sfx/<имя>.ogg`; `crt.gdshader` — ЭЛТ-эффект (настройка `crt`).
    Перечень ассетов — `docs/assets.md`;
  - `style.gd` — палитра, шрифты PT (кириллица + латинский запасной файл), фабрики элементов;
    `Style.fs()` применяет масштаб текста 100–130 %. `i18n.gd` (`T.t`, `T.loc`), `fmt.gd` (суммы,
    даты), `signals.gd` (диегетические сигналы рисков).
- Арт-плейсхолдеры — `assets/art/*.svg` (текст и узоры внутри SVG Godot не рисует).
- `tests/` — unit-тесты (`TestCase`, помощники `H`: `play()` сам снимает улики-фрагменты,
  `approve()` прикалывает улики и утверждает заключение); `tests/ui/` — сценарии (`UiTest`:
  `start(actions)` собирает состояние движком, `press`, `click`, `key`, `has_text`, `shot`).
  `Game.reset_for_test` включает «Мгновенный вывод текста» (лента шифроузла без анимации). После действия экран перестроен — узлы, найденные до него, уже удалены: ищи заново по имени.
- Сборки: `export_presets.cfg` — Windows (`.exe` со встроенным pck), Windows Demo (признак `demo`,
  `Game.demo_build`) и Web (без потоков, для Pages). Демоверсия: флаг `mode_demo` (`Campaign.DEMO_FLAG`)
  при новой игре, после фазы `campaign.demo.last_act` — итог `demo_complete`; в полной игре
  `Campaign.continue_full` продолжает сохранение. App ID полной игры — `steam/full_app_id` в
  `project.godot`. Материалы для магазинов и Next Fest — `docs/store/`, workflow «Store».
  Каталог данных — `user://` = `%APPDATA%\GodShpionov` (`custom_user_dir_name`). Сборка для
  тестеров — тег `playtest-N` (workflow «Playtest», архив в Releases); памятки `docs/playtest.md`, `docs/steam.md`.

## Язык: сейчас только русская версия
Весь видимый текст — по-русски, без латиницы (тест `tests/test_russian.gd`; разрешены `{x}` и
римские цифры). Все символы должны быть в шрифтах PT (тест `tests/test_fonts.gd`): стрелок → ←
там нет — используем « » и тире. Английская версия позже (`i18n/en.json` заморожен).
Исключения (подставляются из кода, не из `ru.json`): клавиши `[Esc]`, `[F8]` и название платформы Steam.

Глоссарий (внутренние id в коде прежние: `mice`, `sdr`, `sog_heat`, `act`, `clue`, `target`):
- Тексты — в стиле документов ПГУ КГБ 80-х: «указание Центра», «шифртелеграмма», «справка»,
  «ориентировка», «рапорт», «сводка перехвата», «мероприятие», «выход в город», «кандидат на
  вербовку», «дело», «сведения», «разведывательные возможности», «основа вербовки»,
  «вербовочное предложение», «доклад с приписками», «срыв», «валютные средства», «выплата»,
  «депонирование на счёт в Москве». Модуль шифросвязи — «Шифрпункт «Фиалка»».
- Акт → «фаза операции»: «Первая фаза операции» (`Fmt.op_phase`, `op_phase_gen`, `op_phase_in`).
  Время суток недели (утро, день, вечер, ночь) словом «фаза» в интерфейсе не называем.
- Беседа: «Контакт» (раппорт) и «Настороженность» (тревога); тоны — «Участие», «Деловой тон»,
  «Нажим», «Игра на самолюбии».
- MICE → «доска мотивов»; мотивы Д / И / К / С — Деньги, Идеология, Компромат, Самолюбие.
- SDR → «проверочный маршрут»; SOG → «наружка ФБР».
- CTR, форма 4789 → «отчёт о валютной операции (форма 4789)»; BSA → «Закон о банковской тайне
  (1970)»; MLCA → «Закон о борьбе с отмыванием денег (1986)».
- SE Division → «отдел СССР и Восточной Европы ЦРУ»; ANLACE → «опергруппа ФБР „Анлейс“».
- Persona non grata → «персона нон грата». Суммы — словами: «10 000 долларов» (`Fmt.usd`).
- Бренды — транслитом в кавычках: «Ферст Вирджиния бэнк», «Потомак селлар», «Вашингтон пост».

## Правила дизайна (из исследования жанра, `docs/best-practices.md`)
- Никаких скрытых таймеров и скрытых чисел: пороги и последствия видны игроку.
- Сохранения не наказывают: автосейв с индикатором, чекпоинты, ручные слоты; Ironman — опция.
- Правило трёх улик + подсказки «намёк → документ → ответ»; без свободного ввода текста.
- Документ — 1–2 экрана, ключевые факты подсвечены; интерактивное явно выделено.
- Читаемость важнее стилизации: масштаб текста, ЭЛТ отключаемый, мгновенный вывод текста.
- Новые правила по одному и в тихие недели; ритуалы короткие; реальная «Прервать контакт».
- Релизный арт — авторский, без генеративного ИИ.
- Контент 16+ (436-ФЗ, 15-ФЗ, требование грантов): без табака, сцен употребления алкоголя, мата и
  натурализма; валидатор (правило `age16`) проверяет тексты. Грантовая стратегия и матрица
  «критерий → механика → формулировка» — `docs/grants.md`.
- Принуждение (нажим, компромат на встрече) даёт неустойчивого агента (`coerced`); «Письма из
  дома» — документы `kind: letter`; «Архив 1985» — `content/archive/`, `engine/archive.gd`,
  `ui/archive_view.gd`, клавиша 8, эпилог «Факт и вымысел» открывается после первой фазы.
  Документальный эпилог в финале (`ui/epilogue_view.gd`, `Game.epilogue_page`) — листы раздела
  `epilogue` с `unlock: "ending:campaign_complete"`: хроника дела Эймса (реальные люди — только здесь).

- Вторая фаза (шаг 11): `engine/delegation.gd` (поручения подчинённым, `plan_op.operative`),
  `engine/decisions.gd` (решения резидента, действие `decide`), тайник `op.contact_target_id`,
  приёмы наружки `sdr.technique` + депеши `teaches`, перк `sog_schedule`; UI — `decision_view.gd`,
  карточка смены фаз `Overlays.phase_card` (`Game.phase_card`), гул «Монополии» `SoundBank.set_tunnel`.
- Третья фаза (шаг 12): `engine/dangle.gd` — пробный пакет и проверка на подставу (`state.package`,
  действия `check_package`, `accept_package`, `reject_package`, запрос с `package_check`, блок
  `package` акта в `campaign.json`); «слепое окно» `sdr.blind_window` + perk `sog_schedule`;
  условия выходов `requires_recruited/flags/decisions`, `essential`; беседа с `requires_op`;
  задача акта `goal.clues_all`, перевод Центра `fund_usd`, `days_per_week`; инструмент `legend`
  (perk `legend`, Мендоса). UI — `package_view.gd` (лоток почты, элемент `pkg`).
- Четвёртая фаза (шаг 13): `engine/arrest_window.gd` — «Окно арестов» (`state.list`, дела в
  `content/list/`, блок `arrest_window` акта, баланс `balance.list`; действия `list_action`,
  `contest_quota`, `restrain_agent`; ночь — `Campaign._list_night`); траты агента
  `finance.spending_per_week`; задача акта `goal.flags_all`. UI — `counterintel_view.gd`
  (пульт обстановки, клавиша 6; `Game.card_selected`, `Game.console_tab`).
- Полиграф (шаг 14): `engine/polygraph.gd` (`state.polygraph`, действия `polygraph_prep`,
  `polygraph_start {rehearsal}`, `polygraph_answer`, `polygraph_rationalize`; вызов утром —
  `Campaign._polygraph_notice`; формулы через `Expression`; `Polygraph.winnable` — для
  валидатора). Экзамен — `content/polygraph/`. UI — `polygraph_view.gd` (вкладка пульта).
- Концовки (шаг 15): `engine/endings.gd` — `final()` после четвёртой фазы (clean_triumph,
  pyrrhic_victory, shadow_exchange, double_bottom; пороги `balance.endings`), `checklist()` для
  итогового экрана; `ending:campaign_complete` в архиве — любая из четырёх. Эпилог концовки —
  листы `arc_end_<концовка>`. Балансный прогон — `engine/autoplay.gd` (стратегии careful, rush,
  hasty), `tools/balance.sh`, тест `tests/test_balance.gd`.
- Объём (шаг 16): `engine/word_count.gd` (слова по разделам контента и `ru.json`, текст веток
  решений); правила `_volume` (потолок `balance.text_budget`) и `_diamonds` (ветки сходятся:
  `ContentSim` с `choices`).
- Встречи на связи: беседы `kind: "handling"` (`order`, `requires`, `start_anxiety`, `success`,
  `failure`) — с уже завербованным агентом; `start_meeting {dialog_id}`, `Meeting.next_handling`,
  `handling_error`; итог `agreed`/`broken_off` в `state.handled`, `Campaign._finish_handling`;
  наружка за личную встречу — `balance.meeting.handling_sog_heat`. UI — блок у агента на магнитофоне.
- Сюжетные линии: документы по условию `cable.requires_flags` (приходят утром после флага);
  разговоры не с кандидатами `kind: "conversation"` (`person`, `requires {act, week, flags}`,
  `start_rapport`, итоги с `flag_set`, рисками, Доверием), список — на магнитофоне;
  `Meeting.conversations`, `person_name`. Варианты фазы `variants [{flags_all, title, intro,
  outro}]` — `Campaign.act_text`. Пятая фаза «Рим»: варианты по `polygraph_passed` /
  `polygraph_inconclusive` / `polygraph_failed` / `kronos_absent`; встречи на связи с одним
  `order` и разными флагами — варианты; `Endings.notes` — строки итога пятой фазы. Флаг
  `contact_<target_id>` — связь с бесконтактным агентом установлена, `recruited_<target_id>` — кандидат
  завербован (линии агентов), `op.success_flag` — флаг чистого выхода. Условие открытия листа
  архива — части через «+» (`ending:…`, `flag:…`, событие): хроники судеб `arc_fate_*`.

- Отзыв плейтеста №1: время недели — дни (`Campaign.PHASE_RU`: понедельник, среда, пятница,
  воскресенье; `PHASE_DAY`, `phase_date`); `main.gd` сохраняет прокрутку списков между перестройками
  (`scroll_key` в meta — свой ключ, "" — не трогать). Обучение — `engine/tutorial.gd` (условия
  шагов), `content/tutorial/`, `content/help/`, `ui/tutorial_view.gd`; прогресс — в настройках
  (`tutorial`, `tutorial_ack`, `help_seen`), в тестах обучение выключено (`reset_for_test`).
  Задания Центра — `engine/centre_tasks.gd`, `content/tasks/`, `state.tasks`, действие
  `answer_task`, срок — `_tasks_night` (входит в предпросмотр доклада `Cipher.report_effects`:
  `report_trust` — только доклад), `ui/task_view.gd`, ящик «Задания»; `H.fresh()` снимает задания
  с контроля, `H.with_tasks()` — с заданиями. Вещдоки — `engine/evidence.gd`, `content/evidence/`,
  `state.evidence`, действие `inspect_detail`, `ui/evidence_view.gd` (сейф на стене, клавиша 9).
  Новые поля состояния — `Schema.opt` с умолчанием в `saves.gd`: старые сохранения грузятся без переноса.
  Главное меню — `ui/main_menu.gd` (`Game.menu_open`, `menu_page`: new/load/settings/about;
  `menu_continue`, `menu_new_game`, `menu_load`, `open_menu`); игра стартует с меню (`--new` — сразу
  новая игра, `--desk` — без меню), новая кампания пишется на диск только по «Новая игра».
- Письма домой: блок `reply` у документа-письма (варианты с `family` и `centre_trust`), действие
  `reply_letter`, `state.family` (0–100) и `state.replies` (вариант, `none` — промолчал, `old` —
  письмо до обновления); `engine/family.gd`, баланс `balance.family`; молчание после срока —
  `_family_night`, кризис ниже порога — флаг `family_crisis` и решение `dec_fam_crisis`
  (`any_act`), в финале — флаг `family_close` / `family_kept` / `family_lost` (листы
  `arc_fate_home*`, строки итога, условие «Чистого триумфа»). Поле `family` есть и у эффектов
  решений и разговоров. UI — блок ответа под письмом (`DocumentView.reply_block`).

## Договорённости
- Пользователь немного программировал. Объясняй ключевые решения коротко и по-русски.
  Код пишешь ты, а тексты, баланс и решения по дизайну — за пользователем.
- Каждый шаг ведёт в свою ветку `step-N-<name>`. Когда все проверки и CI зелёные, ветку сразу
  сливать в `main` (fast-forward) без вопроса пользователю — он так попросил.
- Историческая точность: линию КР в резидентуре вёл заместитель резидента — так и называем героя
  («заместитель резидента», обращение «товарищ полковник»); директивы Центра — «Вашингтон.
  Резиденту, для линии КР»; советские сотрудники живут в жилом корпусе комплекса на Маунт-Алто.
- Персонажи пирамиды вымышлены (Варгас, Кэллоуэй, Хэйлс, Дженкинс, Мендоса, Колдуэлл
  «Кронос»). Реальные люди — только в историческом контексте и хронике. Тон — документальный
  нуар в духе ле Карре, без пропаганды.
- GDScript: тип переменной, взятой из словаря через точку, не выводится — пиши `var x: Dictionary = …`.
