extends Control

const VERSION := "0.4.0"

const FIELD_LEFT := 360.0
const FIELD_RIGHT := 1280.0
const ENEMY_SPAWN_X := 1320.0
const ALLY_SPEED := 55.0
const ENEMY_SPEED := 38.0
const QUEUE_GAP := 26.0
const FIGHT_RANGE := 30.0
const ATTACK_INTERVAL := 0.5
const SPAWN_BASE_COST := 10.0
const SPAWN_INTERVAL := 1.5
const WAVE_INTERVAL := 12.0
const BASE_HP_MAX := 50
const ALLY_CAP := 500
const ENEMY_CAP := 120
const BALL_COST := 15.0
const COLLAPSE_AT := 300  # この数を超えるとステージが崩壊する
const TREMOR_FROM := 120  # 床が揺れ始める数

const UNIT_ZUNDA := preload("res://assets/unit_zunda.svg")
const UNIT_KOGE := preload("res://assets/unit_koge.svg")
const ZUNDA_TEXTURES := {
	"normal": preload("res://assets/characters/zundamon_normal.png"),
	"happy": preload("res://assets/characters/zundamon_happy.png"),
	"sad": preload("res://assets/characters/zundamon_sad.png"),
	"surprised": preload("res://assets/characters/zundamon_surprised.png"),
}
const SFX := {
	"spawn": preload("res://assets/audio/spawn.wav"),
	"creak": preload("res://assets/audio/creak.wav"),
	"collapse": preload("res://assets/audio/collapse.wav"),
	"hit": preload("res://assets/audio/hit.wav"),
	"kill": preload("res://assets/audio/kill.wav"),
	"lost": preload("res://assets/audio/lost.wav"),
	"build": preload("res://assets/audio/build.wav"),
	"wave": preload("res://assets/audio/wave.wav"),
	"advance": preload("res://assets/audio/advance.wav"),
	"lose": preload("res://assets/audio/lose.wav"),
}

# 特性。unlock: nullなら初期解禁。{key, v, label}は解禁条件。
const TRAITS := {
	"bomb": {"name": "爆発", "icon": "爆", "cost": 4.0, "color": Color(0.9, 0.45, 0.2),
		"desc": "倒れるとき自爆して周囲の敵にダメージ8", "unlock": null},
	"swift": {"name": "俊足", "icon": "速", "cost": 3.0, "color": Color(0.4, 0.7, 0.9),
		"desc": "移動速度×1.8 / HP×0.7", "unlock": null},
	"split": {"name": "分裂", "icon": "分", "cost": 6.0, "color": Color(0.55, 0.8, 0.45),
		"desc": "敵を倒すと35%で素のずんだもんが生える",
		"unlock": {"key": "kills", "v": 10, "label": "敵を累計10体倒す"}},
	"glutton": {"name": "大食い", "icon": "食", "cost": 15.0, "color": Color(0.85, 0.6, 0.25),
		"desc": "攻撃×2.5。ただし生産コスト重め",
		"unlock": {"key": "kills", "v": 25, "label": "敵を累計25体倒す"}},
	"mogu": {"name": "もぐもぐ", "icon": "も", "cost": 6.0, "color": Color(0.7, 0.5, 0.8),
		"desc": "敵を倒すたび成長(攻+1 HP+2、最大10回)。育つと大きくなる",
		"unlock": {"key": "spawned", "v": 25, "label": "ずんだもんを累計25体生産"}},
	"tank": {"name": "鉄のもち肌", "icon": "硬", "cost": 8.0, "color": Color(0.55, 0.55, 0.6),
		"desc": "HP×2.5 / 移動速度×0.6",
		"unlock": {"key": "losses", "v": 15, "label": "ずんだもんを累計15体失う"}},
	"bigbomb": {"name": "大爆発", "icon": "轟", "cost": 10.0, "color": Color(0.95, 0.3, 0.15),
		"desc": "自爆が大型化(範囲↑ ダメージ22)",
		"unlock": {"key": "bomb_kills", "v": 15, "label": "自爆で累計15体倒す"}},
	"golden": {"name": "黄金ずんだ", "icon": "金", "cost": 8.0, "color": Color(0.9, 0.75, 0.2),
		"desc": "この個体の撃破報酬×2",
		"unlock": {"key": "zunda_earned", "v": 400, "label": "ずんだを累計400獲得"}},
}
const LINE_B_UNLOCK := {"key": "spawned", "v": 15, "label": "ずんだもんを累計15体生産"}

# 敵タイプ(じゃんけん相性)
const ENEMY_TYPES := {
	"koge": {"name": "こげパン兵", "hp": 1.0, "speed": 1.0, "atk": 1.0, "interval": 0.5,
		"armor": 0.0, "bomb_mult": 1.0, "reward": 1.0, "scale": 1.0,
		"tint": Color.WHITE, "hint": ""},
	"kata": {"name": "かたパン", "hp": 3.0, "speed": 0.55, "atk": 1.2, "interval": 0.6,
		"armor": 2.0, "bomb_mult": 2.0, "reward": 1.6, "scale": 1.15,
		"tint": Color(0.62, 0.68, 0.85), "hint": "かたい! 爆発(2倍)か大食いの大火力で砕くのだ"},
	"haya": {"name": "はやパン", "hp": 0.5, "speed": 2.2, "atk": 0.8, "interval": 0.25,
		"armor": 0.0, "bomb_mult": 1.0, "reward": 1.2, "scale": 0.85,
		"tint": Color(1.0, 0.82, 0.45), "hint": "はやい! 安い量産型の数で受け止めるのだ"},
	"shime": {"name": "しめりパン", "hp": 1.4, "speed": 0.9, "atk": 1.0, "interval": 0.5,
		"armor": 0.0, "bomb_mult": 0.0, "reward": 1.3, "scale": 1.0,
		"tint": Color(0.5, 0.8, 0.85), "hint": "湿ってて爆発が効かないのだ! 通常攻撃で殴るのだ"},
	"boss": {"name": "食パン1号", "hp": 22.0, "speed": 0.45, "atk": 3.0, "interval": 0.7,
		"armor": 1.0, "bomb_mult": 1.0, "reward": 10.0, "scale": 1.8,
		"tint": Color(0.85, 0.75, 0.6), "hint": "ボスなのだ!! 総力戦なのだ!!"},
}

