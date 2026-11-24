# RobloxStrike

Серверно-авторитетный FPS-каркас для Roblox в духе Phantom Forces: реальная баллистика пуль,
сетевое оружие, клиентское предсказание трассеров, HUD и тестовый полигон.

Проект собран по схеме Rojo: весь код лежит в `src/`, в Studio попадает через `default.project.json`.

## Возможности

- **Сервер решает всё**: клиент присылает только точку и направление выстрела, попадания,
  урон, боезапас и перезарядку считает сервер.
- **Баллистика**: пули летят с конечной скоростью, с гравитацией и шагом трассировки
  (`Shared/Ballistics.luau`), есть падение скорости и множители урона по зонам.
- **Детерминированное предсказание**: клиент и сервер используют один и тот же `SeededRandom`
  и один и тот же порядок разброса/трассировки, поэтому локальный трейсер совпадает с серверным.
- **Оружие из данных**: MAC-10 (авто), SPAS-12 (дробовик, 8 дробин), Мачете (ближний бой),
  модули (оптика, глушитель, магазин, рукоятка) в `Shared/Config`.
- **Режимы огня**: Auto / Semi, переключение по `B`, темп стрельбы ограничен сервером.
- **HUD**: панель оружия, патроны, режим огня, индикатор перезарядки, хитмаркер.
- **Камера**: TPS/FPS (`V`), ADS по `ПКМ`, зум по оружию, отдача, коллизия камеры.
- **Тестовый полигон**: платформа, стены и мишени на 25/70/140/240 studs, респавн мишеней.

## Стек

- Roblox Studio + Luau (типизированные модули, `--!nonstrict`)
- [Rojo](https://github.com/rojo-rbx/rojo) 7.7.1
- Внешних пакетов нет

## Структура

```
src/
  client/                     → StarterPlayerScripts.Client (LocalScript + Controllers)
    init.client.luau
    Controllers/
      CameraController.luau   камера TPS/FPS, ADS, отдача
      EffectsController.luau  трейсеры, искры, звуки
      Hud.luau                панель оружия, патроны, перезарядка, хитмаркер
      ViewModelController.luau модель оружия в руках
      WeaponController.luau   ввод, авто-огонь, предсказание, HUD
  server/                     → ServerScriptService.Server (Script + Services)
    init.server.luau
    Services/
      HitboxHistory.luau      история позиций для проверки выстрелов
      MeleeService.luau       ближний бой
      PlayerState.luau        состояние игрока: слоты, патроны, режим огня
      ProjectileService.luau  серверная баллистика и урон
      TestRange.luau          генерация полигона
      WeaponService.luau      валидация выстрелов, перезарядка, смена оружия
  shared/                     → ReplicatedStorage.Shared
    Ballistics.luau           общая трассировка пуль
    DamageModel.luau          зоны попадания и урон
    Net.luau                  ремоуты и контракты пакетов
    SeededRandom.luau         детерминированный ГПСЧ
    WeaponLibrary.luau        резолв оружия + модулей
    Config/
      Settings.luau           общие настройки (урон, полигон, предсказание)
      Weapons.luau            характеристики оружия
      Attachments.luau        модули
      Melee.luau              ближний бой
  assets/weapons/             .rbxm модели MAC-10 и SPAS-12
```

## Запуск

Нужен [Rojo 7.7.1](https://github.com/rojo-rbx/rojo/releases) в `PATH`.

Сборка файла и открытие в Studio:

```bash
rojo build default.project.json -o RobloxStrike.rbxlx
```

Затем Studio → **File → Open from File…** → `RobloxStrike.rbxlx` → **Play** (F5).
Именно `Play`, а не `Run`: клиентские контроллеры живут в `StarterPlayerScripts` и стартуют
только когда появляется `LocalPlayer`.

Live-sync без пересборки:

```bash
rojo serve default.project.json
```

В Studio подключите плагин Rojo к `localhost:34872`, затем нажмите **Play**.

## Управление

| Клавиша | Действие |
| --- | --- |
| `ЛКМ` | огонь / удар |
| `ПКМ` | ADS (прицеливание) |
| `R` | перезарядка |
| `B` | режим огня (Auto / Semi) |
| `1` `2` `3` | слоты: MAC-10 / SPAS-12 / Мачете |
| `V` | камера TPS / FPS |

## Как проходит выстрел

1. `WeaponController` проверяет локальный боезапас, темп и перезарядку.
2. Клиент рисует предсказанный трейсер и отправляет на сервер точку/направление/seed.
3. `ProjectileService` повторяет ту же трассировку, проверяет темп стрельбы и боезапас игрока.
4. Урон применяется в момент, когда пуля долетела (`task.delay(trace.Time, ...)`).
5. Сервер возвращает `ShotResult` (попадания + актуальный боезапас) и рассылает трейсеры
   остальным игрокам — стрелок свой трейсер уже видел.

## Тюнинг

- `src/shared/Config/Settings.luau` — урон, ускорение свободного падения, полигон, предсказание.
- `src/shared/Config/Weapons.luau` — урон, темп, разброс, отдача, зум, магазины.
- `src/shared/Config/Attachments.luau` — модули и их модификаторы.
- `src/shared/Config/Melee.luau` — дистанция и урон ближнего боя.

## Проверки без Studio

```bash
rojo build default.project.json -o build.rbxlx     # сборка проекта
luau-analyze src/**/*.luau                         # статический анализ
```

## Известные ограничения

- Режим `Burst` есть в HUD/`PlayerState`, но ни одно оружие его не использует: клиент трактует
  не-`Auto` режим как одиночный.
- Спринта нет: параметры `SprintSpeed`/`SprintMultiplier` заданы, но `WalkSpeed` не меняется.
- Мачете использует плейсхолдер-клинок (реальной модели нет).
- Это каркас геймплея, а не готовая игра: нет раундов, команд, экономики и карт.
