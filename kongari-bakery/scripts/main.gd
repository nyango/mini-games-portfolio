extends Control

const VERSION := "0.8.0"
const SAVE_PATH := "user://save.json"
const DAY_LENGTH := 75.0
const RUN_DAYS := 12
const RENT_BASE := 300.0
const RENT_GROWTH := 1.5
const GRID_W := 4
const GRID_H := 3
const GRID_SIZE := GRID_W * GRID_H
const CRIT_BASE := 0.06
const BURNT_CHANCE := 0.04
const CLICK_BASE := 10.0
const COMBO_WINDOW := 0.45
const FEVER_COMBO := 15
const FEVER_DURATION := 6.0

const WEATHERS := {
	"sunny": {"name": "晴れ", "desc": "ゴールデンパンが現れやすい"},
	"cloudy": {"name": "くもり", "desc": "おだやかな一日"},
	"rain": {"name": "雨", "desc": "注文は減るが、報酬が増す"},
}

const TAGS := {
	"machine": {"name": "機械", "color": Color(0.62, 0.66, 0.72)},
	"artisan": {"name": "職人", "color": Color(0.72, 0.55, 0.4)},
	"sweet": {"name": "甘味", "color": Color(0.9, 0.6, 0.7)},
	"green": {"name": "緑", "color": Color(0.55, 0.75, 0.45)},
	"service": {"name": "接客", "color": Color(0.5, 0.68, 0.85)},
	"gold": {"name": "黄金", "color": Color(0.88, 0.72, 0.3)},
	"click": {"name": "手仕事", "color": Color(0.88, 0.6, 0.35)},
}

# 設備カード。effect:
#  self_per_adj_tag  となりのtag1枚ごとに自分×(1+v)
#  self_per_adj_any  となりの埋まりマス1つごとに自分×(1+v)
#  self_per_total_tag 盤面のtag1枚ごとに自分×(1+v)
#  adj_tag_boost     となりのtagを×(1+v)
#  row_tag_boost     同じ行のtagを×(1+v)
#  global_per_tag    盤面のtag1枚ごとに全生産+v
#  order_reward_mult / order_interval_mult / golden_interval_mult / click_add / crit_add
const CARDS := {
	"toaster": {"name": "トースター", "tag": "machine", "rate": 6.0,
		"effect": {"type": "self_per_adj_tag", "tag": "machine", "v": 0.5},
		"desc": "となりの機械1台ごとに自分+50%"},
	"oven": {"name": "石窯オーブン", "tag": "machine", "rate": 15.0,
		"effect": {"type": "adj_tag_boost", "tag": "machine", "v": 0.3},
		"desc": "となりの機械の生産+30%"},
	"conveyor": {"name": "ベルトコンベア", "tag": "machine", "rate": 3.0,
		"effect": {"type": "row_tag_boost", "tag": "machine", "v": 0.25},
		"desc": "同じ行の機械の生産+25%"},
	"artisan": {"name": "パン職人", "tag": "artisan", "rate": 12.0,
		"effect": {"type": "adj_tag_boost", "tag": "artisan", "v": 0.4},
		"desc": "となりの職人の生産+40%"},
	"apprentice": {"name": "見習いくん", "tag": "artisan", "rate": 5.0,
		"effect": {"type": "self_per_adj_tag", "tag": "artisan", "v": 1.0},
		"desc": "となりの職人1人ごとに自分+100%"},
	"honey": {"name": "ハチミツ壺", "tag": "sweet", "rate": 4.0,
		"effect": {"type": "adj_tag_boost", "tag": "sweet", "v": 0.6},
		"desc": "となりの甘味の生産+60%"},
	"melon": {"name": "メロンパン型", "tag": "sweet", "rate": 10.0,
		"effect": {"type": "self_per_total_tag", "tag": "sweet", "v": 0.15},
		"desc": "甘味カード1枚ごとに自分+15%"},
	"zunda": {"name": "ずんだ餡", "tag": "green", "rate": 8.0,
		"effect": {"type": "global_per_tag", "tag": "green", "v": 0.05},
		"desc": "緑カード1枚ごとに全生産+5%"},
	"edamame": {"name": "枝豆畑", "tag": "green", "rate": 4.0,
		"effect": {"type": "self_per_adj_any", "v": 0.3},
		"desc": "となりが埋まっているマス1つごとに自分+30%"},
	"register": {"name": "レジスター", "tag": "service", "rate": 2.0,
		"effect": {"type": "order_reward_mult", "v": 0.4},
		"desc": "注文の報酬+40%"},
	"signboard": {"name": "立て看板", "tag": "service", "rate": 3.0,
		"effect": {"type": "order_interval_mult", "v": 0.15},
		"desc": "注文が来やすくなる"},
	"goldoven": {"name": "金の窯", "tag": "gold", "rate": 10.0,
		"effect": {"type": "golden_interval_mult", "v": 0.2},
		"desc": "ゴールデンパンが出やすくなる"},
	"butter": {"name": "発酵バター", "tag": "click", "rate": 0.0,
		"effect": {"type": "click_add", "v": 20.0},
		"desc": "クリックで焼ける数+20"},
	"mitten": {"name": "魔法のミトン", "tag": "click", "rate": 2.0,
		"effect": {"type": "crit_add", "v": 0.04},
		"desc": "クリティカル率+4%"},
}

const SFX := {
	"click": preload("res://assets/audio/click.wav"),
	"crit": preload("res://assets/audio/crit.wav"),
	"burnt": preload("res://assets/audio/burnt.wav"),
	"buy": preload("res://assets/audio/buy.wav"),
	"golden_appear": preload("res://assets/audio/golden_appear.wav"),
	"golden_get": preload("res://assets/audio/golden_get.wav"),
	"milestone": preload("res://assets/audio/milestone.wav"),
	"order_bell": preload("res://assets/audio/order_bell.wav"),
	"order_ok": preload("res://assets/audio/order_ok.wav"),
	"order_fail": preload("res://assets/audio/order_fail.wav"),
	"trophy": preload("res://assets/audio/trophy.wav"),
	"ending": preload("res://assets/audio/ending.wav"),
	"fever": preload("res://assets/audio/fever.wav"),
}
const GOLD_TEXTURE := preload("res://assets/bread_gold.svg")

const ZUNDA_TEXTURES := {
	"normal": preload("res://assets/characters/zundamon_normal.png"),
	"happy": preload("res://assets/characters/zundamon_happy.png"),
	"sad": preload("res://assets/characters/zundamon_sad.png"),
	"surprised": preload("res://assets/characters/zundamon_surprised.png"),
}
const CUSTOMERS := {
	"metan": {
		"name": "四国めたん",
		"normal": preload("res://assets/characters/metan_normal.png"),
		"happy": preload("res://assets/characters/metan_happy.png"),
		"sad": preload("res://assets/characters/metan_sad.png"),
		"offer": ["パンを%s個、お願いできるかしら?", "%s個ほど用意してくださる?", "%s個…できるわよね?"],
		"done": ["さすがですわ!また来るわね", "いい腕ですこと!"],
		"fail": ["残念ですわ…また今度ね", "あら…期待していたのに"],
	},
	"ankomon": {
		"name": "あんこもん",
		"normal": preload("res://assets/characters/ankomon_normal.png"),
		"happy": preload("res://assets/characters/ankomon_happy.png"),
		"sad": preload("res://assets/characters/ankomon_sad.png"),
		"offer": ["パンを%s個ほしいの!", "%s個、お願いなの!", "%s個…がんばってほしいの"],
		"done": ["わーい!ありがとなの!", "おいしそうなの〜!"],
		"fail": ["うぅ…ざんねんなの…", "つぎはまってるの…"],
	},
}

