extends Node3D

@onready var anim = $AnimationPlayer

# --- LOAD YOUR FILES ---
# Make sure these filenames match exactly what is in your FileSystem!
var anim_sit = preload("res://sitting.res")
var anim_walk = preload("res://walking.res") 

# STATE VARIABLES
var state = "idle" # Options: "idle", "sitting", "walking", "targeting"
var target_position = Vector3.ZERO
var move_speed = 2.0
var is_sitting = false

# DRAG DETECTION VARIABLES
var mouse_down_pos: Vector2
var is_dragging = false
var drag_threshold = 5.0  # Pixels of movement to consider it a drag

# MENU VARIABLES - Using 2D UI instead of 3D
var menu_panel: Control
var menu_container: VBoxContainer

func _ready():
	# 1. SETUP ANIMATION LIBRARY IN CODE
	var library = AnimationLibrary.new()
	
	# Configure loops
	anim_sit.loop_mode = Animation.LOOP_NONE     # Sit once and hold
	anim_walk.loop_mode = Animation.LOOP_LINEAR  # Walk forever
	
	# Add to library
	library.add_animation("sit", anim_sit)
	library.add_animation("walk", anim_walk)
	
	# Register with player
	anim.add_animation_library("custom", library)
	
	# Ensure the default idle animation loops
	if anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
	
	# 2. Connect Click
	$Area3D.input_event.connect(_on_character_clicked)
	
	# 3. Create Pop-up Menu
	_setup_popup_menu()

func _process(delta):
	# LOGIC FOR MOVING
	if state == "walking":
		# Calculate distance to target
		var distance_to_target = global_position.distance_to(target_position)
		
		# If we've arrived, switch to idle
		if distance_to_target < 0.1:
			print("Arrived!")
			state = "idle"
			# Play idle animation with looping
			anim.play("mixamo_com", 0.5)
			anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		else:
			# 1. Look at the target (keep her flat on y=0)
			var look_target = Vector3(target_position.x, global_position.y, target_position.z)
			look_at(look_target, Vector3.UP)
			
			# 2. Move towards target using move_toward
			global_position = global_position.move_toward(target_position, move_speed * delta)
	
	# Ensure idle animation keeps playing
	if state == "idle" and not anim.is_playing():
		anim.play("mixamo_com")
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
	
	# Update menu position if visible
	if menu_panel and menu_panel.visible:
		_update_menu_position()
	
	# FIX THE SCALING: Calculate scale based on distance from camera
	# Map distance to scale: closer = scale 1.0, further = scale 0.8
	# Clamp between 0.5 and 1.5 to prevent infinite shrinking
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Calculate distance from camera (3D distance, not just Z)
		var distance_from_camera = global_position.distance_to(camera.global_position)
		
		# Use a reference distance (e.g., 2.0 units) for scale calculation
		# Closer than reference = larger scale, further = smaller scale
		var reference_distance = 2.0
		var normalized_distance = distance_from_camera / reference_distance
		
		# Map distance: at reference_distance = 1.0, closer = up to 1.0, further = down to 0.8
		# Use inverse relationship: closer = larger scale
		var target_scale = 1.0
		if normalized_distance <= 1.0:
			# Closer than reference: scale 0.8 to 1.0
			target_scale = lerp(1.0, 0.8, 1.0 - normalized_distance)
		else:
			# Further than reference: scale 0.8 to 0.5
			target_scale = lerp(0.8, 0.5, clamp((normalized_distance - 1.0) / 2.0, 0.0, 1.0))
		
		# Clamp between 0.5 and 1.5 to prevent infinite shrinking/growing
		target_scale = clamp(target_scale, 0.5, 1.5)
		
		# Apply the scale smoothly
		scale = scale.lerp(Vector3(target_scale, target_scale, target_scale), 0.1)

func _input(event):
	# Detect drag when mouse moves while button is down
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			# Check if mouse has moved enough to be considered a drag
			if mouse_down_pos != Vector2.ZERO:
				var distance = mouse_down_pos.distance_to(event.position)
				if distance > drag_threshold:
					if not is_dragging:
						# Just started dragging - start window drag
						is_dragging = true
						DisplayServer.window_start_drag()
						print("Started dragging window")
					
					# If we start dragging, close menu if it's open
					if menu_panel and menu_panel.visible:
						menu_panel.visible = false
	
	# Handle clicks outside menu to close it (but not when clicking on character or in targeting mode)
	if menu_panel and menu_panel.visible and state != "targeting":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside the menu panel
			var mouse_pos = event.position
			var menu_rect = Rect2(menu_panel.position, menu_panel.size)
			if not menu_rect.has_point(mouse_pos):
				# Clicked outside menu - close it
				# (Character clicks are handled separately via Area3D, so this won't interfere)
				menu_panel.visible = false
	
	# NOTE: Target setting is now handled by main.gd calling set_target_from_click() directly
	# This avoids conflicts when the window is fullscreen and screen coordinates change

