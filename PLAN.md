# PLAN.md — Система репликации для ExtractPro

## Цель

Спроектировать расширяемую сетевую репликацию состояния мира. Мир = физика + логика + игровые сущности (герои, пули, кубы, HP, оружие, инвентарь). Репликация = отдельный слой, который **читает** из мира и **пишет** в сеть.

---

## Принципы

1. **Репликация отдельна от логики.** Системы (HeroSystem, BulletSystem) не знают о сети. ReplicationSystem только копирует данные между `SimWorld` и `NetworkSerializable`.
2. **EventBus = единая точка коммуникации.** Все ивенты идут через шину. Серверная шина публикует локально + broadcast. Клиентская — локально + send to server.
3. **Системы независимы.** `PlayerControllerSystem` публикует `HeroMoveIntent` в шину. `HeroSystem` подписывается. Транспорт — дело шины (ClientEventBus / ServerEventBus).
4. **Не всё реплицируем.** Физика кубов и пуль детерминистическая (обе стороны spawn'ят одинаково). Реплицируем только то, что невозможно детерминистически дублировать.

---

## Три типа данных и три механизма

| Тип данных | Механизм | Когда | Пример |
|---|---|---|---|
| **Часто + всем** | `@:s` на NetworkSerializable | Auto dirty delta, каждый тик | Позиции героев (2-4) |
| **Событийно** | `@:rpc` + Serializable payload | По вызову, one-shot | Выстрел, spawn, damage, join/leave |
| **Редко / конфиг** | `@:s` на NetworkSerializable | Auto, но меняется редко | Гравитация, размер мира |

### Что реплицируем

| Что | Механизм | Почему |
|---|---|---|
| Позиции героев | `@:s` dirty delta | Часто (30 Hz), все должны видеть |
| Спавн пули | `@:rpc(clients) bulletSpawn(...)` | Событие, одного раза достаточно |
| Удаление пули | `@:rpc(clients) bulletRemove(...)` | Событие |
| Damage | `@:rpc(clients) damage(...)` | Событие |
| Join/Leave | `@:rpc(clients) playerJoined/Left(...)` | Событие (уже через `announce()`) |
| Спавн куба | `@:rpc(clients) cubeSpawn(...)` | Один раз, потом физика синхронна |
| Удаление куба | `@:rpc(clients) cubeRemove(...)` | Событие |
| Конфиг мира | `@:s` на WorldState | Редко меняется |

### Что НЕ реплицируем

| Что | Почему |
|---|---|
| Физика кубов | Детерминистическое дублирование (обе стороны spawn'ят одинаково) |
| Позиции пуль | Детерминистическое (обе стороны apply velocity одинаково) |
| Конфиг мира (cdb) | Уже синхронизирован через `GameData` (cdb файл идентичен) |
| Логика (HeroSystem, BulletSystem) | Одинаковая на обеих сторонах |
| Спавн героев | Детерминистический (обе стороны вызывают `spawnHero()`) |

---

## Архитектура: три слоя

```
Layer 1: EventBus (shared)         — типизированная шина, publish/subscribe/flush
Layer 2: Transport (client/server) — ClientEventBus / ServerEventBus
Layer 3: NetworkFacade (shared)    — WorldState + GameNet (@:rpc, @:s)
```

---

## Flow данных

### Клиент → Сервер (input)

```
PlayerControllerSystem
  → bus.publish(HeroMoveIntent("local", ...))
  → ClientEventBus.publish()
    → подписан на HeroMoveIntent
    → mirror.sendPosition(playerId, x, y, z, yaw)
    → RNL: CALL → сервер

Сервер:
  NetRoomSystem.update() → socket.update(0) → receive CALL
  → GameNet.sendPosition__im() → onPosition hook
  → ServerEventBus.publish(HeroMoveIntent(...))
  → HeroSystem.onIntent()
```

### Сервер → Клиент (state)

```
SimWorld.update() → HeroSystem.apply() → body.position updated
  → ReplicationSystem.tick()
    → читает sim.heroes → пишет в worldState.heroes [@:s dirty]
    → flush() → dirty deltas → клиент

Клиент:
  RoomNetSystem.update() → socket.update(0) → receive SYNC
  → worldState.heroes обновляется (mirror)
  → ReplicationSystem.tick()
    → читает mirror → применяет к remote heroes
```

---

## Структура файлов

```
shared/
├── SimWorld.hx                      — физика + логика (без изменений)
├── replication/
│   └── ReplicationSystem.hx         — NEW: sync мир ↔ сеть
├── net/
│   ├── LobbyNet.hx                  — RPC facade (без изменений)
│   ├── GameNet.hx                   — RPC facade (расширить: heroInput, bulletSpawn, ...)
│   ├── WorldState.hx                — NEW: NetworkSerializable, @:s позиции героев
│   ├── HeroState.hx                 — NEW: Serializable, данные героя
│   ├── BulletState.hx               — NEW: Serializable, данные пули (payload для RPC)
│   ├── PlayerInfo.hx                — есть
│   ├── NetConfig.hx                 — есть
│   └── NetRegistry.hx              — добавить новые классы
├── events/
│   ├── EventBus.hx                  — есть (без изменений)
│   └── GameEvents.hx                — есть (HeroMoveIntent, BulletFired)
└── systems/
    ├── HeroSystem.hx                — есть (без изменений)
    └── BulletSystem.hx              — есть (без изменений)

server/
├── events/
│   └── ServerEventBus.hx            — Transport: publish → broadcast (@:rpc)
├── room/
│   ├── Room.hx                      — создать WorldState + GameNet, socket.add()
│   ├── LobbyRoom.hx                 — без изменений
│   └── DemoRoom.hx                  — wire GameNet handlers
└── systems/
    └── NetRoomSystem.hx             — добавить GameNet в socket

client/
├── events/
│   └── ClientEventBus.hx            — Transport: publish → mirror.sendPosition()
├── systems/
│   ├── RoomNetSystem.hx             — findMirror(WorldState + GameNet), wire transport
│   └── PlayerControllerSystem.hx    — есть (без изменений)
└── views/
    └── GamePlayView.hx              — создать ReplicationSystem
```

---

## Детали по файлам

### shared/net/HeroState.hx

```haxe
package shared.net;

import rnl.net.Serializable;

/** Позиция одного героя в мире. Payload для @:rpc и @:s массивов. */
class HeroState extends Serializable {
    @:s public var playerId : String = "";
    @:s public var x : Float = 0;
    @:s public var y : Float = 0;
    @:s public var z : Float = 0;
    @:s public var yaw : Float = 0;
    // Будущее (добавляем когда нужно):
    // @:s public var hp : Float = 100;
    // @:s public var weaponId : Int = 0;
}
```

### shared/net/BulletState.hx

```haxe
package shared.net;

import rnl.net.Serializable;

/** Payload для bulletSpawn RPC — one-shot, не реплицируется через @:s. */
class BulletState extends Serializable {
    @:s public var x : Float = 0;
    @:s public var y : Float = 0;
    @:s public var z : Float = 0;
    @:s public var dirX : Float = 0;
    @:s public var dirY : Float = 0;
    @:s public var dirZ : Float = 0;
    @:s public var lifetime : Float = 0;
}
```

### shared/net/WorldState.hx

```haxe
package shared.net;

import rnl.net.NetworkSerializable;

/** Реплицируемое состояние мира. Только то, что невозможно
    дублировать детерминистически. Сервер owner, клиенты — mirror. */
class WorldState extends NetworkSerializable {
    /** Позиции всех героев. Переприсваивать массив каждый тик
        (plain Array не отслеживает push — dirty bit не ставится). */
    @:s public var heroes : Array<HeroState> = [];
    // Bullets НЕ здесь — спавн/удаление через @:rpc
    // Cubes НЕ здесь — детерминистическое дублирование
    // Config НЕ здесь — уже в GameData (cdb)
}
```

### shared/net/GameNet.hx — расширение

```haxe
package shared.net;

import rnl.net.NetworkSerializable;

/** Game RPC facade. Сервер owner, клиенты — mirror. */
class GameNet extends NetworkSerializable {
    // === Server handler hooks ===
    public var onPosition : Null<String -> Float -> Float -> Float -> Float -> Void> = null;
    public var onFire : Null<String -> Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;
    public var onHeroInput : Null<String -> Float -> Float -> Float -> Float -> Bool -> Void> = null;

    // === Client handler hooks ===
    public var onHeroUpdate : Null<String -> Float -> Float -> Float -> Float -> Void> = null;
    public var onBulletSpawn : Null<Float -> Float -> Float -> Float -> Float -> Float -> Void> = null;
    public var onBulletRemove : Null<Int -> Void> = null;
    public var onCubeSpawn : Null<Int -> Float -> Float -> Float -> Float -> Void> = null;
    public var onCubeRemove : Null<Int -> Void> = null;
    public var onDamage : Null<String -> Float -> Void> = null;

    // === Client -> server RPCs ===

    /** Input: movement intent from a client. */
    @:rpc(server)
    public function heroInput(playerId : String, dirX : Float, dirZ : Float,
                              yaw : Float, mag : Float, jump : Bool) : Void {
        if (onHeroInput != null) onHeroInput(playerId, dirX, dirZ, yaw, mag, jump);
    }

    /** Fire request from a client. */
    @:rpc(server)
    public function fireBullet(playerId : String, x : Float, y : Float, z : Float,
                               dirX : Float, dirY : Float, dirZ : Float) : Void {
        if (onFire != null) onFire(playerId, x, y, z, dirX, dirY, dirZ);
    }

    // === Server -> client RPCs ===

    /** Broadcast: a hero moved. */
    @:rpc(clients)
    public function heroUpdate(playerId : String, x : Float, y : Float,
                               z : Float, yaw : Float) : Void {
        if (onHeroUpdate != null) onHeroUpdate(playerId, x, y, z, yaw);
    }

    /** Broadcast: a bullet was spawned. */
    @:rpc(clients)
    public function bulletSpawn(x : Float, y : Float, z : Float,
                                dirX : Float, dirY : Float, dirZ : Float) : Void {
        if (onBulletSpawn != null) onBulletSpawn(x, y, z, dirX, dirY, dirZ);
    }

    /** Broadcast: a bullet was removed (lifetime expire or collision). */
    @:rpc(clients)
    public function bulletRemove(netId : Int) : Void {
        if (onBulletRemove != null) onBulletRemove(netId);
    }

    /** Broadcast: a cube was spawned (one-shot, then deterministic). */
    @:rpc(clients)
    public function cubeSpawn(netId : Int, x : Float, y : Float, z : Float, size : Float) : Void {
        if (onCubeSpawn != null) onCubeSpawn(netId, x, y, z, size);
    }

    /** Broadcast: a cube was removed. */
    @:rpc(clients)
    public function cubeRemove(netId : Int) : Void {
        if (onCubeRemove != null) onCubeRemove(netId);
    }

    /** Broadcast: damage dealt to a player. */
    @:rpc(clients)
    public function damage(playerId : String, amount : Float) : Void {
        if (onDamage != null) onDamage(playerId, amount);
    }
}
```

### shared/replication/ReplicationSystem.hx

```haxe
package shared.replication;

import shared.SimWorld;
import shared.Player;
import shared.net.WorldState;
import shared.net.HeroState;
import shared.systems.System;

/** Отдельный слой: копирует данные между SimWorld и NetworkSerializable.
    Не знает про логику, RPC, или транспорт. */
class ReplicationSystem extends System {
    var worldState : WorldState;
    var isServer : Bool;

    public function new(bus, sim, worldState, isServer) {
        super(bus, sim, "Replication");
        this.worldState = worldState;
        this.isServer = isServer;
    }

    override function update(dt) {
        if (isServer) syncFromSim();
        else applyToSim();
    }

    /** Сервер: мир → network (dirty deltas auto-replicate). */
    function syncFromSim() {
        var arr : Array<HeroState> = [];
        for (id in sim.heroes.keys()) {
            var body = sim.heroes.get(id);
            var hs = new HeroState();
            hs.playerId = id;
            hs.x = body.getPos().x;
            hs.y = body.getPos().y;
            hs.z = body.getPos().z;
            hs.yaw = 0; // TODO: извлечь yaw из body
            arr.push(hs);
        }
        worldState.heroes = arr; // переприсваивание → dirty bit
    }

    /** Клиент: network → мир (только remote игроки). */
    function applyToSim() {
        for (hs in worldState.heroes) {
            if (hs.playerId == Player.LOCAL) continue;
            var body = sim.heroes.get(hs.playerId);
            if (body != null) {
                body.setPosition(hs.x, hs.y, hs.z);
                // TODO:.apply rotation from hs.yaw
            }
        }
    }
}
```

### client/events/ClientEventBus.hx — Transport

```haxe
package extract.events;

import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.BulletFired;
import shared.net.GameNet;

/** Client bus: local delivery + send input to server via GameNet. */
class ClientEventBus extends EventBus {
    public var gameNet : Null<GameNet> = null;

    override function publish<T>(event : T) {
        super.publish(event);

        // Transport: forward input to server
        if (Std.isOfType(event, HeroMoveIntent)) {
            var e : HeroMoveIntent = cast event;
            if (gameNet != null)
                gameNet.heroInput(e.playerId, e.dirX, e.dirZ, e.yaw, e.mag, e.jump);
        }
        if (Std.isOfType(event, BulletFired)) {
            var e : BulletFired = cast event;
            if (gameNet != null)
                gameNet.fireBullet("_", e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
        }
    }
}
```

### server/events/ServerEventBus.hx — Broadcast

```haxe
package serv.events;

import shared.events.EventBus;
import shared.events.GameEvents.HeroMoveIntent;
import shared.events.GameEvents.BulletFired;
import shared.net.GameNet;

/** Server bus: local delivery + broadcast to clients via GameNet. */
class ServerEventBus extends EventBus {
    public var gameNet : Null<GameNet> = null;

    override function publish<T>(event : T) {
        super.publish(event);

        // Broadcast: forward to clients
        if (Std.isOfType(event, HeroMoveIntent)) {
            var e : HeroMoveIntent = cast event;
            if (gameNet != null)
                gameNet.heroUpdate(e.playerId, 0, 0, 0, 0); // TODO: реальные позиции
        }
        if (Std.isOfType(event, BulletFired)) {
            var e : BulletFired = cast event;
            if (gameNet != null)
                gameNet.bulletSpawn(e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
        }
    }
}
```

### server/room/Room.hx — измнения

```haxe
// Добавить поля:
var worldState : WorldState;
var gameNet : GameNet;

// В конструкторе:
worldState = new WorldState();
netSys.socket.add(worldState);

gameNet = new GameNet();
netSys.socket.add(gameNet);

// Wire transport:
cast(bus, ServerEventBus).gameNet = gameNet;

// В tick(), после world.update():
replication.tick(); // sync heroes → worldState
```

### client/systems/RoomNetSystem.hx — измнения

```haxe
// В onConnected:
var worldStateMirror = clientNet.findMirror(WorldState);
var gameNetMirror = clientNet.findMirror(GameNet);

// Wire transport:
cast(bus, ClientEventBus).gameNet = gameNetMirror;

// Wire GameNet client handlers:
gameNetMirror.onHeroUpdate = onHeroUpdate;
gameNetMirror.onBulletSpawn = onBulletSpawn;
// ...
```

---

## rnl: @:s ограничения и gotchas

| Ограничение | Значение |
|---|---|
| Max 32 `@:s` полей на класс | Single UInt bitmask. Для прототипа достаточно. |
| `Array<T>` с `@:s` не отслеживает `push()` | Нужно **переприсваивать** весь массив каждый тик. |
| Dirty tracking на уровне массива | Изменение элемента помечает весь массив. При 2-4 героях ОК. |
| `@:s(unreliable)` на `__syncChannel = 1` | Все дельты едут по unreliable каналу. Позиции можно потерять. |
| ADD/FULLSYNC всегда reliable | При подключении нового клиента — полное состояние. |
| `@:rpc(clients)` не возвращает значение | Только broadcast. |
| CLID registration mandatory | `NetRegistry.init()` на обеих сторонах. |
| `@:rpc` не может иметь optional args | Макрос ошибается. |
| `Serializable` vs `NetworkSerializable` | `Serializable` = payload (inline). `NetworkSerializable` = replicated object (netId, dirty). |
| `@:s` на anonymous struct | Работает, но нет versioning/migration. |

---

## Ограничения архитектуры

### Что работает сейчас

- LobbyNet RPC facade ✅
- GameNet RPC facade (heroUpdate, bulletSpawn) ✅
- SimWorld (физика + HeroSystem + BulletSystem) ✅
- ClientNet с findMirror<T>() ✅
- RoomNetSystem (client) / NetRoomSystem (server) ✅
- EventBus (publish/subscribe/flush) ✅
- ClientEventBus / ServerEventBus (TODO transport) ✅

### Что нужно построить

- WorldState (NetworkSerializable, @:s поля) ❌
- HeroState / BulletState (Serializable) ❌
- ReplicationSystem (sync мир ↔ сеть) ❌
- ClientEventBus transport (publish → @:rpc) ❌
- ServerEventBus transport (publish → broadcast) ❌
- Room.hx: создание WorldState + GameNet ❌
- RoomNetSystem: findMirror(WorldState + GameNet) ❌

---

## Вопросы для решения

### Q1: heroUpdate через @:s или @:rpc?

**A) `@:s` на WorldState.heroes** — auto dirty delta. Просто, но массив пересылается целиком.
**B) `@:rpc(clients) heroUpdate(...)` — one-shot RPC. Чище, но нужно вызывать каждый тик.

