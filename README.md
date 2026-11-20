# Blackout Freight

[Технологии игры, AI-инструменты и результаты облачных проверок](docs/TECHNOLOGIES.md)

Blackout Freight is a 1–4 player co-op Roblox game. Recover batteries from Depot 07 while evading a security drone, then decide where to send the last of the depot’s power.

**[Play on Roblox](https://www.roblox.com/games/111633787401180/Blackout-Freight) · public for eligible age-checked players 16+ · place version 30** · Sentinel patrols Depot 07 with twin ducted fans and a moving optical head. The airlock has a five-slot receiver and an illuminated canopy. [Studio build](dist/Blackout%20Freight%20Closed%20Test.rbxl) · [In-game patrol](dist/Blackout%20Freight%20Patrol.jpg) · [Blender model](assets/sentinel/Sentinel.blend)

**Portfolio case study** · I shipped a first-shift compass to the Roblox closed test and instrumented a randomized experiment around the first delivery. In v24, Roblox Analytics received all four event stages for each variant during internal QA. The public notebook demonstrates the analysis on synthetic data.

[Read the case study](docs/portfolio.md) · [Watch the v24 demo](dist/blackout-freight-v24-demo.mp4) · [Download the Studio build](https://raw.githubusercontent.com/GlebAvershin/blackout-freight/main/dist/Blackout%20Freight%20Portfolio%20Preview.rbxl) · [Open the notebook](analysis/first_shift_compass.ipynb) · [View GitHub Actions](https://github.com/GlebAvershin/blackout-freight/actions/workflows/verify.yml)

[![Gameplay from v24 showing the off-screen airlock bearing and the first successful battery delivery](dist/blackout-freight-v24-preview.gif)](dist/blackout-freight-v24-demo.mp4)

**AI in the release and in later QA.** Codex helped implement the first-shift compass. After release, four models reviewed the conclusions supported by a synthetic dataset. The domain validator rejected a rollout recommendation. Internal QA separately verified that the published game delivered events in both experiment arms. [Release evidence](docs/portfolio-release-2026-11-16.md) · [Agent verdicts and technology](docs/TECHNOLOGIES.md)

## Об игре

Кооперативная игра Roblox для 1–4 игроков. В ночном Депо 07 нужно пронести пять батарей мимо дрона Sentinel и выбрать, куда направить последний резерв энергии: передать доказательства в эфир или запитать укрытие.

![Blackout Freight — погоня в Депо 07](dist/blackout-freight-chase-cover.jpg)

[Страница игры в Roblox](https://www.roblox.com/games/111633787401180/Blackout-Freight) · [Сборка для Studio](dist/Blackout%20Freight%20Closed%20Test.rbxl) · [Игровой ролик](dist/blackout-freight-chase-gameplay.mp4)

## Депо и Sentinel в Studio

У Sentinel два канальных вентилятора и поворотный оптический блок. Во время патруля янтарный луч проходит по полу и контейнерам. В погоне оптика направляется вперёд, пятно сужается и краснеет. Голубой цвет показывает, что сработала приманка. Вариант Tracker использует фиолетовую оптику при поиске.

![Sentinel в Депо 07, кадр из Roblox Studio](dist/Blackout%20Freight%20Sentinel.jpg)

Над погрузочными рядами появились остеклённые фонари и мостовой кран, над шлюзом — навес с рабочим светом. Пять индикаторов в HUD, на табло и на механическом приёмнике показывают заряд в одном порядке.

[Открыть сборку в Studio](dist/Blackout%20Freight%20Design%20Preview.rbxl) · [Кадр патруля](dist/Blackout%20Freight%20Patrol.jpg) · [Модель Sentinel для Blender](assets/sentinel/Sentinel.blend)

## Компас первой смены

[Открыть в Roblox Studio](dist/Blackout%20Freight%20Portfolio%20Preview.rbxl) · [Кейс на английском](docs/portfolio.md) · [A/B-тест первой доставки](docs/first-shift-experiment.md)

Компас первой смены подсказывает направление и расстояние до батареи или шлюза, когда метка выходит из кадра. В Studio он доступен в подходящей смене после загрузки персонажа. Поверни камеру в сторону от цели, чтобы увидеть стрелку. Успешная доставка выключает компас. Расчёт воронки и доверительных интервалов можно повторить в [Jupyter](analysis/first_shift_compass.ipynb) на синтетических данных.

## Что есть в игре

- Две концовки и сохраняемый журнал. После обеих концовок открываются особые маршруты и записи диспетчера Миры.
- «Чёрный ящик» на Западном обходе. Один игрок несёт кейс, второй отвлекает Sentinel маяком. При совместном извлечении оба получают время экипажа.
- Личный рекорд смены и еженедельные контракты с наградой за три разные недели.
- Блэкаут сектора с предупреждением и командные метки для батареи, опасности и направления.
- Ежедневная смена на Тревоге 1 с общей раскладкой, личными рекордами по размеру экипажа и недельной Стеной славы. У ролей есть косметические награды за мастерство.
- Мобильный HUD со сворачиваемыми подсказками. В журнале настройки звука и кнопка закрытия закреплены отдельно от прокручиваемых записей.
- Шкафчик с бесплатным оформлением за прохождение и предпросмотром Aurora Lens и «Экипажа Депо 07».

## Как запустить

1. Скачай [сборку](dist/Blackout%20Freight%20Closed%20Test.rbxl) и открой её в Roblox Studio через **File → Open from File**.
2. Нажми **Play**. Депо строится при запуске сервера.
3. Следуй за бирюзовой меткой к батарее. На ПК взаимодействие выполняется клавишей **E**, на телефоне — нажатием игровой подсказки. Сдай батарею в янтарном шлюзе. Журнал открывается экранной кнопкой или клавишей **J**.
4. Для кооператива используй **Server & Clients**. Для телефона включи **Device Simulator** и проверь обе ориентации.

20 ноября в закрытом тесте Roblox опубликована v25 из тега v25-rc.1. В десктопном Roblox Player за одну смену проверены все пять кассет приёмника, обе консоли выбора и победа Shelter. В отдельной смене в Player получена победа Broadcast за 2:00. После перехода на другой сервер в журнале подтверждены обе концовки. [Результаты проверки](docs/releases/v25-rc.1.md) Сборки Closed Test, Progression Preview и Portfolio Preview в `dist/` совпадают с проектом Rojo. В локальном тесте журнал хранится до остановки сервера, а приглашения Roblox доступны в опубликованной игре. [Отчёт по версии 24](docs/portfolio-release-2026-11-16.md) · [Сценарий живой проверки](docs/playtest/live-checklist.md)

## Документация

- [Руководство игрока](docs/game-guide.md) — первая смена, управление, финалы, роли и прогрессия.
- [Руководство разработчика](docs/development.md) — установка на Windows и macOS, сборка из Git, архитектура, тесты и развёртывание в Roblox.
- [Чек-лист закрытого теста](docs/playtest/live-checklist.md) · [Отчёт по версии 24](docs/portfolio-release-2026-11-16.md) · [Дизайн главы](docs/last-signal.md) · [Аудио](docs/audio-design.md) · [Рынок и монетизация](docs/market-and-monetization.md).

## История и проверка

- [Состояние проекта на 20 ноября](docs/audit-2026-11-20.md) · [Заметки к пререлизу для Studio](docs/releases/v25-rc.1.md)
- [План расширения и история проверок](docs/expansion-status.md) · [Событие «Потерянный сигнал»](docs/lost-signal-qa-2026-11-13.md)
- [Правила Тревоги и монетизации](docs/advanced-heat-and-commerce.md) · [Нагрузочный тест дронов](docs/heat-5-soak-2026-11-13.md)
- [Комплект внешнего теста](docs/playtest/README.md) · [Проверка сохранений в Studio](docs/persistence-qa-2026-11-13.md) · [Проверка в Roblox Player](docs/live-player-2026-11-13.md)
