extends Control

const DISTRICT_BUTTON_SIZE := Vector2(240, 130)
const DISTRICT_VIEW_SCENE := preload("res://scenes/district_view.tscn")
const PEDESTRIAN_COLOR := Color("d6c7ab")
const CAR_COLOR := Color("2f2f33")
const TAXI_COLOR := Color("b08a3c")

var city_state := {
	"money": 1200,
	"crew": 8,
	"stored_goods": 18,
	"city_heat": 15,
	"day": 1,
}

var districts := {
	"industrial": {
		"name": "Industrial",
		"role": "Production and storage hub",
		"heat": 15,
		"police_presence": 45,
		"demand": 35,
		"rival_pressure": 25,
		"player_control": 20,
		"color": Color("6e6255"),
		"buildings": ["Warehouse", "Workshop Lab"],
		"actions": [
			{"label": "Produce", "id": "produce"},
			{"label": "Store Goods", "id": "store"},
			{"label": "Lay Low", "id": "lay_low"},
		],
	},
	"residential": {
		"name": "Residential",
		"role": "Sales and social influence",
		"heat": 10,
		"police_presence": 55,
		"demand": 70,
		"rival_pressure": 15,
		"player_control": 10,
		"color": Color("8b6b4b"),
		"buildings": ["Corner Store Front", "Bar or Social Club", "Doctor's Office Front"],
		"actions": [
			{"label": "Sell", "id": "sell"},
			{"label": "Build Influence", "id": "influence"},
			{"label": "Lay Low", "id": "lay_low"},
		],
	},
	"slums": {
		"name": "Slums",
		"role": "Recruitment, expansion, hidden activity",
		"heat": 20,
		"police_presence": 25,
		"demand": 50,
		"rival_pressure": 65,
		"player_control": 30,
		"color": Color("5c4734"),
		"buildings": ["Safehouse", "Tenement Block", "Gang Hideout", "Bar or Social Club"],
		"actions": [
			{"label": "Recruit", "id": "recruit"},
			{"label": "Expand Influence", "id": "expand"},
			{"label": "Hide Operations", "id": "hide"},
		],
	},
}

var selected_district_id := "industrial"

var district_details: RichTextLabel
var city_summary: Label
var event_log: RichTextLabel
var action_container: VBoxContainer
var district_buttons := {}
var active_district_view: Control
var city_root_container: Control
var world_map_layer: Control
var actor_layer: Control
var district_overlay_layer: Control
var world_actors: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh_all()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color("1a1714")
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.anchor_right = 1.0
	root_margin.anchor_bottom = 1.0
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_top", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_bottom", 24)
	add_child(root_margin)
	city_root_container = root_margin

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_child(root)

	var sidebar := PanelContainer.new()
	sidebar.custom_minimum_size = Vector2(390, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sidebar)

	var sidebar_content := VBoxContainer.new()
	sidebar_content.add_theme_constant_override("separation", 12)
	sidebar.add_child(sidebar_content)

	var title := Label.new()
	title.text = "OMERTA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	sidebar_content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "World Layer Prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color("d0c4ad")
	sidebar_content.add_child(subtitle)

	district_details = RichTextLabel.new()
	district_details.bbcode_enabled = true
	district_details.fit_content = true
	district_details.scroll_active = false
	district_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_content.add_child(district_details)

	var actions_title := Label.new()
	actions_title.text = "District Actions"
	actions_title.add_theme_font_size_override("font_size", 18)
	sidebar_content.add_child(actions_title)

	action_container = VBoxContainer.new()
	action_container.add_theme_constant_override("separation", 8)
	sidebar_content.add_child(action_container)

	var main_panel := VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 16)
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main_panel)

	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 110)
	main_panel.add_child(header_panel)

	city_summary = Label.new()
	city_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	city_summary.add_theme_font_size_override("font_size", 20)
	city_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_panel.add_child(city_summary)

	var city_board := PanelContainer.new()
	city_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_child(city_board)

	var city_board_inner := Control.new()
	city_board_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_board_inner.custom_minimum_size = Vector2(0, 520)
	city_board.add_child(city_board_inner)

	var city_map_background := ColorRect.new()
	city_map_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_map_background.color = Color("201b17")
	city_board_inner.add_child(city_map_background)

	world_map_layer = Control.new()
	world_map_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_board_inner.add_child(world_map_layer)

	var board_title := Label.new()
	board_title.text = "City World Map"
	board_title.position = Vector2(22, 18)
	board_title.add_theme_font_size_override("font_size", 24)
	city_board_inner.add_child(board_title)

	var board_hint := Label.new()
	board_hint.text = "Three district zones form the first test city: produce in Industrial, sell in Residential, expand in Slums."
	board_hint.position = Vector2(22, 52)
	board_hint.modulate = Color("cbbda1")
	city_board_inner.add_child(board_hint)

	_build_world_map_visuals()

	actor_layer = Control.new()
	actor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_board_inner.add_child(actor_layer)

	district_overlay_layer = Control.new()
	district_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_board_inner.add_child(district_overlay_layer)

	_add_district_region(
		district_overlay_layer,
		"industrial",
		Rect2(80, 125, 300, 180),
		"INDUSTRIAL",
		"",
	)
	_add_district_region(
		district_overlay_layer,
		"residential",
		Rect2(700, 125, 280, 200),
		"RESIDENTIAL",
		"",
	)
	_add_district_region(
		district_overlay_layer,
		"slums",
		Rect2(280, 335, 340, 120),
		"SLUMS",
		"",
	)

	var map_legend := Label.new()
	map_legend.position = Vector2(24, 475)
	map_legend.text = "River and roads split the city into district zones. Click a district region to inspect it."
	map_legend.modulate = Color("bda98a")
	city_board_inner.add_child(map_legend)
	_spawn_world_actors()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	main_panel.add_child(footer)

	var next_day_button := Button.new()
	next_day_button.text = "Advance One Day"
	next_day_button.pressed.connect(_on_advance_day_pressed)
	footer.add_child(next_day_button)

	var tension_button := Button.new()
	tension_button.text = "Crackdown Check"
	tension_button.pressed.connect(_on_crackdown_check_pressed)
	footer.add_child(tension_button)

	var enter_button := Button.new()
	enter_button.text = "Enter Selected District"
	enter_button.pressed.connect(_on_enter_district_pressed)
	footer.add_child(enter_button)

	event_log = RichTextLabel.new()
	event_log.bbcode_enabled = true
	event_log.fit_content = false
	event_log.custom_minimum_size = Vector2(0, 170)
	event_log.scroll_following = true
	main_panel.add_child(event_log)
	_log_event("Prototype loaded. Build your foothold across the city.")


