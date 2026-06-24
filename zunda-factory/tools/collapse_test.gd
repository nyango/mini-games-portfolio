# ステージ崩壊の回帰テスト: 300体到達→崩壊→新フロア展開
# 実行: godot --headless -s tools/collapse_test.gd
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	for i in 310:
		main._spawn_ally(main.lines[0], true)
	for i in 30:
		await process_frame
	if main.stage_level != 1:
		print("COLLAPSE_FAIL stage=%d allies=%d" % [main.stage_level, main.allies.size()])
		quit(1)
		return
	if main.allies.size() != 0:
		print("FALL_FAIL allies=%d" % main.allies.size())
		quit(1)
		return
	print("collapse triggered, waiting for new stage...")
	await create_timer(3.0).timeout
	if main.lane_ys.size() != 6 or main.collapsing:
		print("NEWSTAGE_FAIL lanes=%d collapsing=%s" % [main.lane_ys.size(), main.collapsing])
		quit(1)
		return
	print("COLLAPSE_TEST_OK lanes=%d zunda=%d" % [main.lane_ys.size(), int(main.zunda)])
	quit(0)
