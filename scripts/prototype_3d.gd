extends Node3D

const CAMERA_MOVE_SPEED := 32.0
const CAMERA_ROTATE_SPEED := 1.6
const CAMERA_MIN_HEIGHT := 8.0
const CAMERA_MAX_HEIGHT := 28.0
const CAMERA_MIN_TILT := -88.0
const CAMERA_MAX_TILT := -8.0
const RESIDENTIAL_ONLY := true
const GRID_BLOCKS := 10
const BLOCK_SIZE := 18.0
const ROAD_SIZE := 8.0
const HALF_CITY := ((GRID_BLOCKS * BLOCK_SIZE) + ((GRID_BLOCKS + 1) * ROAD_SIZE)) * 0.5
const TRAFFIC_LIGHT_CYCLE := 7.0
const LANE_OFFSET := 1.6
const SIDEWALK_OFFSET := 4.9
const CAMERA_STREET_OFFSET_Z := 18.0
const DAY_NIGHT_CYCLE := 96.0
const ROAD_ASSET_SCALE := 1.0

var camera_pivot: Node3D
var camera_node: Camera3D
var camera_target_position: Vector3 = Vector3.ZERO
var camera_target_rotation_y: float = 0.0
var camera_target_tilt_x: float = -28.0
var sun_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var world_environment: Environment
var street_lights: Array[OmniLight3D] = []
var time_of_day: float = 0.34
var hud_label: RichTextLabel
var stats_label: RichTextLabel
var status_label: RichTextLabel
var moving_agents: Array[Dictionary] = []
var respawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player_crews: Array[Dictionary] = []
var selected_crew_index: int = -1
var destination_marker: MeshInstance3D
var ground_plane: Plane = Plane(Vector3.UP, 0.0)
var crew_portrait_buttons: Array[Button] = []
var action_buttons: Dictionary = {}
var command_mode: String = "control"
var is_right_dragging: bool = false
var is_left_mouse_down: bool = false
var right_drag_start: Vector2 = Vector2.ZERO
var last_mouse_position: Vector2 = Vector2.ZERO
var camera_drag_sensitivity: float = 0.18
var camera_rotate_drag_sensitivity: float = 0.012
var work_opportunities: Array[Dictionary] = []
var building_sites: Array[Dictionary] = []
var traffic_lights: Array[Dictionary] = []
var traffic_light_timer: float = 0.0
var traffic_ns_green: bool = true
var asset_scene_cache: Dictionary = {}
var context_panel: PanelContainer
var context_title_label: Label
var context_button_row: HBoxContainer
var selected_context_building_id: String = ""
var guard_patrol_points: PackedVector3Array = PackedVector3Array([
	Vector3(-28, 0.9, -60),
	Vector3(28, 0.9, -60),
	Vector3(30, 0.9, 60),
	Vector3(-30, 0.9, 60),
])


func _ready() -> void:
	respawn_rng.randomize()
	_build_world()
	_build_hud()
	set_process(true)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			is_left_mouse_down = mouse_event.pressed
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			camera_target_position.y = maxf(CAMERA_MIN_HEIGHT, camera_target_position.y - 1.5)
			camera_node.position.z = maxf(10.0, camera_node.position.z - 1.2)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			camera_target_position.y = minf(CAMERA_MAX_HEIGHT, camera_target_position.y + 1.5)
			camera_node.position.z = minf(32.0, camera_node.position.z + 1.2)
		elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mouse_event.position)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			is_right_dragging = true
			right_drag_start = mouse_event.position
			last_mouse_position = mouse_event.position
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_event.pressed:
			var drag_distance: float = right_drag_start.distance_to(mouse_event.position)
			if drag_distance < 8.0:
				_handle_right_click(mouse_event.position)
			is_right_dragging = false
	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if is_right_dragging and is_left_mouse_down:
			_rotate_camera_with_mouse(motion_event.relative)
		elif is_right_dragging:
			_pan_camera_with_mouse(motion_event.relative)
		last_mouse_position = motion_event.position


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_day_night_cycle(delta)
	_update_traffic_lights(delta)
	_update_agents(delta)
	_update_player_crews(delta)


func _build_world() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1a1a1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("57534d")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.92
	environment.adjustment_contrast = 1.18
	environment.fog_enabled = true
	environment.fog_light_color = Color("262626")
	environment.fog_light_energy = 0.4
	environment.fog_density = 0.008
	environment.ssr_enabled = true
	environment.ssil_enabled = true
	world_environment = environment
	env.environment = environment
	add_child(env)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48, 40, 0)
	sun_light.light_energy = 1.25
	sun_light.light_color = Color("ddd4c3")
	sun_light.shadow_enabled = true
	add_child(sun_light)

	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-70, -120, 0)
	fill_light.light_energy = 0.18
	fill_light.light_color = Color("7b766d")
	add_child(fill_light)

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 18, 18)
	add_child(camera_pivot)
	camera_target_position = camera_pivot.position
	camera_target_rotation_y = camera_pivot.rotation.y

	camera_node = Camera3D.new()
	camera_node.current = true
	camera_node.position = Vector3(0, 8.0, CAMERA_STREET_OFFSET_Z)
	camera_node.rotation_degrees = Vector3(-28, 0, 0)
	camera_node.fov = 58.0
	camera_node.near = 0.1
	camera_node.far = 600.0
	camera_pivot.add_child(camera_node)
	camera_target_tilt_x = camera_node.rotation_degrees.x

	_add_ground_plane(Vector3.ZERO, Vector2(HALF_CITY * 2.0 + 20.0, HALF_CITY * 2.0 + 20.0), Color("62574d"))
	_add_road_grid()
	_add_district_surfaces()
	_add_building_blockout()
	_add_street_furniture()
	_build_work_opportunities()
	_spawn_agents()
	_spawn_player_crews()
	_build_destination_marker()


func _build_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(470, 190)
	canvas.add_child(panel)

	var panel_content: VBoxContainer = VBoxContainer.new()
	panel_content.add_theme_constant_override("separation", 8)
	panel.add_child(panel_content)

	var title: Label = Label.new()
	title.text = "OMERTA 3D PROTOTYPE"
	title.add_theme_font_size_override("font_size", 22)
	panel_content.add_child(title)

	hud_label = RichTextLabel.new()
	hud_label.bbcode_enabled = true
	hud_label.fit_content = true
	hud_label.scroll_active = false
	hud_label.text = (
		"[b]Direction:[/b] RimWorld-style crew management inside a Mafia-like 3D city.\n"
		+ "[b]Camera:[/b] ZQSD move, A/E rotate, mouse wheel zoom.\n"
		+ "[b]Camera Drag:[/b] Right drag pans, both mouse buttons drag rotates. R/F tilts from street view to top view.\n"
		+ "[b]Crew Controls:[/b] Left click portraits/actions. Left click world to issue manual orders.\n"
		+ "[b]Prototype Goal:[/b] Test a clean 10x10 residential city grid with readable streets, towers, homes, shops, and gang work."
	)
	panel_content.add_child(hud_label)

	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	stats_label.text = (
		"[b]District:[/b] Residential only, rebuilt from scratch\n"
		+ "[b]Layout:[/b] 10x10 blocks, connected streets, towers, homes, shops, gas station\n"
		+ "[b]Player Crew:[/b] 3 gang members starting in Residential\n"
		+ "[b]Work Types:[/b] Runner, Shop, Lookout, Collection, Park Meet"
	)
	panel_content.add_child(stats_label)

	var portrait_panel: PanelContainer = PanelContainer.new()
	portrait_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	portrait_panel.position = Vector2(18, 228)
	portrait_panel.custom_minimum_size = Vector2(196, 252)
	canvas.add_child(portrait_panel)

	var portrait_content: VBoxContainer = VBoxContainer.new()
	portrait_content.add_theme_constant_override("separation", 10)
	portrait_panel.add_child(portrait_content)

	var portrait_title: Label = Label.new()
	portrait_title.text = "Crew Mugshots"
	portrait_title.add_theme_font_size_override("font_size", 18)
	portrait_content.add_child(portrait_title)

	for i in range(player_crews.size()):
		var crew: Dictionary = player_crews[i]
		var portrait_button: Button = Button.new()
		portrait_button.custom_minimum_size = Vector2(170, 62)
		portrait_button.text = "%s\n%s" % [crew["name"], crew["current_job_name"]]
		portrait_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		portrait_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		portrait_button.icon = crew["portrait"]
		portrait_button.expand_icon = true
		portrait_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		portrait_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		portrait_button.pressed.connect(_on_portrait_selected.bind(i))
		portrait_content.add_child(portrait_button)
		crew_portrait_buttons.append(portrait_button)

	var action_panel: PanelContainer = PanelContainer.new()
	action_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	action_panel.offset_left = 260
	action_panel.offset_right = -20
	action_panel.offset_top = -120
	action_panel.offset_bottom = -20
	canvas.add_child(action_panel)

	var action_content: VBoxContainer = VBoxContainer.new()
	action_content.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_content)

	var action_title: Label = Label.new()
	action_title.text = "Crew Commands"
	action_title.add_theme_font_size_override("font_size", 18)
	action_content.add_child(action_title)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_content.add_child(action_row)

	_add_action_button(action_row, "auto_work", "Auto Work")
	_add_action_button(action_row, "control", "Control")
	_add_action_button(action_row, "move", "Move To")
	_add_action_button(action_row, "attack", "Attack")
	_add_action_button(action_row, "guard", "Guard")
	_add_action_button(action_row, "forced_work", "Forced Work")

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.fit_content = true
	status_label.scroll_active = false
	action_content.add_child(status_label)

	context_panel = PanelContainer.new()
	context_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	context_panel.offset_left = 260
	context_panel.offset_right = -20
	context_panel.offset_top = -200
	context_panel.offset_bottom = -130
	context_panel.visible = false
	canvas.add_child(context_panel)

	var context_content := VBoxContainer.new()
	context_content.add_theme_constant_override("separation", 8)
	context_panel.add_child(context_content)

	context_title_label = Label.new()
	context_title_label.text = "Building Actions"
	context_title_label.add_theme_font_size_override("font_size", 18)
	context_content.add_child(context_title_label)

	context_button_row = HBoxContainer.new()
	context_button_row.add_theme_constant_override("separation", 10)
	context_content.add_child(context_button_row)

	_refresh_portrait_buttons()
	_refresh_action_buttons()
	_update_status_text()