const ZUNDA_LINES := {
	"idle": ["いらっしゃいなのだ", "家賃は毎晩取られるのだ…", "シナジーを考えて置くのだ", "クリックすると焼けるのだ", "今日もいい小麦の香りなのだ"],
	"golden_spawn": ["金のパンが飛んでるのだ!", "あれを捕まえるのだ!!"],
	"golden_get": ["やったのだ!大もうけなのだ!", "ぴかぴかなのだ〜!"],
	"crit": ["完璧な焼き加減なのだ!", "こんがりの極みなのだ!"],
	"burnt": ["焦げたのだ…", "黒いのも味なのだ…たぶん", "まっくろなのだ…"],
	"place": ["ここに置くのだ!", "お店が育ってきたのだ"],
	"draft": ["今日はどれを仕入れるのだ?", "悩みどころなのだ…"],
	"order_done": ["納品完了なのだ!", "商売繁盛なのだ〜"],
	"order_fail": ["間に合わなかったのだ…", "ごめんなさいなのだ…"],
	"day_open": ["開店なのだ!今日もがんばるのだ", "朝は焼きたての匂いなのだ"],
	"rent_ok": ["家賃を払えたのだ!えらいのだ", "今夜もしのいだのだ…"],
	"rent_fail": ["家賃が…払えないのだ…", "夜逃げなのだ…"],
	"fever": ["ずんだフィーバーなのだ!!", "手が光ってるのだ!!"],
	"milestone": ["称号ゲットなのだ!", "ボクたち有名になってきたのだ"],
	"trophy": ["実績解除なのだ!"],
	"ending": ["これが…物語の結末なのだ…"],
}
const MOOD_BY_EVENT := {
	"golden_get": "happy", "crit": "happy", "order_done": "happy",
	"day_open": "happy", "milestone": "happy", "trophy": "happy", "place": "happy", "rent_ok": "happy",
	"burnt": "sad", "order_fail": "sad", "rent_fail": "sad",
	"golden_spawn": "surprised", "fever": "happy",
}

const MILESTONES := [
	[1000.0, "見習いパン屋"],
	[10000.0, "町のパン屋さん"],
	[100000.0, "人気ベーカリー"],
]

const ENDINGS := [
	{"id": "burnt", "title": "こげパン伯爵", "hint": "焦がしすぎにも ほどがある…?",
		"text": "あなたは焦げの中に宇宙を見た。\n真っ黒なパンを求めて、今日も行列ができる。"},
	{"id": "golden", "title": "黄金の狩人", "hint": "空飛ぶ黄金を 追い続けた者には…?",
		"text": "黄金のパンを追い続けたあなたの瞳は、\nいつしか黄金色に輝いていた。"},
	{"id": "artisan", "title": "神の手", "hint": "機械に頼らず 手仕事と職人で焼き続けると…?",
		"text": "14日間、その手で焼き続けた。\nあなたの親指は世界遺産に登録された。"},
	{"id": "beloved", "title": "愛されベーカリー", "hint": "お客さんの注文を 大切にすると…?",
		"text": "「いつものお願いね」\n常連さんの笑顔が、何よりのレシピだった。"},
	{"id": "empire", "title": "全自動パン帝国", "hint": "店を機械で 埋め尽くすと…?",
		"text": "もう誰もパンを焼いていない。\n帝国の空に、小麦の香りだけが流れていく。"},
	{"id": "cozy", "title": "ちいさな幸せのパン屋", "hint": "バランスよく 14日間焼きあげると…",
		"text": "特別なことは何もない。\nでも今日も、焼きたての香りに誰かが微笑む。"},
	{"id": "bankrupt", "title": "夜逃げの朝", "hint": "家賃を払えなかったら…?",
		"text": "月明かりの下、リヤカーにオーブンを積んで。\n「また どこかで店を開くのだ…」"},
]

const TROPHIES := [
	{"id": "first_bread", "title": "はじめてのいちまい", "desc": "パンを1個焼く", "key": "total", "v": 1.0},
	{"id": "clicks_300", "title": "指がつよい", "desc": "300回クリックする", "key": "clicks", "v": 300.0},
	{"id": "golden_1", "title": "黄金との遭遇", "desc": "ゴールデンパンを捕まえる", "key": "golden", "v": 1.0},
	{"id": "golden_10", "title": "ゴールデンハンター", "desc": "ゴールデンパンを10個捕まえる", "key": "golden", "v": 10.0},
	{"id": "burnt_10", "title": "焦がしの美学", "desc": "10回焦がす", "key": "burnt", "v": 10.0},
	{"id": "order_1", "title": "はじめての常連さん", "desc": "注文を1回納品する", "key": "orders", "v": 1.0},
	{"id": "order_8", "title": "行列のできる店", "desc": "注文を8回納品する", "key": "orders", "v": 8.0},
	{"id": "cards_10", "title": "設備マニア", "desc": "カードを10枚配置する", "key": "cards", "v": 10.0},
	{"id": "fame_10", "title": "町の有名人", "desc": "名声を☆10にする", "key": "fame", "v": 10.0},
	{"id": "day_7", "title": "一週間の常連", "desc": "7日目まで営業する", "key": "day", "v": 7.0},
	{"id": "clear_1", "title": "完走のパン屋", "desc": "14日目の決算をむかえる", "key": "clears", "v": 1.0},
	{"id": "rich_run", "title": "大繁盛", "desc": "1ランで累計50万個焼く", "key": "total", "v": 500000.0},
	{"id": "end_1", "title": "ひとつの結末", "desc": "エンディングを見る", "key": "endings", "v": 1.0},
	{"id": "end_all", "title": "すべての朝を見た", "desc": "全エンディングを見る", "key": "endings", "v": 7.0},
]

# --- 周回をまたぐデータ ---
var meta := {"trophies": [], "endings": [], "clears": 0}

# --- ラン(周回)ごとのデータ ---
var bread := 0.0
var total_baked := 0.0
var fame := 0
var milestone_index := 0
var run_over := false
var stats := {"clicks": 0.0, "click_baked": 0.0, "burnt": 0.0, "golden": 0.0, "orders_done": 0.0, "orders_failed": 0.0}
var grid: Array = []  # GRID_SIZE個のカードid("「空」は\"\")

# --- 営業日 ---
var day := 1
var day_time_left := DAY_LENGTH
var weather := "cloudy"
var day_stats := {}
var day_fame_start := 0

# --- グリッド計算結果(キャッシュ) ---
var per_sec := 0.0
var cell_rates: Array = []
var grid_click_add := 0.0
var grid_crit_add := 0.0
var grid_order_reward_mult := 1.0
var grid_order_interval_mult := 1.0
var grid_golden_interval_mult := 1.0

# --- ドラフト/配置 ---
var pending_card := ""
var draft_token := 0
var draft_queue := 0

# --- コンボ/フィーバー ---
var combo := 0
var combo_timer := 0.0
var fever_timer := 0.0
var combo_bar: ProgressBar
var combo_label: Label

# --- 注文 ---
var order_state := "none"  # none / offer / active
var order_amount := 0.0
var order_reward := 0.0
var order_fame := 1
var order_time_left := 0.0
var order_cooldown := 25.0

# --- ノード ---
var tile_buttons: Array[Button] = []
var grid_hint: Label
var sfx_players := {}
var golden_timer: Timer
var golden_button: TextureButton
var toast_panel: PanelContainer
var toast_label: Label
var toast_queue: Array[String] = []
var toast_showing := false
var fame_label: Label
var goal_label: Label
var day_label: Label
var day_bar: ProgressBar
var report_token := 0
var zunda: TextureRect
var zunda_bubble: PanelContainer
var zunda_bubble_label: Label
var customer: TextureRect
var customer_bubble: PanelContainer
var customer_bubble_label: Label
var customer_id := "metan"
var speak_token := 0
var idle_chat_timer: Timer
var order_panel: PanelContainer
var order_title: Label
var order_body: Label
var order_accept: Button
var order_decline: Button
var order_deliver: Button
var overlay: Control = null
var _title_clicks := 0
var _title_click_time := 0

@onready var bread_label: Label = %BreadLabel
@onready var rate_label: Label = %RateLabel
@onready var bread_button: TextureButton = %BreadButton
@onready var shop_list: VBoxContainer = %ShopList