func _on_character_clicked(_camera, event, _click_pos, _normal, _shape_idx):
	# LOGIC FOR CLICKING THE GIRL
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Mouse button down - start tracking for drag
			mouse_down_pos = event.position
			is_dragging = false
			print("Mouse down on character - tracking for drag/click")
		else:
			# Mouse button up - check if it was a click or drag
			var mouse_up_pos = event.position
			var drag_distance = mouse_down_pos.distance_to(mouse_up_pos) if mouse_down_pos != Vector2.ZERO else 0.0
			
			# Only show menu if we didn't drag (is_dragging is false) AND distance is below threshold
			if not is_dragging and drag_distance <= drag_threshold:
				# It was a click, not a drag - show menu
				print("Character clicked (not dragged)! Distance: ", drag_distance)
				
				# Toggle menu visibility and position it near the character on screen
				if menu_panel:
					var was_visible = menu_panel.visible
					menu_panel.visible = !was_visible
					
					if menu_panel.visible:
						# Position menu near character on screen
						_update_menu_position()
					
					print("Menu now visible: ", menu_panel.visible)
				else:
					print("ERROR: menu_panel is null!")
				
				# If she is sitting, make her stand
				if state == "sitting":
					anim.play("mixamo_com", 0.5)
					if anim.has_animation("mixamo_com"):
						anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
					state = "idle"
			else:
				# It was a drag - close menu if it's open and don't show menu
				if menu_panel and menu_panel.visible:
					menu_panel.visible = false
				print("Character was dragged, menu closed. is_dragging: ", is_dragging, " Distance: ", drag_distance)
			
			# Reset drag state
			is_dragging = false
			mouse_down_pos = Vector2.ZERO

func _setup_popup_menu():
	# Get the root viewport to add UI to
	var root = get_tree().root
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "MenuCanvasLayer"
	# Use call_deferred to avoid "parent busy" error during _ready()
	root.add_child.call_deferred(canvas_layer)
	
	# Create main panel
	menu_panel = Panel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.size = Vector2(200, 120)
	menu_panel.position = Vector2(100, 100)  # Initial position, will be updated
	menu_panel.visible = false
	canvas_layer.add_child.call_deferred(menu_panel)
	
	# Create container for buttons
	menu_container = VBoxContainer.new()
	menu_container.name = "MenuContainer"
	menu_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_container.add_theme_constant_override("separation", 10)
	menu_container.set_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.add_child.call_deferred(menu_container)
	
	# Add padding
	menu_container.add_theme_constant_override("margin_left", 10)
	menu_container.add_theme_constant_override("margin_right", 10)
	menu_container.add_theme_constant_override("margin_top", 10)
	menu_container.add_theme_constant_override("margin_bottom", 10)
	
	# Create 'Sit' Button
	var sit_button = Button.new()
	sit_button.name = "SitButton"
	sit_button.text = "Sit"
	sit_button.custom_minimum_size = Vector2(0, 40)
	sit_button.pressed.connect(_on_sit_button_pressed)
	menu_container.add_child.call_deferred(sit_button)
	
	# Create 'Fetch' Button
	var fetch_button = Button.new()
	fetch_button.name = "FetchButton"
	fetch_button.text = "Fetch"
	fetch_button.custom_minimum_size = Vector2(0, 40)
	fetch_button.pressed.connect(_on_fetch_button_pressed)
	menu_container.add_child.call_deferred(fetch_button)
	
	# Wait for deferred calls to complete, then verify menu is set up
	await get_tree().process_frame
	await get_tree().process_frame  # Wait an extra frame to be sure
	
	print("Menu UI created and added to scene tree")
	if menu_panel:
		print("Menu setup complete. Menu visible: ", menu_panel.visible)
		print("Menu panel in tree: ", menu_panel.is_inside_tree())
	else:
		print("ERROR: menu_panel is null after setup!")

