extends Control

signal back_requested

const TILE_SIZE := Vector2(48, 48)
const GRID_COLUMNS := 12
const GRID_ROWS := 8

var district_id: String = ""
var district_data: Dictionary = {}

var title_label: Label
var subtitle_label: Label
var stats_label: RichTextLabel
var lots_label: RichTextLabel
var grid_container: GridContainer


func setup(new_district_id: String, new_district_data: Dictionary) -> void:
	district_id = new_district_id
	district_data = new_district_data.duplicate(true)


func _ready() -> void:
	_build_ui()
	_refresh_view()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.color = Color("15120f")
	add_child(background)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 18)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(360, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_panel)

	var left_content := VBoxContainer.new()
	left_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_content.add_theme_constant_override("separation", 12)
	left_panel.add_child(left_content)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	left_content.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.modulate = Color("d0c3ab")
	left_content.add_child(subtitle_label)

	stats_label = RichTextLabel.new()
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	stats_label.scroll_active = false
	left_content.add_child(stats_label)

	var lot_title := Label.new()
	lot_title.text = "Planned Lots"
	lot_title.add_theme_font_size_override("font_size", 18)
	left_content.add_child(lot_title)

	lots_label = RichTextLabel.new()
	lots_label.bbcode_enabled = true
	lots_label.fit_content = true
	lots_label.scroll_active = false
	left_content.add_child(lots_label)

	var back_button := Button.new()
	back_button.text = "Back To City"
	back_button.custom_minimum_size = Vector2(0, 46)
	back_button.pressed.connect(_on_back_pressed)
	left_content.add_child(back_button)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_panel)

	var right_content := VBoxContainer.new()
	right_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_content.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_content)

	var board_title := Label.new()
	board_title.text = "District Layer Preview"
	board_title.add_theme_font_size_override("font_size", 22)
	right_content.add_child(board_title)

	var board_hint := Label.new()
	board_hint.text = "Tile-based lots, roads, and operations preview."
	board_hint.modulate = Color("c9b894")
	right_content.add_child(board_hint)

	var grid_panel := PanelContainer.new()
	grid_panel.custom_minimum_size = Vector2(620, 430)
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_content.add_child(grid_panel)

	grid_container = GridContainer.new()
	grid_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid_container.columns = GRID_COLUMNS
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	grid_panel.add_child(grid_container)


func _refresh_view() -> void:
	if district_data.is_empty():
		return

	title_label.text = "%s District" % district_data["name"]
	subtitle_label.text = "%s. This preview shows how the district layer can feel before full building gameplay exists." % district_data["role"]
	stats_label.text = (
		"[b]Heat:[/b] %d\n"
		+ "[b]Police Presence:[/b] %d\n"
		+ "[b]Demand:[/b] %d\n"
		+ "[b]Rival Pressure:[/b] %d\n"
		+ "[b]Player Control:[/b] %d"
	) % [
		district_data["heat"],
		district_data["police_presence"],
		district_data["demand"],
		district_data["rival_pressure"],
		district_data["player_control"],
	]
	lots_label.text = _build_lots_text()
	_build_grid()


func _build_lots_text() -> String:
	var lots: PackedStringArray = _get_lot_descriptions()
	var lines: Array[String] = []
	for lot in lots:
		lines.append("- %s" % lot)
	return "\n".join(lines)


func _build_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()

	var map_rows: Array[String] = _get_map_rows()
	var palette: Dictionary = _get_tile_palette()
	for row in map_rows:
		for x in range(row.length()):
			var key := row.substr(x, 1)
			var tile := PanelContainer.new()
			tile.custom_minimum_size = TILE_SIZE
			var color_rect := ColorRect.new()
			color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			color_rect.color = palette.get(key, Color("2d2924"))
			color_rect.custom_minimum_size = TILE_SIZE
			tile.add_child(color_rect)

			var label := Label.new()
			label.text = _get_tile_label(key)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 9)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.add_child(label)

			grid_container.add_child(tile)