func _update_camera(delta: float) -> void:
	var move_input: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_Z):
		move_input.z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_input.z += 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_Q):
		move_input.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_input.x += 1.0

	if move_input != Vector3.ZERO:
		var flattened_basis: Basis = Basis.from_euler(Vector3(0.0, camera_pivot.rotation.y, 0.0))
		var direction: Vector3 = (flattened_basis * move_input).normalized()
		camera_target_position += direction * CAMERA_MOVE_SPEED * delta

	if Input.is_key_pressed(KEY_A):
		camera_target_rotation_y += CAMERA_ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_E):
		camera_target_rotation_y -= CAMERA_ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_R):
		camera_target_tilt_x -= 32.0 * delta
	if Input.is_key_pressed(KEY_F):
		camera_target_tilt_x += 32.0 * delta

	camera_target_position.x = clampf(camera_target_position.x, -HALF_CITY + 12.0, HALF_CITY - 12.0)
	camera_target_position.z = clampf(camera_target_position.z, -HALF_CITY + 12.0, HALF_CITY - 12.0)
	camera_target_position.y = clampf(camera_target_position.y, CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT)
	camera_target_tilt_x = clampf(camera_target_tilt_x, CAMERA_MIN_TILT, CAMERA_MAX_TILT)

	camera_pivot.position = camera_pivot.position.lerp(camera_target_position, clampf(delta * 7.5, 0.0, 1.0))
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, camera_target_rotation_y, clampf(delta * 8.0, 0.0, 1.0))
	camera_node.rotation_degrees.x = lerpf(camera_node.rotation_degrees.x, camera_target_tilt_x, clampf(delta * 8.0, 0.0, 1.0))


func _pan_camera_with_mouse(relative: Vector2) -> void:
	var flattened_basis: Basis = Basis.from_euler(Vector3(0.0, camera_pivot.rotation.y, 0.0))
	var zoom_ratio: float = inverse_lerp(CAMERA_MIN_HEIGHT, CAMERA_MAX_HEIGHT, camera_target_position.y)
	var pan_scale: float = lerpf(0.38, 0.92, zoom_ratio)
	var pan_vector: Vector3 = flattened_basis * Vector3(-relative.x * camera_drag_sensitivity * pan_scale, 0.0, -relative.y * camera_drag_sensitivity * pan_scale)
	camera_target_position += pan_vector
	camera_target_position.x = clampf(camera_target_position.x, -HALF_CITY + 12.0, HALF_CITY - 12.0)
	camera_target_position.z = clampf(camera_target_position.z, -HALF_CITY + 12.0, HALF_CITY - 12.0)


func _rotate_camera_with_mouse(relative: Vector2) -> void:
	camera_target_rotation_y -= relative.x * camera_rotate_drag_sensitivity
	camera_target_tilt_x = clampf(camera_target_tilt_x + (relative.y * 0.06), CAMERA_MIN_TILT, CAMERA_MAX_TILT)


func _add_ground_plane(pos: Vector3, plane_size: Vector2, color: Color) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(plane_size.x, 0.2, plane_size.y)
	mesh_instance.mesh = box
	mesh_instance.position = pos + Vector3(0, -0.1, 0)
	mesh_instance.material_override = _make_material(color)
	add_child(mesh_instance)


func _add_road_grid() -> void:
	var road_span: float = (GRID_BLOCKS * BLOCK_SIZE) + ((GRID_BLOCKS + 1) * ROAD_SIZE)
	var road_centers: Array[float] = []
	for i in range(GRID_BLOCKS + 1):
		var edge_start: float = -HALF_CITY + (ROAD_SIZE * 0.5) + float(i) * (BLOCK_SIZE + ROAD_SIZE)
		road_centers.append(edge_start)

	if _has_imported_road_assets():
		_add_imported_road_grid(road_centers)
		for row in range(1, GRID_BLOCKS):
			for col in range(1, GRID_BLOCKS):
				var intersection_center: Vector3 = Vector3(
					-HALF_CITY + (ROAD_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE),
					0.05,
					-HALF_CITY + (ROAD_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
				)
				if row % 2 == 0 and col % 2 == 0:
					_add_traffic_light_cluster(intersection_center)
		return

	for z_pos in road_centers:
		_add_street(Vector3(0, 0.03, z_pos), Vector3(road_span, 0.06, ROAD_SIZE), Color("303235"), Color("8b816f"))
	for x_pos in road_centers:
		_add_street(Vector3(x_pos, 0.03, 0), Vector3(ROAD_SIZE, 0.06, road_span), Color("303235"), Color("8b816f"))

	for row in range(GRID_BLOCKS + 1):
		var z_pos: float = road_centers[row]
		for col in range(GRID_BLOCKS):
			var segment_center_x: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE)
			_add_lane_markings_horizontal(segment_center_x, z_pos, BLOCK_SIZE - 1.8)
	for col in range(GRID_BLOCKS + 1):
		var x_pos: float = road_centers[col]
		for row in range(GRID_BLOCKS):
			var segment_center_z: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
			_add_lane_markings_vertical(x_pos, segment_center_z, BLOCK_SIZE - 1.8)

	for row in range(1, GRID_BLOCKS):
		for col in range(1, GRID_BLOCKS):
			var intersection_center: Vector3 = Vector3(
				-HALF_CITY + (ROAD_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE),
				0.05,
				-HALF_CITY + (ROAD_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
			)
			_add_box(intersection_center + Vector3(0, 0.035, 0), Vector3(ROAD_SIZE + 0.18, 0.03, ROAD_SIZE + 0.18), Color("303235"))
			_add_crosswalks(intersection_center)
			if row % 2 == 0 and col % 2 == 0:
				_add_traffic_light_cluster(intersection_center)


func _has_imported_road_assets() -> bool:
	return ResourceLoader.exists("res://assets/external/kenney_city-kit-roads/Models/GLB format/road-straight.glb") and ResourceLoader.exists("res://assets/external/kenney_city-kit-roads/Models/GLB format/road-crossroad-line.glb")


func _add_imported_road_grid(road_centers: Array[float]) -> void:
	var straight_path: String = "res://assets/external/kenney_city-kit-roads/Models/GLB format/road-straight.glb"
	var crossroad_path: String = "res://assets/external/kenney_city-kit-roads/Models/GLB format/road-crossroad-line.glb"
	var road_scale: Vector3 = Vector3.ONE * ROAD_ASSET_SCALE

	for row in range(GRID_BLOCKS + 1):
		for col in range(GRID_BLOCKS + 1):
			var intersection_center := Vector3(road_centers[col], 0.02, road_centers[row])
			if _spawn_asset_model(crossroad_path, intersection_center, road_scale, Vector3.ZERO) == null:
				_add_box(intersection_center, Vector3(ROAD_SIZE + 0.2, 0.05, ROAD_SIZE + 0.2), Color("303235"))

	for row in range(GRID_BLOCKS + 1):
		var z_pos: float = road_centers[row]
		for col in range(GRID_BLOCKS):
			var center_x: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE)
			if _spawn_asset_model(straight_path, Vector3(center_x, 0.021, z_pos), road_scale, Vector3.ZERO) == null:
				_add_street(Vector3(center_x, 0.03, z_pos), Vector3(BLOCK_SIZE, 0.06, ROAD_SIZE), Color("303235"), Color("8b816f"))

	for col in range(GRID_BLOCKS + 1):
		var x_pos: float = road_centers[col]
		for row in range(GRID_BLOCKS):
			var center_z: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
			if _spawn_asset_model(straight_path, Vector3(x_pos, 0.021, center_z), road_scale, Vector3(0, 90, 0)) == null:
				_add_street(Vector3(x_pos, 0.03, center_z), Vector3(ROAD_SIZE, 0.06, BLOCK_SIZE), Color("303235"), Color("8b816f"))


func _add_district_surfaces() -> void:
	_add_box(Vector3(0, 0.01, 0), Vector3(HALF_CITY * 2.0 - 4.0, 0.02, HALF_CITY * 2.0 - 4.0), Color("6a5b4e"))

	var centers := _get_block_centers()
	for center_data: Dictionary in centers:
		var center: Vector3 = center_data["position"]
		_add_box(Vector3(center.x, 0.025, center.z), Vector3(BLOCK_SIZE, 0.03, BLOCK_SIZE), Color("7c7366"))
		_add_box(Vector3(center.x, 0.04, center.z), Vector3(BLOCK_SIZE - 3.0, 0.025, BLOCK_SIZE - 3.0), Color("6d6257"))

	var park_outer_color := Color("5e764f")
	var park_inner_color := Color("748d5f")
	var park_center := _get_block_center(4, 4)
	_add_box(Vector3(park_center.x, 0.03, park_center.z), Vector3(BLOCK_SIZE, 0.04, BLOCK_SIZE), park_outer_color)
	_add_box(Vector3(park_center.x, 0.04, park_center.z), Vector3(BLOCK_SIZE - 5.0, 0.05, BLOCK_SIZE - 5.0), park_inner_color)
	_add_box(Vector3(park_center.x, 0.05, park_center.z), Vector3(3, 0.05, BLOCK_SIZE), Color("b8b09d"))
	_add_box(Vector3(park_center.x, 0.05, park_center.z), Vector3(BLOCK_SIZE, 0.05, 3), Color("b8b09d"))
	for x_pos in [-4.0, 4.0]:
		for z_pos in [-4.0, 4.0]:
			_add_box(Vector3(park_center.x + x_pos, 2.0, park_center.z + z_pos), Vector3(1.3, 4.0, 1.3), Color("5e4a32"))
			_add_box(Vector3(park_center.x + x_pos, 4.7, park_center.z + z_pos), Vector3(4.0, 1.7, 4.0), Color("4d653d"))


func _add_building_blockout() -> void:
	building_sites.clear()
	var centers := _get_block_centers()
	for center_data: Dictionary in centers:
		var row: int = center_data["row"]
		var col: int = center_data["col"]
		var block_center: Vector3 = center_data["position"]
		if row == 4 and col == 4:
			continue
		if row == 0 and col == GRID_BLOCKS - 1:
			_build_gas_station_block(block_center, "gas_station_main")
		elif row == 0 or row == GRID_BLOCKS - 1 or col == 0 or col == GRID_BLOCKS - 1 or ((row + col) % 3 == 0):
			_build_house_block(block_center, "house_%d_%d" % [row, col])
		else:
			_build_tower_block(block_center, "tower_%d_%d" % [row, col])


