extends Node3D

var current_scale = 1.0
var base_size = Vector2i(350, 600)
var is_fullscreen = false
var is_fetching = false
var saved_position: Vector2i
var saved_size: Vector2i
var original_environment: Environment

# Store the camera's original "Home" position to return to
var cam_home_pos: Vector3
var cam_home_rot: Vector3

func _ready():
	add_to_group("Main")
	
	# Prevent auto-scaling
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	
	# Transparency Setup
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_size(base_size)
	
	var viewport = get_viewport()
	if viewport:
		viewport.transparent_bg = true
		
	# Save Camera Home Position
	var cam = get_tree().get_first_node_in_group("MainCamera")
	if cam:
		cam_home_pos = cam.global_position
		cam_home_rot = cam.global_rotation

func _process(_delta):
	if is_fullscreen or is_fetching:
		return
	
	if OS.get_name() != "macOS":
		var win_size = DisplayServer.window_get_size()
		var polygon = PackedVector2Array([
			Vector2(0, 0),
			Vector2(win_size.x, 0),
			Vector2(win_size.x, win_size.y),
			Vector2(0, win_size.y)
		])
		DisplayServer.window_set_mouse_passthrough(polygon)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	# FETCH CLICK
	if is_fetching and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_tree().call_group("Mascot", "set_target_from_click", event.position)
		set_window_mode("small")
		return
		
	# SCALING
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_scale += 0.1
			_update_window_size()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_scale -= 0.1
			_update_window_size()

	# DRAGGING
	if not is_fetching and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		DisplayServer.window_start_drag()

func _update_window_size():
	current_scale = clamp(current_scale, 0.5, 2.0)
	var new_size = Vector2i(base_size.x * current_scale, base_size.y * current_scale)
	DisplayServer.window_set_size(new_size)

func set_window_mode(mode_name: String):
	var cam = get_tree().get_first_node_in_group("MainCamera")
	
	match mode_name:
		"fullscreen":
			saved_position = DisplayServer.window_get_position()
			saved_size = DisplayServer.window_get_size()
			
			# 1. Get Screen Size (Safe height for Windows)
			var screen_size = DisplayServer.screen_get_size()
			var safe_size = Vector2i(screen_size.x, screen_size.y - 1)
			
			# 2. Resize Window
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(safe_size)
			DisplayServer.window_set_position(Vector2i(0, 0))
			
			# 3. COMPENSATE CAMERA (The Magic Fix)
			if cam:
				# Calculate Zoom Ratio (How much taller did the window get?)
				var height_ratio = float(safe_size.y) / float(base_size.y)
				
				# Move camera BACK so she stays the same size
				# (We multiply Z distance by the ratio)
				cam.global_position.z = cam_home_pos.z * height_ratio
				
				# Move camera PAN so she stays in the corner
				# We project the "center of the old window" to the new world space
				var center_offset_x = (safe_size.x / 2.0) - (saved_position.x + base_size.x / 2.0)
				var center_offset_y = (safe_size.y / 2.0) - (saved_position.y + base_size.y / 2.0)
				
				# Convert pixels to meters (Rough approximation based on FOV)
				# 0.0015 is a magic number for default FOV. Adjust if she drifts left/right.
				var pixel_to_meter = 0.0015 * cam.global_position.z 
				
				cam.global_position.x = cam_home_pos.x - (center_offset_x * pixel_to_meter)
				cam.global_position.y = cam_home_pos.y + (center_offset_y * pixel_to_meter)

			# 4. Transparency & Input
			get_tree().get_root().set_transparent_background(true)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
			_ensure_transparency_after_resize.call_deferred()
			
			if OS.get_name() != "macOS":
				DisplayServer.window_set_mouse_passthrough([])
			
			is_fetching = true
			is_fullscreen = true
			
		"small":
			# Restore Size
			DisplayServer.window_set_size(base_size)
			_snap_to_corner()
			
			# RESTORE CAMERA
			if cam:
				cam.global_position = cam_home_pos
				cam.global_rotation = cam_home_rot
			
			is_fetching = false
			is_fullscreen = false
			
			_ensure_transparency_after_resize.call_deferred()

func _ensure_transparency_after_resize():
	# Force transparency re-apply after a few frames to beat Windows glitches
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().get_root().set_transparent_background(true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true)
	_apply_transparent_environment()

func _apply_transparent_environment():
	var world_env = get_node_or_null("WorldEnvironment")
	if world_env:
		var transparent_env = Environment.new()
		transparent_env.background_mode = 3 # BG_CANVAS
		world_env.environment = transparent_env

func _snap_to_corner():
	var screen_rect = DisplayServer.screen_get_usable_rect()
	var win_size = DisplayServer.window_get_size()
	var target_x = screen_rect.position.x + screen_rect.size.x - win_size.x - 20
	var target_y = screen_rect.position.y + screen_rect.size.y - win_size.y - 20
	DisplayServer.window_set_position(Vector2i(target_x, target_y))