func _ready() -> void:
	GameLog.info("起動 v%s (platform=%s)" % [VERSION, OS.get_name()])
	grid.resize(GRID_SIZE)
	grid.fill("")
	_reset_day_stats()
	_load_game()
	weather = WEATHERS.keys()[randi() % WEATHERS.size()]
	_build_grid_ui()
	_recalc_grid()
	_setup_audio()
	_setup_golden()
	_setup_toast()
	_setup_top_bar()
	_setup_order_panel()
	_setup_characters()
	_start_idle_animation()
	GameLog.info("ロード完了: %d日目 所持%s 配置%d枚 名声%d エンド%d/%d" % [
		day, _fmt(bread), _cards_placed(), fame, meta["endings"].size(), ENDINGS.size()])

	var title: Label = $Title
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_input)

	var save_timer := Timer.new()
	save_timer.wait_time = 10.0
	save_timer.autostart = true
	save_timer.timeout.connect(_save_game)
	add_child(save_timer)

	var tick_timer := Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = true
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

	if _cards_placed() == 0 and day == 1:
		draft_queue = 3  # 初日は3枚ドラフトしてビルドの種を持って始める
		_start_draft()


func _process(delta: float) -> void:
	if run_over:
		return
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if fever_timer > 0.0:
		fever_timer -= delta
		if fever_timer <= 0.0:
			_end_fever()
	var gain := _effective_per_sec() * delta
	bread += gain
	total_baked += gain
	day_stats["auto_baked"] += gain
	_update_day(delta)
	_update_order(delta)
	_check_milestones()
	_update_ui()


func _multiplier() -> float:
	return 1.0 + fame * 0.02 + meta["endings"].size() * 0.05


func _effective_per_sec() -> float:
	return per_sec * _multiplier() * (3.0 if _in_fever() else 1.0)


func _click_power() -> float:
	var power := (CLICK_BASE + meta["endings"].size() * 5.0 + grid_click_add) * _multiplier()
	return power * (2.0 if _in_fever() else 1.0)


func _in_fever() -> bool:
	return fever_timer > 0.0


func _start_fever() -> void:
	fever_timer = FEVER_DURATION
	_play("fever")
	_zunda_say("fever", 2.5)
	_shake(8.0)
	_spawn_float("ずんだフィーバー!! 生産×3", bread_button.position + Vector2(0, -40), Color(0.9, 0.65, 0.05), 36)
	var bg: ColorRect = $Background
	var tw := bg.create_tween()
	tw.tween_property(bg, "color", Color(1.0, 0.9, 0.6), 0.3)


func _end_fever() -> void:
	combo = 0
	var bg: ColorRect = $Background
	var tw := bg.create_tween()
	tw.tween_property(bg, "color", Color(0.976, 0.937, 0.851), 0.6)


func _crit_chance() -> float:
	return CRIT_BASE + grid_crit_add


func _rent(for_day: int) -> float:
	return snappedf(RENT_BASE * pow(RENT_GROWTH, for_day - 1), 1.0)


func _golden_delay(base_min: float, base_max: float) -> float:
	var delay := randf_range(base_min, base_max) * grid_golden_interval_mult
	if weather == "sunny":
		delay *= 0.6
	return delay


func _order_delay(base_min: float, base_max: float) -> float:
	var delay := randf_range(base_min, base_max) * grid_order_interval_mult
	if weather == "rain":
		delay *= 1.5
	return delay


# --- グリッド ---

func _cards_placed() -> int:
	var n := 0
	for id in grid:
		if id != "":
			n += 1
	return n


func _tag_count(tag: String) -> int:
	var n := 0
	for id in grid:
		if id != "" and CARDS[id]["tag"] == tag:
			n += 1
	return n


func _neighbors(index: int) -> Array:
	var result: Array = []
	var row := index / GRID_W
	var col := index % GRID_W
	if col > 0: result.append(index - 1)
	if col < GRID_W - 1: result.append(index + 1)
	if row > 0: result.append(index - GRID_W)
	if row < GRID_H - 1: result.append(index + GRID_W)
	return result


func _recalc_grid() -> void:
	cell_rates.resize(GRID_SIZE)
	var mults: Array = []
	mults.resize(GRID_SIZE)
	grid_click_add = 0.0
	grid_crit_add = 0.0
	grid_order_reward_mult = 1.0
	grid_order_interval_mult = 1.0
	grid_golden_interval_mult = 1.0
	var global_pct := 0.0

	for i in GRID_SIZE:
		mults[i] = 1.0
	# 自己強化とグローバル効果
	for i in GRID_SIZE:
		if grid[i] == "":
			continue
		var card: Dictionary = CARDS[grid[i]]
		var fx: Dictionary = card["effect"]
		match fx["type"]:
			"self_per_adj_tag":
				for j in _neighbors(i):
					if grid[j] != "" and CARDS[grid[j]]["tag"] == fx["tag"]:
						mults[i] *= 1.0 + fx["v"]
			"self_per_adj_any":
				for j in _neighbors(i):
					if grid[j] != "":
						mults[i] *= 1.0 + fx["v"]
			"self_per_total_tag":
				var n := _tag_count(fx["tag"]) - 1  # 自分は除く
				mults[i] *= 1.0 + fx["v"] * maxi(0, n)
			"global_per_tag":
				global_pct += fx["v"] * _tag_count(fx["tag"])
			"order_reward_mult":
				grid_order_reward_mult *= 1.0 + fx["v"]
			"order_interval_mult":
				grid_order_interval_mult *= 1.0 - fx["v"]
			"golden_interval_mult":
				grid_golden_interval_mult *= 1.0 - fx["v"]
			"click_add":
				grid_click_add += fx["v"]
			"crit_add":
				grid_crit_add += fx["v"]
	grid_order_interval_mult = maxf(0.35, grid_order_interval_mult)
	grid_golden_interval_mult = maxf(0.35, grid_golden_interval_mult)
	# オーラ(隣・行)効果
	for i in GRID_SIZE:
		if grid[i] == "":
			continue
		var fx: Dictionary = CARDS[grid[i]]["effect"]
		match fx["type"]:
			"adj_tag_boost":
				for j in _neighbors(i):
					if grid[j] != "" and CARDS[grid[j]]["tag"] == fx["tag"]:
						mults[j] *= 1.0 + fx["v"]
			"row_tag_boost":
				var row := i / GRID_W
				for col in GRID_W:
					var j := row * GRID_W + col
					if j != i and grid[j] != "" and CARDS[grid[j]]["tag"] == fx["tag"]:
						mults[j] *= 1.0 + fx["v"]
	# 合算
	per_sec = 0.0
	for i in GRID_SIZE:
		if grid[i] == "":
			cell_rates[i] = 0.0
			continue
		var rate: float = CARDS[grid[i]]["rate"] * mults[i] * (1.0 + global_pct)
		cell_rates[i] = rate
		per_sec += rate
	_update_grid_ui()


func _build_grid_ui() -> void:
	shop_list.add_theme_constant_override("separation", 6)
	var head := Label.new()
	head.text = "— 店内レイアウト —"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	shop_list.add_child(head)
	var grid_box := GridContainer.new()
	grid_box.columns = GRID_W
	grid_box.add_theme_constant_override("h_separation", 6)
	grid_box.add_theme_constant_override("v_separation", 6)
	shop_list.add_child(grid_box)
	for i in GRID_SIZE:
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(84, 84)
		tile.clip_text = true
		tile.pressed.connect(_on_tile_pressed.bind(i))
		grid_box.add_child(tile)
		tile_buttons.append(tile)
	grid_hint = Label.new()
	grid_hint.add_theme_font_size_override("font_size", 13)
	grid_hint.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_hint.text = "毎朝カードを1枚ドラフトして配置。タイルをクリックで詳細/売却。"
	shop_list.add_child(grid_hint)


