extends Node2D
## CHAIN BLASTER - 物理連鎖爆破パズル
## 1発の爆発から赤いクレートを連鎖させ、最小手数で全部吹き飛ばす。

const DW := 1152.0          # design width
const DH := 648.0           # design height
const FLOOR_Y := 596.0
const WALL := 24.0

const CRATE := 46.0
const PUSH_RADIUS := 185.0
const IGNITE_RADIUS := 112.0
const PUSH_FORCE := 820.0

const COL_WOOD := Color(0.62, 0.42, 0.22)
const COL_WOOD_HI := Color(0.78, 0.55, 0.30)
const COL_EXPLO := Color(1.0, 0.27, 0.32)
const COL_EXPLO_HI := Color(1.0, 0.55, 0.30)
const COL_GOLD := Color(1.0, 0.85, 0.30)

enum State { START, PLAYING, WIN, LOSE }

var state: int = State.START
var level := 1
var bombs_left := 0
var level_par := 0
var total_explosive := 0
var required := 0
var destroyed := 0
var chain := 0
var best_chain := 0
var score := 0
var best_score := 0
var pending := 0
var settle_timer := 0.0

var bodies: Array = []         # all RigidBody2D crates
var rings: Array = []          # active shockwave rings {pos, r, max_r, a}
var shake := 0.0
var pulse_t := 0.0

var camera: Camera2D
var world: Node2D
var ui: CanvasLayer
var lbl_top: Label
var lbl_center: Label
var lbl_sub: Label
var lbl_help: Label
var font: FontFile
var mouse_pos := Vector2(DW * 0.5, DH * 0.5)

const SAVE_PATH := "user://chain_blaster.cfg"


func _ready() -> void:
	randomize()
	_load_font()
	_load_best()
	_build_static()
	_build_ui()
	start_level()
	_show_intro()


func _load_font() -> void:
	font = FontFile.new()
	var path := "res://assets/fonts/MPLUSRounded1c-Regular.ttf"
	if ResourceLoader.exists(path):
		var f := load(path)
		if f is FontFile:
			font = f


func _apply_font(lbl: Label) -> void:
	if font:
		lbl.add_theme_font_override("font", font)


# ---------------------------------------------------------------- setup
func _build_static() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(DW * 0.5, DH * 0.5)
	add_child(camera)
	camera.make_current()

	world = Node2D.new()
	add_child(world)

	_make_wall(Vector2(DW * 0.5, FLOOR_Y + 60.0), Vector2(DW, 120.0))      # floor
	_make_wall(Vector2(WALL * 0.5, DH * 0.5), Vector2(WALL, DH))           # left
	_make_wall(Vector2(DW - WALL * 0.5, DH * 0.5), Vector2(WALL, DH))      # right


func _make_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var poly := Polygon2D.new()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	poly.color = Color(0.10, 0.13, 0.24)
	body.add_child(poly)
	world.add_child(body)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	lbl_top = Label.new()
	lbl_top.position = Vector2(28, 18)
	_apply_font(lbl_top)
	lbl_top.add_theme_font_size_override("font_size", 26)
	ui.add_child(lbl_top)

	lbl_center = Label.new()
	lbl_center.size = Vector2(DW, 120)
	lbl_center.position = Vector2(0, DH * 0.5 - 90)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(lbl_center)
	lbl_center.add_theme_font_size_override("font_size", 64)
	ui.add_child(lbl_center)

	lbl_sub = Label.new()
	lbl_sub.size = Vector2(DW, 60)
	lbl_sub.position = Vector2(0, DH * 0.5 + 6)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(lbl_sub)
	lbl_sub.add_theme_font_size_override("font_size", 26)
	ui.add_child(lbl_sub)

	lbl_help = Label.new()
	lbl_help.size = Vector2(DW, 44)
	lbl_help.position = Vector2(0, DH - 46)
	lbl_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(lbl_help)
	lbl_help.add_theme_font_size_override("font_size", 18)
	lbl_help.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0, 0.72))
	lbl_help.text = "クリック/タップで爆破。赤いクレートを全部連鎖爆破しよう。R: 最初から"
	ui.add_child(lbl_help)


# ---------------------------------------------------------------- level
func start_level(play_now := true) -> void:
	for b in bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	rings.clear()
	state = State.PLAYING if play_now else State.START
	destroyed = 0
	chain = 0
	best_chain = 0
	pending = 0
	settle_timer = 0.0

	_spawn_field()
	total_explosive = 0
	for b in bodies:
		if b.get_meta("explosive"):
			total_explosive += 1
	required = total_explosive
	bombs_left = level_par
	lbl_center.text = ""
	lbl_sub.text = ""
	lbl_help.text = "水色の円に赤箱を入れて撃つ。島ごとに狙い所が違います。真ん中空撃ちは罠。R: 最初から"
	_update_ui()