const COMMANDER_LINES := {
	"wave": ["敵が来るのだ!", "こげパン軍団なのだ!"],
	"kill_streak": ["押してるのだ!いいぞなのだ!", "物量こそ正義なのだ!"],
	"swarm": ["ボクの軍団…壮観なのだ…", "画面がずんだ色なのだ!"],
	"starve": ["ずんだが足りないのだ!畑を増やすのだ!", "培養槽が止まってるのだ…"],
	"base_hit": ["工場が攻撃されてるのだ!?", "やばいのだ!守るのだ!"],
	"overrun": ["泉が守ってくれたのだ…たすかったのだ", "押し戻されたのだ…品種を見直すのだ"],
	"unlock": ["新しい特性を開発したのだ!!", "研究が進んだのだ!"],
	"ball": ["ずんだボールなのだ!集まるのだ!"],
	"creak": ["な、なんか床が鳴ってるのだ…", "過密すぎるのだ…床が…", "みしみし言ってるのだ!?"],
	"recall": ["ごめんなのだ…何体か畑に帰ってもらうのだ", "非常人員なのだ…ゆるすのだ…"],
	"ration": ["ボクのへそくりずんだなのだ…使うのだ", "緊急配給なのだ!"],
	"collapse": ["ゆ、床が抜けたのだーーー!!", "ステージごと崩壊なのだ!?!?"],
	"newstage": ["地下に新しいフロアがあったのだ!広いのだ!", "ここなら もっと増やせるのだ…ふふふなのだ"],
	"idle": ["特性の組み合わせで化けるのだ", "「全部強化」が正解とは限らないのだ", "フィールドをクリックすると群れを呼べるのだ", "300体超えたら床が…どうなるのだろうな…"],
}

# 経済
var zunda := 100.0
var farms := 1
var starving := false
# 実測フロー(1秒ごとに集計してUIに出す)
var _acc := {"farm": 0.0, "kill": 0.0, "spent": 0.0}
var flow_rates := {"farm": 0.0, "kill": 0.0, "spent": 0.0}

# 品種ライン
var lines: Array = [
	{"name": "品種A", "traits": ["", "", ""], "spawners": 1, "credit": 0.0, "unlocked": true, "active": true},
	{"name": "品種B", "traits": ["", "", ""], "spawners": 0, "credit": 0.0, "unlocked": false, "active": true},
]
var starve_time := 0.0
var unlocked_traits: Array = ["bomb", "swift"]

# 進行カウンタ(解禁条件用)
var counters := {"kills": 0, "bomb_kills": 0, "losses": 0, "spawned": 0, "zunda_earned": 0}

# 戦闘
var allies: Array = []
var enemies: Array = []
var wave := 0
var wave_timer := 10.0
var next_theme := "koge"
var lane_ys: Array = [200.0, 300.0, 400.0, 500.0, 600.0]
var stage_level := 0
var collapsing := false
var creak_warned := 0
var field_nodes: Array = []
var stage_bar: ProgressBar
var stage_label: Label
var base_hp := BASE_HP_MAX
var overruns := 0

# UI/ノード
var battle_layer: Node2D
var sfx_players := {}
var stock_label: Label
var flow_label: Label
var army_label: Label
var wave_label: Label
var base_bar: ProgressBar
var farm_button: Button
var line_boxes: Array = []
var commander: TextureRect
var bubble: PanelContainer
var bubble_label: Label
var speak_token := 0
var overlay: Control = null
var _last_sfx := {}

@onready var background: ColorRect = $Background


func _ready() -> void:
	GameLog.info("起動 ずんだもん増殖工場 v%s (platform=%s)" % [VERSION, OS.get_name()])
	battle_layer = $BattleLayer
	# 背景がクリックを食うとフィールドクリック(ずんだボール)が届かない
	$Background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$FactoryPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_audio()
	_setup_field()
	_setup_factory_panel()
	_setup_commander()
	var idle := Timer.new()
	idle.wait_time = 18.0
	idle.autostart = true
	idle.timeout.connect(func() -> void:
		if not bubble.visible:
			_say("idle")
	)
	add_child(idle)
	var hb := Timer.new()
	hb.wait_time = 1.0
	hb.autostart = true
	hb.timeout.connect(func() -> void:
		_check_unlocks()
		for key in _acc:
			flow_rates[key] = _acc[key]
			_acc[key] = 0.0
		if OS.has_feature("web"):
			JavaScriptBridge.eval("try{localStorage.setItem('zf_hb',''+Date.now())}catch(e){}")
	)
	add_child(hb)


func _process(delta: float) -> void:
	if collapsing:
		return
	_update_economy(delta)
	_update_waves(delta)
	_update_units(delta)
	_update_tremor()
	_update_ui()