func _build_world_map_visuals() -> void:
	var haze := ColorRect.new()
	haze.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	haze.color = Color(0.08, 0.07, 0.06, 0.18)
	world_map_layer.add_child(haze)

	var river := _make_rect(Vector2(560, 110), Vector2(90, 330), Color("2f4b53"))
	world_map_layer.add_child(river)
	world_map_layer.add_child(_make_rect(Vector2(595, 110), Vector2(16, 330), Color(0.60, 0.78, 0.82, 0.18)))
	world_map_layer.add_child(_make_rect(Vector2(110, 130), Vector2(270, 10), Color("6c6256")))
	world_map_layer.add_child(_make_rect(Vector2(110, 152), Vector2(270, 6), Color("8a7b63")))
	world_map_layer.add_child(_make_rect(Vector2(360, 255), Vector2(360, 18), Color("6b5a46")))
	world_map_layer.add_child(_make_rect(Vector2(284, 348), Vector2(520, 14), Color("5d4c3d")))

	world_map_layer.add_child(_make_rect(Vector2(68, 118), Vector2(320, 190), Color(0.44, 0.38, 0.31, 0.25)))
	world_map_layer.add_child(_make_rect(Vector2(80, 125), Vector2(300, 180), Color("4b4137")))
	for i in range(5):
		world_map_layer.add_child(_make_rect(Vector2(108 + (i * 48), 190), Vector2(34, 54), Color("7d684d")))
	for i in range(4):
		world_map_layer.add_child(_make_rect(Vector2(110 + (i * 58), 145), Vector2(16, 34), Color("8e7658")))
		world_map_layer.add_child(_make_rect(Vector2(102 + (i * 58), 118 - (i % 2) * 10), Vector2(30, 18), Color(0.70, 0.66, 0.60, 0.22)))

	world_map_layer.add_child(_make_rect(Vector2(690, 118), Vector2(300, 210), Color(0.52, 0.40, 0.29, 0.24)))
	world_map_layer.add_child(_make_rect(Vector2(700, 125), Vector2(280, 200), Color("6f5540")))
	for row in range(2):
		for col in range(4):
			world_map_layer.add_child(_make_rect(Vector2(728 + (col * 54), 154 + (row * 62)), Vector2(36, 42), Color("a17c55")))
	for i in range(3):
		world_map_layer.add_child(_make_rect(Vector2(734 + (i * 62), 255), Vector2(42, 30), Color("875238")))
	world_map_layer.add_child(_make_rect(Vector2(916, 155), Vector2(42, 118), Color("546244")))

	world_map_layer.add_child(_make_rect(Vector2(270, 320), Vector2(360, 150), Color(0.36, 0.28, 0.19, 0.26)))
	world_map_layer.add_child(_make_rect(Vector2(280, 335), Vector2(340, 120), Color("4a392c")))
	for row in range(2):
		for col in range(5):
			world_map_layer.add_child(_make_rect(Vector2(305 + (col * 52), 356 + (row * 34)), Vector2(28, 24), Color("7b5b40")))
	for i in range(3):
		world_map_layer.add_child(_make_rect(Vector2(352 + (i * 76), 344), Vector2(12, 102), Color(0.16, 0.12, 0.09, 0.42)))
	world_map_layer.add_child(_make_rect(Vector2(565, 372), Vector2(18, 18), Color("b06032")))

	_add_map_label(world_map_layer, "INDUSTRIAL", Vector2(96, 128))
	_add_map_label(world_map_layer, "RESIDENTIAL", Vector2(716, 128))
	_add_map_label(world_map_layer, "SLUMS", Vector2(296, 338))


