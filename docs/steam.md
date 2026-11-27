# Steam: что настроить в Steamworks

Игра уже собирается со Steam (GodotSteam, шаблон Godot со встроенным Steam). Пока своей страницы
нет, используется тестовое приложение Valve «Spacewar» (App ID 480, файл `steam_appid.txt`
рядом с .exe). Когда появится своё приложение:

1. **App ID.** В `tools/export.sh` заменить `480` на свой App ID (файл `steam_appid.txt` нужен только
   для запуска не из Steam; в сборку для Steam его не кладут).
2. **Достижения** — Steamworks → Stats & Achievements. API Name каждого — как `id` в
   `content/achievements/steam.json`; название и описание — оттуда же. Иконки (64×64, цветная и
   серая) — авторские.
3. **Облачные сохранения (Steam Auto-Cloud)** — Steamworks → Steam Cloud → Root: `WinAppDataRoaming`,
   Subdirectory: `GodShpionov/saves`, Pattern: `*.json`. (Журнал плейтеста `telemetry/` в облако
   не нужен.)
4. **Depot**: содержимое `build/windows/` без `steam_appid.txt`: `GodShpionov.exe`, `steam_api64.dll`.
5. **Демоверсия** — отдельное приложение Steam: depot из `build/windows-demo/` (без
   `steam_appid.txt`), App ID полной игры — в `project.godot` (`steam/full_app_id`), тогда на экране
   «Конец демоверсии» появится кнопка «Добавить полную игру в список желаемого». Страница, капсулы,
   трейлер и Next Fest — `docs/store/README.md`.

## VK Play

VK Play поддерживает «Эмуляцию Steam»: сборка с GodotSteam работает и там — в кабинете разработчика
VK Play выдаётся ID эмуляции, его подставляют вместо App ID Steam (`steam_appid.txt`). Название
на промобаннерах VK Play должно быть по-русски — «Год шпионов». Комиссия VK Play — 5%; для KPI
грантов ИРИ засчитываются российские установки (см. `docs/grants.md`).

Если Steam не запущен или игра собрана без него, она работает как обычно — без достижений и
оверлея. Статус виден внизу настроек: «Steam: подключён / не запущен / нет в этой сборке».