func _update_tremor() -> void:
	# 過密になるほど床が揺れ、きしみ、傾く
	var load_count := allies.size()
	if load_count < TREMOR_FROM:
		battle_layer.position = Vector2.ZERO
		battle_layer.rotation = 0.0
		return
	var intensity := (load_count - TREMOR_FROM) / float(COLLAPSE_AT - TREMOR_FROM)
	battle_layer.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * 6.0
	battle_layer.rotation = sin(Time.get_ticks_msec() / 300.0) * intensity * 0.012
	if intensity > 0.4 and creak_warned < 1:
		creak_warned = 1
		_play("creak")
		_say("creak", 3.0)
	if intensity > 0.8 and creak_warned < 2:
		creak_warned = 2
		_play("creak", 0.7)
		_say("creak", 3.0)
		_flash_background(Color(0.9, 0.85, 0.75))
	if load_count >= COLLAPSE_AT:
		_trigger_collapse()


func _gui_input(event: InputEvent) -> void:
	# フィールドクリック = ずんだボール(群れを呼び寄せる)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x > FIELD_LEFT + 20 and zunda >= BALL_COST and overlay == null:
			_throw_ball(event.position)


# --- 経済・生産 ---

func _income() -> float:
	return farms * 6.0


func _line_unit_cost(line: Dictionary) -> float:
	var cost := SPAWN_BASE_COST
	for trait_id in line["traits"]:
		if trait_id != "":
			cost += TRAITS[trait_id]["cost"]
	return cost


func _total_consumption() -> float:
	var total := 0.0
	for line in lines:
		if line["active"]:
			total += line["spawners"] / SPAWN_INTERVAL * _line_unit_cost(line)
	return total


func _update_economy(delta: float) -> void:
	zunda += _income() * delta
	_acc["farm"] += _income() * delta
	var was_starving := starving
	starving = false
	for line in lines:
		if line["spawners"] <= 0 or not line["active"]:
			continue
		line["credit"] += line["spawners"] * delta / SPAWN_INTERVAL
		while line["credit"] >= 1.0:
			line["credit"] -= 1.0
			var cost := _line_unit_cost(line)
			if zunda < cost:
				starving = true
				break
			if allies.size() >= ALLY_CAP:
				break
			zunda -= cost
			_acc["spent"] += cost
			_spawn_ally(line)
	if starving and not was_starving and randf() < 0.4:
		_say("starve")
	# 欠乏が続いたら自動で立て直す(操作不能の防止)
	if starving:
		starve_time += delta
		if starve_time >= 8.0:
			_emergency_recall()
			starve_time = 4.0  # 続くなら4秒ごとに繰り返す
	else:
		starve_time = 0.0


func _emergency_recall() -> void:
	if allies.size() > 0:
		# 後方(工場寄り)のずんだもんから最大3体を畑に帰してずんだに再変換
		var sorted := allies.duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])
		var count := mini(3, sorted.size())
		for i in count:
			var unit: Dictionary = sorted[i]
			allies.erase(unit)
			_burst(Vector2(unit["x"], lane_ys[unit["lane"]]), Color(0.7, 0.9, 0.5), 8)
			unit["sprite"].queue_free()
			_gain_zunda(25.0)
			_acc["farm"] += 25.0
		_say("recall", 3.0)
		_toast_label("緊急帰農: %d体が畑へ (+%d)" % [count, count * 25])
		GameLog.info("緊急帰農: %d体 → ずんだ+%d" % [count, count * 25])
	else:
		# 軍団すらいない: 司令官の非常配給で最低限の再起動を保証
		_gain_zunda(40.0)
		_acc["farm"] += 40.0
		_say("ration", 3.0)
		_toast_label("緊急配給 +40")
		GameLog.info("緊急配給 +40")


func _gain_zunda(amount: float) -> void:
	zunda += amount
	counters["zunda_earned"] += int(amount)


func _farm_cost() -> float:
	return snappedf(20.0 * pow(1.5, farms - 1), 1.0)


func _spawner_cost(line: Dictionary) -> float:
	return snappedf(50.0 * pow(1.6, line["spawners"]), 1.0)


# --- 特性解禁 ---

func _check_unlocks() -> void:
	for trait_id in TRAITS:
		if trait_id in unlocked_traits:
			continue
		var condition: Variant = TRAITS[trait_id]["unlock"]
		if condition != null and counters[condition["key"]] >= condition["v"]:
			unlocked_traits.append(trait_id)
			_announce_unlock("特性「%s」解禁! — %s" % [TRAITS[trait_id]["name"], TRAITS[trait_id]["desc"]])
	if not lines[1]["unlocked"] and counters[LINE_B_UNLOCK["key"]] >= LINE_B_UNLOCK["v"]:
		lines[1]["unlocked"] = true
		_announce_unlock("品種ラインB 解禁! 2種類の品種を同時生産できるのだ")
		_rebuild_factory_panel()


func _announce_unlock(text: String) -> void:
	GameLog.info("解禁: %s" % text)
	_play("advance")
	_say("unlock", 3.0)
	_toast_label(text)


# --- ユニット ---

func _make_unit_sprite(texture: Texture2D, tint: Color = Color.WHITE) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(0.55, 0.55)
	sprite.modulate = tint
	battle_layer.add_child(sprite)
	return sprite