func _make_rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	return rect


func _add_map_label(parent: Control, text: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("efe3c8")
	parent.add_child(label)


func _add_district_region(parent: Control, district_id: String, rect: Rect2, title: String, description: String) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = title if description.is_empty() else "%s\n%s" % [title, description]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 1)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0.01))
	button.flat = true
	button.pressed.connect(_on_district_selected.bind(district_id))
	parent.add_child(button)
	district_buttons[district_id] = button


func _refresh_all() -> void:
	_update_city_heat()
	_refresh_city_summary()
	_refresh_district_details()
	_refresh_action_buttons()
	_refresh_district_button_styles()


func _refresh_city_summary() -> void:
	city_summary.text = "Day %d    Money: $%d    Crew: %d    Goods: %d    City Heat: %d" % [
		city_state["day"],
		city_state["money"],
		city_state["crew"],
		city_state["stored_goods"],
		city_state["city_heat"],
	]


func _refresh_district_details() -> void:
	var district: Dictionary = districts[selected_district_id]
	var building_text := ", ".join(district["buildings"])
	district_details.text = (
		"[b]%s[/b]\n%s\n\n"
		+ "[b]Heat:[/b] %d\n"
		+ "[b]Police Presence:[/b] %d\n"
		+ "[b]Demand:[/b] %d\n"
		+ "[b]Rival Pressure:[/b] %d\n"
		+ "[b]Player Control:[/b] %d\n\n"
		+ "[b]Planned Buildings:[/b]\n%s"
	) % [
		district["name"],
		district["role"],
		district["heat"],
		district["police_presence"],
		district["demand"],
		district["rival_pressure"],
		district["player_control"],
		building_text,
	]


func _refresh_action_buttons() -> void:
	for child in action_container.get_children():
		child.queue_free()

	var district: Dictionary = districts[selected_district_id]
	for action_data in district["actions"]:
		var button := Button.new()
		button.text = action_data["label"]
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(_on_action_pressed.bind(action_data["id"]))
		action_container.add_child(button)


func _refresh_district_button_styles() -> void:
	for district_id in district_buttons.keys():
		var button: Button = district_buttons[district_id]
		var district: Dictionary = districts[district_id]
		var district_color: Color = district["color"]
		button.modulate = Color(1, 1, 1, 1)
		button.self_modulate = Color(1, 1, 1, 1)
		button.tooltip_text = "%s: %s" % [district["name"], district["role"]]
		var alpha: float = 0.10 if district_id == selected_district_id else 0.03
		var border_alpha: float = 0.75 if district_id == selected_district_id else 0.35
		var border_width: int = 3 if district_id == selected_district_id else 1
		var style := StyleBoxFlat.new()
		style.bg_color = Color(district_color.r, district_color.g, district_color.b, alpha)
		style.border_color = Color(district_color.r + 0.1, district_color.g + 0.1, district_color.b + 0.1, border_alpha)
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)


func _on_district_selected(district_id: String) -> void:
	selected_district_id = district_id
	_log_event("Selected %s district." % districts[district_id]["name"])
	_refresh_all()


func _on_action_pressed(action_id: String) -> void:
	match action_id:
		"produce":
			_apply_industrial_produce()
		"store":
			_apply_store_goods()
		"sell":
			_apply_sell_goods()
		"influence":
			_apply_build_influence()
		"lay_low":
			_apply_lay_low()
		"recruit":
			_apply_recruit()
		"expand":
			_apply_expand()
		"hide":
			_apply_hide_operations()

	_refresh_all()


