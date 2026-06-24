extends Node
## ゲーム内ロガー(autoload: GameLog)
## リングバッファ + user://log.txt 永続化 + Webではコンソールにも出力される

const LOG_PATH := "user://log.txt"
const MAX_LINES := 300

var lines: PackedStringArray = []
var _dirty := false


func _ready() -> void:
	_load_previous()
	var flush_timer := Timer.new()
	flush_timer.wait_time = 5.0
	flush_timer.autostart = true
	flush_timer.timeout.connect(_flush_if_dirty)
	add_child(flush_timer)


func info(msg: String) -> void:
	_add("INFO", msg)


func warn(msg: String) -> void:
	_add("WARN", msg)
	_flush()


func error(msg: String) -> void:
	_add("ERROR", msg)
	_flush()


func dump() -> String:
	return "\n".join(lines)


func _add(level: String, msg: String) -> void:
	var line := "%s [%s] %s" % [Time.get_datetime_string_from_system(), level, msg]
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	print(line)
	_dirty = true


func _flush_if_dirty() -> void:
	if _dirty:
		_flush()


func _flush() -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(dump())
	_dirty = false


func _load_previous() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var file := FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return
	var prev := file.get_as_text().split("\n")
	# 前回分は直近50行だけ引き継ぐ
	var keep := prev.slice(maxi(0, prev.size() - 50))
	for line in keep:
		if line != "":
			lines.append(line)
	lines.append("---- (前回セッションここまで) ----")