При 2-4 героях A проще. При большом количестве — B эффиентнее.

**Рекомендация:** начать с A (проще), перейти на B при масштабировании.

### Q2: Максимум героев?

Определяет подход к репликации:
- 2-4 героя → `@:s Array<HeroState>` (переприсваивание каждый тик, ~200-500 байт)
- 8-16 героев → `@:rpc(clients) heroUpdate(...)` (только изменённые)
- 32+ → персонифицированная рассылка (каждому клиенту только видимых)

**Вопрос:** сколько героев максимум в прототипе?

### Q3: Клиент applies remote hero positions — через физику или transform?

**A) Transform (ткинет позицию)** — проще, но дёргано при потере пакетов.
**B) Velocity (задаёт velocity)** — плавнее, но нужен interpolation.

**Рекомендация:** начать с A (проще), добавить interpolation позже.

### Q4: Один ReplicationSystem или два?

**A) Один с `isServer` флагом** — проще, меньше кода.
**B) ServerReplication / ClientReplication** — чище, но дублирование.

**Рекомендация:** A (проще для прототипа).

### Q5: GameNet.heroInput — нужен ли он?

`ClientEventBus` уже может вызывать `mirror.sendPosition()` напрямую. `heroInput` RPC = `sendPosition` с другим именем.