func _get_map_rows() -> Array[String]:
	match district_id:
		"industrial":
			return [
				"TTTTWWBBBBRR",
				"TTTTWWBBBBRR",
				"YYYYWWLLLLRR",
				"YYYYWWLLLLRR",
				"....WW....RR",
				"SSSSWWCCCCRR",
				"SSSSWWCCCCRR",
				"....WW....RR",
			]
		"residential":
			return [
				"HHHH==SSSSPP",
				"HHHH==SSSSPP",
				"HHHH==BBBBPP",
				"HHHH==BBBBPP",
				"....==....PP",
				"FFFF==CCCCPP",
				"FFFF==CCCCPP",
				"....==....PP",
			]
		"slums":
			return [
				"TTAA~~HHCC..",
				"TTAA~~HHCC..",
				"SSAA~~GGCC..",
				"SSAA~~GGCC..",
				"..~~..~~..RR",
				"BB~~TT~~KKRR",
				"BB~~TT~~KKRR",
				"..~~..~~..RR",
			]
	return []


func _get_tile_palette() -> Dictionary:
	match district_id:
		"industrial":
			return {
				"T": Color("5b554e"),
				"W": Color("7e5a34"),
				"B": Color("8a6b45"),
				"R": Color("47433d"),
				"Y": Color("6a6156"),
				"L": Color("9a7b4f"),
				".": Color("2f2a25"),
				"S": Color("66594a"),
				"C": Color("7b6d5d"),
			}
		"residential":
			return {
				"H": Color("826246"),
				"=": Color("6d5b44"),
				"S": Color("94724d"),
				"P": Color("546244"),
				"B": Color("7f4c33"),
				".": Color("3d342c"),
				"F": Color("58613d"),
				"C": Color("6f533e"),
			}
		"slums":
			return {
				"T": Color("5c4936"),
				"A": Color("46372a"),
				"~": Color("3f4d47"),
				"H": Color("77614a"),
				"C": Color("5f5348"),
				".": Color("342a23"),
				"S": Color("6c533d"),
				"G": Color("6f4535"),
				"R": Color("4a433b"),
				"B": Color("50392d"),
				"K": Color("6a5f54"),
			}
	return {}


func _get_tile_label(tile_key: String) -> String:
	match district_id:
		"industrial":
			match tile_key:
				"T":
					return "Tracks"
				"W":
					return "Road"
				"B":
					return "Warehouse"
				"R":
					return "Rail"
				"Y":
					return "Yard"
				"L":
					return "Lab"
				"S":
					return "Storage"
				"C":
					return "Crates"
				_:
					return ""
		"residential":
			match tile_key:
				"H":
					return "Homes"
				"=":
					return "Street"
				"S":
					return "Shops"
				"P":
					return "Park"
				"B":
					return "Bar"
				"F":
					return "Front"
				"C":
					return "Club"
				_:
					return ""
		"slums":
			match tile_key:
				"T":
					return "Tenement"
				"A":
					return "Alley"
				"~":
					return "Backway"
				"H":
					return "Hideout"
				"C":
					return "Crowd"
				"S":
					return "Shacks"
				"G":
					return "Gang"
				"R":
					return "Road"
				"B":
					return "Basement"
				"K":
					return "Scrapyard"
				_:
					return ""
	return ""


func _get_lot_descriptions() -> PackedStringArray:
	match district_id:
		"industrial":
			return PackedStringArray([
				"Warehouse row for bulk goods and contraband storage",
				"Workshop lab lot for early production chains",
				"Rail and loading yard for future transport gameplay",
				"Storage block for hidden stockpiles and logistics",
			])
		"residential":
			return PackedStringArray([
				"Corner shops for sales fronts and passive cash flow",
				"Bar district for influence, meetings, and recruitment",
				"Club lots for social control and future laundering",
				"Residential blocks where complaints can raise heat",
			])
		"slums":
			return PackedStringArray([
				"Tenements for footholds and passive recruitment",
				"Alleys and backways for hidden movement and stash routes",
				"Gang blocks for future conflict and intimidation gameplay",
				"Basement and scrapyard lots for secret operations",
			])
	return PackedStringArray()


func _on_back_pressed() -> void:
	back_requested.emit()