func _update_grid_ui() -> void:
	for i in GRID_SIZE:
		var tile := tile_buttons[i]
		if grid[i] == "":
			tile.text = "+" if pending_card != "" else ""
			tile.self_modulate = Color(0.6, 1.0, 0.6) if pending_card != "" else Color(1, 1, 1, 0.55)
			tile.tooltip_text = ""
		else:
			var card: Dictionary = CARDS[grid[i]]
			tile.text = "%s\n%s/秒" % [card["name"], _fmt(cell_rates[i] * _multiplier())]
			tile.self_modulate = TAGS[card["tag"]]["color"]
			tile.tooltip_text = "%s [%s]\n%s" % [card["name"], TAGS[card["tag"]]["name"], card["desc"]]


func _on_tile_pressed(index: int) -> void:
	if pending_card != "":
		_place_card(index)
		return
	if grid[index] == "":
		return
	_show_sell_dialog(index)


func _place_card(index: int) -> void:
	var removed := ""
	if grid[index] != "":
		removed = grid[index]
	grid[index] = pending_card
	var card: Dictionary = CARDS[pending_card]
	pending_card = ""
	grid_hint.text = "毎朝カードを1枚ドラフトして配置。タイルをクリックで詳細/売却。"
	_recalc_grid()
	_play("buy")
	_zunda_say("place", 2.0)
	if removed != "":
		_show_toast("%s を撤去して %s を配置!" % [CARDS[removed]["name"], card["name"]])
	GameLog.info("配置: %s → マス%d%s" % [card["name"], index, " (撤去:%s)" % removed if removed != "" else ""])
	_save_game()


func _show_sell_dialog(index: int) -> void:
	var card: Dictionary = CARDS[grid[index]]
	var refund := snappedf(_rent(day) * 0.3, 1.0)
	var dim := _make_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var box := _padded_vbox(panel, 20)
	box.add_child(_styled_label("%s [%s]" % [card["name"], TAGS[card["tag"]]["name"]], 24, Color(0.45, 0.28, 0.1), true))
	box.add_child(_styled_label("%s\n基本 %s/秒 → いま %s/秒" % [card["desc"], _fmt(card["rate"]), _fmt(cell_rates[index] * _multiplier())], 16, Color(0.4, 0.32, 0.25), true))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var sell := Button.new()
	sell.text = "売却する (+%s個)" % _fmt(refund)
	sell.custom_minimum_size = Vector2(180, 42)
	sell.pressed.connect(func() -> void:
		grid[index] = ""
		bread += refund
		_recalc_grid()
		GameLog.info("売却: %s (+%s)" % [card["name"], _fmt(refund)])
		_close_overlay()
	)
	buttons.add_child(sell)
	var cancel := Button.new()
	cancel.text = "やめる"
	cancel.custom_minimum_size = Vector2(120, 42)
	cancel.pressed.connect(_close_overlay)
	buttons.add_child(cancel)


# --- ドラフト ---

func _start_draft() -> void:
	_zunda_say("draft", 3.0)
	var pool: Array = CARDS.keys()
	var picks: Array = []
	while picks.size() < 3:
		var card_id: String = pool[randi() % pool.size()]
		if not (card_id in picks):
			picks.append(card_id)
	GameLog.info("%d日目ドラフト: %s" % [day, ", ".join(picks)])
	var dim := _make_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var box := _padded_vbox(panel, 22)
	box.add_child(_styled_label("%d日目の朝 — 仕入れるカードを1枚えらぶ" % day, 22, Color(0.45, 0.28, 0.1), true))
	box.add_child(_styled_label("天気: %s (%s) / 今夜の家賃: %s 個" % [WEATHERS[weather]["name"], WEATHERS[weather]["desc"], _fmt(_rent(day))], 15, Color(0.55, 0.42, 0.3), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for card_id in picks:
		var card: Dictionary = CARDS[card_id]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(195, 130)
		btn.text = "%s\n[%s] %s/秒\n%s" % [card["name"], TAGS[card["tag"]]["name"], _fmt(card["rate"]), card["desc"]]
		btn.self_modulate = TAGS[card["tag"]]["color"]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_draft_pick.bind(card_id))
		row.add_child(btn)
	var skip := Button.new()
	skip.text = "スキップして開店 (+%s個)" % _fmt(_rent(day) * 0.25)
	skip.custom_minimum_size = Vector2(260, 40)
	skip.pressed.connect(func() -> void:
		bread += snappedf(_rent(day) * 0.25, 1.0)
		GameLog.info("ドラフトをスキップ")
		_close_overlay()
	)
	var skip_box := HBoxContainer.new()
	skip_box.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_box.add_child(skip)
	box.add_child(skip_box)
	# 放置プレイヤー向け: 20秒で自動ピック→空きマスに自動配置
	draft_token += 1
	var token := draft_token
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if token == draft_token and overlay != null:
			_on_draft_pick(picks[randi() % picks.size()])
			if pending_card != "":
				for i in GRID_SIZE:
					if grid[i] == "":
						_place_card(i)
						break
	)


func _on_draft_pick(card_id: String) -> void:
	draft_token += 1
	_close_overlay()
	pending_card = card_id
	grid_hint.text = "「%s」を置くマスをクリック!(埋まったマスに置くと入れ替え)" % CARDS[card_id]["name"]
	_update_grid_ui()
	GameLog.info("ドラフト選択: %s" % CARDS[card_id]["name"])


# --- 営業日 ---

func _reset_day_stats() -> void:
	day_stats = {"clicks": 0, "click_baked": 0.0, "auto_baked": 0.0, "orders_done": 0,
		"orders_failed": 0, "golden": 0, "burnt": 0}
	day_fame_start = fame


func _update_day(delta: float) -> void:
	day_time_left -= delta
	if day_time_left > 0.0:
		return
	if overlay != null:
		day_time_left = 5.0  # 別の画面を見ている間は閉店を待つ
		return
	_close_day()


func _close_day() -> void:
	day_time_left = INF
	var rent := _rent(day)
	var paid := bread >= rent
	GameLog.info("%d日目 閉店: 家賃%s %s / 手焼き%s 自動%s 注文%d/%d" % [
		day, _fmt(rent), "支払OK" if paid else "支払不能",
		_fmt(day_stats["click_baked"]), _fmt(day_stats["auto_baked"]),
		day_stats["orders_done"], day_stats["orders_done"] + day_stats["orders_failed"]])
	if not paid:
		_zunda_say("rent_fail", 5.0)
		_finish_run(_ending_by_id("bankrupt"))
		return
	bread -= rent
	_zunda_say("rent_ok", 2.5)
	if day >= RUN_DAYS:
		meta["clears"] = int(meta["clears"]) + 1
		_finish_run(_judge_ending())
		return
	_show_day_report(rent)


func _show_day_report(rent_paid: float) -> void:
	_play("milestone")
	var list := _list_overlay("%d日目 閉店レポート (残り%d日)" % [day, RUN_DAYS - day])
	var fame_diff := fame - day_fame_start
	var report := "家賃 %s 個を支払った (残り在庫 %s 個)\n" % [_fmt(rent_paid), _fmt(bread)]
	report += "焼いたパン: 手焼き %s / 自動 %s\n" % [_fmt(day_stats["click_baked"]), _fmt(day_stats["auto_baked"])]
	report += "注文: 納品 %d 件 / 失敗 %d 件\n" % [day_stats["orders_done"], day_stats["orders_failed"]]
	report += "ゴールデンパン: %d 個 / 焦げ %d 回\n" % [day_stats["golden"], day_stats["burnt"]]
	report += "名声: ☆%d (%s%d)\n" % [fame, "+" if fame_diff >= 0 else "", fame_diff]
	report += "明日の家賃: %s 個" % _fmt(_rent(day + 1))
	list.add_child(_styled_label(report, 18, Color(0.4, 0.32, 0.2), false))
	var next := Button.new()
	next.text = "翌朝へ (カードドラフト)"
	next.custom_minimum_size = Vector2(0, 48)
	next.pressed.connect(_advance_day)
	list.add_child(next)
	report_token += 1
	var token := report_token
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		if token == report_token and overlay != null:
			_advance_day()
	)