func _apply_industrial_produce() -> void:
	var district: Dictionary = districts["industrial"]
	city_state["stored_goods"] += 6
	district["heat"] += 8
	district["police_presence"] += 3
	_log_event("Industrial production run completed. Goods increased, but smoke and movement raised suspicion.")


func _apply_store_goods() -> void:
	var district: Dictionary = districts["industrial"]
	district["heat"] = max(district["heat"] - 3, 0)
	district["player_control"] += 1
	_log_event("Goods were quietly redistributed through warehouse channels. Heat eased slightly.")


func _apply_sell_goods() -> void:
	var district: Dictionary = districts["residential"]
	if city_state["stored_goods"] <= 0:
		_log_event("No goods available to sell in Residential.")
		return

	var sold: int = min(city_state["stored_goods"], 5)
	city_state["stored_goods"] -= sold
	city_state["money"] += sold * 45
	district["heat"] += 6
	district["player_control"] += 2
	_log_event("Residential crews moved product through local corners and social clubs. Cash flow improved.")


func _apply_build_influence() -> void:
	var district: Dictionary = districts["residential"]
	city_state["money"] = max(city_state["money"] - 60, 0)
	district["player_control"] += 4
	district["heat"] += 2
	_log_event("Money was spent on favors, drinks, and neighborhood goodwill in Residential.")


func _apply_lay_low() -> void:
	var district: Dictionary = districts[selected_district_id]
	district["heat"] = max(district["heat"] - 6, 0)
	district["police_presence"] = max(district["police_presence"] - 2, 0)
	_log_event("%s crews kept things quiet for a day. Pressure cooled down." % district["name"])


func _apply_recruit() -> void:
	var district: Dictionary = districts["slums"]
	city_state["crew"] += 1
	district["rival_pressure"] += 4
	district["player_control"] += 2
	_log_event("A new recruit was picked up in the Slums, but rival eyes are starting to notice.")


func _apply_expand() -> void:
	var district: Dictionary = districts["slums"]
	city_state["money"] = max(city_state["money"] - 80, 0)
	district["player_control"] += 5
	district["heat"] += 3
	district["rival_pressure"] += 5
	_log_event("Influence expanded deeper into the Slums. Control rises, but tension comes with it.")


func _apply_hide_operations() -> void:
	var district: Dictionary = districts["slums"]
	district["heat"] = max(district["heat"] - 4, 0)
	district["rival_pressure"] = max(district["rival_pressure"] - 2, 0)
	_log_event("Operations were tucked deeper into back alleys and basements in the Slums.")


func _on_advance_day_pressed() -> void:
	city_state["day"] += 1
	for district_id in districts.keys():
		var district: Dictionary = districts[district_id]
		district["heat"] = clampi(district["heat"] + _heat_drift(district_id), 0, 100)
		district["police_presence"] = clampi(district["police_presence"] + _police_drift(district), 0, 100)
		district["rival_pressure"] = clampi(district["rival_pressure"] + _rival_drift(district_id), 0, 100)
		district["demand"] = clampi(district["demand"] + randi_range(-2, 2), 10, 90)

	_update_city_heat()
	_check_passive_events()
	_log_event("Day %d begins. The city keeps moving." % city_state["day"])
	_refresh_all()


func _on_crackdown_check_pressed() -> void:
	_update_city_heat()
	for district_id in districts.keys():
		var district: Dictionary = districts[district_id]
		if district["heat"] >= 65 and district["police_presence"] >= 55:
			_log_event("Police crackdown warning in %s. A raid system can hook into this later." % district["name"])
		elif district["rival_pressure"] >= 70:
			_log_event("Gang pressure is boiling over in %s. Future district combat will start here." % district["name"])
	_refresh_all()


func _on_enter_district_pressed() -> void:
	if active_district_view != null:
		return

	var district_view := DISTRICT_VIEW_SCENE.instantiate()
	district_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	district_view.call("setup", selected_district_id, districts[selected_district_id])
	district_view.connect("back_requested", Callable(self, "_on_district_view_back_requested"))
	if city_root_container != null:
		city_root_container.visible = false
	add_child(district_view)
	active_district_view = district_view
	_log_event("Entered the %s district layer." % districts[selected_district_id]["name"])


func _on_district_view_back_requested() -> void:
	if active_district_view == null:
		return

	active_district_view.queue_free()
	active_district_view = null
	if city_root_container != null:
		city_root_container.visible = true
	_log_event("Returned to the city overview.")