func _show_intro() -> void:
	state = State.START
	lbl_center.text = "CHAIN BLASTER"
	lbl_center.add_theme_color_override("font_color", COL_GOLD)
	lbl_sub.text = "限られたボムで、離れた赤い箱の島をすべて消せばクリア。"
	lbl_help.text = "水色の円に入った赤箱だけが起爆します。どの島から撃つかを選ぶゲームです。クリック/タップで開始。"
	_update_ui()


func _spawn_field() -> void:
	# Hand-authored puzzle layouts. Red crates are separated into islands so
	# a lazy center click no longer clears the board. Later layouts have pairs
	# that can be bridged with a well-placed shot for score/bomb efficiency.
	var pattern := (level - 1) % 6
	var tier := int((level - 1) / 6)
	match pattern:
		0:
			level_par = 2
			_spawn_cluster(Vector2(300, FLOOR_Y), 3, 4, 0)
			_spawn_cluster(Vector2(850, FLOOR_Y), 3, 4, 2)
		1:
			level_par = 3
			_spawn_cluster(Vector2(220, FLOOR_Y), 3, 5, 1)
			_spawn_cluster(Vector2(575, FLOOR_Y), 3, 4, 0)
			_spawn_cluster(Vector2(930, FLOOR_Y), 3, 5, 2)
		2:
			level_par = 2
			_spawn_cluster(Vector2(250, FLOOR_Y), 4, 4, 0)
			_spawn_cluster(Vector2(470, FLOOR_Y), 3, 4, 2) # bridgeable pair
			_spawn_cluster(Vector2(900, FLOOR_Y), 3, 5, 1)
		3:
			level_par = 3
			_spawn_cluster(Vector2(205, FLOOR_Y), 3, 4, 2)
			_spawn_cluster(Vector2(430, FLOOR_Y), 3, 5, 0) # bridgeable pair
			_spawn_cluster(Vector2(740, FLOOR_Y), 3, 4, 1)
			_spawn_cluster(Vector2(965, FLOOR_Y), 3, 5, 2) # bridgeable pair
		4:
			level_par = 3
			_spawn_cluster(Vector2(270, FLOOR_Y), 4, 6, 1)
			_spawn_cluster(Vector2(580, FLOOR_Y), 3, 4, 0)
			_spawn_cluster(Vector2(875, FLOOR_Y), 4, 6, 2)
			_spawn_bridge(Vector2(430, FLOOR_Y - 94), Vector2(720, FLOOR_Y - 94), 3)
		_:
			level_par = 4
			_spawn_cluster(Vector2(170, FLOOR_Y), 3, 5, 2)
			_spawn_cluster(Vector2(380, FLOOR_Y), 3, 4, 0)
			_spawn_cluster(Vector2(600, FLOOR_Y), 4, 6, 1)
			_spawn_cluster(Vector2(815, FLOOR_Y), 3, 4, 2)
			_spawn_cluster(Vector2(1030, FLOOR_Y), 3, 5, 0)

	# A little escalation after the first loop: fewer spare shots, taller stacks.
	level_par = maxi(1, level_par - mini(tier, 1))


func _spawn_cluster(base: Vector2, cols: int, rows: int, red_bias: int) -> void:
	var mid := float(cols - 1) * 0.5
	for c in range(cols):
		for r in range(rows):
			var x := base.x + (float(c) - mid) * (CRATE + 3.0)
			var y := base.y - CRATE * 0.5 - float(r) * (CRATE + 2.0)
			var spine := red_bias
			var explosive: bool = c == spine or (r == rows - 1 and abs(c - spine) <= 1)
			# Wood caps create messy physics and make the best shot less obvious.
			if r == 0 and c != spine:
				explosive = false
			_make_crate(Vector2(x, y), explosive)


func _spawn_bridge(a: Vector2, b: Vector2, count: int) -> void:
	for i in range(count):
		var t := float(i + 1) / float(count + 1)
		var p := a.lerp(b, t)
		_make_crate(p + Vector2(0, randf_range(-8, 8)), true)


