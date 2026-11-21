# Разработка Blackout Freight

На новом Windows или macOS игра запускается локально в Roblox Studio. Для сборки из исходников нужен Rojo, для автоматических проверок — Luau CLI и Python. Нативные приглашения, облачные сохранения, покупки и данные Creator Hub проверяются в опубликованной среде Roblox.

## Установка и первая сборка

1. Установи [Git](https://git-scm.com/downloads) и [Roblox Studio](https://create.roblox.com/docs/studio/setup), войди в Studio со своим аккаунтом. Если GitHub запросит доступ к репозиторию, войди под аккаунтом, которому он выдан.
2. Клонируй репозиторий и создай свою ветку от `main`.

   ```sh
   git clone https://github.com/GlebAvershin/blackout-freight.git
   cd blackout-freight
   git switch -c codex/my-change
   ```

3. Установи [Rokit](https://github.com/rojo-rbx/rokit) и выполни `rokit install` в корне проекта, либо установи [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) в PATH вручную. Проверь `rojo --version`. Версию проекта фиксирует [rokit.toml](../rokit.toml).
4. Собери локальный файл и открой его в Studio через **File → Open from File**.

   ```sh
   rojo build -o "dist/Blackout Freight.rbxl"
   ```

5. Нажми **Test / Play (F5)**. Карта в режиме редактирования может выглядеть пустой: сервер создаёт Депо 07 при старте смены. Подбери отмеченную батарею, сдай в шлюзе и проверь счётчик `1/5`. Повторяй сборку после изменений и заново открывай файл. Локальный файл по этому пути исключён из Git.

Если нужно просто поиграть, открой [готовую сборку Studio](../dist/Blackout%20Freight%20Closed%20Test.rbxl). Для работы с исходниками начни с клона. Каталог `.tools/` разработчика не нужен на другом ПК.

Для быстрой синхронизации можно установить плагин командой `rojo plugin install`, запустить `rojo serve` из корня проекта и нажать **Connect** в плагине Rojo 7 в открытой локальной копии. Адрес по умолчанию — `localhost:34872`, фактический порт указан в выводе команды. Правь файлы в `src/`: Rojo переносит изменения из Git в Studio. [Установка Rojo и плагина](https://rojo.space/docs/v7/getting-started/installation/)

## Где что менять

| Область | Точки входа |
| --- | --- |
| Смены, доставка и выбор финала | [Shift.server.luau](../src/server/Shift.server.luau), [Round.luau](../src/shared/Round.luau) |
| Геометрия и поведение дронов | [Depot.luau](../src/server/Depot.luau), [FreightYard.luau](../src/server/FreightYard.luau), [SentinelController.luau](../src/server/SentinelController.luau) |
| Корпус, оптика и движение вентиляторов Sentinel | [Sentinel.blend](../assets/sentinel/Sentinel.blend), [экспортёр Blender](../assets/sentinel/build.py), [SentinelPresentation.client.luau](../src/client/SentinelPresentation.client.luau) |
| HUD, журнал и первая доставка | [Hud.client.luau](../src/client/Hud.client.luau), [JournalPanel.luau](../src/client/JournalPanel.luau), [FirstShiftCompass.luau](../src/client/FirstShiftCompass.luau) |
| Профиль, рейтинг и пропуска | [ProfileService.luau](../src/server/ProfileService.luau), [HallOfFame.luau](../src/server/HallOfFame.luau), [CommerceService.luau](../src/server/CommerceService.luau) |
| Баланс и подключённые функции | [Config.luau](../src/shared/Config.luau), [CrewChallenges.luau](../src/shared/CrewChallenges.luau), [Roles.luau](../src/shared/Roles.luau) |

[default.project.json](../default.project.json) размещает `src/shared` в `ReplicatedStorage.Freight`, `src/server` в `ServerScriptService.Freight`, а `src/client` — в `StarterPlayerScripts.Freight`. Клиент показывает состояние и отправляет действия. Сервер проверяет их, начисляет награды и сохраняет профиль. Поэтому изменения правил начинай на сервере, а общий чистый расчёт выноси в `src/shared`.

### Графика Sentinel

В Blender корпус, вентиляторы и оптика собраны в координатах единого шасси. У деталей есть свойства `primitive` и `group`. После изменения положения, ориентации или размеров деталей сохрани сцену и из корня проекта выполни экспорт.

```sh
blender -b assets/sentinel/Sentinel.blend --python assets/sentinel/build.py -- --export
```

Экспортёр обновит [SentinelRig.json](../src/client/SentinelRig.json). При запуске клиент строит из этих данных обычные детали Roblox, привязывает их к серверному корпусу и меняет оптику при переходах между режимами. При включённом уменьшении движения вентиляторы останавливаются и оптика перестаёт сканировать из стороны в сторону. Сценарий `scripts/run-guidance-studio-qa.py` проверяет сборку корпуса, движение вентилятора, попадание луча в поверхность и смену цветов.

## Проверки перед отправкой изменений

Установи [Luau CLI 0.747](https://github.com/luau-lang/luau/releases/tag/0.747), добавь `luau` и `luau-compile` в PATH и установи [Python 3](https://www.python.org/downloads/). Из корня проекта выполни:

```sh
luau-compile --null src tests
for test in tests/*.test.luau; do luau "$test" || exit 1; done
python3 scripts/check-release.py --artifact "dist/Blackout Freight.rbxl" --rojo rojo
```

В PowerShell тот же набор команд выглядит так:

```powershell
luau-compile --null src tests
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Get-ChildItem tests -Filter '*.test.luau' | ForEach-Object {
    luau $_.FullName
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
py -3 scripts/check-release.py --artifact "dist/Blackout Freight.rbxl" --rojo rojo
```

Проверка сборки сравнивает файл со свежей сборкой Rojo. После правок сначала пересобери `.rbxl`. Для игровых изменений в Studio проверь первую доставку и затронутый сценарий. Используй **Server & Clients** для двух, затем при необходимости четырёх клиентов и **Device Simulator** для обеих ориентаций телефона. Автоматические сценарии в `scripts/run-*-studio-qa.py` рассчитаны на macOS. [Режимы тестирования Studio](https://create.roblox.com/docs/studio/testing-modes) · [GitHub Actions](../.github/workflows/verify.yml)

Если меняешь аналитику, установи [uv](https://docs.astral.sh/uv/getting-started/installation/) и выполни `uv sync --project analysis --locked --python 3.12 --group notebook`, затем `uv run --project analysis --locked --group notebook python -m unittest discover -s analysis`. [Эксперимент и формат данных](first-shift-experiment.md)

## Развёртывание в Roblox

Для самостоятельного теста опубликуй собранный локальный файл в **отдельный закрытый experience** под своим аккаунтом. Начни с приватного доступа. Если нужны другие участники, настрой закрытый доступ и тестировщиков в Creator Hub. Установи лимит стартового места в четыре игрока, запусти игру в Roblox Player и проверь первую доставку, победу и повторный вход на другой сервер с тем же аккаунтом.

- В Studio профиль хранится в памяти сервера. В Roblox Player профиль пишет `FreightProfile_v1` через DataStoreService. Места одного experience используют общие хранилища, поэтому для изоляции нужен отдельный experience. [Настройка DataStore в Roblox](https://create.roblox.com/docs/cloud-services/data-stores)
- Для полной копии облачной конфигурации проверь доступность звуков и других облачных ассетов, настрой приглашения и создай собственные пропуска, если они нужны. Идентификаторы пропусков оригинала находятся в `Config.luau`; для тестовой копии используй её идентификаторы или отключи соответствующие предложения значением `0`. Базовый локальный игровой цикл доступен без ключей и покупок.
- Для обновления основного закрытого теста требуется доступ на публикацию к universe `10775560304`, стартовое место `111633787401180`. После проверки сборки публикуй в существующее место и сверь номер версии в Creator Hub. [История версий](https://create.roblox.com/dashboard/creations/experiences/10775560304/places/111633787401180/version-history)
- [publish-closed-test.py](../scripts/publish-closed-test.py) без `--publish` выводит размер, SHA-256 и назначение файла. С `--publish` отправляет файл в основное место и запрашивает ключ Open Cloud. Для тестового experience используй Studio и выбери его явно. [Публикация через Open Cloud](https://create.roblox.com/docs/cloud/guides/usage-place-publishing)

Исходники хранятся в Git. Если обновляешь релиз, собери из той же версии Rojo все три отслеживаемых файла в `dist/`: Closed Test, Progression Preview и Portfolio Preview. Проверь их через `check-release.py`, запиши номер опубликованной версии и SHA-256, затем отправь коммит на GitHub. [Пример отчёта о выпуске](portfolio-release.md) · [Чек-лист живого теста](playtest/live-checklist.md)

## Ассет шлюза и пререлиз

Палитра, размеры в studs и координаты деталей задаются в [ReceiverGeometry.json](../src/server/ReceiverGeometry.json). Сервер строит стойку, а [клиентский скрипт](../src/client/ChargeReceiver.client.luau) показывает принятый заряд. Для рендера из тех же размеров запусти из корня проекта `blender --background --python-exit-code 1 --python assets/airlock-receiver/render.py`. Проверена версия Blender 4.5.16 LTS.

Для следующего GitHub-пререлиза создай файл `docs/releases/<тег>.md`, обнови три сборки и README, выполни проверки, затем отправь тег вида `v25-rc.2` на проверенном коммите. GitHub Actions собирает игру из источников, сравнивает файлы, тестирует аналитику и выпускает Studio-пакет с контрольными суммами. Публикация на серверах Roblox выполняется отдельно.

При переносе проекта на другой путь пересоздай исполняемые точки входа локального Python-окружения командой `uv sync --project analysis --locked --group notebook --reinstall`. Для Tableau из корня запусти:

```sh
uv run --project analysis --locked --group tableau python analysis/export_tableau.py analysis/synthetic_compass_counts.csv FirstShiftCompass-synthetic.hyper --source synthetic
```

Открой файл как источник данных в Tableau Desktop. Поля `segment` и `variant` задают группу, `event` — этап, `events` — число событий. Для доли доставок раздели число `delivered_90` на `exposed` в той же группе. Экспортёр проверяет исходные агрегаты и повторно открывает созданный файл. [Tableau Hyper API](https://tableau.github.io/hyper-db/docs/)
