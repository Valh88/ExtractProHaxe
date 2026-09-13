# PLAN.md — Система репликации для ExtractPro (Pattern A)

## Цель

Спроектировать расширяемую сетевую репликацию игровых сущностей.
Мир = физика + логика + сущности (герои, пули, кубы, HP, оружие, инвентарь).
Репликация = **per-entity объекты**: игровая сущность, которой нужна
репликация, сама является `NetworkSerializable` со своими `@:s` полями.

**В рамках этого плана:** per-entity state sync (HeroObject → mirror),
transport (EventBus → GameNet), one-shot events (@:rpc + payload),
mirror discovery, SyncBridge (единственная копия — позиция из Oimo).

**Не в рамках:** lag compensation, jitter buffer, tick sync — это game layer,
поверх rnl и replication.

---

## Принципы

1. **Игровые данные живут в одном месте.** У каждого факта игровых данных
   (HP, оружие, счёт) ровно один контейнер — `@:s` поле своей сущности.
   Никаких пар «игровой контейнер + транспортный контейнер».
2. **`NetworkSerializable` — опция на контейнере.** Сущность, которой нужна
   репликация, наследуется от него; детерминистическая (куб/пуля) — обычный
   класс, пока всё решает физика. Это не два слоя — это один паттерн,
   применённый локально.
3. **Репликация <> логика.** Системы читают/пишут сущности напрямую
   (`sim.heroEnts[id].hp -= 25`); dirty tracking и доставку делает rnl сам.
4. **EventBus = единая точка коммуникации.** События (input, damage-фидбек,
   спавн пули) идут через шину; транспорт — система-подписчик, шина не знает
   о GameNet.
5. **Не всё реплицируем.** Детерминистическая часть (кубы, отрисовка пуль,
   физика) остаётся где есть. Реплицируется только то, что нужно серверу
   контролировать (авторитетные позиции героев, HP) или нельзя получить
   детерминистически.

---

## rnl vs Game Layer: что где

### rnl (транспорт + сериализация)

- UDP/RNL сокеты
- `@:s` dirty deltas (reliable/unreliable) — автоматически, per-поле
- `@:rpc` вызовы (server/clients/all)
- Per-object ADD/SYNC/REMOVE/FULLSYNC (netId)
- Peer management, timeout
- **НЕ знает про:** ping, lag, prediction, interpolation

### Game Layer (поверх rnl)

| Механизм | Что делает | Где живёт | Статус |
|---|---|---|---|
| Client prediction | Клиент применяет input локально | `HeroSystem` (shared) | ✅ есть |
| Interpolation | Плавное движение между состояниями | `PhysRenderer` (`PhysCore.interpol`) | ✅ есть |
| Server reconciliation | Клиент сверяет локальное состояние с авторитетным | клиентский SyncBridge | ❌ TODO |
| Lag compensation | Сервер «отматывает» время для попаданий | `DamageSystem` (будущий) | ❌ TODO |
| Jitter buffer | Буферизация входящих пакетов | клиентский SyncBridge | ❌ TODO |

---

## Три типа данных и три механизма

| Тип данных | Механизм | Когда | Пример |
|---|---|---|---|
| **Часто + всем** | `@:s` на per-entity объекте (HeroObject) | Auto dirty delta, 30 Hz | Позиция, HP героя |
| **Событийно** | `@:rpc` + Serializable payload | По вызову, one-shot | Выстрел, damage-фидбек |
| **Детерминизм** | общий sim, без сети | Всегда | Кубы, физика, логика |

### Что реплицируем / нет

| Что | Механизм | Почему |
|---|---|---|
| Позиция + HP + оружие героя | `@:s` HeroObject | сервер-owned, античит |
| Спавн пули | `@:rpc(clients) bulletSpawn` | one-shot, дальше — детерминизм |
| Damage-фидбек (числа, HUD) | `@:rpc(clients) damage` | мгновенный визуал |
| Input (движение/прыжок) | `@:rpc(server) heroInput` | prediction на клиенте |
| Join/Leave | `LobbyNet.announce` | уже есть |
| Кубы / их физика | **не реплицируем** | детерминистически одинаковы |
| Пули (движение, коллизии) | **не реплицируем** | детерминистическая симуляция |
| Логика (HeroSystem, BulletSystem) | **не реплицируем** | одна на обе стороны |
| Спавн героев | детерминистический | обе стороны вызывают `spawnHero()` |

