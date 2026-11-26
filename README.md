# Линия КР: Вашингтон, 1985

Диегетический UI-симулятор офицера линии контрразведки Вашингтонской резидентуры ПГУ КГБ,
1984–1986. Платформа: Windows (Steam, VK Play).

- План разработки: [docs/plan.md](docs/plan.md)
- Концепт и GDD: [docs/](docs/README.md)

## Как запустить у себя

Нужен [Node.js 22](https://nodejs.org/).

```bash
npm install
```

```bash
npm run dev
```

Откроется http://localhost:5173. Для отладки акт и язык можно задать в адресе:
`http://localhost:5173/?act=3&lang=en`.

## Проверки

```bash
npm run check
```

```bash
npm run e2e
```

`check` запускает линтер, проверку типов, unit-тесты и сборку. `e2e` проходит игру в браузере
через Playwright и сохраняет скриншоты в `test-results/screens/`.