func _spawn_world_actors() -> void:
	if actor_layer == null:
		return

	for child in actor_layer.get_children():
		child.queue_free()
	world_actors.clear()

	_add_world_actor("ped", Vector2(400, 260), PackedVector2Array([Vector2(400, 260), Vector2(700, 260)]), 38.0, PEDESTRIAN_COLOR, Vector2(8, 8))
	_add_world_actor("ped", Vector2(520, 355), PackedVector2Array([Vector2(300, 355), Vector2(780, 355)]), 30.0, PEDESTRIAN_COLOR, Vector2(8, 8))
	_add_world_actor("ped", Vector2(325, 408), PackedVector2Array([Vector2(325, 408), Vector2(575, 408)]), 26.0, Color("bca27f"), Vector2(8, 8))
	_add_world_actor("ped", Vector2(760, 285), PackedVector2Array([Vector2(760, 160), Vector2(760, 305)]), 22.0, Color("e0d6c0"), Vector2(8, 8))
	_add_world_actor("car", Vector2(365, 263), PackedVector2Array([Vector2(365, 263), Vector2(715, 263)]), 72.0, CAR_COLOR, Vector2(18, 10))
	_add_world_actor("car", Vector2(715, 263), PackedVector2Array([Vector2(715, 263), Vector2(365, 263)]), 86.0, TAXI_COLOR, Vector2(18, 10))
	_add_world_actor("truck", Vector2(162, 145), PackedVector2Array([Vector2(162, 145), Vector2(348, 145)]), 48.0, Color("4d4b47"), Vector2(22, 12))
	_add_world_actor("car", Vector2(286, 355), PackedVector2Array([Vector2(286, 355), Vector2(792, 355)]), 60.0, Color("6f4033"), Vector2(18, 10))


func _add_world_actor(actor_type: String, start_position: Vector2, path: PackedVector2Array, speed: float, color: Color, size: Vector2) -> void:
	var sprite := ColorRect.new()
	sprite.position = start_position
	sprite.size = size
	sprite.color = color
	actor_layer.add_child(sprite)
	world_actors.append({
		"type": actor_type,
		"node": sprite,
		"path": path,
		"target_index": 1,
		"speed": speed,
		"size": size,
	})


func _process(delta: float) -> void:
	_update_world_actors(delta)


func _update_world_actors(delta: float) -> void:
	if world_actors.is_empty() or actor_layer == null or not city_root_container.visible:
		return

	for actor: Dictionary in world_actors:
		var node: ColorRect = actor["node"]
		var path: PackedVector2Array = actor["path"]
		var target_index: int = actor["target_index"]
		var actor_size: Vector2 = actor["size"]
		var speed: float = actor["speed"]
		var target: Vector2 = path[target_index]
		var current_center: Vector2 = node.position + (actor_size * 0.5)
		var to_target: Vector2 = target - current_center
		var distance: float = to_target.length()
		if distance <= speed * delta:
			current_center = target
			target_index = 0 if target_index == path.size() - 1 else target_index + 1
			actor["target_index"] = target_index
		else:
			current_center += to_target.normalized() * speed * delta

		node.position = current_center - (actor_size * 0.5)


func _heat_drift(district_id: String) -> int:
	match district_id:
		"industrial":
			return 1
		"residential":
			return 0
		"slums":
			return -1
	return 0


func _police_drift(district: Dictionary) -> int:
	if district["heat"] >= 60:
		return 3
	if district["heat"] >= 35:
		return 1
	return -1


func _rival_drift(district_id: String) -> int:
	match district_id:
		"slums":
			return 2
		"industrial":
			return 1
		_:
			return 0


func _check_passive_events() -> void:
	var industrial: Dictionary = districts["industrial"]
	var residential: Dictionary = districts["residential"]
	var slums: Dictionary = districts["slums"]

	if industrial["heat"] >= 50:
		_log_event("Industrial smoke, trucks, and whispers are drawing more city attention.")
	if residential["demand"] >= 75:
		_log_event("Residential demand is peaking. A stronger sales network would pay off here.")
	if slums["rival_pressure"] >= 75:
		_log_event("The Slums are turning volatile. Rival gangs are close to open conflict.")


func _update_city_heat() -> void:
	var total_heat := 0
	for district in districts.values():
		total_heat += district["heat"]
	city_state["city_heat"] = int(round(total_heat / float(districts.size())))


func _log_event(message: String) -> void:
	if event_log == null:
		return
	event_log.append_text("[color=#d6c7ab]- %s[/color]\n" % message)