> **Примечание:** детерминизм — НЕ гарантия. Когда пуля/куб станут
> серверными (античит, разрушаемость), они получат свой класс с `@:s` —
> ровно как HeroObject. Это локальное изменение типа, не архитектурное.

---

## Архитектура данных

### Source of truth: SimWorld (сервер owns)

```
SimWorld
├── heroes  : Map<String, PhysBody>    — физические тела (позиция, velocity)
├── heroEnts: Map<String, HeroObject>  — НЕТВОРК-сущности (HP, оружие, счёт, позиция-копия)
├── systems : Systems                  — логика (HeroSystem, BulletSystem)
└── bus     : EventBus                 — коммуникация
```

Ключ обеих map — `playerId`. `HeroObject` создаёт/добавляет сервер;
клиент получает mirror и строит свою `Map<playerId, HeroObject>`.

### HeroObject — единственное место игровых данных героя

```haxe
// shared/net/HeroObject.hx
class HeroObject extends rnl.net.NetworkSerializable {
    @:s public var playerId : String = "";
    // позиция — единственная копия (Oimo владеет transform PhysBody)
    @:s public var posX : Float = 0;
    @:s public var posY : Float = 0;
    @:s public var posZ : Float = 0;
    @:s public var yaw : Float = 0;
    // игровые данные — ЖИВУТ здесь
    @:s public var hp : Float = 100;
    @:s public var maxHp : Float = 100;
    @:s public var weaponId : Int = 0;
    @:s public var ammo : Int = 0;
    @:s public var score : Int = 0;

    public function new() {
        super();
        __syncChannel = 1; // позиции loss-tolerant (unreliable)
    }
}
```

**Правило доступа:**
- **Сервер** — создаёт `HeroObject`, `net.add(obj)`, пишет в `@:s` поля
  (dirty ставится сам, SYNC летит клиентам).
- **Клиент** — читает mirror напрямую (HUD `obj.hp`); НЕ пишет в него
  (это рушит dirty-бит и конфликтует с сервером).

### Один факт данных — одно место (без дублирования)

```
Система (сервер):  sim.heroEnts[id].hp -= 25
                     ↓ dirty автоматически
нуждается только в этом → SYNC → зеркала клиентов
```

Позиция — единственная явная копия: `PhysBody` владеет transform (Oimo),
его нельзя сделать `@:s` полем. Пишет её **SyncBridge** (см. ниже).

---

## Архитектура: три слоя (коммуникация)

```
Layer 1: EventBus (shared)             — чистая pub/sub без знаний о транспорте
Layer 2: TransportSystems (client/server) — подписчики шины → GameNet RPC
Layer 3: Per-entity replicated objects  — HeroObject (@:s) + GameNet (@:rpc)
```

**Принцип:** шина ничего не знает о GameNet. Транспорт = система-подписчик,
как HeroSystem. Добавление ивента = подписка в TransportSystem, без правок шины.

---

## Flow данных

### Клиент → Сервер (input)

```
PlayerControllerSystem
  → bus.publish(HeroMoveIntent("local", ...))
  → ClientTransportSystem.onHeroMove()     [подписчик шины]
    → gameNet.heroInput(playerId, dirX, dirZ, yaw, mag, jump)
    → RNL: CALL → сервер

Сервер:
  NetRoomSystem.update() → socket.update(0) → receive CALL
  → GameNet.heroInput__im() → onHeroInput hook
  → bus.publish(HeroMoveIntent(...))       [локальная доставка]
  → HeroSystem.onIntent()                  [двигает PhysBody]
```

### Сервер → Клиент (state): два канала

```
A) @:s dirty delta (автоматически, 30 Hz) — авторитетное состояние:
   HeroSystem.move → PhysBody
   SyncBridge (сервер): body.pos → obj.pos*     [1 строка]
   системы пишут: obj.hp = ...                   [1 строка]
   rnl: dirty/clear → SYNC (unreliable канал) → mirror на клиенте

B) @:rpc event (one-shot, мгновенно) — визуальный фидбек:
   ServerTransportSystem.onPlayerDamaged()
     → gameNet.damage(playerId, amount)
     → клиенты показывают damage number / HUD flash
```

**Зачем оба:** `@:s` = авторитетное HP (задержка до 33ms), `@:rpc` = мгновенный
фидбек UI. Оба инициируются сервером от одного события.

---

## Структура файлов