func _add_street_furniture() -> void:
	for center_data: Dictionary in _get_block_centers():
		var row: int = center_data["row"]
		var col: int = center_data["col"]
		var center: Vector3 = center_data["position"]
		if row == 4 and col == 4:
			_add_park_furniture(center)
			continue
		_add_block_sidewalk_details(center)


func _spawn_agents() -> void:
	moving_agents.clear()

	_add_agent(
		_make_pedestrian_mesh(Color("d8ccb7"), Color("5b4334")),
		PackedVector3Array([Vector3(-84, 0.8, -SIDEWALK_OFFSET), Vector3(84, 0.8, -SIDEWALK_OFFSET)]),
		4.0,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("c2b097"), Color("32455e")),
		PackedVector3Array([Vector3(-18.0 - SIDEWALK_OFFSET, 0.8, -18), Vector3(-18.0 - SIDEWALK_OFFSET, 0.8, 84)]),
		3.2,
		"pedestrian"
	)
	_add_agent(
		_make_vehicle_mesh(Color("2a2a2a"), Color("54514b")),
		PackedVector3Array([Vector3(-92, 0.45, -42 - LANE_OFFSET), Vector3(92, 0.45, -42 - LANE_OFFSET)]),
		9.0,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("7c6b56"), Color("cbbd97")),
		PackedVector3Array([Vector3(92, 0.45, 42 + LANE_OFFSET), Vector3(-92, 0.45, 42 + LANE_OFFSET)]),
		10.5,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("403e3b"), Color("66615c")),
		PackedVector3Array([Vector3(-92, 0.45, -72.0 - LANE_OFFSET), Vector3(92, 0.45, -72.0 - LANE_OFFSET)]),
		7.0,
		"vehicle"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("dfd2be"), Color("4f5a34")),
		PackedVector3Array([Vector3(18.0 + SIDEWALK_OFFSET, 0.8, 18), Vector3(18.0 + SIDEWALK_OFFSET, 0.8, 84)]),
		3.6,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("ceb89a"), Color("6b4a37")),
		PackedVector3Array([Vector3(-84, 0.8, 18 + SIDEWALK_OFFSET), Vector3(84, 0.8, 18 + SIDEWALK_OFFSET)]),
		3.8,
		"pedestrian"
	)
	_add_agent(
		_make_vehicle_mesh(Color("5a2f29"), Color("8a6a5f")),
		PackedVector3Array([Vector3(-92, 0.45, 72 - LANE_OFFSET), Vector3(92, 0.45, 72 - LANE_OFFSET)]),
		8.4,
		"vehicle"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("d5c6b0"), Color("3a3f59")),
		PackedVector3Array([Vector3(-84, 0.8, -30 + SIDEWALK_OFFSET), Vector3(84, 0.8, -30 + SIDEWALK_OFFSET)]),
		3.5,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("cdb294"), Color("574234")),
		PackedVector3Array([Vector3(-84, 0.8, 30 - SIDEWALK_OFFSET), Vector3(84, 0.8, 30 - SIDEWALK_OFFSET)]),
		3.4,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("c9b08f"), Color("2f523b")),
		PackedVector3Array([Vector3(54 + SIDEWALK_OFFSET, 0.8, -84), Vector3(54 + SIDEWALK_OFFSET, 0.8, 84)]),
		3.0,
		"pedestrian"
	)
	_add_agent(
		_make_vehicle_mesh(Color("252525"), Color("6b655c")),
		PackedVector3Array([Vector3(-92, 0.45, -LANE_OFFSET), Vector3(92, 0.45, -LANE_OFFSET)]),
		7.6,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("2b2b2b"), Color("5b5852")),
		PackedVector3Array([Vector3(-54 - LANE_OFFSET, 0.45, -72), Vector3(-54 - LANE_OFFSET, 0.45, 72)]),
		8.2,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("353535"), Color("868077")),
		PackedVector3Array([Vector3(-54 + LANE_OFFSET, 0.45, 72), Vector3(-54 + LANE_OFFSET, 0.45, -72)]),
		7.5,
		"vehicle"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("e0ccb0"), Color("6f6240")),
		PackedVector3Array([Vector3(-36, 0.8, -54 - SIDEWALK_OFFSET), Vector3(36, 0.8, -54 - SIDEWALK_OFFSET)]),
		3.1,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("d7c19e"), Color("7a3f3f")),
		PackedVector3Array([Vector3(36, 0.8, 54 + SIDEWALK_OFFSET), Vector3(-36, 0.8, 54 + SIDEWALK_OFFSET)]),
		3.7,
		"pedestrian"
	)
	_add_agent(
		_make_vehicle_mesh(Color("1f1f1f"), Color("c1b49d")),
		PackedVector3Array([Vector3(92, 0.45, -24 + LANE_OFFSET), Vector3(-92, 0.45, -24 + LANE_OFFSET)]),
		8.8,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("4b2923"), Color("8d7467")),
		PackedVector3Array([Vector3(24 + LANE_OFFSET, 0.45, -92), Vector3(24 + LANE_OFFSET, 0.45, 92)]),
		8.1,
		"vehicle"
	)
	_add_agent(
		_make_vehicle_mesh(Color("323232"), Color("777067")),
		PackedVector3Array([Vector3(24 - LANE_OFFSET, 0.45, 92), Vector3(24 - LANE_OFFSET, 0.45, -92)]),
		7.9,
		"vehicle"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("dfc3a0"), Color("2a2f3e")),
		PackedVector3Array([Vector3(-66 - SIDEWALK_OFFSET, 0.8, -84), Vector3(-66 - SIDEWALK_OFFSET, 0.8, 84)]),
		3.0,
		"pedestrian"
	)
	_add_agent(
		_make_pedestrian_mesh(Color("d8c8b1"), Color("6d513a")),
		PackedVector3Array([Vector3(84, 0.8, -54 + SIDEWALK_OFFSET), Vector3(-84, 0.8, -54 + SIDEWALK_OFFSET)]),
		3.2,
		"pedestrian"
	)


func _spawn_player_crews() -> void:
	player_crews.clear()
	_add_player_crew("Vito", Vector3(-10, 0.9, 28), Color("8f1f1f"))
	_add_player_crew("Marco", Vector3(0, 0.9, 28), Color("a52b2b"))
	_add_player_crew("Luca", Vector3(10, 0.9, 28), Color("7a1818"))
	_set_selected_crew(0)