**Вариант A:** Удалить `sendPosition`, оставить `heroInput` как единый input RPC.
**Вариант B:** Оставить оба (sendPosition для позиций, heroInput для всего input).

**Рекомендация:** A — один RPC для input чище.

### Q6: `Std.isOfType` для определения типа ивента?

В Haxe 4.x `Std.isOfType(event, HeroMoveIntent)` работает. Альтернатива — `Type.getClass(event) == HeroMoveIntent`.

**Рекомендация:** `Std.isOfType` — чище.

### Q7: CubeSpawn через @:rpc или детерминистически?

Сейчас кубы спавнятся одинаково на обеих сторонах (один и тот же таймер в `SimWorld.update()`). Если сохранить детерминистику —不需要 репликация.

**Вариант A:** Оставить детерминистику (проще).
**Вариант B:** Сервер authoritative — кубы только на сервере, клиент получает `cubeSpawn` RPC.

**Рекомендация:** A для прототипа, B когда появится разная геометрия уровней.

### Q8: __syncChannel = 1 для WorldState?

Если `__syncChannel = 1` — все дельты (включая reliable `@:s` поля) едут по unreliable каналу. Позиции можно потерять, следующий тик перезапишет.

**Вариант A:** `__syncChannel = 0` (reliable) — guaranteed delivery, но больше bandwidth.
**Вариант B:** `__syncChannel = 1` (unreliable) — loss-tolerant, fewer retransmits.
**Вариант C:** Reliable для конфига, unreliable для позиций (нужно два объекта или `@:s(unreliable)`).