```
shared/
├── SimWorld.hx                         — ✅ heroEnts: Map<String, HeroObject> (#if sys)
├── replication/
│   └── SyncBridge.hx                   — ✅ NEW: единственная копия body↔obj позиции (#if sys)
├── net/
│   ├── HeroObject.hx                   — ✅ NEW: per-entity NetworkSerializable
│   ├── GameNet.hx                      — ✅ EDIT: только события + playerJoined
│   ├── LobbyNet.hx / PlayerInfo.hx     — есть, без изменений
│   ├── NetConfig.hx                    — есть
│   └── NetRegistry.hx                  — ✅ EDIT: +CLID HeroObject
├── events/                             — есть (без изменений)
└── systems/
    ├── HeroSystem.hx                   — есть; спавн сущности вызывает room/кто-то
    └── BulletSystem.hx                 — есть (без изменений)

server/
├── systems/
│   ├── NetRoomSystem.hx                — есть
│   └── ServerTransportSystem.hx        — ✅ NEW: подписчик шины → broadcast через GameNet
├── room/
│   ├── Room.hx                         — ✅ EDIT: GameNet + ServerTransportSystem; flush шины в tick
│   ├── LobbyRoom.hx                    — без изменений
│   └── DemoRoom.hx                     — ✅ EDIT: HeroObject на join, playerJoined, SyncBridge(true)
└── events/                             — есть

client/
├── systems/
│   ├── RoomNetSystem.hx                — ✅ EDIT: gameNet mirror + onPlayerJoined/onBulletSpawn/onDamage
│   ├── PlayerControllerSystem.hx       — есть
│   └── ClientTransportSystem.hx        — ✅ NEW: подписчик шины → input через GameNet
├── views/
│   └── GamePlayView.hx                 — ✅ EDIT: heroEnts poll, SyncBridge(false), wire GameNet
└── events/                             — есть
```

---

## Детали по файлам

### shared/net/HeroObject.hx

Класс с `@:s` игровыми полями (см. выше). Дополнительно:

```haxe
override function onFullSync() : Void {
    // mirror прибыл: выставить dirty, чтобы клиент прочитал полное состояние
    super.onFullSync();
}
```

> rnl-лимит: максимум 32 `@:s` поля на класс. Сейчас 9. Вся будущая
> игровая статистика (инвентарь, баффы) — сюда, запас есть.

### shared/net/NetRegistry.hx — добавить

```haxe
Registry.getCLID(Type.getClassName(HeroObject));
```

> ADD/FULLSYNC резолвят класс по имени (`Type.resolveClass`) и CLID не требуют,
> но регистрация обязательна для value-«Serializable» payload'ов (PlayerInfo).
> HeroObject — NetworkSerializable — регистрируем для симметрии/безопасности.
> Класс должен пережить DCE (`-D dce=no` уже в обоих hxml).

### client/src/extract/net/ClientNet.hx — `findObjects`

`findMirror<T>` возвращает ПЕРВЫЙ объект класса. Для per-entity нужны все:

```haxe
/** All mirrored NetworkSerializable instances of `cls` (empty on web). */
public function findObjects<T:NetworkSerializable>(cls : Class<T>) : Array<T>
{
    if (socket == null) return [];
    var out : Array<T> = [];
    for (o in socket.objects)
    {
        var m = Std.downcast(o, cls);
        if (m != null) out.push(m);
    }
    return out;
}
```

(`#if !sys` stub: `return [];`)

### shared/replication/SyncBridge.hx

Единственное место явного копирования позиции (Oimo владеет transform).
isServer определяет направление:

```haxe
class SyncBridge extends System {
    var isServer : Bool;   // true — сервер, false — клиент

    override function update(dt : Float) : Void {
        if (isServer) pushSimToNet();
        else pullNetToSim();
    }

    /** Сервер: авторитетная физика → HeroObject (отправка клиентам). */
    function pushSimToNet() {
        for (id in sim.heroes.keys()) {
            var obj = sim.heroEnts.get(id);
            if (obj == null) continue;
            var p = sim.heroes.get(id).getPos();
            obj.posX = p.x; obj.posY = p.y; obj.posZ = p.z;
            // yaw: извлечь из PhysBody (Quat → angle вокруг Y) — TODO
        }
    }

    /** Клиент: mirror → тело remote-игрока (для рендера интерполяции).
        Player.LOCAL пропускаем — его движение идёт локально (prediction),
        применение зеркала дёрнуло/перектлав бы собственное тело. */
    function pullNetToSim() {
        for (id in sim.heroes.keys()) {
            if (id == Player.LOCAL) continue; // prediction — свой герой локальный
            var obj = sim.heroEnts.get(id);
            if (obj == null) continue;
            var body = sim.heroes.get(id);
            body.setPosition(obj.posX, obj.posY, obj.posZ);
        }
    }
}
```