func _spawn_ally(line: Dictionary, free_basic := false) -> void:
	var traits: Array = [] if free_basic else line["traits"].filter(func(t: String) -> bool: return t != "")
	var atk := 2.0
	var hp := 10.0
	var speed := ALLY_SPEED
	var tint := Color.WHITE
	for trait_id in traits:
		match trait_id:
			"swift": speed *= 1.8; hp *= 0.7
			"glutton": atk *= 2.5
			"tank": hp *= 2.5; speed *= 0.6
		tint = tint.lerp(TRAITS[trait_id]["color"], 0.25)
	var unit := {
		"sprite": _make_unit_sprite(UNIT_ZUNDA, tint),
		"lane": randi() % lane_ys.size(),
		"x": FIELD_LEFT + randf_range(0, 20),
		"hp": hp, "hp_max": hp, "atk": atk, "speed": speed,
		"cd": randf_range(0.0, ATTACK_INTERVAL),
		"traits": traits, "mogu": 0,
		"boost": 0.0, "bob": randf() * TAU,
	}
	allies.append(unit)
	counters["spawned"] += 1
	_play_throttled("spawn", 0.1, randf_range(0.9, 1.2))
	if counters["spawned"] == 60:
		_say("swarm")


func _spawn_enemy(type_id: String, mult: float) -> void:
	if enemies.size() >= ENEMY_CAP:
		return
	var t: Dictionary = ENEMY_TYPES[type_id]
	var hp: float = 8.0 * t["hp"] * mult
	var unit := {
		"sprite": _make_unit_sprite(UNIT_KOGE, t["tint"]),
		"type": type_id,
		"lane": randi() % lane_ys.size(),
		"x": ENEMY_SPAWN_X + randf_range(0, 60),
		"hp": hp, "hp_max": hp,
		"atk": (2.0 + wave * 0.3) * t["atk"],
		"speed": ENEMY_SPEED * t["speed"],
		"interval": t["interval"],
		"armor": t["armor"],
		"cd": randf_range(0.0, 0.5),
		"bob": randf() * TAU,
	}
	unit["sprite"].scale = Vector2(0.55, 0.55) * t["scale"]
	enemies.append(unit)


func _pick_theme() -> String:
	if (wave + 1) % 5 == 0:
		return "boss"
	if wave < 2:
		return "koge"
	return ["koge", "kata", "haya", "shime"][randi() % 4]


func _update_waves(delta: float) -> void:
	wave_timer -= delta
	if wave_timer > 0.0:
		return
	wave += 1
	wave_timer = WAVE_INTERVAL
	var theme := next_theme
	next_theme = _pick_theme()
	# 軍団が大きいほど・深層ほど波も強くなる(勝ちすぎ防止のラバーバンド)
	var count := 2 + wave + allies.size() / 35
	var mult := pow(1.13, wave) * pow(1.25, stage_level)
	if theme == "boss":
		_spawn_enemy("boss", mult)
		for i in maxi(2, count / 2):
			_spawn_enemy("koge", mult)
	else:
		for i in count:
			_spawn_enemy(theme if randf() < 0.65 else "koge", mult)
	_play("wave")
	var t: Dictionary = ENEMY_TYPES[theme]
	if t["hint"] != "":
		_toast_label("ウェーブ%d: %s襲来! %s" % [wave, t["name"], t["hint"]])
		_say("wave", 2.5)
	elif wave % 3 == 1:
		_say("wave")
	GameLog.info("ウェーブ%d: %s %d体 (×%.2f) / 軍団%d ずんだ%d / 次=%s" % [
		wave, t["name"], count, mult, allies.size(), int(zunda), ENEMY_TYPES[next_theme]["name"]])


func _front(units: Array, lane: int, rightmost: bool) -> Dictionary:
	var best := {}
	for unit in units:
		if unit["lane"] != lane:
			continue
		if best.is_empty() or (unit["x"] > best["x"]) == rightmost:
			best = unit
	return best