func _add_player_crew(name: String, start_position: Vector3, color: Color) -> void:
	var crew_root := Node3D.new()
	add_child(crew_root)
	crew_root.position = start_position

	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.38
	body_mesh.bottom_radius = 0.48
	body_mesh.height = 1.6
	body.mesh = body_mesh
	body.position = Vector3(0, 0.8, 0)
	body.material_override = _make_material(color)
	crew_root.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.26
	head_mesh.height = 0.52
	head.mesh = head_mesh
	head.position = Vector3(0, 1.9, 0)
	head.material_override = _make_material(Color("d3b895"))
	crew_root.add_child(head)

	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.06
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.06, 0)
	ring.material_override = _make_material(Color(0.95, 0.83, 0.35, 0.95))
	ring.visible = false
	crew_root.add_child(ring)

	var label := Label3D.new()
	label.text = name
	label.position = Vector3(0, 2.45, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.modulate = Color("f4e7d0")
	crew_root.add_child(label)

	player_crews.append({
		"name": name,
		"root": crew_root,
		"body": body,
		"ring": ring,
		"target": start_position,
		"speed": 7.2,
		"state": "Auto Work",
		"manual_control": false,
		"preferred_jobs": _get_preferred_jobs(name),
		"assigned_job_id": "",
		"job_timer": 0.0,
		"job_origin": start_position,
		"current_job_name": "Unassigned",
		"path_queue": [],
		"portrait": _make_crew_portrait(name, color),
	})


func _build_destination_marker() -> void:
	destination_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.7
	marker_mesh.bottom_radius = 0.7
	marker_mesh.height = 0.08
	destination_marker.mesh = marker_mesh
	destination_marker.material_override = _make_material(Color(0.20, 0.80, 0.42, 0.92))
	destination_marker.position = Vector3(0, 0.08, 0)
	destination_marker.visible = false
	add_child(destination_marker)


func _handle_left_click(screen_pos: Vector2) -> void:
	if _is_pointer_over_ui():
		return

	var world_pos: Variant = _get_ground_click_position(screen_pos)
	if world_pos == null:
		return

	var clicked_position: Vector3 = world_pos as Vector3
	var best_index := -1
	var best_distance := 3.8
	for i in range(player_crews.size()):
		var crew: Dictionary = player_crews[i]
		var root: Node3D = crew["root"]
		var distance: float = root.position.distance_to(clicked_position)
		if distance < best_distance:
			best_distance = distance
			best_index = i

	if best_index >= 0:
		_set_selected_crew(best_index)
		return

	if selected_crew_index < 0:
		return

	var crew: Dictionary = player_crews[selected_crew_index]
	var manual_control: bool = crew["manual_control"]
	if not manual_control and command_mode != "control":
		return

	match command_mode:
		"control":
			crew["manual_control"] = true
			crew["state"] = "Controlled"
			_update_status_text()
			_refresh_portrait_buttons()
		"move":
			_issue_manual_order(crew, clicked_position, "Moving", Color(0.20, 0.80, 0.42, 0.92))
		"guard":
			crew["manual_control"] = false
			crew["patrol_points"] = guard_patrol_points
			crew["patrol_index"] = 0
			_set_crew_route(crew, guard_patrol_points[0])
			crew["state"] = "Patrolling"
			crew["current_job_name"] = "Territory Guard"
			destination_marker.material_override = _make_material(Color(0.82, 0.74, 0.22, 0.92))
			destination_marker.position = Vector3(guard_patrol_points[0].x, 0.08, guard_patrol_points[0].z)
			destination_marker.visible = true
			_refresh_portrait_buttons()
			_update_status_text()
		"attack":
			_issue_manual_order(crew, clicked_position, "Attack Order", Color(0.82, 0.22, 0.22, 0.92))
		"forced_work":
			_issue_forced_work(crew, clicked_position)


func _handle_right_click(screen_pos: Vector2) -> void:
	if _is_pointer_over_ui() or selected_crew_index < 0:
		return

	var world_pos: Variant = _get_ground_click_position(screen_pos)
	if world_pos == null:
		return

	if command_mode == "forced_work":
		var clicked_position: Vector3 = world_pos as Vector3
		var building := _get_building_at_position(clicked_position)
		if not building.is_empty():
			_show_building_context(building)


func _get_ground_click_position(screen_pos: Vector2) -> Variant:
	if camera_node == null:
		return null

	var ray_origin: Vector3 = camera_node.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = camera_node.project_ray_normal(screen_pos)
	var hit: Variant = ground_plane.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return null
	return hit


func _set_selected_crew(index: int) -> void:
	selected_crew_index = index
	for i in range(player_crews.size()):
		var crew: Dictionary = player_crews[i]
		var ring: MeshInstance3D = crew["ring"]
		var body: MeshInstance3D = crew["body"]
		ring.visible = i == selected_crew_index
		body.scale = Vector3.ONE * (1.1 if i == selected_crew_index else 1.0)
	_refresh_portrait_buttons()
	_sync_command_mode_with_selected_crew()
	_update_status_text()


func _update_player_crews(delta: float) -> void:
	var ui_needs_refresh: bool = false
	for crew: Dictionary in player_crews:
		var root: Node3D = crew["root"]
		var speed: float = crew["speed"]
		var manual_control: bool = crew["manual_control"]
		var previous_state: String = crew["state"]

		if not manual_control:
			_update_auto_work_state(crew, delta)

		var target: Vector3 = crew["target"]
		var path_queue: Array = crew.get("path_queue", [])
		var offset: Vector3 = target - root.position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.05:
			if not path_queue.is_empty():
				var next_waypoint: Vector3 = path_queue[0]
				path_queue.remove_at(0)
				crew["path_queue"] = path_queue
				crew["target"] = next_waypoint
				continue
			if manual_control and crew["state"] == "Moving":
				crew["state"] = "Controlled"
			elif manual_control and crew["state"] == "Attack Order":
				crew["state"] = "Holding Fire"
			elif manual_control and crew["state"] == "Guarding":
				crew["state"] = "Defending"
			elif manual_control and crew["state"] == "Forced Work":
				crew["state"] = "Forced Working"
			elif not manual_control and crew["state"] == "Patrolling":
				var patrol_points: PackedVector3Array = crew.get("patrol_points", PackedVector3Array())
				if patrol_points.size() > 0:
					var patrol_index: int = crew.get("patrol_index", 0)
					patrol_index = (patrol_index + 1) % patrol_points.size()
					crew["patrol_index"] = patrol_index
					_set_crew_route(crew, patrol_points[patrol_index])
			if crew["state"] != previous_state:
				ui_needs_refresh = true
			continue
		var step: float = speed * delta
		if distance <= step:
			root.position = Vector3(target.x, root.position.y, target.z)
		else:
			var direction: Vector3 = offset.normalized()
			root.position += Vector3(direction.x, 0.0, direction.z) * step
		if crew["state"] != previous_state:
			ui_needs_refresh = true

	if ui_needs_refresh:
		_refresh_portrait_buttons()
		_update_status_text()


func _add_action_button(parent: HBoxContainer, action_id: String, label_text: String) -> void:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(120, 44)
	button.text = label_text
	button.pressed.connect(_on_action_button_pressed.bind(action_id))
	parent.add_child(button)
	action_buttons[action_id] = button


func _on_action_button_pressed(action_id: String) -> void:
	if selected_crew_index >= 0:
		var crew: Dictionary = player_crews[selected_crew_index]
		match action_id:
			"auto_work":
				crew["manual_control"] = false
				crew["state"] = "Auto Work"
				crew["assigned_job_id"] = ""
				crew["job_timer"] = 0.0
				command_mode = "auto_work"
			"control":
				crew["manual_control"] = true
				crew["state"] = "Controlled"
				_hide_building_context()
				command_mode = "control"
			_:
				if not crew["manual_control"]:
					return
				crew["manual_control"] = true
				_hide_building_context()
				command_mode = action_id
	_refresh_action_buttons()
	_refresh_portrait_buttons()
	_update_status_text()


func _on_portrait_selected(index: int) -> void:
	_set_selected_crew(index)


func _refresh_portrait_buttons() -> void:
	for i in range(crew_portrait_buttons.size()):
		var button: Button = crew_portrait_buttons[i]
		var crew: Dictionary = player_crews[i]
		var state_text: String = crew["state"]
		button.text = "%s\n%s" % [crew["name"], crew["current_job_name"]]
		button.icon = crew["portrait"]
		button.add_theme_font_size_override("font_size", 12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4c3329") if i == selected_crew_index else Color("211c1a")
		style.border_color = Color("d2b279") if i == selected_crew_index else Color("5b5148")
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)


func _refresh_action_buttons() -> void:
	var manual_actions := {
		"move": true,
		"attack": true,
		"guard": true,
		"forced_work": true,
	}
	var manual_enabled: bool = false
	if selected_crew_index >= 0:
		var selected_crew: Dictionary = player_crews[selected_crew_index]
		manual_enabled = selected_crew["manual_control"]

	for action_id in action_buttons.keys():
		var button: Button = action_buttons[action_id]
		var is_manual_action: bool = manual_actions.has(action_id)
		button.visible = not is_manual_action or manual_enabled
		var style := StyleBoxFlat.new()
		style.bg_color = Color("72563d") if action_id == command_mode else Color("332a24")
		style.border_color = Color("dcc287") if action_id == command_mode else Color("75624e")
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)


func _update_status_text() -> void:
	if status_label == null or selected_crew_index < 0:
		return
	var crew: Dictionary = player_crews[selected_crew_index]
	var control_text: String = "Manual" if crew["manual_control"] else "Auto"
	var preferred_jobs: PackedStringArray = crew["preferred_jobs"]
	var preference_text: String = ", ".join(preferred_jobs)
	status_label.text = (
		"[b]Selected:[/b] %s\n"
		+ "[b]Mode:[/b] %s\n"
		+ "[b]Command:[/b] %s\n"
		+ "[b]Current State:[/b] %s\n"
		+ "[b]Current Job:[/b] %s\n"
		+ "[b]Preferred Jobs:[/b] %s\n"
		+ "[b]Mouse:[/b] Left click portraits/actions. Move/Attack use ground click. Forced Work uses right click on buildings. Right drag pans. Both buttons drag rotates."
	) % [
		crew["name"],
		control_text,
		command_mode.capitalize(),
		crew["state"],
		crew["current_job_name"],
		preference_text,
	]


func _is_pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _issue_manual_order(crew: Dictionary, clicked_position: Vector3, state_text: String, marker_color: Color) -> void:
	var move_target: Vector3 = _snap_to_sidewalk(clicked_position)
	move_target.x = clampf(move_target.x, -160.0, 160.0)
	move_target.z = clampf(move_target.z, -90.0, 90.0)
	crew["manual_control"] = true
	_set_crew_route(crew, Vector3(move_target.x, 0.9, move_target.z))
	crew["state"] = state_text
	destination_marker.material_override = _make_material(marker_color)
	destination_marker.position = Vector3(move_target.x, 0.08, move_target.z)
	destination_marker.visible = true
	_refresh_portrait_buttons()
	_update_status_text()


func _sync_command_mode_with_selected_crew() -> void:
	if selected_crew_index < 0:
		return
	var crew: Dictionary = player_crews[selected_crew_index]
	command_mode = "control" if crew["manual_control"] else "auto_work"
	_hide_building_context()
	_refresh_action_buttons()


func _set_crew_route(crew: Dictionary, destination: Vector3) -> void:
	var route: Array[Vector3] = _build_sidewalk_route(crew["root"].position, destination)
	if route.is_empty():
		crew["target"] = destination
		crew["path_queue"] = []
		return
	crew["target"] = route[0]
	route.remove_at(0)
	crew["path_queue"] = route


func _build_sidewalk_route(start_position: Vector3, destination: Vector3) -> Array[Vector3]:
	var start_sidewalk: Vector3 = _snap_to_sidewalk(start_position)
	var end_sidewalk: Vector3 = _snap_to_sidewalk(destination)
	var route: Array[Vector3] = []
	var last_point: Vector3 = Vector3(start_position.x, 0.9, start_position.z)

	for waypoint: Vector3 in [
		start_sidewalk,
		Vector3(end_sidewalk.x, 0.9, start_sidewalk.z),
		end_sidewalk,
	]:
		if last_point.distance_to(waypoint) > 0.2:
			route.append(waypoint)
			last_point = waypoint
	return route


func _snap_to_sidewalk(world_position: Vector3) -> Vector3:
	var sidewalk_lines: Array[float] = []
	for i in range(GRID_BLOCKS + 1):
		var road_center: float = -HALF_CITY + (ROAD_SIZE * 0.5) + float(i) * (BLOCK_SIZE + ROAD_SIZE)
		sidewalk_lines.append(road_center - SIDEWALK_OFFSET)
		sidewalk_lines.append(road_center + SIDEWALK_OFFSET)

	var snapped_x: float = _nearest_axis_value(world_position.x, sidewalk_lines)
	var snapped_z: float = _nearest_axis_value(world_position.z, sidewalk_lines)
	return Vector3(snapped_x, 0.9, snapped_z)


func _nearest_axis_value(value: float, candidates: Array[float]) -> float:
	var best_value: float = candidates[0]
	var best_distance: float = absf(value - best_value)
	for candidate: float in candidates:
		var candidate_distance: float = absf(value - candidate)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_value = candidate
	return best_value


func _get_preferred_jobs(name: String) -> PackedStringArray:
	match name:
		"Vito":
			return PackedStringArray(["Runner", "Collection", "Lookout"])
		"Marco":
			return PackedStringArray(["Shop", "Park Meet", "Collection"])
		_:
			return PackedStringArray(["Lookout", "Runner", "Shop"])


