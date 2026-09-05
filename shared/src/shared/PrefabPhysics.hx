package shared;

import haxe.Json;

import oimo.collision.geometry.BoxGeometry;
import oimo.common.Mat3;
import oimo.common.Vec3;
import oimo.dynamics.rigidbody.RigidBodyType;

import phys.core.IPhysics;
import phys.core.PhysBody;

/** World-space context handed to a spawn handler (accumulated parent transform). */
typedef PrefabSpawnCtx = {
	phys : IPhysics,
	pos : Vec3,
	rot : Mat3,
	scale : Vec3,
	obj : Dynamic,
	spawned : Array<PhysBody>,
};

/** A spawn handler: spawn bodies for one prefab object from `ctx.obj` + world transform. */
typedef PrefabObjHandler = PrefabSpawnCtx -> Void;

/**
	Строит физические коллайдеры из hide-префаба уровня, руководствуясь его
	обычным JSON-представлением — а НЕ через `hrt.prefab`. Это отвязывает
	геометрию уровня от hide-рантайма, поэтому один и тот же класс работает
	везде, где идёт симуляция:
	- клиент HL (`#if hide`): префаб также даёт визуал; здесь мы лишь добавляем
	  статические коллайдеры (пол, колонны, ...).
	- сервер (headless, без heaps): читает тот же файл `.prefab` с диска через
	  `sys.io.File` — идентичные коллайдеры без дублирования кода.
	- web (JS): поддержки hide нет, поэтому игра строит уровень процедурно и
	  вообще не вызывает этот класс.

	## Данные префаба

	Префаб hide — это файл `.prefab` = один JSON-объект с `type`, `name`,
	опциональным трансформом (`x/y/z`, `scaleX/Y/Z`, `rotationX/Y/Z` в
	градусах) и опциональными `children` (вложенные объекты). Обход дерева
	накапливает трансформы родителей, так что вложенные объекты попадают в
	правильное мировое пространство. Объекты с `enabled == false` /
	`editorOnly == true` пропускаются (`skipInvisible`).

	## Встроенный обработчик: "box"

	Префаб hide `Box` — это единичный куб, растянутый через `scaleX/Y/Z`,
	поэтому он становится СТАТИЧЕСКИМ коллайдером `BoxGeometry` с полуразмерами
	= `0.5 * scale` и накопленным мировым вращением (порядок совпадает с
	`h3d.Matrix.initRotation`: `Rz*Ry*Rx`).

	## Расширение (главная цель дизайна)

	Спавн — это реестр обработчиков по `type` (`registerHandler`). Чтобы
	добавить новый коллайдер (сфера, террейн, выпуклая оболочка из модели,
	динамические ящики, ...), зарегистрируйте обработчик для нужного `type`
	префаба — менять этот класс не нужно:
	```
	var pp = new PrefabPhysics(sim.phys);
	pp.registerHandler("terrain", (ctx) -> {
		// ctx.obj — сырой объект префаба, ctx.pos/rot/scale — мировой трансформ
		TerrainBody.build(ctx.phys, fieldFrom(ctx.obj), ...);
	});
	pp.registerHandler("crate", (ctx) -> {
		var b = ctx.phys.spawnBody(RigidBodyType._DYNAMIC, ctx.pos, "crate");
		b.addBox(ctx.scale.x * 0.5, ctx.scale.y * 0.5, ctx.scale.z * 0.5);
		ctx.spawned.push(b);
	});
	```
	Обработчики сами решают, что читать из `ctx.obj` (доп. поля вроде `props`,
	`dynamic`, ... остаются на их усмотрение). `onSpawned` вызывается для
	каждого созданного тела, чтобы потребители могли привязать визуал (клиент)
	или залогировать (сервер).

	## Использование (клиент, под `#if hide`)

	```
	var prefabPhys = new PrefabPhysics(sim.phys);
	prefabPhys.load(PrefabPhysics.defaultLevelPath("levels/test.prefab"));
	```
**/
class PrefabPhysics {

	/** Context a spawn handler receives (accumulated world transform + raw obj). */
	public var handlers : Map<String, PrefabObjHandler>;

	/** Called for every body this class spawns (client: bind visuals / server: log). */
	public var onSpawned : Null<PhysBody -> Dynamic -> Void>;

	/** Skip objects with `enabled == false` / `editorOnly == true`. */
	public var skipInvisible : Bool = true;

	final phys : IPhysics;

	public function new(phys : IPhysics) {
		this.phys = phys;
		handlers = new Map();
		registerDefaultHandlers();
	}

	/** Register a spawn handler for a prefab `type` (e.g. "box", "terrain", ...). */
	public function registerHandler(type : String, h : PrefabObjHandler) : Void {
		handlers.set(type, h);
	}

	public function unregisterHandler(type : String) : Void {
		handlers.remove(type);
	}