func _update_units(delta: float) -> void:
	var dead_allies: Array = []
	var dead_enemies: Array = []
	for lane in lane_ys.size():
		var front_ally := _front(allies, lane, true)
		var front_enemy := _front(enemies, lane, false)
		var clash: bool = not front_ally.is_empty() and not front_enemy.is_empty() \
			and front_enemy["x"] - front_ally["x"] <= FIGHT_RANGE
		if clash:
			front_ally["cd"] -= delta
			front_enemy["cd"] -= delta
			if front_ally["cd"] <= 0.0:
				front_ally["cd"] = ATTACK_INTERVAL
				front_enemy["hp"] -= maxf(1.0, front_ally["atk"] - front_enemy["armor"])
				_play_throttled("hit", 0.09, randf_range(0.9, 1.2))
				_flash(front_enemy)
				if front_enemy["hp"] <= 0 and not (front_enemy in dead_enemies):
					dead_enemies.append(front_enemy)
					_on_enemy_killed(front_enemy, front_ally)
			if front_enemy["cd"] <= 0.0:
				front_enemy["cd"] = front_enemy["interval"]
				front_ally["hp"] -= front_enemy["atk"]
				_flash(front_ally)
				if front_ally["hp"] <= 0 and not (front_ally in dead_allies):
					dead_allies.append(front_ally)
	# 移動(レーンごとにソートして前詰まり判定をO(n)に)
	var lane_allies: Array = []
	var lane_enemies: Array = []
	for i in lane_ys.size():
		lane_allies.append([])
		lane_enemies.append([])
	for unit in allies:
		if unit["boost"] > 0.0:
			unit["boost"] -= delta
		unit["lane"] = mini(unit["lane"], lane_ys.size() - 1)
		lane_allies[unit["lane"]].append(unit)
	for unit in enemies:
		unit["lane"] = mini(unit["lane"], lane_ys.size() - 1)
		lane_enemies[unit["lane"]].append(unit)
	for i in lane_ys.size():
		var ally_arr: Array = lane_allies[i]
		var enemy_arr: Array = lane_enemies[i]
		ally_arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] > b["x"])
		enemy_arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["x"] < b["x"])
		var enemy_front_x: float = enemy_arr[0]["x"] if enemy_arr.size() > 0 else INF
		var ahead_x := INF
		for unit in ally_arr:
			var blocked: bool = (ahead_x - unit["x"] < QUEUE_GAP) or (enemy_front_x - unit["x"] <= FIGHT_RANGE)
			if not blocked:
				var speed: float = unit["speed"] * (2.0 if unit["boost"] > 0.0 else 1.0)
				unit["x"] = minf(unit["x"] + speed * delta, FIELD_RIGHT + 30.0)
			ahead_x = unit["x"]
		var ally_front_x: float = ally_arr[0]["x"] if ally_arr.size() > 0 else -INF
		var ahead_ex := -INF
		for unit in enemy_arr:
			var blocked: bool = (unit["x"] - ahead_ex < QUEUE_GAP) or (unit["x"] - ally_front_x <= FIGHT_RANGE)
			if not blocked:
				unit["x"] -= unit["speed"] * delta
			ahead_ex = unit["x"]
			if unit["x"] <= FIELD_LEFT:
				base_hp -= 2
				if not (unit in dead_enemies):
					dead_enemies.append(unit)
				_play_throttled("lost", 0.2)
				_say("base_hit", 2.5)
				_shake_factory()
				if base_hp <= 0:
					_overrun()
					return
	# 死亡処理(敵)
	for unit in dead_enemies:
		if unit in enemies:
			enemies.erase(unit)
			_burst(Vector2(unit["x"], lane_ys[unit["lane"]]), Color(0.4, 0.3, 0.2))
			unit["sprite"].queue_free()
	# 死亡処理(味方) — 爆発はここで連鎖する
	for unit in dead_allies:
		if unit in allies:
			allies.erase(unit)
			counters["losses"] += 1
			_explode_if_bomber(unit)
			_burst(Vector2(unit["x"], lane_ys[unit["lane"]]), Color(0.6, 0.85, 0.5))
			unit["sprite"].queue_free()
			_play_throttled("lost", 0.15)
	# 描画
	var t := Time.get_ticks_msec() / 1000.0
	for unit in allies:
		var grow: float = 1.0 + unit["mogu"] * 0.06
		unit["sprite"].scale = Vector2(0.55, 0.55) * grow
		unit["sprite"].position = Vector2(unit["x"], lane_ys[unit["lane"]] + sin(t * 6.0 + unit["bob"]) * 3.0)
	for unit in enemies:
		unit["sprite"].position = Vector2(unit["x"], lane_ys[unit["lane"]] + sin(t * 5.0 + unit["bob"]) * 2.0)


func _on_enemy_killed(enemy: Dictionary, killer: Dictionary) -> void:
	counters["kills"] += 1
	var reward: float = (6.0 + wave) * ENEMY_TYPES[enemy.get("type", "koge")]["reward"]
	if "golden" in killer.get("traits", []):
		reward *= 2.0
	_gain_zunda(reward)
	_acc["kill"] += reward
	if enemy.get("type", "koge") == "boss":
		_toast_label("食パン1号 撃破!! +%d" % int(reward))
		_play("advance")
	_play_throttled("kill", 0.06, randf_range(0.9, 1.15))
	# 分裂: 倒した個体の足元から素のずんだもんが生える
	if "split" in killer.get("traits", []) and randf() < 0.35 and allies.size() < ALLY_CAP:
		_spawn_ally(lines[0], true)
		var newborn: Dictionary = allies[allies.size() - 1]
		newborn["lane"] = killer["lane"]
		newborn["x"] = killer["x"] - 10.0
	# もぐもぐ: 食べて育つ
	if "mogu" in killer.get("traits", []) and killer["mogu"] < 10:
		killer["mogu"] += 1
		killer["atk"] += 1.0
		killer["hp"] = minf(killer["hp"] + 2.0, killer["hp_max"] + killer["mogu"] * 2.0)
	if counters["kills"] % 30 == 0:
		_say("kill_streak", 2.5)


func _explode_if_bomber(unit: Dictionary) -> void:
	var traits: Array = unit.get("traits", [])
	var big := "bigbomb" in traits
	if not big and not ("bomb" in traits):
		return
	var radius := 110.0 if big else 70.0
	var damage := 22.0 if big else 8.0
	var pos := Vector2(unit["x"], lane_ys[unit["lane"]])
	_burst(pos, Color(1.0, 0.55, 0.15), 24)
	_play_throttled("kill", 0.05, 0.7)
	var killed: Array = []
	for enemy in enemies:
		var enemy_pos := Vector2(enemy["x"], lane_ys[enemy["lane"]])
		if pos.distance_to(enemy_pos) <= radius:
			# じゃんけん: かたパンには2倍、しめりパンには無効
			var edmg: float = damage * ENEMY_TYPES[enemy.get("type", "koge")]["bomb_mult"]
			if edmg <= 0.0:
				continue
			enemy["hp"] -= edmg
			_flash(enemy)
			if enemy["hp"] <= 0:
				killed.append(enemy)
	for enemy in killed:
		enemies.erase(enemy)
		counters["kills"] += 1
		counters["bomb_kills"] += 1
		var reward: float = (6.0 + wave) * ENEMY_TYPES[enemy.get("type", "koge")]["reward"]
		_gain_zunda(reward)
		_acc["kill"] += reward
		_burst(Vector2(enemy["x"], lane_ys[enemy["lane"]]), Color(0.4, 0.3, 0.2))
		enemy["sprite"].queue_free()


# --- ずんだボール(介入) ---