func _update_auto_work_state(crew: Dictionary, delta: float) -> void:
	var root: Node3D = crew["root"]
	if crew["assigned_job_id"] == "":
		_assign_best_auto_job(crew)

	var current_job := _get_work_opportunity_by_id(crew["assigned_job_id"])
	if current_job.is_empty():
		return

	var current_job_point: Vector3 = _snap_to_sidewalk(current_job["position"])
	var distance_to_job: float = root.position.distance_to(current_job_point)
	var job_timer: float = crew["job_timer"]

	if distance_to_job <= 0.35:
		if job_timer <= 0.0:
			job_timer = current_job["duration"] + respawn_rng.randf_range(0.0, 1.5)
		job_timer -= delta
		crew["job_timer"] = job_timer
		crew["target"] = current_job_point
		crew["state"] = "Working"
		crew["current_job_name"] = current_job["job_type"]
		if job_timer <= 0.0:
			_assign_best_auto_job(crew, crew["assigned_job_id"])
			var next_job := _get_work_opportunity_by_id(crew["assigned_job_id"])
			if next_job.is_empty():
				return
			_set_crew_route(crew, _snap_to_sidewalk(next_job["position"]))
			crew["job_timer"] = 0.0
			crew["state"] = "Walking To Job"
			crew["current_job_name"] = next_job["job_type"]
	else:
		var queued_points: Array = crew.get("path_queue", [])
		if root.position.distance_to(crew["target"]) < 0.2 and queued_points.is_empty():
			_set_crew_route(crew, current_job_point)
		crew["state"] = "Walking To Job"
		crew["current_job_name"] = current_job["job_type"]


func _build_work_opportunities() -> void:
	work_opportunities.clear()
	_add_work_opportunity("shop_front_north", "Shop", Vector3(0, 0.9, -54), Color("e1c17b"))
	_add_work_opportunity("shop_front_south", "Shop", Vector3(0, 0.9, 54), Color("e1c17b"))
	_add_work_opportunity("park_meet", "Park Meet", Vector3(-4, 0.9, 0), Color("78a95d"))
	_add_work_opportunity("runner_west", "Runner", Vector3(-36, 0.9, 24), Color("75b5d8"))
	_add_work_opportunity("runner_east", "Runner", Vector3(36, 0.9, 24), Color("75b5d8"))
	_add_work_opportunity("collection_mid", "Collection", Vector3(0, 0.9, 36), Color("c88b4d"))
	_add_work_opportunity("lookout_north", "Lookout", Vector3(36, 0.9, -72), Color("d86e6e"))
	_add_work_opportunity("lookout_south", "Lookout", Vector3(-36, 0.9, 72), Color("d86e6e"))


func _add_work_opportunity(job_id: String, job_type: String, position: Vector3, color: Color) -> void:
	var marker := MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.55
	marker_mesh.bottom_radius = 0.55
	marker_mesh.height = 0.12
	marker.mesh = marker_mesh
	marker.position = Vector3(position.x, 0.08, position.z)
	marker.material_override = _make_material(color)
	add_child(marker)

	var label := Label3D.new()
	label.text = job_type
	label.position = Vector3(position.x, 0.7, position.z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 20
	label.modulate = color.lightened(0.3)
	add_child(label)

	work_opportunities.append({
		"id": job_id,
		"job_type": job_type,
		"position": position,
		"duration": 3.0,
		"marker": marker,
	})


func _assign_best_auto_job(crew: Dictionary, exclude_job_id: String = "") -> void:
	var preferred_jobs: PackedStringArray = crew["preferred_jobs"]
	var root: Node3D = crew["root"]
	var best_score := -99999.0
	var best_job_id := ""

	for opportunity: Dictionary in work_opportunities:
		var job_id: String = opportunity["id"]
		if job_id == exclude_job_id:
			continue
		var job_type: String = opportunity["job_type"]
		var job_position: Vector3 = opportunity["position"]
		var preference_bonus := 0.0
		for i in range(preferred_jobs.size()):
			if preferred_jobs[i] == job_type:
				preference_bonus = 30.0 - float(i * 8)
				break
		var distance_penalty: float = root.position.distance_to(job_position) * 0.15
		var score: float = preference_bonus - distance_penalty
		if score > best_score:
			best_score = score
			best_job_id = job_id

	if best_job_id != "":
		crew["assigned_job_id"] = best_job_id


func _get_work_opportunity_by_id(job_id: String) -> Dictionary:
	for opportunity: Dictionary in work_opportunities:
		if opportunity["id"] == job_id:
			return opportunity
	return {}


func _get_closest_work_opportunity(position: Vector3) -> Dictionary:
	var best_distance := 999999.0
	var best_match: Dictionary = {}
	for opportunity: Dictionary in work_opportunities:
		var distance: float = position.distance_to(opportunity["position"])
		if distance < best_distance:
			best_distance = distance
			best_match = opportunity
	return best_match


func _issue_forced_work(crew: Dictionary, clicked_position: Vector3) -> void:
	return


func _show_building_context(building: Dictionary) -> void:
	selected_context_building_id = building["id"]
	context_title_label.text = "%s: choose a forced job" % building["name"]
	for child in context_button_row.get_children():
		child.queue_free()
	for action_name: String in building["actions"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 40)
		button.text = action_name
		button.pressed.connect(_on_context_action_selected.bind(action_name))
		context_button_row.add_child(button)
	context_panel.visible = true


func _hide_building_context() -> void:
	selected_context_building_id = ""
	if context_panel != null:
		context_panel.visible = false


func _on_context_action_selected(action_name: String) -> void:
	if selected_crew_index < 0 or selected_context_building_id == "":
		return
	var building := _get_building_by_id(selected_context_building_id)
	if building.is_empty():
		return
	var crew: Dictionary = player_crews[selected_crew_index]
	crew["manual_control"] = true
	crew["assigned_job_id"] = building["id"]
	_set_crew_route(crew, _snap_to_sidewalk(building["position"]))
	crew["state"] = "Forced Work"
	crew["current_job_name"] = action_name
	crew["job_timer"] = 4.0 + respawn_rng.randf_range(0.0, 1.5)
	destination_marker.material_override = _make_material(Color(0.30, 0.65, 0.92, 0.92))
	destination_marker.position = Vector3(building["position"].x, 0.08, building["position"].z)
	destination_marker.visible = true
	_hide_building_context()
	_refresh_portrait_buttons()
	_update_status_text()


func _get_building_at_position(position: Vector3) -> Dictionary:
	for building: Dictionary in building_sites:
		var center: Vector3 = building["position"]
		var footprint: Vector2 = building["footprint"]
		if absf(position.x - center.x) <= footprint.x * 0.5 and absf(position.z - center.z) <= footprint.y * 0.5:
			return building
	return {}


func _get_building_by_id(building_id: String) -> Dictionary:
	for building: Dictionary in building_sites:
		if building["id"] == building_id:
			return building
	return {}


func _register_building_site(building_id: String, building_name: String, building_type: String, position: Vector3, footprint: Vector2, actions: Array[String]) -> void:
	building_sites.append({
		"id": building_id,
		"name": building_name,
		"type": building_type,
		"position": position,
		"footprint": footprint,
		"actions": actions,
	})


func _get_block_centers() -> Array[Dictionary]:
	var centers: Array[Dictionary] = []
	for row in range(GRID_BLOCKS):
		for col in range(GRID_BLOCKS):
			var x_pos: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE)
			var z_pos: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
			centers.append({
				"row": row,
				"col": col,
				"position": Vector3(x_pos, 0, z_pos),
			})
	return centers


func _get_block_center(row: int, col: int) -> Vector3:
	var x_pos: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(col) * (BLOCK_SIZE + ROAD_SIZE)
	var z_pos: float = -HALF_CITY + ROAD_SIZE + (BLOCK_SIZE * 0.5) + float(row) * (BLOCK_SIZE + ROAD_SIZE)
	return Vector3(x_pos, 0, z_pos)


func _build_house_block(block_center: Vector3, block_id: String) -> void:
	var lot_offsets: Array[Vector3] = []
	for z_idx in range(2):
		for x_idx in range(2):
			var x_pos: float = -4.4 + float(x_idx) * 8.8
			var z_pos: float = -4.4 + float(z_idx) * 8.8
			lot_offsets.append(Vector3(x_pos, 0, z_pos))

	for i in range(lot_offsets.size()):
		var house_center: Vector3 = block_center + lot_offsets[i]
		var facade := Color("72665d") if i % 2 == 0 else Color("8b8178")
		var roof := Color("5a514b") if i % 3 == 0 else Color("6d6359")
		_add_detailed_building(house_center, Vector3(7.8, 14.0 + float(i % 2) * 2.0, 7.8), facade, roof, 5 + (i % 2), false)
		if i < 2:
			_add_storefront_row(house_center + Vector3(0, 0, 3.85), 5.8, Color("c7b06f"), Color("2a2523"))
			_register_building_site("%s_shop_%d" % [block_id, i], "Corner Shop", "shop", house_center + Vector3(0, 0.9, 0), Vector2(7.8, 7.8), ["Money Laundering", "Protection", "Collection"])
			_add_signboard(house_center + Vector3(0, 8.2, 4.05), "BARBER" if i % 2 == 0 else "DELI", Color("d4c18a"), Color("2a2521"))
		else:
			_register_building_site("%s_home_%d" % [block_id, i], "Town House", "apartment", house_center + Vector3(0, 0.9, 0), Vector2(7.8, 7.8), ["Protection", "Collection"])


func _build_tower_block(block_center: Vector3, block_id: String) -> void:
	var tower_offsets: Array[Vector3] = [
		Vector3(-4.5, 0, -4.5),
		Vector3(4.5, 0, -4.5),
		Vector3(-4.5, 0, 4.5),
		Vector3(4.5, 0, 4.5),
	]
	var tower_assets: Array[String] = _get_tower_asset_paths()
	for i in range(tower_offsets.size()):
		var tower_center: Vector3 = block_center + tower_offsets[i]
		var tower_asset_path: String = tower_assets[(i + int(absf(block_center.x + block_center.z))) % tower_assets.size()]
		var tower_rotation: Vector3 = Vector3(0, float((i % 4) * 90), 0)
		var spawned_tower: Node3D = _spawn_asset_model(tower_asset_path, tower_center + Vector3(0, 0.02, 0), Vector3.ONE * 1.65, tower_rotation)
		if spawned_tower == null:
			var floors: int = 8 + (i % 3) * 2
			var facade := Color("47484b") if i % 2 == 0 else Color("2f3134")
			var roof := Color("737479") if i % 2 == 0 else Color("5d5f63")
			_add_detailed_building(tower_center, Vector3(6.0, 0, 6.0), facade, roof, floors, false)
		_add_storefront_row(tower_center + Vector3(0, 0, 3.3), 5.2, Color("bda86a"), Color("22201f"))
		_register_building_site("%s_tower_%d" % [block_id, i], "Mixed Use Tower", "tower", tower_center + Vector3(0, 0.9, 0), Vector2(6.0, 6.0), ["Protection", "Collection", "Money Laundering"])
		_add_signboard(tower_center + Vector3(0, 4.5, 3.55), "HOTEL" if i % 2 == 0 else "CAFE", Color("e0cc90"), Color("272423"))