**Рекомендация:** B для позиций героев (30 Hz, следующий тик перезапишет).

### Q9: Порядок реализации?

1. Serializable классы (HeroState, BulletState) — данные
2. NetworkSerializable (WorldState) — контейнер
3. ReplicationSystem — sync логика
4. ClientEventBus / ServerEventBus — transport
5. Room.hx — создание объектов
6. RoomNetSystem —irror discovery
7. GamePlayView — подключение

**Или** другой порядок?

---

## Решения (заполнять по мере реализации)

- [ ] Q1: @:s или @:rpc для heroUpdate?
- [ ] Q2: Максимум героев?
- [ ] Q3: Transform или velocity для remote heroes?
- [ ] Q4: Один или два ReplicationSystem?
- [ ] Q5: heroInput или sendPosition?
- [ ] Q6: Std.isOfType или Type.getClass?
- [ ] Q7: CubeSpawn — @:rpc или детерминистика?
- [ ] Q8: __syncChannel для WorldState?
- [ ] Q9: Порядок реализации?

---

## Статус

- [ ] Phase 1: Serializable классы (HeroState, BulletState)
- [ ] Phase 2: NetworkSerializable (WorldState)
- [ ] Phase 3: GameNet расширение (heroInput, bulletSpawn, ...)
- [ ] Phase 4: ReplicationSystem
- [ ] Phase 5: ClientEventBus transport
- [ ] Phase 6: ServerEventBus transport
- [ ] Phase 7: Room.hx (создание WorldState + GameNet)
- [ ] Phase 8: RoomNetSystem (mirror discovery)
- [ ] Phase 9: GamePlayView (подключение)
- [ ] Phase 10: Тест и отладка