func _advance_day() -> void:
	report_token += 1
	_close_overlay()
	day += 1
	weather = WEATHERS.keys()[randi() % WEATHERS.size()]
	day_time_left = DAY_LENGTH
	_reset_day_stats()
	GameLog.info("%d日目 開店: 天気=%s" % [day, WEATHERS[weather]["name"]])
	_zunda_say("day_open")
	_show_toast("%d日目 開店! %s — %s" % [day, WEATHERS[weather]["name"], WEATHERS[weather]["desc"]])
	_save_game()
	_start_draft()


# --- クリック ---

func _on_bread_button_pressed() -> void:
	if run_over:
		return
	stats["clicks"] += 1.0
	day_stats["clicks"] += 1
	if not _in_fever():
		combo += 1
		combo_timer = COMBO_WINDOW
		if combo >= FEVER_COMBO:
			_start_fever()
	var roll := randf()
	var bread_pos := bread_button.position + bread_button.size * 0.5
	var power := _click_power()
	if roll < BURNT_CHANCE:
		stats["burnt"] += 1.0
		day_stats["burnt"] += 1
		_gain_click(1.0)
		_play("burnt", randf_range(0.95, 1.05))
		_flash_bread(Color(0.35, 0.25, 0.18))
		_spawn_float("こげた… +1", bread_pos, Color(0.3, 0.22, 0.15), 22)
		_zunda_say("burnt")
	elif roll < BURNT_CHANCE + _crit_chance():
		var gain := power * 10.0
		_gain_click(gain)
		_play("crit", randf_range(0.95, 1.1))
		_shake()
		_spawn_crumbs(bread_pos, 24, Color(1.0, 0.8, 0.3))
		_spawn_float("こんがり! +%s" % _fmt(gain), bread_pos, Color(0.95, 0.55, 0.1), 32)
		_zunda_say("crit", 2.0)
	else:
		_gain_click(power)
		# コンボが乗るほどピッチが上がる(連打の気持ちよさ)
		_play("click", 0.9 + minf(combo, FEVER_COMBO) * 0.03 + randf_range(0.0, 0.1))
		_spawn_crumbs(bread_pos, 8, Color(0.85, 0.57, 0.23))
		_spawn_float("+%s" % _fmt(power), bread_pos + Vector2(randf_range(-40, 40), -30), Color(0.5, 0.33, 0.15), 24)
	bread_button.scale = Vector2(0.9, 0.9)
	var tw := create_tween()
	tw.tween_property(bread_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gain_click(amount: float) -> void:
	bread += amount
	total_baked += amount
	stats["click_baked"] += amount
	day_stats["click_baked"] += amount


func _on_tick() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('kb_hb',''+Date.now())}catch(e){}")
	if run_over:
		return
	_check_trophies()
	if _effective_per_sec() > 0.0:
		var pos := bread_button.position + Vector2(bread_button.size.x * 0.5, -10)
		_spawn_float("+%s" % _fmt(_effective_per_sec()), pos + Vector2(randf_range(-60, 60), 0), Color(0.65, 0.5, 0.3, 0.8), 18)
	if order_state == "none":
		order_cooldown -= 1.0
		if order_cooldown <= 0.0:
			_offer_order()


# --- 注文 ---

