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
   Subdirectory: `Washington1985/saves`, Pattern: `*.json`. (Журнал плейтеста `telemetry/` в облако
   не нужен.)
4. **Depot**: содержимое `build/windows/` без `steam_appid.txt`: `Washington1985.exe`, `steam_api64.dll`.

Если Steam не запущен или игра собрана без него, она работает как обычно — без достижений и
оверлея. Статус виден внизу настроек: «Steam: подключён / не запущен / нет в этой сборке».