func _throw_ball(pos: Vector2) -> void:
	zunda -= BALL_COST
	_say("ball", 2.0)
	_play("spawn", 0.7)
	# 着弾マーク
	_burst(pos, Color(0.6, 0.9, 0.4), 16)
	# 近くの味方を呼び寄せて加速・回復
	var lane := 0
	var best_dist := INF
	for i in lane_ys.size():
		if absf(lane_ys[i] - pos.y) < best_dist:
			best_dist = absf(lane_ys[i] - pos.y)
			lane = i
	for unit in allies:
		var unit_pos := Vector2(unit["x"], lane_ys[unit["lane"]])
		if unit_pos.distance_to(pos) <= 260.0:
			unit["lane"] = lane
			unit["boost"] = 2.5
			unit["hp"] = minf(unit["hp"] + 2.0, unit["hp_max"])
	GameLog.info("ずんだボール: (%d, %d) レーン%d" % [int(pos.x), int(pos.y), lane])


# --- 押し返し(敗北なし) ---

func _overrun() -> void:
	overruns += 1
	base_hp = BASE_HP_MAX
	var lost := snappedf(zunda * 0.5, 1.0)
	zunda -= lost
	# ずんだの泉が画面上の敵を押し流す
	for unit in enemies:
		_burst(Vector2(unit["x"], lane_ys[unit["lane"]]), Color(0.55, 0.85, 0.5), 14)
		unit["sprite"].queue_free()
	enemies.clear()
	wave_timer = maxf(wave_timer, 8.0)
	_play("lose")
	_say("overrun", 4.0)
	_toast_label("ずんだの泉、発動!! (ずんだ%dを流出)" % int(lost))
	_flash_background(Color(0.7, 0.95, 0.65))
	GameLog.warn("押し返し%d回目: wave%d ずんだ-%d" % [overruns, wave, int(lost)])


# --- 演出 ---

func _flash(unit: Dictionary) -> void:
	var sprite: Sprite2D = unit["sprite"]
	sprite.modulate = Color(1.6, 1.2, 1.2)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _flash_background(color: Color) -> void:
	var tw := background.create_tween()
	tw.tween_property(background, "color", color, 0.15)
	tw.tween_property(background, "color", Color(0.96, 0.93, 0.85), 0.6)


func _burst(pos: Vector2, color: Color, amount: int = 10) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 500)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0
	particles.color = color
	battle_layer.add_child(particles)
	get_tree().create_timer(0.9).timeout.connect(particles.queue_free)


func _shake_factory() -> void:
	var panel: ColorRect = $FactoryPanel
	var tw := panel.create_tween()
	tw.tween_property(panel, "position:x", -6.0, 0.05)
	tw.tween_property(panel, "position:x", 0.0, 0.08)


func _toast_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.05))
	label.position = Vector2(440, 70)
	label.z_index = 40
	add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)


# --- UI ---

func _setup_field() -> void:
	for node in field_nodes:
		if is_instance_valid(node):
			node.queue_free()
	field_nodes.clear()
	for y in lane_ys:
		var line := ColorRect.new()
		line.color = Color(0.5, 0.45, 0.35, 0.12)
		line.position = Vector2(FIELD_LEFT, y + 16)
		line.size = Vector2(FIELD_RIGHT - FIELD_LEFT, 2)
		add_child(line)
		field_nodes.append(line)
	var wall := ColorRect.new()
	wall.color = Color(0.35, 0.42, 0.28)
	wall.position = Vector2(FIELD_LEFT - 12, 140)
	wall.size = Vector2(12, 520)
	add_child(wall)
	field_nodes.append(wall)


# --- ステージ崩壊 ---

func _trigger_collapse() -> void:
	if collapsing:
		return
	collapsing = true
	stage_level += 1
	creak_warned = 0
	var fallen := allies.size()
	var refund := fallen * 20.0
	GameLog.info("ステージ崩壊!! レベル%d: %d体が転落、ずんだ+%d" % [stage_level, fallen, int(refund)])
	_play("collapse")
	_say("collapse", 4.0)
	_flash_background(Color(0.75, 0.6, 0.45))
	# 画面ごと揺らす
	var shake := create_tween()
	for i in 10:
		shake.tween_property(self, "position", Vector2(randf_range(-14, 14), randf_range(-14, 14)), 0.05)
	shake.tween_property(self, "position", Vector2.ZERO, 0.1)
	# 全ユニットが奈落へ
	for unit in allies + enemies:
		var sprite: Sprite2D = unit["sprite"]
		var tw := sprite.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "position:y", 900.0, randf_range(0.5, 1.3)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(randf_range(0.0, 0.6))
		tw.tween_property(sprite, "rotation", randf_range(-8.0, 8.0), 1.3)
		tw.chain().tween_callback(sprite.queue_free)
	allies.clear()
	enemies.clear()
	_gain_zunda(refund)
	# レーン線も落ちる
	for node in field_nodes:
		if is_instance_valid(node):
			var tw: Tween = node.create_tween()
			tw.tween_property(node, "position:y", 900.0, randf_range(0.6, 1.0)) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(randf_range(0.1, 0.5))
	_toast_label("ステージ崩壊!!! %d体が転落 → ずんだ%dに還元" % [fallen, int(refund)])
	# 2.2秒後: 地下の新フロア(レーン+1、広い)
	get_tree().create_timer(2.2).timeout.connect(_open_new_stage)