func _setup_order_panel() -> void:
	order_panel = PanelContainer.new()
	order_panel.position = Vector2(24, 120)
	order_panel.custom_minimum_size = Vector2(310, 0)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	order_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	order_title = Label.new()
	order_title.add_theme_font_size_override("font_size", 20)
	box.add_child(order_title)
	order_body = Label.new()
	order_body.add_theme_font_size_override("font_size", 16)
	order_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(order_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	order_accept = Button.new()
	order_accept.text = "受ける"
	order_accept.pressed.connect(_on_order_accept)
	buttons.add_child(order_accept)
	order_decline = Button.new()
	order_decline.text = "断る"
	order_decline.pressed.connect(_on_order_decline)
	buttons.add_child(order_decline)
	order_deliver = Button.new()
	order_deliver.text = "納品する"
	order_deliver.pressed.connect(_on_order_deliver)
	buttons.add_child(order_deliver)
	add_child(order_panel)
	order_panel.visible = false


func _offer_order() -> void:
	order_state = "offer"
	var scale_base: float = maxf(15.0, _effective_per_sec() * 18.0 + _click_power() * 12.0)
	order_amount = snappedf(scale_base * randf_range(0.8, 1.6), 1.0)
	order_reward = snappedf(order_amount * randf_range(1.8, 2.4) * grid_order_reward_mult, 1.0)
	order_fame = 2 if order_amount > scale_base * 1.2 else 1
	if weather == "rain":
		order_reward = snappedf(order_reward * 1.3, 1.0)
	order_time_left = randf_range(40.0, 75.0)
	GameLog.info("注文出現: %s個 / %d秒 / 報酬%s+☆%d" % [_fmt(order_amount), int(order_time_left), _fmt(order_reward), order_fame])
	customer_id = CUSTOMERS.keys()[randi() % CUSTOMERS.size()]
	customer.visible = true
	_customer_say("offer", _fmt(order_amount))
	_play("order_bell")
	order_panel.visible = true
	order_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(order_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_order_accept() -> void:
	order_state = "active"


func _on_order_decline() -> void:
	order_state = "none"
	order_panel.visible = false
	order_cooldown = _order_delay(20.0, 40.0)
	_hide_customer_later()


func _hide_customer_later() -> void:
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if order_state == "none":
			customer.visible = false
			customer_bubble.visible = false
	)


func _on_order_deliver() -> void:
	if bread < order_amount:
		return
	bread -= order_amount
	bread += order_reward
	total_baked += order_reward
	fame += order_fame
	stats["orders_done"] += 1.0
	day_stats["orders_done"] += 1
	GameLog.info("注文納品: %s個 → 報酬%s ☆%d (通算%d回)" % [_fmt(order_amount), _fmt(order_reward), fame, int(stats["orders_done"])])
	_customer_say("done")
	_zunda_say("order_done", 2.5)
	_hide_customer_later()
	_play("order_ok")
	_spawn_float("納品完了! +%s  ☆+%d" % [_fmt(order_reward), order_fame], order_panel.position + Vector2(150, 0), Color(0.2, 0.55, 0.25), 24)
	order_state = "none"
	order_panel.visible = false
	order_cooldown = _order_delay(35.0, 70.0)
	_save_game()


func _update_order(delta: float) -> void:
	if order_state == "none":
		return
	order_time_left -= delta
	if order_time_left <= 0.0:
		stats["orders_failed"] += 1.0
		day_stats["orders_failed"] += 1
		if order_state == "active":
			fame = maxi(0, fame - 1)
			GameLog.warn("注文失敗: %s個に間に合わず (☆%d)" % [_fmt(order_amount), fame])
			_customer_say("fail")
			_zunda_say("order_fail", 2.5)
			_play("order_fail")
			_spawn_float("間に合わなかった… ☆-1", order_panel.position + Vector2(150, 0), Color(0.6, 0.25, 0.2), 22)
		order_state = "none"
		order_panel.visible = false
		order_cooldown = _order_delay(30.0, 60.0)
		_hide_customer_later()
		return
	if order_state == "offer":
		order_title.text = "★ 注文が来た!"
		order_body.text = "パン %s 個を %d 秒以内に!\n報酬: パン %s 個 + 名声☆%d" % [_fmt(order_amount), int(order_time_left), _fmt(order_reward), order_fame]
		order_accept.visible = true
		order_decline.visible = true
		order_deliver.visible = false
	else:
		order_title.text = "▼ 注文対応中"
		order_body.text = "パン %s 個 / 残り %d 秒" % [_fmt(order_amount), int(order_time_left)]
		order_accept.visible = false
		order_decline.visible = false
		order_deliver.visible = true
		order_deliver.disabled = bread < order_amount
		order_deliver.text = "納品する (%s/%s)" % [_fmt(minf(bread, order_amount)), _fmt(order_amount)]


# --- ゴールデンパン ---

func _setup_golden() -> void:
	golden_timer = Timer.new()
	golden_timer.one_shot = true
	golden_timer.timeout.connect(_spawn_golden)
	add_child(golden_timer)
	golden_timer.start(_golden_delay(12.0, 25.0))


func _spawn_golden() -> void:
	if run_over:
		return
	GameLog.info("ゴールデンパン出現")
	_zunda_say("golden_spawn", 2.5)
	_play("golden_appear")
	golden_button = TextureButton.new()
	golden_button.texture_normal = GOLD_TEXTURE
	golden_button.ignore_texture_size = true
	golden_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	golden_button.size = Vector2(90, 90)
	golden_button.pivot_offset = Vector2(45, 45)
	var from_left := randf() < 0.5
	var y := randf_range(size.y * 0.15, size.y * 0.75)
	golden_button.position = Vector2(-100 if from_left else size.x + 10, y)
	golden_button.pressed.connect(_on_golden_pressed)
	add_child(golden_button)
	var target_x := size.x + 10 if from_left else -100.0
	# Tweenはボタン自身に束縛する: ボタン削除と同時にTweenも消え、
	# 削除済みオブジェクトを対象にした無限ループTweenの空回り(フリーズ)を防ぐ
	var tw := golden_button.create_tween()
	tw.set_parallel(true)
	tw.tween_property(golden_button, "position:x", target_x, 7.0)
	tw.tween_property(golden_button, "position:y", y + randf_range(-50, 50), 7.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(_despawn_golden)
	var wiggle := golden_button.create_tween().set_loops(10)
	wiggle.tween_property(golden_button, "rotation", 0.15, 0.4).set_trans(Tween.TRANS_SINE)
	wiggle.tween_property(golden_button, "rotation", -0.15, 0.4).set_trans(Tween.TRANS_SINE)


func _despawn_golden() -> void:
	if is_instance_valid(golden_button):
		golden_button.queue_free()
	golden_button = null
	golden_timer.start(_golden_delay(30.0, 60.0))


func _on_golden_pressed() -> void:
	var bonus: float = max(_rent(day) * 0.4, bread * 0.12 + _effective_per_sec() * 25.0)
	bonus = snappedf(bonus, 1.0)
	bread += bonus
	total_baked += bonus
	stats["golden"] += 1.0
	day_stats["golden"] += 1
	GameLog.info("ゴールデンパン獲得: +%s (通算%d個)" % [_fmt(bonus), int(stats["golden"])])
	_zunda_say("golden_get")
	_play("golden_get")
	_shake(6.0)
	var pos := golden_button.position + Vector2(45, 0)
	_spawn_crumbs(pos, 30, Color(1.0, 0.85, 0.2))
	_spawn_float("ゴールデンパン! +%s" % _fmt(bonus), pos, Color(0.85, 0.6, 0.0), 34)
	_despawn_golden()


# --- 称号・トロフィー ---

func _check_milestones() -> void:
	if milestone_index >= MILESTONES.size():
		return
	if total_baked < MILESTONES[milestone_index][0]:
		return
	var title: String = MILESTONES[milestone_index][1]
	milestone_index += 1
	GameLog.info("称号獲得: %s (累計%s)" % [title, _fmt(total_baked)])
	_zunda_say("milestone", 2.5)
	_play("milestone")
	_show_toast("称号獲得: %s" % title)
	_save_game()


func _stat_value(key: String) -> float:
	match key:
		"total": return total_baked
		"clicks": return stats["clicks"]
		"golden": return stats["golden"]
		"burnt": return stats["burnt"]
		"orders": return stats["orders_done"]
		"cards": return float(_cards_placed())
		"fame": return float(fame)
		"day": return float(day)
		"clears": return float(meta["clears"])
		"endings": return float(meta["endings"].size())
	return 0.0


func _check_trophies() -> void:
	for trophy in TROPHIES:
		if trophy["id"] in meta["trophies"]:
			continue
		if _stat_value(trophy["key"]) >= trophy["v"]:
			meta["trophies"].append(trophy["id"])
			GameLog.info("実績解除: %s" % trophy["title"])
			_zunda_say("trophy", 2.0)
			_play("trophy")
			_show_toast("実績解除: %s" % trophy["title"])
			_save_game()


# --- エンディング(ラン終了) ---

func _ending_by_id(id: String) -> Dictionary:
	for ending in ENDINGS:
		if ending["id"] == id:
			return ending
	return ENDINGS[5]


func _judge_ending() -> Dictionary:
	var click_ratio: float = stats["click_baked"] / maxf(1.0, total_baked)
	if stats["burnt"] >= 20.0:
		return _ending_by_id("burnt")
	if stats["golden"] >= 8.0:
		return _ending_by_id("golden")
	if _tag_count("machine") >= 6:
		return _ending_by_id("empire")
	if click_ratio >= 0.45 or _tag_count("artisan") + _tag_count("click") >= 6:
		return _ending_by_id("artisan")
	if stats["orders_done"] >= 10.0 or _tag_count("service") >= 5:
		return _ending_by_id("beloved")
	return _ending_by_id("cozy")


func _finish_run(ending: Dictionary) -> void:
	run_over = true
	day_time_left = INF
	order_state = "none"
	order_panel.visible = false
	if is_instance_valid(golden_button):
		golden_button.queue_free()
		golden_button = null
	golden_timer.stop()
	if not (ending["id"] in meta["endings"]):
		meta["endings"].append(ending["id"])
	_zunda_say("ending", 6.0)
	GameLog.info("ラン終了: %s (日数%d クリック比%.0f%% 注文%d 黄金%d 焦げ%d 機械%d 職人%d 接客%d)" % [
		ending["title"], day, stats["click_baked"] / maxf(1.0, total_baked) * 100.0,
		int(stats["orders_done"]), int(stats["golden"]), int(stats["burnt"]),
		_tag_count("machine"), _tag_count("artisan"), _tag_count("service")])
	_play("ending")
	_save_game()
	_show_ending(ending)


func _show_ending(ending: Dictionary) -> void:
	var dim := _make_overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var box := _padded_vbox(panel, 24)
	var head := "倒産…" if ending["id"] == "bankrupt" else "14日間の営業をやりとげた!"
	box.add_child(_styled_label("%s ◆ エンディング %d/%d ◆" % [head, meta["endings"].size(), ENDINGS.size()], 16, Color(0.6, 0.45, 0.25), true))
	box.add_child(_styled_label(ending["title"], 36, Color(0.45, 0.28, 0.1), true))
	box.add_child(_styled_label(ending["text"], 18, Color(0.35, 0.3, 0.25), true))
	box.add_child(_styled_label("累計 %s 個 / 名声 ☆%d / 配置 %d枚" % [_fmt(total_baked), fame, _cards_placed()], 15, Color(0.5, 0.42, 0.32), true))
	if meta["endings"].size() < ENDINGS.size():
		box.add_child(_styled_label("…ほかの結末も あるみたい(「エンド」ボタンから確認)", 14, Color(0.55, 0.5, 0.45), true))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var reset := Button.new()
	reset.text = "新しい朝 (周回ボーナス: クリック+%d 生産+%d%%)" % [meta["endings"].size(), meta["endings"].size() * 5]
	reset.custom_minimum_size = Vector2(380, 48)
	reset.pressed.connect(func() -> void:
		_close_overlay()
		_new_morning()
	)
	buttons.add_child(reset)


func _new_morning() -> void:
	bread = 0.0
	total_baked = 0.0
	fame = 0
	milestone_index = 0
	run_over = false
	pending_card = ""
	for key in stats:
		stats[key] = 0.0
	grid.fill("")
	_recalc_grid()
	order_state = "none"
	order_panel.visible = false
	order_cooldown = 25.0
	day = 1
	weather = WEATHERS.keys()[randi() % WEATHERS.size()]
	day_time_left = DAY_LENGTH
	_reset_day_stats()
	golden_timer.start(_golden_delay(12.0, 25.0))
	GameLog.info("新しい朝(ラン開始): エンド%d/%d" % [meta["endings"].size(), ENDINGS.size()])
	_save_game()
	_show_toast("新しい朝が来た! 14日間の経営、再挑戦なのだ")
	_start_draft()


# --- 一覧オーバーレイ ---

func _setup_top_bar() -> void:
	fame_label = Label.new()
	fame_label.position = Vector2(24, 14)
	fame_label.add_theme_font_size_override("font_size", 22)
	fame_label.add_theme_color_override("font_color", Color(0.75, 0.55, 0.1))
	add_child(fame_label)

	goal_label = Label.new()
	goal_label.position = Vector2(24, 44)
	goal_label.add_theme_font_size_override("font_size", 15)
	goal_label.add_theme_color_override("font_color", Color(0.62, 0.4, 0.3))
	add_child(goal_label)

	day_label = Label.new()
	day_label.position = Vector2(24, 66)
	day_label.add_theme_font_size_override("font_size", 16)
	day_label.add_theme_color_override("font_color", Color(0.5, 0.4, 0.28))
	add_child(day_label)

	day_bar = ProgressBar.new()
	day_bar.position = Vector2(24, 92)
	day_bar.custom_minimum_size = Vector2(200, 10)
	day_bar.show_percentage = false
	day_bar.max_value = DAY_LENGTH
	add_child(day_bar)

	combo_bar = ProgressBar.new()
	combo_bar.position = Vector2(300, 600)
	combo_bar.custom_minimum_size = Vector2(220, 14)
	combo_bar.show_percentage = false
	combo_bar.max_value = FEVER_COMBO
	add_child(combo_bar)
	combo_label = Label.new()
	combo_label.position = Vector2(300, 616)
	combo_label.add_theme_font_size_override("font_size", 14)
	combo_label.add_theme_color_override("font_color", Color(0.6, 0.45, 0.2))
	combo_label.text = "れんだでフィーバー!"
	add_child(combo_label)

	var version_label := Label.new()
	version_label.text = "v%s" % VERSION
	version_label.position = Vector2(24, size.y - 28)
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5))
	add_child(version_label)

	var credit_label := Label.new()
	credit_label.text = "立ち絵: 坂本アヒル様 / 東北ずん子・ずんだもんPJ ガイドライン準拠の二次創作"
	credit_label.position = Vector2(size.x - 460, size.y - 28)
	credit_label.add_theme_font_size_override("font_size", 12)
	credit_label.add_theme_color_override("font_color", Color(0.7, 0.62, 0.5))
	add_child(credit_label)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.position = Vector2(size.x - 330, 12)
	add_child(bar)
	var trophy_btn := Button.new()
	trophy_btn.text = "実績"
	trophy_btn.custom_minimum_size = Vector2(96, 36)
	trophy_btn.pressed.connect(_show_trophy_list)
	bar.add_child(trophy_btn)
	var end_btn := Button.new()
	end_btn.text = "エンド"
	end_btn.custom_minimum_size = Vector2(96, 36)
	end_btn.pressed.connect(_show_ending_list)
	bar.add_child(end_btn)
	var mute_btn := Button.new()
	mute_btn.text = "♪ オン"
	mute_btn.toggle_mode = true
	mute_btn.custom_minimum_size = Vector2(96, 36)
	mute_btn.toggled.connect(func(pressed: bool) -> void:
		mute_btn.text = "♪ オフ" if pressed else "♪ オン"
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), pressed)
	)
	bar.add_child(mute_btn)