	/** Default "box" handler — a scaled unit cube becomes a STATIC box collider. */
	function registerDefaultHandlers() : Void {
		registerHandler("box", spawnBox);
	}

	/**
		Read a prefab from the platform-appropriate source and spawn its bodies.
		`path`:
		- client (`#if heapsphysics_render`, HL+web): resource path, e.g. "levels/test.prefab"
		- server (headless): filesystem path relative to CWD, e.g. "client/res/levels/test.prefab"
	**/
	public function load(path : String) : Array<PhysBody> {
		#if heapsphysics_render
		return parse(hxd.Res.load(path).toText());
		#else
		return parse(sys.io.File.getContent(path));
		#end
	}

	/**
		Resolve a prefab resource path for this build type.
		`path` is the resource path (e.g. "levels/test.prefab"):
		- client (`#if heapsphysics_render`, HL+web): used as-is via `hxd.Res`,
		- server (headless): prefixed with the resources dir so `sys.io.File` finds it.
	**/
	public static function defaultLevelPath(path : String) : String {
		#if heapsphysics_render
		return path;
		#else
		return "res/" + path;
		#end
	}

	/** Parse prefab JSON text and spawn bodies (pure — unit-testable). */
	public function parse(content : String) : Array<PhysBody> {
		var spawned : Array<PhysBody> = [];
		var data = Json.parse(content);
		var children : Array<Dynamic> = Reflect.field(data, "children");
		if (children == null)
			return spawned;
		var identity = new Mat3();
		identity.identity();
		for (c in children)
			walk(c, new Vec3(), identity, new Vec3(1, 1, 1), spawned);
		return spawned;
	}

	function walk(obj : Dynamic, pos : Vec3, rot : Mat3, scale : Vec3, spawned : Array<PhysBody>) : Void {
		if (skipInvisible) {
			if (Reflect.field(obj, "enabled") == false) return;
			if (Reflect.field(obj, "editorOnly") == true) return;
		}

		// local transform
		var lx = nf(obj, "x"), ly = nf(obj, "y"), lz = nf(obj, "z");
		var lsx = nf1(obj, "scaleX"), lsy = nf1(obj, "scaleY"), lsz = nf1(obj, "scaleZ");
		var lrx = rad(obj, "rotationX");
		var lry = rad(obj, "rotationY");
		var lrz = rad(obj, "rotationZ");

		// localRot = Rz * Ry * Rx — matches h3d.Matrix.initRotation (Object3D.applyTransform)
		var localRot = new Mat3();
		localRot.identity();
		localRot.prependRotation(lrx, 1, 0, 0);
		localRot.prependRotation(lry, 0, 1, 0);
		localRot.prependRotation(lrz, 0, 0, 1);
		var worldRot = rot.mul(localRot);

		// world scale = parent scale * local scale (diagonal only, no shear)
		var worldScale = scale.scale3(lsx, lsy, lsz);

		// world pos = parent pos + parentRot * (parentScale * local pos)
		var localPos = new Vec3(lx * scale.x, ly * scale.y, lz * scale.z);
		var worldPos = pos.add(localPos.mulMat3(rot));

		// spawn via handler for this object's type
		var type : Dynamic = Reflect.field(obj, "type");
		if (type != null) {
			var h = handlers.get(Std.string(type));
			if (h != null)
				h({ phys : phys, pos : worldPos, rot : worldRot, scale : worldScale, obj : obj, spawned : spawned });
		}

		// recurse (unknown types still act as transform containers)
		var children : Array<Dynamic> = Reflect.field(obj, "children");
		if (children != null)
			for (c in children)
				walk(c, worldPos, worldRot, worldScale, spawned);
	}

	/** Built-in: a hide Box (unit cube scaled by scaleX/Y/Z) -> STATIC box collider. */
	function spawnBox(ctx : PrefabSpawnCtx) : Void {
		var hx = ctx.scale.x * 0.5;
		var hy = ctx.scale.y * 0.5;
		var hz = ctx.scale.z * 0.5;
		var name : Dynamic = Reflect.field(ctx.obj, "name");
		var b = ctx.phys.spawnBody(RigidBodyType._STATIC, ctx.pos, name != null ? Std.string(name) : null);
		b.addShape(new BoxGeometry(new Vec3(hx, hy, hz)), null, ctx.rot);
		ctx.spawned.push(b);
		if (onSpawned != null) onSpawned(b, ctx.obj);
	}

	static inline function nf(o : Dynamic, f : String) : Float {
		var v : Dynamic = Reflect.field(o, f);
		return Std.isOfType(v, Float) ? v : 0.0;
	}

	static inline function nf1(o : Dynamic, f : String) : Float {
		var v : Dynamic = Reflect.field(o, f);
		return Std.isOfType(v, Float) ? v : 1.0;
	}

	static inline function rad(o : Dynamic, f : String) : Float {
		return nf(o, f) * Math.PI / 180;
	}
}