func _build_gas_station_block(block_center: Vector3, block_id: String) -> void:
	var gas_station_asset: Node3D = _spawn_asset_model("res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-g.glb", block_center + Vector3(0, 0.02, -1.4), Vector3.ONE * 2.6, Vector3.ZERO)
	if gas_station_asset == null:
		_add_box(block_center + Vector3(0, 2.5, -3.0), Vector3(9.0, 5.0, 7.0), Color("3a3837"))
	_add_storefront_row(block_center + Vector3(0, 0, 0.8), 7.5, Color("cab06d"), Color("22201f"))
	_add_signboard(block_center + Vector3(0, 4.8, 1.0), "FUEL", Color("e2d3a1"), Color("532621"))
	_add_box(block_center + Vector3(0, 3.3, 5.2), Vector3(12.0, 0.6, 5.0), Color("6b6762"))
	_add_box(block_center + Vector3(-3.2, 1.3, 5.2), Vector3(1.1, 2.6, 1.1), Color("73706b"))
	_add_box(block_center + Vector3(3.2, 1.3, 5.2), Vector3(1.1, 2.6, 1.1), Color("73706b"))
	_add_box(block_center + Vector3(-3.2, 0.9, 6.8), Vector3(1.2, 1.8, 1.2), Color("7a3026"))
	_add_box(block_center + Vector3(3.2, 0.9, 6.8), Vector3(1.2, 1.8, 1.2), Color("d3c48b"))
	_register_building_site("%s_station" % block_id, "Gas Station", "shop", block_center + Vector3(0, 0.9, -1.5), Vector2(9.0, 7.0), ["Money Laundering", "Protection", "Collection"])


func _add_signboard(pos: Vector3, text: String, panel_color: Color, frame_color: Color) -> void:
	_add_box(pos + Vector3(0, -1.1, -0.08), Vector3(0.18, 2.2, 0.18), frame_color.darkened(0.15))
	_add_box(pos, Vector3(4.0, 1.3, 0.4), frame_color)
	_add_box(pos + Vector3(0, 0, 0.1), Vector3(3.5, 0.9, 0.15), panel_color)
	var sign := Label3D.new()
	sign.text = text
	sign.position = pos + Vector3(0, -0.15, 0.3)
	sign.rotation_degrees = Vector3(0, 0, 0)
	sign.font_size = 28
	sign.modulate = Color("2a221c")
	add_child(sign)

func _add_street(pos: Vector3, street_size: Vector3, road_color: Color = Color("2f3134"), curb_color: Color = Color("7d7264")) -> void:
	_add_box(pos, street_size, road_color)
	if street_size.x > street_size.z:
		_add_box(pos + Vector3(0, 0.02, -street_size.z * 0.55), Vector3(street_size.x, 0.02, 1.8), curb_color)
		_add_box(pos + Vector3(0, 0.02, street_size.z * 0.55), Vector3(street_size.x, 0.02, 1.8), curb_color)
	else:
		_add_box(pos + Vector3(-street_size.x * 0.55, 0.02, 0), Vector3(1.8, 0.02, street_size.z), curb_color)
		_add_box(pos + Vector3(street_size.x * 0.55, 0.02, 0), Vector3(1.8, 0.02, street_size.z), curb_color)


func _add_detailed_building(center: Vector3, footprint: Vector3, facade_color: Color, roof_color: Color, floors: int, industrial_style: bool) -> void:
	var total_height: float = float(floors) * 2.6
	var body_size := Vector3(footprint.x, total_height, footprint.z)
	_add_box(center + Vector3(0, total_height * 0.5, 0), body_size, facade_color)
	_add_box(center + Vector3(0, total_height + 0.35, 0), Vector3(footprint.x + 0.8, 0.7, footprint.z + 0.8), roof_color)
	_add_box(center + Vector3(0, 0.45, footprint.z * 0.5 - 0.15), Vector3(footprint.x * 0.92, 0.9, 0.35), roof_color.darkened(0.15))
	_add_box(center + Vector3(0, total_height * 0.35, footprint.z * 0.5 + 0.14), Vector3(footprint.x * 0.14, total_height * 0.72, 0.22), roof_color.lightened(0.08))

	var window_rows: int = max(1, floors)
	var window_columns: int = max(2, int(floor(footprint.x / 2.8)))
	for row in range(window_rows):
		for col in range(window_columns):
			var x_offset: float = -footprint.x * 0.35 + (float(col) * (footprint.x * 0.7 / max(1, window_columns - 1)))
			var y_offset: float = 1.2 + float(row) * 2.2
			_add_box(center + Vector3(x_offset, y_offset, footprint.z * 0.5 + 0.08), Vector3(0.8, 1.1, 0.16), Color("d9d4c8") if row % 3 == 0 else Color("8c8578"))

	if industrial_style:
		_add_box(center + Vector3(-footprint.x * 0.22, total_height + 1.8, -footprint.z * 0.2), Vector3(1.0, 3.6, 1.0), roof_color.darkened(0.2))
		_add_box(center + Vector3(footprint.x * 0.18, total_height + 1.5, 0), Vector3(0.8, 3.0, 0.8), roof_color.darkened(0.25))
	else:
		_add_box(center + Vector3(0, total_height + 0.95, 0), Vector3(footprint.x * 0.85, 0.4, footprint.z * 0.85), roof_color.lightened(0.08))
		if footprint.x >= 5.0:
			_add_box(center + Vector3(0, total_height - 2.0, 0), Vector3(footprint.x * 0.76, 3.1, footprint.z * 0.76), facade_color.lightened(0.08))
			_add_box(center + Vector3(0, total_height + 2.4, 0), Vector3(footprint.x * 0.42, 2.0, footprint.z * 0.42), roof_color.lightened(0.16))


func _add_storefront_row(center: Vector3, width: float, awning_color: Color, frame_color: Color) -> void:
	_add_box(center + Vector3(0, 1.25, 0), Vector3(width, 2.5, 0.55), Color("1c1d20"))
	_add_box(center + Vector3(0, 2.65, -0.35), Vector3(width + 0.8, 0.35, 1.0), awning_color)
	var shop_count: int = max(3, int(floor(width / 4.0)))
	for i in range(shop_count):
		var x_offset: float = -width * 0.42 + float(i) * (width * 0.84 / max(1, shop_count - 1))
		_add_box(center + Vector3(x_offset, 1.15, 0.1), Vector3(0.28, 2.3, 0.75), frame_color)
		_add_box(center + Vector3(x_offset, 0.35, 0.12), Vector3(2.0, 0.55, 0.7), frame_color.darkened(0.1))
		_add_box(center + Vector3(x_offset, 1.35, 0.15), Vector3(1.55, 1.25, 0.1), Color("d8d2c4"))


func _add_container_yard(center: Vector3, columns: int, rows: int) -> void:
	for row in range(rows):
		for col in range(columns):
			var x_offset: float = float(col) * 5.4 - float(columns - 1) * 2.7
			var z_offset: float = float(row) * 4.0 - float(rows - 1) * 2.0
			var tint := Color("8b5c3c") if (row + col) % 2 == 0 else Color("5f6f7e")
			_add_box(center + Vector3(x_offset, 1.1, z_offset), Vector3(4.6, 2.2, 3.4), tint)


func _add_caravan_strip(center: Vector3, count: int) -> void:
	for i in range(count):
		var z_offset: float = float(i) * 9.0 - float(count - 1) * 4.5
		_add_box(center + Vector3(0, 1.2, z_offset), Vector3(8.0, 2.4, 4.0), Color("8a7a66"))
		_add_box(center + Vector3(0, 2.7, z_offset), Vector3(6.8, 0.4, 3.2), Color("b9a98e"))


func _make_pedestrian_mesh(skin_color: Color, outfit_color: Color) -> MeshInstance3D:
	var root := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.52, 1.15, 0.34)
	root.mesh = body_mesh
	root.material_override = _make_material(Color("242424").lerp(outfit_color, 0.22))
	add_child(root)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.18
	head_mesh.height = 0.36
	head.mesh = head_mesh
	head.position = Vector3(0, 0.72, 0)
	head.material_override = _make_material(skin_color)
	root.add_child(head)

	var coat := MeshInstance3D.new()
	var coat_mesh := BoxMesh.new()
	coat_mesh.size = Vector3(0.62, 0.92, 0.42)
	coat.mesh = coat_mesh
	coat.position = Vector3(0, -0.08, 0)
	coat.material_override = _make_material(Color("111111").lerp(outfit_color, 0.18))
	root.add_child(coat)

	var hat_brim := MeshInstance3D.new()
	var hat_brim_mesh := CylinderMesh.new()
	hat_brim_mesh.top_radius = 0.24
	hat_brim_mesh.bottom_radius = 0.32
	hat_brim_mesh.height = 0.04
	hat_brim.mesh = hat_brim_mesh
	hat_brim.position = Vector3(0, 0.96, 0)
	hat_brim.material_override = _make_material(Color("151515"))
	root.add_child(hat_brim)

	var hat_top := MeshInstance3D.new()
	var hat_top_mesh := CylinderMesh.new()
	hat_top_mesh.top_radius = 0.17
	hat_top_mesh.bottom_radius = 0.17
	hat_top_mesh.height = 0.22
	hat_top.mesh = hat_top_mesh
	hat_top.position = Vector3(0, 1.08, 0)
	hat_top.material_override = _make_material(Color("1d1d1d"))
	root.add_child(hat_top)

	return root