func _make_overlay() -> Control:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.07, 0.04, 0.6)
	overlay.add_child(dim)
	add_child(overlay)
	return overlay


func _close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _list_overlay(title: String) -> VBoxContainer:
	var dim := _make_overlay()
	var panel := PanelContainer.new()
	panel.position = Vector2(size.x * 0.5 - 330, 50)
	panel.custom_minimum_size = Vector2(660, 0)
	dim.add_child(panel)
	var box := _padded_vbox(panel, 16)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title_label := _styled_label(title, 24, Color(0.45, 0.28, 0.1), false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var close := Button.new()
	close.text = "とじる ×"
	close.pressed.connect(_close_overlay)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 520)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _show_trophy_list() -> void:
	var unlocked: int = meta["trophies"].size()
	var list := _list_overlay("★ トロフィー (%d/%d)" % [unlocked, TROPHIES.size()])
	for trophy in TROPHIES:
		var got: bool = trophy["id"] in meta["trophies"]
		var text: String = "★ %s — %s" % [trophy["title"], trophy["desc"]] if got else "□ ??? — %s" % trophy["desc"]
		var color := Color(0.4, 0.3, 0.15) if got else Color(0.6, 0.55, 0.5)
		list.add_child(_styled_label(text, 17, color, false))


func _show_ending_list() -> void:
	var seen: int = meta["endings"].size()
	var list := _list_overlay("◆ エンディング (%d/%d)" % [seen, ENDINGS.size()])
	list.add_child(_styled_label("14日間の経営をやりとげる(か、倒産する)と物語が結末をむかえる。\nどの結末になるかは、お店のかたちとあなたの焼き方しだい。", 15, Color(0.5, 0.42, 0.32), false))
	for ending in ENDINGS:
		var got: bool = ending["id"] in meta["endings"]
		if got:
			list.add_child(_styled_label("◆ %s\n　%s" % [ending["title"], ending["text"].replace("\n", " ")], 17, Color(0.4, 0.3, 0.15), false))
		else:
			list.add_child(_styled_label("□ ???\n　ヒント: %s" % ending["hint"], 17, Color(0.6, 0.55, 0.5), false))


func _padded_vbox(panel: PanelContainer, pad: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, pad)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func _styled_label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# --- キャラクター ---

func _setup_characters() -> void:
	zunda = TextureRect.new()
	zunda.texture = ZUNDA_TEXTURES["normal"]
	zunda.position = Vector2(20, 410)
	zunda.custom_minimum_size = Vector2(160, 300)
	zunda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	zunda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	zunda.pivot_offset = Vector2(80, 300)
	add_child(zunda)
	var bob := zunda.create_tween().set_loops()
	bob.tween_property(zunda, "scale", Vector2(1.015, 0.99), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(zunda, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	zunda_bubble = _make_bubble()
	zunda_bubble.position = Vector2(30, 350)
	zunda_bubble_label = zunda_bubble.get_child(0).get_child(0)

	customer = TextureRect.new()
	customer.texture = CUSTOMERS["metan"]["normal"]
	customer.position = Vector2(348, 124)
	customer.custom_minimum_size = Vector2(120, 230)
	customer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	customer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	customer.visible = false
	add_child(customer)

	customer_bubble = _make_bubble()
	customer_bubble.position = Vector2(348, 360)
	customer_bubble_label = customer_bubble.get_child(0).get_child(0)

	idle_chat_timer = Timer.new()
	idle_chat_timer.one_shot = true
	idle_chat_timer.timeout.connect(_on_idle_chat)
	add_child(idle_chat_timer)
	idle_chat_timer.start(randf_range(6.0, 12.0))


func _make_bubble() -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(230, 0)
	bubble.visible = false
	bubble.z_index = 20
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 8)
	bubble.add_child(margin)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)
	add_child(bubble)
	return bubble


func _zunda_say(event: String, hold: float = 3.5) -> void:
	if not ZUNDA_LINES.has(event):
		return
	var line_pool: Array = ZUNDA_LINES[event]
	var line: String = line_pool[randi() % line_pool.size()]
	var mood: String = MOOD_BY_EVENT.get(event, "normal")
	zunda.texture = ZUNDA_TEXTURES[mood]
	_show_bubble(zunda_bubble, zunda_bubble_label, line, hold)
	speak_token += 1
	var token := speak_token
	get_tree().create_timer(hold).timeout.connect(func() -> void:
		if token == speak_token:
			zunda.texture = ZUNDA_TEXTURES["normal"]
	)