Размещение:
- **Сервер:** `Room.roomSystems.add(new SyncBridge(bus, world, heroObjs, true))`
  — тикает в `roomSystems.update(dt)` (после `world.update`, 30 Hz).
- **Клиент:** `GamePlayView.systems.add(new SyncBridge(bus, sim, heroEnts, false))`
  — тикает каждый кадр.

> Только позиция копируется. HP/оружие/счёт пишут системы напрямую —
> dirty бешеный, отдельного копирования нет.

### shared/net/GameNet.hx — только события

Удалить `sendPosition`/`heroUpdate` (позиция теперь в HeroObject). Остаются:

```haxe
class GameNet extends NetworkSerializable {
    public var onHeroInput : Null<Float->Float->Float->Float->Bool->Void> = null; // pid сервер резолвит из __rpcCaller
    public var onFire      : Null<Float->Float->Float->Float->Float->Float->Void> = null;
    public var onBulletSpawn : Null<String->Float->Float->Float->Float->Float->Float->Void> = null; // ownerId first
    public var onDamage    : Null<String->Float->Void> = null;
    public var onPlayerJoined : Null<String->String->Void> = null; // playerId, name

    @:rpc(server)  public function heroInput(dirX, dirZ, yaw, mag, jump) { if(onHeroInput!=null) onHeroInput(...); }
    @:rpc(server)  public function fireBullet(x,y,z,dirX,dirY,dirZ) { if(onFire!=null) onFire(...); }
    @:rpc(clients) public function bulletSpawn(ownerId:String, ...) { if(onBulletSpawn!=null) onBulletSpawn(...); }
    @:rpc(clients) public function damage(playerId:String, amount:Float) { if(onDamage!=null) onDamage(playerId, amount); }
    @:rpc(clients) public function playerJoined(playerId:String, name:String) { if(onPlayerJoined!=null) onPlayerJoined(playerId, name); }
}
```

### server/systems/ServerTransportSystem.hx — NEW

```haxe
class ServerTransportSystem extends System {
    var gameNet : Null<GameNet>;
    public function new(bus, gd, gameNet) {
        super(bus, null, gd, "ServerTransport");
        this.gameNet = gameNet;
        bus.subscribe(BulletFired, onBulletFire);
    }
    function onBulletFire(e : BulletFired) {
        if (gameNet != null) gameNet.bulletSpawn(e.ownerId, e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
    }
    // TODO: subscribe to damage/playerDamaged → gameNet.damage(...)
    override function dispose() {
        bus.unsubscribe(BulletFired, onBulletFire);
        gameNet = null;
        super.dispose();
    }
}
```

> Позиции/HP НЕ идут через шину — их реплицирует HeroObject (@:s).
> Шина только для one-shot событий.

### client/systems/ClientTransportSystem.hx — NEW

```haxe
class ClientTransportSystem extends System {
    var gameNet : Null<GameNet>;
    public function new(bus, gd, gameNet) {
        super(bus, null, gd, "ClientTransport");
        this.gameNet = gameNet;
        bus.subscribe(HeroMoveIntent, onHeroMove);
        bus.subscribe(BulletFired, onBulletFire);
    }
    function onHeroMove(e : HeroMoveIntent) {
        if (gameNet != null) gameNet.heroInput(e.playerId, e.dirX, e.dirZ, e.yaw, e.mag, e.jump);
    }
    function onBulletFire(e : BulletFired) {
        if (gameNet != null) gameNet.fireBullet("_", e.x, e.y, e.z, e.dirX, e.dirY, e.dirZ);
    }
    override function dispose() {
        bus.unsubscribe(HeroMoveIntent, onHeroMove);
        bus.unsubscribe(BulletFired, onBulletFire);
        gameNet = null;
        super.dispose();
    }
}
```

### server/room/Room.hx — EDIT

```haxe
var gameNet : GameNet;
// в конструкторе (после netSys):
gameNet = new GameNet();
netSys.socket.add(gameNet);
roomSystems.add(new ServerTransportSystem(bus, gd, gameNet));
```

### server/room/DemoRoom.hx — EDIT (на join)