func _make_vehicle_mesh(body_color: Color, roof_color: Color) -> Node3D:
	var root := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.3, 0.62, 5.2)
	root.mesh = body_mesh
	root.material_override = _make_material(Color("0f0f0f").lerp(body_color, 0.32))
	add_child(root)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.45, 0.6, 1.95)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, 0.62, -0.2)
	roof.material_override = _make_material(Color("141414").lerp(roof_color, 0.28))
	root.add_child(roof)

	var hood := MeshInstance3D.new()
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(1.55, 0.24, 1.45)
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 0.3, 1.78)
	hood.material_override = _make_material(Color("161616").lerp(roof_color.darkened(0.12), 0.28))
	root.add_child(hood)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(1.62, 0.32, 1.18)
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 0.34, -2.02)
	trunk.material_override = _make_material(Color("121212").lerp(body_color, 0.26))
	root.add_child(trunk)

	var grille := MeshInstance3D.new()
	var grille_mesh := BoxMesh.new()
	grille_mesh.size = Vector3(1.12, 0.5, 0.16)
	grille.mesh = grille_mesh
	grille.position = Vector3(0, 0.38, 2.56)
	grille.material_override = _make_material(Color("a79d88"))
	root.add_child(grille)

	for headlight_x in [-0.46, 0.46]:
		var headlight := MeshInstance3D.new()
		var headlight_mesh := SphereMesh.new()
		headlight_mesh.radius = 0.12
		headlight_mesh.height = 0.24
		headlight.mesh = headlight_mesh
		headlight.position = Vector3(headlight_x, 0.34, 2.46)
		headlight.material_override = _make_material(Color("d8c88b"))
		root.add_child(headlight)

	for fender_x in [-0.96, 0.96]:
		var front_fender := MeshInstance3D.new()
		var rear_fender := MeshInstance3D.new()
		var fender_mesh := BoxMesh.new()
		fender_mesh.size = Vector3(0.44, 0.4, 1.18)
		front_fender.mesh = fender_mesh
		rear_fender.mesh = fender_mesh
		front_fender.position = Vector3(fender_x, 0.1, 1.55)
		rear_fender.position = Vector3(fender_x, 0.1, -1.55)
		front_fender.material_override = _make_material(Color("121212").lerp(body_color, 0.28))
		rear_fender.material_override = _make_material(Color("121212").lerp(body_color, 0.28))
		root.add_child(front_fender)
		root.add_child(rear_fender)

	for x_pos in [-0.82, 0.82]:
		for z_pos in [-1.45, 1.45]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.34
			wheel_mesh.bottom_radius = 0.34
			wheel_mesh.height = 0.28
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees = Vector3(90, 0, 0)
			wheel.position = Vector3(x_pos, -0.08, z_pos)
			wheel.material_override = _make_material(Color("181818"))
			root.add_child(wheel)

	return root


func _add_agent(mesh_instance: Node3D, path: PackedVector3Array, speed: float, agent_type: String) -> void:
	if mesh_instance.get_parent() == null:
		add_child(mesh_instance)
	mesh_instance.position = path[0]
	moving_agents.append({
		"node": mesh_instance,
		"path": path,
		"target_index": 1,
		"speed": speed,
		"type": agent_type,
		"active": true,
		"respawn_timer": 0.0,
		"spawn_at_start": true,
	})


func _update_agents(delta: float) -> void:
	for agent: Dictionary in moving_agents:
		var node: Node3D = agent["node"]
		var is_active: bool = agent["active"]
		if not is_active:
			var respawn_timer: float = agent["respawn_timer"]
			respawn_timer -= delta
			if respawn_timer <= 0.0:
				_respawn_agent(agent)
			else:
				agent["respawn_timer"] = respawn_timer
			continue

		var path: PackedVector3Array = agent["path"]
		var target_index: int = agent["target_index"]
		var speed: float = agent["speed"]
		var target: Vector3 = path[target_index]
		var offset: Vector3 = target - node.position
		var distance: float = offset.length()
		var direction: Vector3 = offset.normalized()

		if agent["type"] == "vehicle" and _vehicle_should_stop(node.position, target):
			continue

		if distance <= speed * delta:
			node.position = target
			if target_index == path.size() - 1:
				_despawn_agent(agent)
				continue
			target_index += 1
			agent["target_index"] = target_index
		else:
			node.position += direction * speed * delta
			if direction.length() > 0.001:
				node.rotation.y = atan2(-direction.x, -direction.z)


func _despawn_agent(agent: Dictionary) -> void:
	var node: Node3D = agent["node"]
	node.visible = false
	agent["active"] = false
	agent["respawn_timer"] = respawn_rng.randf_range(1.8, 5.5)
	agent["spawn_at_start"] = not agent["spawn_at_start"]


func _respawn_agent(agent: Dictionary) -> void:
	var node: Node3D = agent["node"]
	var path: PackedVector3Array = agent["path"]
	var spawn_at_start: bool = agent["spawn_at_start"]
	var spawn_index: int = 0 if spawn_at_start else path.size() - 1
	var next_index: int = 1 if spawn_at_start else path.size() - 2
	node.position = path[spawn_index]
	node.visible = true
	agent["active"] = true
	agent["respawn_timer"] = 0.0
	agent["target_index"] = next_index


func _add_box(pos: Vector3, box_size: Vector3, color: Color) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = _make_material(color)
	add_child(mesh_instance)


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _noir_grade(color)
	material.roughness = 0.92
	material.metallic = 0.02
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _noir_grade(color: Color) -> Color:
	var luminance: float = (color.r * 0.299) + (color.g * 0.587) + (color.b * 0.114)
	var grayscale := Color(luminance, luminance, luminance, color.a)
	var warm_accent: Color = Color("c9ae73")
	var red_accent: Color = Color("8b2d22")
	if color.r > color.g * 1.2 and color.r > color.b * 1.2:
		return grayscale.lerp(red_accent, 0.55)
	if color.g > 0.7 and color.r > 0.6:
		return grayscale.lerp(warm_accent, 0.62)
	if color.b > color.r * 1.2:
		return grayscale.lerp(Color("87909a"), 0.24)
	return grayscale


func _get_house_asset_paths() -> Array[String]:
	return [
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-a.glb",
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-c.glb",
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-f.glb",
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-h.glb",
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-l.glb",
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/building-type-p.glb",
	]


func _get_tower_asset_paths() -> Array[String]:
	return [
		"res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-skyscraper-a.glb",
		"res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-skyscraper-b.glb",
		"res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-skyscraper-c.glb",
		"res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-skyscraper-d.glb",
		"res://assets/external/kenney_city-kit-commercial_2.1/Models/GLB format/building-skyscraper-e.glb",
	]


func _get_vehicle_asset_path(body_color: Color) -> String:
	var luminance: float = (body_color.r * 0.299) + (body_color.g * 0.587) + (body_color.b * 0.114)
	if luminance < 0.28:
		return "res://assets/external/VehiclesFBXformat/Sedan.fbx"
	if body_color.r > body_color.b and body_color.r > body_color.g:
		return "res://assets/external/VehiclesFBXformat/Wagon.fbx"
	if body_color.b > body_color.r:
		return "res://assets/external/VehiclesFBXformat/Jeep.fbx"
	return "res://assets/external/VehiclesFBXformat/Pickup.fbx"


func _spawn_asset_model(asset_path: String, position: Vector3, asset_scale: Vector3 = Vector3.ONE, rotation_deg: Vector3 = Vector3.ZERO, add_to_scene: bool = true) -> Node3D:
	if not ResourceLoader.exists(asset_path):
		return null
	var packed_scene: PackedScene = asset_scene_cache[asset_path] as PackedScene if asset_scene_cache.has(asset_path) else null
	if packed_scene == null:
		var loaded: Resource = load(asset_path)
		if loaded == null or not (loaded is PackedScene):
			return null
		packed_scene = loaded as PackedScene
		asset_scene_cache[asset_path] = packed_scene
	var instance: Node3D = packed_scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = position
	instance.scale = asset_scale
	instance.rotation_degrees = rotation_deg
	if add_to_scene:
		add_child(instance)
	return instance


func _make_crew_portrait(name: String, accent_color: Color) -> Texture2D:
	var width: int = 52
	var height: int = 68
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var coat_color: Color = _noir_grade(accent_color.darkened(0.25))
	var hat_color: Color = _noir_grade(Color("1a1a1a"))
	var skin_color: Color = _noir_grade(Color("d2b594"))
	var background: Color = _noir_grade(Color("3b3531"))
	var light_strip: Color = _noir_grade(Color("c6af74"))

	image.fill(background)

	for y in range(height):
		var edge_mix: float = absf((float(y) / float(height - 1)) - 0.5) * 0.55
		var row_color: Color = background.darkened(edge_mix)
		for x in range(width):
			image.set_pixel(x, y, row_color)

	for y in range(8, 16):
		for x in range(10, 42):
			image.set_pixel(x, y, hat_color)
	for y in range(4, 10):
		for x in range(16, 36):
			image.set_pixel(x, y, hat_color.lightened(0.05))

	for y in range(18, 34):
		for x in range(17, 35):
			image.set_pixel(x, y, skin_color)

	for y in range(23, 26):
		for x in range(20, 24):
			image.set_pixel(x, y, Color("131313"))
		for x in range(28, 32):
			image.set_pixel(x, y, Color("131313"))

	for y in range(30, 33):
		for x in range(22, 30):
			image.set_pixel(x, y, Color("2b2724"))

	for y in range(35, 62):
		for x in range(9, 43):
			image.set_pixel(x, y, coat_color)
	for y in range(36, 55):
		for x in range(22, 30):
			image.set_pixel(x, y, skin_color.darkened(0.08))

	for y in range(16, 62):
		image.set_pixel(5, y, light_strip)
		image.set_pixel(6, y, light_strip)

	if name == "Vito":
		for y in range(40, 62):
			image.set_pixel(16, y, _noir_grade(Color("8b2d22")))
	elif name == "Marco":
		for y in range(39, 62):
			image.set_pixel(26, y, _noir_grade(Color("c9ae73")))
	elif name == "Luca":
		for y in range(43, 62):
			image.set_pixel(34, y, _noir_grade(Color("7e7f85")))

	return ImageTexture.create_from_image(image)