func _open_new_stage() -> void:
	var lane_count := mini(5 + stage_level, 8)
	lane_ys.clear()
	var top := 190.0
	var bottom := 640.0
	for i in lane_count:
		lane_ys.append(top + (bottom - top) * i / float(lane_count - 1))
	_setup_field()
	# 地下に行くほど背景が深い色になる
	var depth := minf(stage_level * 0.06, 0.3)
	background.color = Color(0.96 - depth, 0.93 - depth * 0.8, 0.85 - depth * 0.5)
	wave_timer = maxf(wave_timer, 10.0)
	base_hp = BASE_HP_MAX
	collapsing = false
	_play("advance")
	_say("newstage", 4.0)
	_toast_label("地下%dF 開放! レーン%d本 — もっと増やせるのだ" % [stage_level, lane_count])
	GameLog.info("新ステージ: 地下%dF レーン%d" % [stage_level, lane_count])


var panel_box: VBoxContainer


func _setup_factory_panel() -> void:
	panel_box = VBoxContainer.new()
	panel_box.position = Vector2(16, 14)
	panel_box.custom_minimum_size = Vector2(310, 0)
	panel_box.add_theme_constant_override("separation", 6)
	add_child(panel_box)
	_rebuild_factory_panel()

	var version := Label.new()
	version.text = "試作 v%s / 立ち絵: 坂本アヒル様 (ずんずんPJ二次創作)" % VERSION
	version.position = Vector2(16, size.y - 24)
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(0.7, 0.75, 0.62))
	add_child(version)


func _rebuild_factory_panel() -> void:
	for child in panel_box.get_children():
		child.queue_free()
	line_boxes.clear()

	var title := Label.new()
	title.text = "ずんだもん増殖工場"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 0.85))
	panel_box.add_child(title)

	stock_label = Label.new()
	stock_label.add_theme_font_size_override("font_size", 18)
	stock_label.add_theme_color_override("font_color", Color(0.8, 0.95, 0.6))
	panel_box.add_child(stock_label)

	flow_label = Label.new()
	flow_label.add_theme_font_size_override("font_size", 13)
	flow_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
	panel_box.add_child(flow_label)

	army_label = Label.new()
	army_label.add_theme_font_size_override("font_size", 13)
	army_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65))
	panel_box.add_child(army_label)

	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 13)
	wave_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.55))
	panel_box.add_child(wave_label)

	base_bar = ProgressBar.new()
	base_bar.max_value = BASE_HP_MAX
	base_bar.show_percentage = false
	base_bar.custom_minimum_size = Vector2(0, 10)
	panel_box.add_child(base_bar)

	stage_label = Label.new()
	stage_label.add_theme_font_size_override("font_size", 13)
	stage_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	panel_box.add_child(stage_label)
	stage_bar = ProgressBar.new()
	stage_bar.max_value = COLLAPSE_AT
	stage_bar.show_percentage = false
	stage_bar.custom_minimum_size = Vector2(0, 10)
	panel_box.add_child(stage_bar)

	farm_button = Button.new()
	farm_button.custom_minimum_size = Vector2(0, 44)
	farm_button.pressed.connect(func() -> void:
		var cost := _farm_cost()
		if zunda >= cost:
			zunda -= cost
			farms += 1
			_play("build")
			GameLog.info("ずんだ畑 ×%d" % farms)
	)
	panel_box.add_child(farm_button)

	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		var sep := Label.new()
		sep.text = "— %s —" % line["name"]
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep.add_theme_font_size_override("font_size", 14)
		sep.add_theme_color_override("font_color", Color(0.92, 0.96, 0.85))
		panel_box.add_child(sep)
		if not line["unlocked"]:
			var locked := Label.new()
			locked.text = "ロック中: %s" % LINE_B_UNLOCK["label"]
			locked.add_theme_font_size_override("font_size", 13)
			locked.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
			panel_box.add_child(locked)
			line_boxes.append({})
			continue
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 6)
		panel_box.add_child(slot_row)
		var slot_buttons: Array = []
		for slot in 3:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(96, 52)
			btn.pressed.connect(_open_trait_picker.bind(line_index, slot))
			slot_row.add_child(btn)
			slot_buttons.append(btn)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		panel_box.add_child(row)
		var toggle_btn := Button.new()
		toggle_btn.custom_minimum_size = Vector2(74, 44)
		toggle_btn.pressed.connect(func() -> void:
			line["active"] = not line["active"]
			_play("build", 0.8 if not line["active"] else 1.1)
			GameLog.info("%s %s" % [line["name"], "稼働" if line["active"] else "停止"])
		)
		row.add_child(toggle_btn)
		var spawner_btn := Button.new()
		spawner_btn.custom_minimum_size = Vector2(0, 44)
		spawner_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spawner_btn.pressed.connect(func() -> void:
			var cost := _spawner_cost(line)
			if zunda >= cost:
				zunda -= cost
				line["spawners"] += 1
				_play("build")
				GameLog.info("%s 培養槽 ×%d" % [line["name"], line["spawners"]])
		)
		row.add_child(spawner_btn)
		line_boxes.append({"slots": slot_buttons, "spawner": spawner_btn, "toggle": toggle_btn})

	var hint := Label.new()
	hint.text = "フィールドをクリック: ずんだボール(%d消費)\n— 群れを呼び寄せ・加速・小回復" % int(BALL_COST)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_box.add_child(hint)


