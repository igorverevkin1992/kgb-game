# Линия КР: Вашингтон, 1985

Диегетический UI-симулятор офицера линии контрразведки Вашингтонской резидентуры ПГУ КГБ,
1984–1986. Движок — Godot 4.7. Платформа: Windows (Steam, VK Play).

- План разработки: [docs/plan.md](docs/plan.md)
- Концепт и документация: [docs/](docs/README.md)
- Как править контент: [docs/content-guide.md](docs/content-guide.md)

## Как поиграть

- **В браузере:** https://igorverevkin1992.github.io/kgb-game/ (обновляется после каждого
  слияния в `main`).
- **На Windows:** скачайте артефакт `LiniyaKR-windows` из последнего успешного запуска CI
  (вкладка Actions) — это один файл `LiniyaKR.exe`.
- **В редакторе Godot:** установите [Godot 4.7](https://godotengine.org/download) (обычная
  версия, не .NET), откройте папку репозитория как проект и нажмите F5.

Отладка: запуск с аргументами `-- --new` начинает кампанию заново, `-- --act=3` показывает стол
как в акте 3.

## Проверки (Linux или облачная сессия)

```bash
tools/validate.sh
```

```bash
tools/test.sh
```

```bash
tools/ui-test.sh
```

`validate` проверяет контент, `test` — движок, `ui-test` проходит сценарии интерфейса под
виртуальным экраном и сохраняет скриншоты в `build/screens/`. Сборки: `tools/export.sh all`.
