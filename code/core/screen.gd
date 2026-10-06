extends Node
## Responsive presentation context. Turns physical pixels into a logical canvas
## (CSS-like points: an iPhone 14 is 390×844), tracks safe-area insets and picks a layout mode.
## Game logic never reads this — only the view layer does.

signal layout_changed

enum Mode { PORTRAIT, LANDSCAPE, DESKTOP }

var mode: int = Mode.DESKTOP
var size := Vector2(1920, 1080)        # logical canvas size
var dpr := 1.0                         # physical px per logical px
var safe := Rect2()                    # safe rect in logical coords
var touch := false                     # primary input looks like touch
var low_power := false                 # phones / web: cheaper effects, fewer redraws
var _fps_acc := 0.0
var _fps_low := 0.0
var _downgraded := false
var _forced_dpr := 0.0
var _forced_insets := []               # [top, right, bottom, left] for screenshots / testing


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dpr="):
			_forced_dpr = float(a.substr(6))
		elif a.begins_with("--safe="):
			_forced_insets = Array(a.substr(7).split(",")).map(func(x): return float(x))
	touch = DisplayServer.is_touchscreen_available() or OS.has_feature("web_ios") or OS.has_feature("web_android")
	low_power = OS.has_feature("web") or OS.has_feature("mobile")
	get_tree().root.size_changed.connect(_apply)
	_apply.call_deferred()


func _apply() -> void:
	var win := get_tree().root
	var phys := Vector2(win.size)
	dpr = _forced_dpr if _forced_dpr > 0.0 else _device_pixel_ratio()
	var logical := phys / dpr
	# Large desktop monitors: scale the whole UI up a little so it reads from a chair.
	var boost := 1.0
	if minf(logical.x, logical.y) >= 900.0 and not touch:
		boost = clampf(minf(logical.x / 1600.0, logical.y / 900.0), 1.0, 1.6)
	logical /= boost
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(logical.round())
	size = Vector2(win.content_scale_size)
	var k := phys.x / size.x
	var ins := _insets_physical()
	safe = Rect2(ins[3] / k, ins[0] / k, size.x - (ins[1] + ins[3]) / k, size.y - (ins[0] + ins[2]) / k)
	var short := minf(size.x, size.y)
	if size.x < size.y and size.x < 760.0:
		mode = Mode.PORTRAIT
	elif short < 560.0:
		mode = Mode.LANDSCAPE
	else:
		mode = Mode.DESKTOP
	layout_changed.emit()


## Web: if the device can't hold ~40 fps at the capped pixel ratio, drop rendering to 1.5×.
## (The page caps devicePixelRatio to 2 via window.__nsDpr — see export head_include.)
func _process(delta: float) -> void:
	if not OS.has_feature("web") or _downgraded:
		return
	_fps_acc += delta
	if _fps_acc < 3.0:
		return
	if Engine.get_frames_per_second() < 40:
		_fps_low += delta
	else:
		_fps_low = 0.0
	if _fps_low > 2.5:
		_downgraded = true
		JavaScriptBridge.eval("window.__nsDpr=1.5;window.dispatchEvent(new Event('resize'));", true)


func is_phone() -> bool:
	return mode != Mode.DESKTOP


func _device_pixel_ratio() -> float:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		return maxf(1.0, float(v))
	return maxf(1.0, DisplayServer.screen_get_scale())


## [top, right, bottom, left] in physical pixels.
func _insets_physical() -> Array:
	if not _forced_insets.is_empty():
		return _forced_insets.map(func(v): return v * dpr)
	if OS.has_feature("web"):
		var js := """(function(){var d=document.createElement('div');
			d.style.cssText='position:fixed;top:0;left:0;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);visibility:hidden';
			document.body.appendChild(d);var s=getComputedStyle(d);
			var r=[s.paddingTop,s.paddingRight,s.paddingBottom,s.paddingLeft].map(function(v){return (parseFloat(v)||0)*(window.devicePixelRatio||1)});
			d.remove();return r.join(',');})()"""
		var res = JavaScriptBridge.eval(js, true)
		if res is String and res != "":
			return Array(res.split(",")).map(func(x): return float(x))
	var sa := DisplayServer.get_display_safe_area()
	var ss := DisplayServer.screen_get_size()
	if sa.size.x > 0 and sa.size != ss and OS.has_feature("mobile"):
		return [sa.position.y, ss.x - sa.end.x, ss.y - sa.end.y, sa.position.x]
	return [0.0, 0.0, 0.0, 0.0]