func _update_menu_position():
	# Position menu near character on screen, ensuring it never overlaps the character
	if not menu_panel:
		return
		
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	# Estimate character height in world space (adjust this value based on your character's actual height)
	var character_world_height = 1.6
	
	# Calculate the top of the character in world space (accounting for current scale)
	var character_top_world = global_position + Vector3(0, character_world_height * scale.y, 0)
	
	# Project both the character's base and top positions to screen space
	var character_base_screen = camera.unproject_position(global_position)
	var character_top_screen = camera.unproject_position(character_top_world)
	
	# Calculate the character's height in screen space for bounds checking
	var character_screen_height = abs(character_top_screen.y - character_base_screen.y)
	
	var padding = 20.0  # Padding to ensure no overlap
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Try positioning above the character first
	var menu_x_position = character_top_screen.x - menu_panel.size.x / 2
	var menu_y_position = character_top_screen.y - menu_panel.size.y - padding
	
	# Verify menu bottom is safely above character top
	var menu_bottom_y = menu_y_position + menu_panel.size.y
	if menu_bottom_y > character_top_screen.y - padding or menu_y_position < 0:
		# Not enough room above - position to the right side
		var horizontal_offset = max(character_screen_height * 0.6, 100.0) + padding
		menu_x_position = character_top_screen.x + horizontal_offset
		menu_y_position = character_top_screen.y - menu_panel.size.y / 2
		
		# If that goes off screen, try left side
		if menu_x_position + menu_panel.size.x > viewport_size.x:
			menu_x_position = character_top_screen.x - menu_panel.size.x - horizontal_offset
			# If left side also doesn't fit, center horizontally and position below
			if menu_x_position < 0:
				menu_x_position = clamp(character_top_screen.x - menu_panel.size.x / 2, 0, viewport_size.x - menu_panel.size.x)
				menu_y_position = character_base_screen.y + padding
	
	menu_panel.position = Vector2(menu_x_position, menu_y_position)
	
	# Clamp to viewport bounds (final safety check)
	menu_panel.position.x = clamp(menu_panel.position.x, 0, viewport_size.x - menu_panel.size.x)
	menu_panel.position.y = clamp(menu_panel.position.y, 0, viewport_size.y - menu_panel.size.y)

func _on_sit_button_pressed():
	print("Sit button pressed")
	if menu_panel:
		menu_panel.visible = false
	
	# Play sitting animation
	if state != "sitting":
		state = "sitting"
		anim.play("custom/sit", 0.5)
		is_sitting = true
		print("Playing sit animation")
	else:
		# If already sitting, stand up
		state = "idle"
		anim.play("mixamo_com", 0.5)
		if anim.has_animation("mixamo_com"):
			anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		is_sitting = false
		print("Standing up")

func _on_fetch_button_pressed():
	print("Fetch button pressed")
	if menu_panel:
		menu_panel.visible = false
	
	# Enter targeting mode so the next click sets a target
	state = "targeting"
	
	# Find the Main node and call set_window_mode to enter fullscreen fetch mode
	var main_node = get_tree().get_first_node_in_group("Main")
	if main_node and main_node.has_method("set_window_mode"):
		main_node.set_window_mode("fullscreen")

func set_target_from_click(screen_pos: Vector2):
	# Set target from screen click position (called by main.gd when in fetch mode)
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	# Create a Plane at the character's current Y position (the floor level)
	var character_y = global_position.y
	var drop_plane = Plane(Vector3.UP, character_y)
	
	# Project a ray from the camera using project_ray_origin and project_ray_normal
	# screen_pos is already in viewport coordinates, so use it directly
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_normal = camera.project_ray_normal(screen_pos)
	
	# Get the intersection point
	var intersection = drop_plane.intersects_ray(ray_origin, ray_normal)
	
	if intersection:
		# Make sure the target is reasonable - check if it's in front of the camera
		var to_intersection = intersection - camera.global_position
		var camera_forward = -camera.transform.basis.z
		
		# Only accept targets that are in front of the camera
		if to_intersection.dot(camera_forward) > 0:
			# Set target_position to this 3D point (keep Y at character's level)
			target_position = Vector3(intersection.x, character_y, intersection.z)
			
			print("Target set to: ", target_position, " from screen_pos: ", screen_pos, " from character position: ", global_position)
			
			# Close menu if open
			if menu_panel and menu_panel.visible:
				menu_panel.visible = false
			
			# Exit targeting mode and start walking
			state = "walking"
			anim.play("custom/walk", 0.5)
		else:
			print("Target rejected: behind camera")
	else:
		print("No intersection found for screen_pos: ", screen_pos)