func _open_trait_picker(line_index: int, slot: int) -> void:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.04, 0.55)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "%s スロット%d — 特性をえらぶ" % [lines[line_index]["name"], slot + 1]
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var clear := Button.new()
	clear.text = "(はずす) — 生産コストを下げる"
	clear.custom_minimum_size = Vector2(0, 40)
	clear.pressed.connect(func() -> void:
		lines[line_index]["traits"][slot] = ""
		_close_overlay()
	)
	box.add_child(clear)
	for trait_id in TRAITS:
		var data: Dictionary = TRAITS[trait_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 48)
		if trait_id in unlocked_traits:
			btn.text = "%s (+コスト%d) — %s" % [data["name"], int(data["cost"]), data["desc"]]
			btn.self_modulate = data["color"]
			btn.pressed.connect(func() -> void:
				lines[line_index]["traits"][slot] = trait_id
				_play("build")
				GameLog.info("%s slot%d = %s" % [lines[line_index]["name"], slot, data["name"]])
				_close_overlay()
			)
		else:
			btn.text = "??? — 解禁条件: %s" % data["unlock"]["label"]
			btn.disabled = true
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "とじる"
	cancel.pressed.connect(_close_overlay)
	box.add_child(cancel)
	add_child(overlay)


func _close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _setup_commander() -> void:
	commander = TextureRect.new()
	commander.texture = ZUNDA_TEXTURES["normal"]
	commander.position = Vector2(200, 540)
	commander.custom_minimum_size = Vector2(100, 180)
	commander.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	commander.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(commander)
	bubble = PanelContainer.new()
	bubble.position = Vector2(16, 560)
	bubble.custom_minimum_size = Vector2(190, 0)
	bubble.visible = false
	bubble.z_index = 20
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 7)
	bubble.add_child(margin)
	bubble_label = Label.new()
	bubble_label.add_theme_font_size_override("font_size", 13)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(bubble_label)
	add_child(bubble)


func _say(event: String, hold: float = 3.0) -> void:
	if not COMMANDER_LINES.has(event):
		return
	var pool: Array = COMMANDER_LINES[event]
	bubble_label.text = pool[randi() % pool.size()]
	bubble.visible = true
	var mood := "normal"
	match event:
		"kill_streak", "swarm", "unlock", "ball": mood = "happy"
		"starve", "overrun": mood = "sad"
		"wave", "base_hit": mood = "surprised"
	commander.texture = ZUNDA_TEXTURES[mood]
	speak_token += 1
	var token := speak_token
	get_tree().create_timer(hold).timeout.connect(func() -> void:
		if token == speak_token:
			bubble.visible = false
			commander.texture = ZUNDA_TEXTURES["normal"]
	)


func _update_ui() -> void:
	stock_label.text = "ずんだ: %d" % int(zunda)
	var starve_mark := "  ← ずんだ不足!" if starving else ""
	var net: float = flow_rates["farm"] + flow_rates["kill"] - flow_rates["spent"]
	flow_label.text = "収入 畑+%.0f 戦利品+%.0f / 生産費 -%.0f → %s%.0f/秒\n培養フル稼働には %.0f/秒 必要%s" % [
		flow_rates["farm"], flow_rates["kill"], flow_rates["spent"],
		"+" if net >= 0 else "", net, _total_consumption(), starve_mark]
	army_label.text = "軍団 %d体 / 累計 %d / 撃破 %d / ロスト %d" % [allies.size(), counters["spawned"], counters["kills"], counters["losses"]]
	wave_label.text = "ウェーブ %d / つぎまで %d秒 / 敵 %d体\n予報: %s%s" % [
		wave, int(maxf(wave_timer, 0)), enemies.size(),
		ENEMY_TYPES[next_theme]["name"],
		"多め" if next_theme != "koge" and next_theme != "boss" else ("!!" if next_theme == "boss" else "")]
	base_bar.value = base_hp
	stage_label.text = "ステージ負荷 %d/%d — 地下%dF (超えると床が抜ける!?)" % [allies.size(), COLLAPSE_AT, stage_level]
	stage_bar.value = allies.size()
	farm_button.text = "ずんだ畑 ×%d — コスト %d (+6.0/秒)" % [farms, int(_farm_cost())]
	farm_button.disabled = zunda < _farm_cost()
	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		if not line["unlocked"] or line_boxes[line_index].is_empty():
			continue
		var boxes: Dictionary = line_boxes[line_index]
		for slot in 3:
			var trait_id: String = line["traits"][slot]
			var btn: Button = boxes["slots"][slot]
			if trait_id == "":
				btn.text = "+特性"
				btn.self_modulate = Color(1, 1, 1, 0.7)
			else:
				btn.text = "%s\n+%d" % [TRAITS[trait_id]["name"], int(TRAITS[trait_id]["cost"])]
				btn.self_modulate = TRAITS[trait_id]["color"]
		var spawner_btn: Button = boxes["spawner"]
		spawner_btn.text = "培養槽 ×%d — コスト %d (1体%d)" % [line["spawners"], int(_spawner_cost(line)), int(_line_unit_cost(line))]
		spawner_btn.disabled = zunda < _spawner_cost(line)
		var toggle_btn: Button = boxes["toggle"]
		toggle_btn.text = "稼働中" if line["active"] else "停止中"
		toggle_btn.self_modulate = Color(0.7, 1.0, 0.7) if line["active"] else Color(1.0, 0.6, 0.5)


# --- オーディオ ---

func _setup_audio() -> void:
	for key in SFX:
		var player := AudioStreamPlayer.new()
		player.stream = SFX[key]
		player.max_polyphony = 6
		player.volume_db = -6.0
		add_child(player)
		sfx_players[key] = player


func _play(key: String, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = sfx_players[key]
	player.pitch_scale = pitch
	player.play()


func _play_throttled(key: String, min_interval: float, pitch: float = 1.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_sfx.get(key, 0)) < min_interval * 1000.0:
		return
	_last_sfx[key] = now
	_play(key, pitch)