func _make_crate(pos: Vector2, explosive: bool) -> void:
	var body := RigidBody2D.new()
	body.position = pos
	body.mass = 1.0
	body.angular_damp = 1.2
	body.linear_damp = 0.2
	body.contact_monitor = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(CRATE, CRATE)
	shape.shape = rect
	body.add_child(shape)

	var poly := Polygon2D.new()
	var h := CRATE * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	poly.name = "fill"
	body.add_child(poly)

	var inner := Polygon2D.new()
	var hi := CRATE * 0.5 - 6.0
	inner.polygon = PackedVector2Array([
		Vector2(-hi, -hi), Vector2(hi, -hi), Vector2(hi, hi), Vector2(-hi, hi)])
	inner.name = "inner"
	body.add_child(inner)

	world.add_child(body)
	bodies.append(body)
	_set_explosive(body, explosive)


func _set_explosive(body: RigidBody2D, explosive: bool) -> void:
	body.set_meta("explosive", explosive)
	body.set_meta("armed", explosive)
	var fill := body.get_node("fill") as Polygon2D
	var inner := body.get_node("inner") as Polygon2D
	if explosive:
		fill.color = COL_EXPLO
		inner.color = COL_EXPLO_HI
	else:
		fill.color = COL_WOOD
		inner.color = COL_WOOD_HI


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	var clicked := false
	var pos := Vector2.ZERO
	if event is InputEventMouseMotion:
		mouse_pos = get_global_mouse_position()
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked = true
		pos = get_global_mouse_position()
		mouse_pos = pos
	elif event is InputEventScreenTouch and event.pressed:
		clicked = true
		pos = get_global_mouse_position()
		mouse_pos = pos
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		level = 1
		score = 0
		start_level()
		return

	if not clicked:
		return

	match state:
		State.START:
			score = 0
			level = 1
			start_level()
		State.PLAYING:
			if bombs_left > 0:
				player_blast(pos)
		State.WIN:
			level += 1
			start_level()
		State.LOSE:
			start_level()


# ---------------------------------------------------------------- blasts
func player_blast(pos: Vector2) -> void:
	bombs_left -= 1
	chain = 0
	shake = max(shake, 14.0)
	_add_ring(pos, 300.0, Color(0.7, 0.95, 1.0))
	_spawn_burst(pos, Color(0.7, 0.95, 1.0), 30)
	var hits := _do_blast(pos)
	if hits == 0:
		lbl_sub.text = "MISS! 水色の円に赤箱を入れて撃つ必要があります。"
		lbl_center.text = "MISS"
		lbl_center.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		lbl_center.text = ""
	_update_ui()
	settle_timer = 0.0


func _do_blast(pos: Vector2) -> int:
	var hits := 0
	for b in bodies:
		if not is_instance_valid(b):
			continue
		var d: float = b.global_position.distance_to(pos)
		if d < PUSH_RADIUS:
			var dir: Vector2 = (b.global_position - pos)
			if dir.length() < 1.0:
				dir = Vector2(randf_range(-1, 1), -1)
			dir = dir.normalized()
			var fall: float = 1.0 - d / PUSH_RADIUS
			b.apply_central_impulse(dir * PUSH_FORCE * fall + Vector2(0, -120.0 * fall))
			b.apply_torque_impulse(randf_range(-1.0, 1.0) * 9000.0 * fall)
	# ignite explosives -> chain
	for b in bodies:
		if not is_instance_valid(b):
			continue
		if b.get_meta("explosive") and b.get_meta("armed"):
			if b.global_position.distance_to(pos) < IGNITE_RADIUS:
				_ignite(b)
				hits += 1
	return hits


func _ignite(crate: RigidBody2D) -> void:
	if not crate.get_meta("armed"):
		return
	crate.set_meta("armed", false)
	pending += 1
	var delay := randf_range(0.05, 0.12)
	get_tree().create_timer(delay).timeout.connect(_detonate.bind(crate))


func _detonate(crate: RigidBody2D) -> void:
	pending -= 1
	if not is_instance_valid(crate):
		_after_event()
		return
	var pos: Vector2 = crate.global_position
	destroyed += 1
	chain += 1
	best_chain = max(best_chain, chain)
	score += 60 * max(1, chain)
	shake = max(shake, 9.0 + float(chain) * 1.4)
	_add_ring(pos, 230.0, COL_EXPLO_HI)
	_spawn_burst(pos, COL_EXPLO, 26)

	bodies.erase(crate)
	crate.queue_free()

	if chain == 4:
		_slowmo()

	_do_blast(pos)
	_update_ui()
	_after_event()


func _slowmo() -> void:
	Engine.time_scale = 0.35
	var t := get_tree().create_timer(0.18, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = 1.0)


# ---------------------------------------------------------------- effects
func _add_ring(pos: Vector2, max_r: float, col: Color) -> void:
	rings.append({"pos": pos, "r": 8.0, "max_r": max_r, "a": 1.0, "col": col})
	queue_redraw()


