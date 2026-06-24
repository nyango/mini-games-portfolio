# スモークテスト: ゴールデンパンのフリーズ回帰 + ラン制サイクル + エンディング画面
# 実行: godot --headless -s tools/freeze_test.gd (プロジェクトルートで)
extends SceneTree


func _initialize() -> void:
	_run()


func _fail(msg: String) -> void:
	print(msg)
	quit(1)


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main._close_overlay()  # 初日ドラフトを閉じてクリーンな状態に

	# ゴールデンパン: クリック despawn と自然 despawn の両経路
	main._spawn_golden()
	for i in 10:
		await process_frame
	print("golden spawned, clicking...")
	main._on_golden_pressed()
	for i in 60:
		await process_frame
	print("survived click despawn")
	main._spawn_golden()
	for i in 10:
		await process_frame
	main._despawn_golden()
	for i in 60:
		await process_frame

	# ドラフト→配置
	main._start_draft()
	for i in 5:
		await process_frame
	if main.overlay == null:
		_fail("DRAFT_NOT_SHOWN")
		return
	main._on_draft_pick("toaster")
	for i in 5:
		await process_frame
	main._place_card(0)
	for i in 5:
		await process_frame
	if main.grid[0] != "toaster" or main.per_sec <= 0.0:
		_fail("PLACE_FAIL grid0=%s per_sec=%f" % [main.grid[0], main.per_sec])
		return
	print("draft+place ok (per_sec=%.2f)" % main.per_sec)

	# シナジー: トースターを2台隣接させると1台あたりが伸びる
	var single: float = main.cell_rates[0]
	main.grid[1] = "toaster"
	main._recalc_grid()
	if main.cell_rates[0] <= single:
		_fail("SYNERGY_FAIL %f -> %f" % [single, main.cell_rates[0]])
		return
	print("synergy ok (%.2f -> %.2f)" % [single, main.cell_rates[0]])

	# 閉店→家賃支払い→レポート→翌日ドラフト
	var day_before: int = main.day
	main.bread = 100000.0
	main.day_time_left = 0.2
	for i in 40:
		await process_frame
	if main.overlay == null:
		_fail("DAY_REPORT_NOT_SHOWN")
		return
	main._advance_day()
	for i in 10:
		await process_frame
	if main.day != day_before + 1:
		_fail("DAY_ADVANCE_FAIL day=%d before=%d" % [main.day, day_before])
		return
	if main.overlay == null:
		_fail("MORNING_DRAFT_NOT_SHOWN")
		return
	main._close_overlay()
	print("day cycle ok (day=%d)" % main.day)

	# 最終日→決算エンディング
	main.day = main.RUN_DAYS
	main.bread = 100000.0
	main.day_time_left = 0.2
	for i in 40:
		await process_frame
	if not main.run_over or main.overlay == null:
		_fail("RUN_END_FAIL run_over=%s" % main.run_over)
		return
	var panel: Control = main.overlay.find_children("", "PanelContainer", true, false)[0]
	var center_x: float = panel.global_position.x + panel.size.x * 0.5
	if absf(center_x - 640.0) > 50.0:
		_fail("ENDING_PANEL_OFF_CENTER center_x=%f" % center_x)
		return
	print("run end + ending panel centered (x=%d)" % int(center_x))

	# 倒産経路: 新しい朝→家賃を払えず夜逃げ
	main._close_overlay()
	main._new_morning()
	for i in 5:
		await process_frame
	main._close_overlay()  # 朝ドラフトを閉じる
	main.bread = 0.0
	main.day_time_left = 0.2
	for i in 40:
		await process_frame
	if not main.run_over:
		_fail("BANKRUPT_FAIL")
		return
	if not ("bankrupt" in main.meta["endings"]):
		_fail("BANKRUPT_ENDING_NOT_RECORDED")
		return
	print("bankrupt path ok")
	print("FREEZE_TEST_OK")
	quit(0)