func _update_day_night_cycle(delta: float) -> void:
	time_of_day = wrapf(time_of_day + (delta / DAY_NIGHT_CYCLE), 0.0, 1.0)
	var day_angle: float = time_of_day * TAU
	var sun_height: float = sin(day_angle)
	var daylight: float = clampf((sun_height + 0.18) / 1.12, 0.0, 1.0)

	if sun_light != null:
		sun_light.rotation_degrees.x = lerpf(-18.0, -78.0, daylight)
		sun_light.rotation_degrees.y = lerpf(-35.0, 55.0, time_of_day)
		sun_light.light_energy = lerpf(0.08, 1.25, daylight)
		sun_light.light_color = Color("8e97b3").lerp(Color("f0debc"), daylight)

	if fill_light != null:
		fill_light.light_energy = lerpf(0.04, 0.22, daylight)
		fill_light.light_color = Color("607199").lerp(Color("8f8475"), daylight)

	if world_environment != null:
		world_environment.background_color = Color("11131a").lerp(Color("7c7469"), daylight)
		world_environment.ambient_light_color = Color("596684").lerp(Color("8e8579"), daylight)
		world_environment.ambient_light_energy = lerpf(0.32, 0.58, daylight)
		world_environment.fog_light_color = Color("17191f").lerp(Color("6e675e"), daylight)
		world_environment.fog_density = lerpf(0.014, 0.006, daylight)

	for street_light: OmniLight3D in street_lights:
		street_light.light_energy = lerpf(1.85, 0.0, daylight)


func _add_lane_markings_horizontal(center_x: float, z_pos: float, segment_length: float) -> void:
	var dash_length: float = 2.8
	var gap_length: float = 2.4
	var start_x: float = center_x - (segment_length * 0.5) + 1.2
	var end_x: float = center_x + (segment_length * 0.5) - 1.2
	var x_pos: float = start_x
	while x_pos < end_x:
		var actual_dash: float = minf(dash_length, end_x - x_pos)
		_add_box(Vector3(x_pos + actual_dash * 0.5, 0.065, z_pos), Vector3(actual_dash, 0.01, 0.24), Color("d5c59a"))
		x_pos += dash_length + gap_length


func _add_lane_markings_vertical(x_pos: float, center_z: float, segment_length: float) -> void:
	var dash_length: float = 2.8
	var gap_length: float = 2.4
	var start_z: float = center_z - (segment_length * 0.5) + 1.2
	var end_z: float = center_z + (segment_length * 0.5) - 1.2
	var z_pos: float = start_z
	while z_pos < end_z:
		var actual_dash: float = minf(dash_length, end_z - z_pos)
		_add_box(Vector3(x_pos, 0.065, z_pos + actual_dash * 0.5), Vector3(0.24, 0.01, actual_dash), Color("d5c59a"))
		z_pos += dash_length + gap_length


func _add_crosswalks(intersection_center: Vector3) -> void:
	for stripe_index in range(-2, 3):
		var stripe_offset: float = float(stripe_index) * 0.9
		_add_box(intersection_center + Vector3(stripe_offset, 0.07, -2.35), Vector3(0.46, 0.01, 2.3), Color("d8d1bf"))
		_add_box(intersection_center + Vector3(stripe_offset, 0.07, 2.35), Vector3(0.46, 0.01, 2.3), Color("d8d1bf"))
		_add_box(intersection_center + Vector3(-2.35, 0.07, stripe_offset), Vector3(2.3, 0.01, 0.46), Color("d8d1bf"))
		_add_box(intersection_center + Vector3(2.35, 0.07, stripe_offset), Vector3(2.3, 0.01, 0.46), Color("d8d1bf"))


func _add_traffic_light_cluster(intersection_center: Vector3) -> void:
	var offsets: Array[Vector3] = [
		Vector3(-2.6, 0, -2.6),
		Vector3(2.6, 0, -2.6),
		Vector3(-2.6, 0, 2.6),
		Vector3(2.6, 0, 2.6),
	]
	for offset: Vector3 in offsets:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.12
		pole_mesh.bottom_radius = 0.12
		pole_mesh.height = 4.6
		pole.mesh = pole_mesh
		pole.position = intersection_center + offset + Vector3(0, 2.3, 0)
		pole.material_override = _make_material(Color("3f3f3f"))
		add_child(pole)

		var housing := MeshInstance3D.new()
		var housing_mesh := BoxMesh.new()
		housing_mesh.size = Vector3(0.55, 1.5, 0.55)
		housing.mesh = housing_mesh
		housing.position = intersection_center + offset + Vector3(0, 4.0, 0)
		housing.material_override = _make_material(Color("1e1e1e"))
		add_child(housing)

		var red_light := MeshInstance3D.new()
		var amber_light := MeshInstance3D.new()
		var green_light := MeshInstance3D.new()
		for light_mesh_instance: MeshInstance3D in [red_light, amber_light, green_light]:
			var bulb_mesh := SphereMesh.new()
			bulb_mesh.radius = 0.13
			bulb_mesh.height = 0.26
			light_mesh_instance.mesh = bulb_mesh
			housing.add_child(light_mesh_instance)
		red_light.position = Vector3(0, 0.45, 0.3)
		amber_light.position = Vector3(0, 0.0, 0.3)
		green_light.position = Vector3(0, -0.45, 0.3)

		var axis: String = "ns" if absf(offset.x) > absf(offset.z) else "ew"
		traffic_lights.append({
			"axis": axis,
			"red": red_light,
			"amber": amber_light,
			"green": green_light,
			"position": intersection_center,
		})


func _update_traffic_lights(delta: float) -> void:
	traffic_light_timer += delta
	if traffic_light_timer >= TRAFFIC_LIGHT_CYCLE:
		traffic_light_timer = 0.0
		traffic_ns_green = not traffic_ns_green

	for light_data: Dictionary in traffic_lights:
		var axis: String = light_data["axis"]
		var is_green: bool = traffic_ns_green if axis == "ns" else not traffic_ns_green
		var red_light: MeshInstance3D = light_data["red"]
		var amber_light: MeshInstance3D = light_data["amber"]
		var green_light: MeshInstance3D = light_data["green"]
		red_light.material_override = _make_material(Color("b02a23") if not is_green else Color("421817"))
		amber_light.material_override = _make_material(Color("7c6420"))
		green_light.material_override = _make_material(Color("38a04d") if is_green else Color("173d22"))


func _vehicle_should_stop(current_position: Vector3, target_position: Vector3) -> bool:
	var moving_along_x: bool = absf(target_position.x - current_position.x) > absf(target_position.z - current_position.z)
	for light_data: Dictionary in traffic_lights:
		var light_position: Vector3 = light_data["position"]
		var axis: String = light_data["axis"]
		var relevant_axis: String = "ew" if moving_along_x else "ns"
		if axis != relevant_axis:
			continue
		var close_in_cross_axis: bool = absf(current_position.z - light_position.z) < 2.2 if moving_along_x else absf(current_position.x - light_position.x) < 2.2
		if not close_in_cross_axis:
			continue
		var current_along: float = current_position.x if moving_along_x else current_position.z
		var target_along: float = target_position.x if moving_along_x else target_position.z
		var light_along: float = light_position.x if moving_along_x else light_position.z
		var approaching: bool = (current_along < light_along and target_along > current_along) or (current_along > light_along and target_along < current_along)
		var close_to_line: bool = absf(current_along - light_along) < 3.6
		if approaching and close_to_line:
			var is_green: bool = traffic_ns_green if axis == "ns" else not traffic_ns_green
			if not is_green:
				return true
	return false


func _add_block_sidewalk_details(block_center: Vector3) -> void:
	var detail_color: Color = Color("9a907f")
	_add_box(block_center + Vector3(0, 0.055, -BLOCK_SIZE * 0.5 + 1.1), Vector3(BLOCK_SIZE - 2.0, 0.04, 1.2), detail_color)
	_add_box(block_center + Vector3(0, 0.055, BLOCK_SIZE * 0.5 - 1.1), Vector3(BLOCK_SIZE - 2.0, 0.04, 1.2), detail_color)
	_add_box(block_center + Vector3(-BLOCK_SIZE * 0.5 + 1.1, 0.055, 0), Vector3(1.2, 0.04, BLOCK_SIZE - 2.0), detail_color)
	_add_box(block_center + Vector3(BLOCK_SIZE * 0.5 - 1.1, 0.055, 0), Vector3(1.2, 0.04, BLOCK_SIZE - 2.0), detail_color)

	for corner: Vector3 in [Vector3(-6.4, 0, -6.4), Vector3(6.4, 0, -6.4), Vector3(-6.4, 0, 6.4), Vector3(6.4, 0, 6.4)]:
		_add_street_lamp(block_center + corner)


func _add_park_furniture(park_center: Vector3) -> void:
	_add_block_sidewalk_details(park_center)
	for tree_offset: Vector3 in [Vector3(-4.5, 0, -4.5), Vector3(4.5, 0, -4.5), Vector3(-4.5, 0, 4.5), Vector3(4.5, 0, 4.5), Vector3(0, 0, 0)]:
		_add_tree(park_center + tree_offset)
	_add_box(park_center + Vector3(0, 0.18, -3.6), Vector3(4.6, 0.16, 0.5), Color("6a4c32"))
	_add_box(park_center + Vector3(0, 0.18, 3.6), Vector3(4.6, 0.16, 0.5), Color("6a4c32"))


func _add_tree(tree_pos: Vector3) -> void:
	var tree_asset: Node3D = _spawn_asset_model(
		"res://assets/external/kenney_city-kit-suburban_2.0/Models/GLB format/tree-large.glb",
		tree_pos,
		Vector3.ONE * 0.8,
		Vector3(0, respawn_rng.randf_range(0.0, 360.0), 0)
	)
	if tree_asset == null:
		_add_box(tree_pos + Vector3(0, 1.3, 0), Vector3(0.5, 2.6, 0.5), Color("5b402b"))
		_add_box(tree_pos + Vector3(0, 3.3, 0), Vector3(2.8, 2.1, 2.8), Color("546d41"))
		_add_box(tree_pos + Vector3(0, 4.4, 0), Vector3(1.8, 1.4, 1.8), Color("65834e"))


func _add_street_lamp(lamp_pos: Vector3) -> void:
	_add_box(lamp_pos + Vector3(0, 1.9, 0), Vector3(0.18, 3.8, 0.18), Color("474747"))
	_add_box(lamp_pos + Vector3(0, 3.95, 0), Vector3(0.52, 0.28, 0.52), Color("c9b779"))
	var street_light := OmniLight3D.new()
	street_light.position = lamp_pos + Vector3(0, 3.85, 0)
	street_light.light_color = Color("ffd89a")
	street_light.light_energy = 0.0
	street_light.omni_range = 18.0
	street_light.shadow_enabled = false
	add_child(street_light)
	street_lights.append(street_light)