func _spawn_burst(pos: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 620.0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 460.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = col
	world.add_child(p)
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _draw() -> void:
	# neon grid background
	for x in range(0, int(DW) + 1, 48):
		draw_line(Vector2(x, 0), Vector2(x, DH), Color(0.18, 0.35, 0.52, 0.16), 1.0)
	for y in range(0, int(DH) + 1, 48):
		draw_line(Vector2(0, y), Vector2(DW, y), Color(0.18, 0.35, 0.52, 0.16), 1.0)
	draw_rect(Rect2(0, FLOOR_Y - 2, DW, 4), Color(0.38, 0.85, 1.0, 0.35))

	# Aim preview: the blue circle is the first-blast ignition range.
	if state == State.PLAYING or state == State.START:
		draw_circle(mouse_pos, IGNITE_RADIUS, Color(0.35, 0.85, 1.0, 0.055))
		draw_arc(mouse_pos, IGNITE_RADIUS, 0.0, TAU, 72, Color(0.35, 0.9, 1.0, 0.55), 3.0, true)
		draw_arc(mouse_pos, PUSH_RADIUS, 0.0, TAU, 72, Color(0.95, 0.95, 1.0, 0.18), 1.5, true)

	for r in rings:
		var col: Color = r["col"]
		col.a = r["a"] * 0.9
		draw_arc(r["pos"], r["r"], 0.0, TAU, 48, col, 5.0 * r["a"], true)


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	pulse_t += delta
	# make live (armed) explosive crates pulse so they read as targets
	var glow := 0.5 + 0.5 * sin(pulse_t * 6.0)
	for b in bodies:
		if not is_instance_valid(b):
			continue
		if b.get_meta("explosive") and b.get_meta("armed"):
			var inner := b.get_node_or_null("inner") as Polygon2D
			if inner:
				inner.color = COL_EXPLO_HI.lerp(Color(1, 1, 0.7), glow)

	# shockwave rings
	if not rings.is_empty():
		for r in rings:
			r["r"] = min(r["max_r"], r["r"] + (r["max_r"] - r["r"]) * delta * 9.0)
			r["a"] -= delta * 2.6
		var keep: Array = []
		for r in rings:
			if r["a"] > 0.0:
				keep.append(r)
		rings = keep
		queue_redraw()

	# camera shake
	if shake > 0.0:
		shake = max(0.0, shake - delta * 60.0)
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# cleanup crates that left the arena
	var changed := false
	for b in bodies.duplicate():
		if not is_instance_valid(b):
			continue
		var p: Vector2 = b.global_position
		if p.y > DH + 260.0 or p.x < -160.0 or p.x > DW + 160.0:
			if b.get_meta("explosive") and b.get_meta("armed"):
				destroyed += 1
				changed = true
			bodies.erase(b)
			b.queue_free()
	if changed:
		_update_ui()
		_after_event()

	if state == State.PLAYING:
		settle_timer += delta
		if pending == 0 and settle_timer > 0.35:
			_check_end()


func _after_event() -> void:
	settle_timer = 0.0
	if pending == 0:
		_check_end()


func _check_end() -> void:
	if state != State.PLAYING or pending > 0:
		return
	if destroyed >= required:
		_win()
	elif bombs_left <= 0:
		_lose()


func _win() -> void:
	state = State.WIN
	score += bombs_left * 250 + best_chain * 120
	best_score = max(best_score, score)
	_save_best()
	lbl_center.text = "CLEAR!"
	lbl_center.add_theme_color_override("font_color", COL_GOLD)
	lbl_sub.text = "最大チェイン x%d ・ ボム残 %d  /  クリック or タップで次へ" % [best_chain, bombs_left]
	_update_ui()


func _lose() -> void:
	state = State.LOSE
	lbl_center.text = "OUT OF BOMBS"
	lbl_center.add_theme_color_override("font_color", COL_EXPLO)
	lbl_sub.text = "残り %d 個 ・ クリック or タップでリトライ" % (required - destroyed)
	_update_ui()


func _update_ui() -> void:
	var chain_txt := ""
	if chain >= 2 and state == State.PLAYING:
		chain_txt = "   CHAIN x%d" % chain
	lbl_top.text = "LV %d    RED %d/%d    BOMB %d/%d    SCORE %d    BEST %d%s" % [
		level, destroyed, required, bombs_left, level_par, score, best_score, chain_txt]


# ---------------------------------------------------------------- save
func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = int(cfg.get_value("progress", "best_score", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.save(SAVE_PATH)