```haxe
// peer собрался играть → создать авторскую сущность
var obj = new HeroObject();
obj.playerId = playerId;
obj.hp = 100; obj.maxHp = 100;     // из GameData? TODO
sim.heroEnts.set(playerId, obj);
netSys.socket.add(obj);
roomSystems.add(new SyncBridge(bus, world, sim.heroEnts, true));
```

### client/views/GamePlayView.hx — EDIT

```haxe
var heroEnts : Map<String, HeroObject> = new Map();
var gameNetMirror = roomNet.clientNet.findMirror(GameNet);

systems.add(new ClientTransportSystem(bus, gd, gameNetMirror));
// poll mirrors каждый кадр (в update()):
for (o in roomNet.clientNet.findObjects(HeroObject)) {
    if (!heroEnts.exists(o.playerId)) {
        heroEnts.set(o.playerId, o);
        // показать remote-героя (спавн mesh) — TODO
    }
}
systems.add(new SyncBridge(bus, sim, heroEnts, false));

gameNetMirror.onDamage = (pid, amount) -> { /* HUD damage number */ };
```

### client/systems/RoomNetSystem.hx — EDIT

Добавить в `update()` после mirror-up: сбор `heroEnts` из `findObjects`,
выносить наружу как `heroEnts: Map<String, HeroObject>` (или оставить
GamePlayView самому поллить — см. выше).

---

## rnl: @:s ограничения и gotchas

| Ограничение | Здесь |
|---|---|
| Max 32 `@:s` полей/класс | HeroObject: 9. Запас для инвентаря. |
| `Array<T>` с `@:s` не видит `push()` | В Pattern A массивов нет — поля on-the-fly. ✅ |
| Dirty per-поле / per-объект | XY упаковки не надо — 32-битный битмаск сам. |
| `__syncChannel = 1` (unreliable) | Позиции ловятся потерями → следующий SYNC перепишет. |
| ADD/FULLSYNC всегда reliable | Первое полное состояние приходит гарантированно. |
| `@:rpc(clients)` — только broadcast | События one-shot, ок. |
| CLID registration | NetRegistry.init() на обеих сторонах; HeroObject добавить. |
| `@:rpc` — без optional args | Держать сигнатуры фиксированными. |
| Serializable vs NetworkSerializable | HeroObject — второй (netId/dirty). Payload'ы (@:rpc args) — первый. |
| rnl `receiveCall` patch (`__rpcCaller`) | Нужен для map peerId→playerId (есть в AGENTS.md). |

---

## Ограничения архитектуры

### Что работает сейчас