func _customer_say(event: String, amount: String = "") -> void:
	var data: Dictionary = CUSTOMERS[customer_id]
	var line_pool: Array = data[event]
	var line: String = line_pool[randi() % line_pool.size()]
	if "%s" in line:
		line = line % amount
	var mood := "happy" if event == "done" else ("sad" if event == "fail" else "normal")
	customer.texture = data[mood]
	_show_bubble(customer_bubble, customer_bubble_label, line, 4.0)


func _show_bubble(bubble: PanelContainer, label: Label, text: String, hold: float) -> void:
	label.text = text
	bubble.visible = true
	bubble.scale = Vector2(0.7, 0.7)
	var tw := bubble.create_tween()
	tw.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_callback(func() -> void: bubble.visible = false)


func _on_idle_chat() -> void:
	if not zunda_bubble.visible and overlay == null and not run_over:
		_zunda_say("idle")
	idle_chat_timer.start(randf_range(18.0, 35.0))


# --- ログビューア(タイトルを5回クリックで開く隠し画面) ---

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		if now - _title_click_time > 3000:
			_title_clicks = 0
		_title_click_time = now
		_title_clicks += 1
		if _title_clicks >= 5:
			_title_clicks = 0
			_show_log_viewer()


func _show_log_viewer() -> void:
	var list := _list_overlay("ログ (v%s)" % VERSION)
	var copy := Button.new()
	copy.text = "ログをコピー(不具合報告用)"
	copy.custom_minimum_size = Vector2(0, 40)
	copy.pressed.connect(func() -> void:
		_copy_log()
		copy.text = "コピーしました!"
	)
	list.add_child(copy)
	var js_log := _js_error_log()
	if js_log != "[]" and js_log != "" and js_log != "null":
		list.add_child(_styled_label("[ブラウザ側エラー・異常終了記録]\n%s" % js_log, 13, Color(0.7, 0.3, 0.2), false))
	list.add_child(_styled_label(GameLog.dump(), 13, Color(0.4, 0.35, 0.3), false))


func _js_error_log() -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("localStorage.getItem('kb_errlog')||'[]'", true))
	return "[]"


func _copy_log() -> void:
	var text := "こんがりベーカリー v%s\n%s\n\n[ブラウザ側]\n%s" % [VERSION, GameLog.dump(), _js_error_log()]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard.writeText(%s)" % JSON.stringify(text), true)
	else:
		DisplayServer.clipboard_set(text)


# --- トースト ---

func _setup_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.position = Vector2(size.x * 0.5 - 200, -80)
	toast_panel.custom_minimum_size = Vector2(400, 56)
	toast_panel.z_index = 60
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_panel.add_child(toast_label)
	add_child(toast_panel)


func _show_toast(text: String) -> void:
	toast_queue.append(text)
	if not toast_showing:
		_next_toast()


func _next_toast() -> void:
	if toast_queue.is_empty():
		toast_showing = false
		return
	toast_showing = true
	toast_label.text = toast_queue.pop_front()
	var tw := create_tween()
	tw.tween_property(toast_panel, "position:y", 20.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(toast_panel, "position:y", -80.0, 0.3)
	tw.tween_callback(_next_toast)


# --- 演出ヘルパー ---

func _spawn_float(text: String, pos: Vector2, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	label.z_index = 10
	add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", pos.y - 70.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(label.queue_free)


func _spawn_crumbs(pos: Vector2, amount: int, color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.position = pos
	particles.one_shot = true
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 70.0
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 260.0
	particles.gravity = Vector2(0, 600)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = color
	particles.z_index = 9
	add_child(particles)
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


func _flash_bread(color: Color) -> void:
	bread_button.modulate = color
	var tw := create_tween()
	tw.tween_property(bread_button, "modulate", Color.WHITE, 0.35)


func _shake(strength: float = 4.0) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _start_idle_animation() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(bread_button, "scale", Vector2(1.03, 0.97), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bread_button, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- オーディオ ---

func _setup_audio() -> void:
	for key in SFX:
		var player := AudioStreamPlayer.new()
		player.stream = SFX[key]
		player.max_polyphony = 4
		player.volume_db = -4.0
		add_child(player)
		sfx_players[key] = player
	# BGMは一旦オフ(SEのみ)。後日精査して差し替える。


func _play(key: String, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = sfx_players[key]
	player.pitch_scale = pitch
	player.play()


# --- UI更新・セーブ ---

func _update_ui() -> void:
	bread_label.text = "%s 個" % _fmt(bread)
	rate_label.text = "毎秒 %s 個 / クリック %s 個" % [_fmt(_effective_per_sec()), _fmt(_click_power())]
	fame_label.text = "☆ %d 名声 (生産+%d%%)" % [fame, int((_multiplier() - 1.0) * 100)]
	var rent := _rent(day)
	var ok := bread >= rent
	goal_label.text = "今夜の家賃: %s 個 (%s)" % [_fmt(rent), "OK" if ok else "あと%s個!" % _fmt(rent - bread)]
	day_label.text = "%d日目/%d日 %s" % [day, RUN_DAYS, WEATHERS[weather]["name"]]
	day_bar.value = clampf(DAY_LENGTH - day_time_left, 0.0, DAY_LENGTH)
	if _in_fever():
		combo_bar.value = FEVER_COMBO
		combo_label.text = "フィーバー中!! 生産×3 (%0.1f秒)" % fever_timer
		combo_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.05))
	else:
		combo_bar.value = combo
		combo_label.text = "れんだでフィーバー! (%d/%d)" % [combo, FEVER_COMBO] if combo > 0 else "れんだでフィーバー!"
		combo_label.add_theme_color_override("font_color", Color(0.6, 0.45, 0.2))


func _fmt(value: float) -> String:
	if value >= 1_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if value >= 10_000.0:
		return "%.1fk" % (value / 1_000.0)
	if value < 10.0 and value != floor(value):
		return "%.1f" % value
	return str(int(value))


func _save_game() -> void:
	var data := {
		"version": 2,
		"run": {
			"bread": bread,
			"total_baked": total_baked,
			"fame": fame,
			"milestone_index": milestone_index,
			"run_over": run_over,
			"stats": stats,
			"grid": grid,
			"day": day,
		},
		"meta": meta,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
	else:
		GameLog.error("セーブ失敗: %s を開けない (err=%d)" % [SAVE_PATH, FileAccess.get_open_error()])


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		GameLog.error("セーブ読込失敗: ファイルを開けない (err=%d)" % FileAccess.get_open_error())
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		GameLog.error("セーブ読込失敗: JSONパースエラー")
		return
	# 旧バージョンのセーブ: 実績・エンディングだけ引き継いで新ランを開始
	var saved_meta: Dictionary = data.get("meta", {})
	meta["trophies"] = saved_meta.get("trophies", [])
	meta["endings"] = saved_meta.get("endings", [])
	meta["clears"] = int(saved_meta.get("clears", 0))
	if int(data.get("version", 1)) < 2:
		GameLog.info("旧セーブを検出: 実績/エンドのみ引き継いで新ランを開始")
		return
	var run: Dictionary = data.get("run", {})
	bread = float(run.get("bread", 0.0))
	total_baked = float(run.get("total_baked", bread))
	fame = int(run.get("fame", 0))
	milestone_index = int(run.get("milestone_index", 0))
	run_over = bool(run.get("run_over", false))
	day = int(run.get("day", 1))
	var saved_stats: Dictionary = run.get("stats", {})
	for key in stats:
		stats[key] = float(saved_stats.get(key, 0.0))
	var saved_grid: Array = run.get("grid", [])
	for i in mini(saved_grid.size(), GRID_SIZE):
		var card_id := str(saved_grid[i])
		grid[i] = card_id if CARDS.has(card_id) else ""
	# ラン終了状態でロードされたら新しい朝から
	if run_over:
		run_over = false
		grid.fill("")
		bread = 0.0
		total_baked = 0.0
		fame = 0
		milestone_index = 0
		day = 1
		for key in stats:
			stats[key] = 0.0