- LobbyNet RPC facade ✅
- GameNet RPC facade (только события: heroInput/fire/bulletSpawn/damage) ✅
- SimWorld (физика + HeroSystem + BulletSystem) ✅
- ClientNet: `findMirror<T>` ✅ + `findObjects<T>` ✅
- RoomNetSystem (client) / NetRoomSystem (server) ✅
- EventBus, ClientEventBus / ServerEventBus ✅ (transport — подписчик, не шина)
- SyncBridge (shared/replication, #if sys) ✅
- ClientTransportSystem / ServerTransportSystem (Phase 5) ✅
- Room/GameNet/ServerTransport + DemoRoom (HeroObject на join, playerJoined, SyncBridge(true)) (Phase 6) ✅
- GamePlayView/RoomNetSystem: heroEnts poll, SyncBridge(false), wire handlers (Phase 7) ✅
- Прогон: server + 2 headless клиента видят HeroObject друг друга (Phase 8) ✅

### Что нужно построить (Pattern A)

- HeroObject (NetworkSerializable, @:s игровые поля) ✅
- ClientNet.findObjects<T> (все mirror'ы класса) ✅
- SyncBridge (единственное копирование body↔obj) ✅
- GameNet чистка (только события: heroInput/fire/bulletSpawn/damage) ✅
- Room.hx: GameNet + ServerTransportSystem ✅
- DemoRoom: HeroObject на join + net.add + SyncBridge(true) ✅
- GamePlayView: heroEnts map + SyncBridge(false) + wire handlers ✅
- RoomNetSystem / GamePlayView: poll findObjects(HeroObject) ✅

---

## Фазы

1. **HeroObject** + NetRegistry → компилится `server.hxml`/`win.hxml`/`web.hxml`
2. **ClientNet.findObjects<T>** (+ web-stub `[]`)
3. **SyncBridge** (push/pull, yaw из PhysBody TODO)
4. **GameNet** — чистка: убрать sendPosition/heroUpdate, оставить события
5. **ServerTransport / ClientTransport** — подписчики шины → GameNet
6. **Room.hx** — GameNet + ServerTransport; **DemoRoom** — HeroObject на join
7. **GamePlayView / RoomNetSystem** — heroEnts map, SyncBridge(false), wire handlers
8. **Сборки + прогон**: сервер, клиент; два клиента видят друг друга (позиция/HP)

---

## Решения (Pattern A)

- **Entity = NetworkSerializable (HeroObject).** Никаких WorldState/HeroState/playerData.
- **Единственная копия — позиция из Oimo** (SyncBridge, 1 строка на ось).
- **Двухканальность HP:** `@:s` авторитетный (33ms), `@:rpc` фидбек UI (мгновенно).
- **GameNet — только события.** Позиции/состояние — `@:s` per-entity.
- **Детерминизм — не гарантия:** будущая серверная пуля/куб = новый класс
  с `@:s` (тот же паттерн, локальное изменение типа).
- **`__syncChannel = 1`** на HeroObject (позиции unreliable, loss-tolerant).
- **Клиент узнаёт свой server-pid по имени** — из `@:s name` ПОЛЯ HeroObject
  (в ADD приходит имя владельца → матч с `playerName` на ADD-time, без гонок
  и повторного спавна своей сущности как remote). Dубликаты имён — прототип-ограничение.
- **Сервер НЕ доверяет client-supplied playerId** — `heroInput`/`fireBullet`
  не несут pid; сервер резолвит его из `__rpcCaller` → `playerByPeer`.
  Клиент физически не может вести чужого героя.
- **Камера/якорь привязаны ТОЛЬКО к локальному герою** — `setHero` регистрирует
  ключ ДО onSpawn, view биндит `player.mesh` только при `sim.hero == b`
  (remote-спавны не угоняют камеру и origin пуль).
- **SyncBridge.ownId** — клиент пропускает СВОЁ тело (prediction); имя — не
  константа Player.LOCAL, а server-id (для будущей смены ключей).
- **bulletSpawn(ownerId, ...)** — стрелявший клиент уже заспавнил пулю локально
  и пропускает эхо; remote-клиенты спавнят через `BulletSystem.spawnBullet()`
  НАПРЯМУЮ (в обход шины → нет эха RPC).
- **Серверный шина флашится в `Room.tick`** (`bus.flush()` после
  roomSystems.update) — RPC-handler'ы публикуют в шину, доставка в конце тика.
- **Remote-герои на клиенте = марионетки** (`spawnHero(pid, false)`, ни state,
  ни input): позицию и yaw каждый тик ставит SyncBridge pull; HeroSystem
  применяется только к локальному (prediction) и серверным героям.

---

## Вопросы (решённые)

- Q1: **поворот remote-героев** — `@:s yaw` на HeroObject; push извлекает yaw из
  Quat (инверсия сеттера HeroSystem.apply: `yaw = -2*atan2(q.y, q.w)`), pull
  прикладывает тем же Quat. Remote-герои на клиенте — МАРИОНЕТКИ: `spawnHero(pid, false)`
  без state → HeroSystem не перетирает ориентацию/скорость (только локальный игрок
  симулируется предсказательно, серверные тела латчатся к зеркалу).
- Q2: **DamageSystem** — логика в BulletSystem: пересечение скорости пули с
  позицией героя → `sim.heroEnts[pid].hp -= d` → `PlayerDamaged` →
  ServerTransport → `gameNet.damage`. (урон-фидбек `@:rpc`, HP-состояние `@:s`)
- Q3: **HeroObject.spawn** — DemoRoom на join (серверный lifecycle), HeroSystem
  не знает о сети.
- Q4: **LATE-JOIN** — FULLSYNC шлёт полное состояние всех HeroObject'ов
  автоматически (подтверждено прогоном: Bob сразу увидел p1). Доп. логика не нужна.

---

## Статус

- [x] Phase 1: HeroObject + NetRegistry
- [x] Phase 2: ClientNet.findObjects<T>
- [x] Phase 3: SyncBridge
- [x] Phase 4: GameNet — чистка
- [x] Phase 5: TransportSystems (client/server)
- [x] Phase 6: Room.hx / DemoRoom (+ GameNet, HeroObject)
- [x] Phase 7: GamePlayView / RoomNetSystem
- [x] Phase 8: Сборки + прогон