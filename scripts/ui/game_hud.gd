class_name GameHud
extends Control

## Presentation-only HUD. It never mutates run state; it emits intents that
## the controller validates (locally for the host, via RPC for clients).

signal tower_palette_selected(definition_id: String)
signal launch_requested
signal ready_requested
signal upgrade_requested(tower_id: int)
signal sell_requested(tower_id: int)
signal targeting_requested(tower_id: int, mode: int)
signal offer_chosen(upgrade_id: String)
signal return_requested
signal selection_cleared

const RunStateModel = preload("res://scripts/game/run_state.gd")
const COLOR_OK := Color("8ed8c6")
const COLOR_WARN := Color("ffb27a")
const COLOR_ERROR := Color("ff8d72")
const COLOR_MUTED := Color("92a09d")
const TOAST_DURATION := 3.5
const MESSAGE_DURATION := 2.5
## WC3 command-card grid hotkeys, row by row (QWER / ASDF / ZXCV).
const CARD_KEYS: Array[Key] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]
const CARD_SLOT_SIZE := Vector2(66, 44)
const SLOT_UPGRADE := 0
const SLOT_FIRST_TARGETING := 4
const SLOT_SELL := 10
const SLOT_CANCEL := 11
## Card-sized names for TowerTargeting.Mode (FIRST, LAST, STRONGEST, NEAREST).
const TARGETING_SHORT_NAMES: Array[String] = ["First", "Last", "Strong", "Near"]

var _catalog: ContentCatalog
var _card_slots: Array[Button] = []
var _card_actions: Array[Callable] = []
## Inputs the card was last built from; rebuilding restyles 12 buttons and
## re-shapes their text, so it is skipped when nothing visible changed.
var _card_signature := ""
var _selected_definition_id := ""
var _shown_tower_id := 0
var _gold := 0
var _modifiers: RunModifiers
## Selected-tower state shown on the command card.
var _tower_definition: TowerDefinition
var _tower_tier := 0
var _tower_targeting := 0
var _tower_can_control := false
var _upgrade_cost := -1
var _sell_value := 0
## Creep inspection (click a creep); its panel refreshes from the controller.
var _creep_definition: CreepDefinition
## 3D portrait: the selected unit's model rendered in its own small world.
var _portrait_viewport: SubViewport
var _portrait_holder: Node3D
var _portrait_camera: Camera3D
var _portrait_scene: PackedScene
var _multiboard_toggle: Button
var _multiboard_collapsed := false
var _toast_timer := 0.0
var _message_timer := 0.0
var _end_screen_shown := false
var _offer_ids: Array[String] = []

@onready var phase_label: Label = %PhaseLabel
@onready var wave_label: Label = %WaveLabel
@onready var lives_label: Label = %LivesLabel
@onready var gold_label: Label = %GoldLabel
@onready var active_label: Label = %ActiveLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var launch_button: Button = %LaunchButton
@onready var ready_button: Button = %ReadyButton
@onready var settings_button: Button = %SettingsButton
@onready var position_label: Label = %PositionLabel
@onready var top_bar: PanelContainer = %TopBar
@onready var console: PanelContainer = %Console
@onready var command_card: GridContainer = %CommandCard
@onready var minimap: Minimap = %Minimap
@onready var portrait: ColorRect = %Portrait
@onready var portrait_glyph: Label = %PortraitGlyph
@onready var idle_info: VBoxContainer = %IdleInfo
@onready var palette_description: Label = %PaletteDescription
@onready var placement_hint: Label = %PlacementHint
@onready var tower_panel: VBoxContainer = %TowerPanel
@onready var tower_name: Label = %TowerName
@onready var tower_stats: Label = %TowerStats
@onready var wave_heading: Label = %WaveHeading
@onready var wave_preview: Label = %WavePreview
@onready var positions_list: VBoxContainer = %PositionsList
@onready var modifiers_list: Label = %ModifiersList
@onready var seed_label: Label = %SeedLabel
@onready var return_button: Button = %ReturnButton
@onready var toast_label: Label = %ToastLabel
@onready var offer_overlay: Control = %OfferOverlay
@onready var offer_subtitle: Label = %OfferSubtitle
@onready var offer_cards: HBoxContainer = %OfferCards
@onready var end_overlay: Control = %EndOverlay
@onready var end_title: Label = %EndTitle
@onready var end_summary: Label = %EndSummary
@onready var end_return_button: Button = %EndReturnButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider
@onready var edge_pan_check: CheckButton = %EdgePanCheck
@onready var shadows_check: CheckButton = %ShadowsCheck
@onready var show_controls_button: Button = %ShowControlsButton
@onready var close_settings_button: Button = %CloseSettingsButton
@onready var controls_overlay: Control = %ControlsOverlay
@onready var dismiss_controls_button: Button = %DismissControlsButton


func _ready() -> void:
	theme = WC3Theme.build()
	top_bar.add_theme_stylebox_override("panel", WC3Theme.bar_style())
	console.add_theme_stylebox_override("panel", WC3Theme.bar_style())
	_build_command_card()
	_build_portrait_view()
	_build_multiboard_toggle()
	launch_button.pressed.connect(func() -> void: launch_requested.emit())
	ready_button.pressed.connect(func() -> void: ready_requested.emit())
	settings_button.pressed.connect(toggle_settings)
	return_button.pressed.connect(func() -> void: return_requested.emit())
	end_return_button.pressed.connect(func() -> void: return_requested.emit())
	close_settings_button.pressed.connect(func() -> void: settings_overlay.visible = false)
	show_controls_button.pressed.connect(func() -> void:
		settings_overlay.visible = false
		show_controls_overlay())
	dismiss_controls_button.pressed.connect(func() -> void:
		controls_overlay.visible = false
		GameSettings.mark_controls_seen())
	master_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("master", value))
	music_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("music", value))
	effects_slider.value_changed.connect(func(value: float) -> void: GameSettings.set_volume("effects", value))
	edge_pan_check.toggled.connect(func(pressed: bool) -> void: GameSettings.set_edge_pan(pressed))
	shadows_check.toggled.connect(func(pressed: bool) -> void: GameSettings.set_shadows(pressed))
	tower_panel.visible = false
	offer_overlay.visible = false
	end_overlay.visible = false
	settings_overlay.visible = false
	controls_overlay.visible = false
	toast_label.visible = false
	placement_hint.text = ""
	_build_position_rows()


func setup(catalog: ContentCatalog) -> void:
	_catalog = catalog
	_refresh_card()
	palette_description.text = "Pick a tower from the command card, then click inside your position."


func attach_minimap(map: WintermaulMap, camera: BattlefieldCamera) -> void:
	minimap.attach(map, camera)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			placement_hint.text = ""


# --- State display ------------------------------------------------------------

func update_state(snapshot: Dictionary, context: Dictionary) -> void:
	var phase: int = snapshot["phase"]
	var wave: WaveDefinition = context["wave"]
	var modifiers: RunModifiers = context["modifiers"]
	var is_host: bool = context["is_host"]
	var waiting_for: int = int(snapshot.get("waiting_for", 0))
	var wave_index: int = int(snapshot["wave_index"])
	var has_offer := not (snapshot.get("offer", []) as Array).is_empty()
	var wave_one_ready_pressed: bool = bool(context.get("wave_one_ready_pressed", false))

	phase_label.text = _phase_name(phase)
	wave_label.text = "WAVE  %s / %s" % [snapshot["wave_index"] + 1, snapshot["wave_count"]]
	lives_label.text = "LIVES  %s" % snapshot["lives"]
	gold_label.text = "GOLD  %s" % snapshot["gold"]
	active_label.text = "CREEPS  %s    TOWERS  %s" % [snapshot["active_count"], snapshot.get("tower_count", 0)]
	if phase == RunStateModel.Phase.BUILD:
		if waiting_for > 0:
			countdown_label.text = "Waiting for %d player(s) to load" % waiting_for
		elif has_offer:
			countdown_label.text = "Choose a team upgrade"
		elif wave_index == 0:
			countdown_label.text = "Ready check %d/%d  ·  auto-start in %.0fs" % [int(snapshot.get("wave_one_ready", 0)), int(snapshot.get("wave_one_total", 0)), float(snapshot["countdown"])]
		else:
			countdown_label.text = "Next wave in %.1fs" % float(snapshot["countdown"])
	elif phase == RunStateModel.Phase.WAVE:
		countdown_label.text = "%s  ·  all nine positions active" % wave.title
	else:
		countdown_label.text = "Run over"
	launch_button.visible = phase == RunStateModel.Phase.BUILD
	launch_button.disabled = not is_host or waiting_for > 0 or has_offer
	ready_button.visible = phase == RunStateModel.Phase.BUILD and wave_index == 0 and waiting_for == 0 and not has_offer
	ready_button.disabled = wave_one_ready_pressed
	ready_button.text = "Ready ✓" if wave_one_ready_pressed else "Ready Up"
	return_button.visible = phase in [RunStateModel.Phase.VICTORY, RunStateModel.Phase.DEFEAT]

	var controllable: Array[int] = context["controllable"]
	var owners: PackedInt32Array = snapshot.get("owners", PackedInt32Array())
	position_label.text = _position_summary(controllable, owners, is_host)

	_selected_definition_id = str(context.get("selected_definition", ""))
	_gold = snapshot["gold"]
	_modifiers = modifiers
	_refresh_card()
	if not _selected_definition_id.is_empty():
		var selected := _catalog.get_tower(_selected_definition_id)
		var stats := modifiers.modify_stats(selected.stats_for_tier(0), selected.id)
		palette_description.text = "%s  ·  %s\n%s\nDamage %d   Range %.0f   Cooldown %.2fs%s%s" % [
			selected.display_name,
			selected.role,
			selected.description,
			stats["damage"],
			stats["range"],
			stats["cooldown"],
			"   Splash %.0f" % stats["splash_radius"] if float(stats["splash_radius"]) > 0.0 else "",
			"   Slow %d%%" % roundi(float(stats["slow_factor"]) * 100.0) if float(stats["slow_factor"]) > 0.0 else "",
		]
	else:
		palette_description.text = "Pick a tower from the command card, then click inside your position. Click a placed tower to inspect it."

	_update_wave_preview(phase, wave, snapshot)
	_update_position_rows(snapshot, owners, context)

	var lines := modifiers.summary_lines()
	modifiers_list.text = "\n".join(PackedStringArray(lines)) if not lines.is_empty() else "None yet. Offers appear after selected waves."
	seed_label.text = "SEED  %s    PLAYERS  %s" % [snapshot.get("seed", 0), snapshot.get("player_count", 1)]


func _position_summary(controllable: Array[int], owners: PackedInt32Array, is_host: bool) -> String:
	if controllable.size() >= owners.size() and owners.size() > 0:
		return "YOU CONTROL ALL NINE POSITIONS"
	var numbers := PackedStringArray()
	for position_index in controllable:
		numbers.append(str(position_index + 1))
	if numbers.is_empty():
		return "SPECTATING  ·  NO POSITION ASSIGNED"
	var text := "YOU CONTROL POSITION%s %s" % ["S" if numbers.size() > 1 else "", ", ".join(numbers)]
	if is_host:
		text += "  (HOST)"
	return text


func _update_wave_preview(phase: int, wave: WaveDefinition, snapshot: Dictionary) -> void:
	var heading := "NEXT WAVE %d  ·  %s" % [wave.number, wave.title.to_upper()] if phase == RunStateModel.Phase.BUILD else "WAVE %d  ·  %s" % [wave.number, wave.title.to_upper()]
	if wave.has_boss():
		heading += "  ·  BOSS"
	wave_heading.text = heading
	wave_heading.add_theme_color_override("font_color", COLOR_ERROR if wave.has_boss() else COLOR_OK)
	var lines := wave.preview_lines()
	var queued_total := 0
	for queued in snapshot.get("queued", PackedInt32Array()):
		queued_total += queued
	var text := "\n".join(PackedStringArray(lines))
	text += "\nPer position, scaled by team size. Top row positions receive double waves."
	if phase == RunStateModel.Phase.WAVE:
		text += "\nQueued %d  ·  Active %d" % [queued_total, snapshot["active_count"]]
	wave_preview.text = text


func _build_position_rows() -> void:
	for child in positions_list.get_children():
		child.queue_free()
	for position_index in range(ClassicWintermaulLayout.PLAYER_COUNT):
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", ClassicWintermaulLayout.PLAYER_COLORS[position_index].lightened(0.18))
		row.text = "P%d" % (position_index + 1)
		positions_list.add_child(row)


func _update_position_rows(snapshot: Dictionary, owners: PackedInt32Array, context: Dictionary) -> void:
	var queued: PackedInt32Array = snapshot["queued"]
	var spawned: PackedInt32Array = snapshot["spawned"]
	var local_peer: int = context["local_peer"]
	var names: Dictionary = context.get("owner_names", {})
	for position_index in range(mini(ClassicWintermaulLayout.PLAYER_COUNT, positions_list.get_child_count())):
		var row := positions_list.get_child(position_index) as Label
		var owner := owners[position_index] if position_index < owners.size() else 0
		var owner_text := "HOST"
		if owner == local_peer and owner != 0:
			owner_text = "YOU"
		elif owner != 0 and owner != BuildPermissionPolicy.HOST_PEER_ID:
			owner_text = str(names.get(owner, "ALLY"))
		row.text = "P%d  %-6s  SPAWNED %02d  QUEUED %02d" % [position_index + 1, owner_text, spawned[position_index], queued[position_index]]


func _phase_name(phase: int) -> String:
	match phase:
		RunStateModel.Phase.BUILD:
			return "BUILD PHASE"
		RunStateModel.Phase.WAVE:
			return "WAVE ACTIVE"
		RunStateModel.Phase.VICTORY:
			return "VICTORY"
		RunStateModel.Phase.DEFEAT:
			return "DEFEAT"
	return "UNKNOWN"


# --- Palette and tower panel --------------------------------------------------

func _on_palette_button_pressed(definition_id: String) -> void:
	if _selected_definition_id == definition_id:
		_selected_definition_id = ""
	else:
		_selected_definition_id = definition_id
	tower_palette_selected.emit(_selected_definition_id)


func show_tower(record: Dictionary, definition: TowerDefinition, stats: Dictionary, upgrade_cost: int, sell_value: int, can_control: bool, gold: int) -> void:
	_shown_tower_id = int(record["id"])
	_tower_definition = definition
	_tower_tier = int(record["tier"])
	_tower_targeting = int(record["targeting"])
	_tower_can_control = can_control
	_upgrade_cost = upgrade_cost
	_sell_value = sell_value
	_gold = gold
	_creep_definition = null
	tower_panel.visible = true
	idle_info.visible = false
	_set_portrait(definition.display_name, definition.primary_color, definition.accent_color, definition.visual_scene_for_tier(_tower_tier), &"idle")
	tower_name.text = "%s  ·  %s  ·  P%d" % [definition.display_name, definition.tier_name(_tower_tier), int(record["position"]) + 1]
	var lines := PackedStringArray([
		"Damage %d    Range %.0f    Cooldown %.2fs" % [stats["damage"], stats["range"], stats["cooldown"]],
	])
	if float(stats.get("splash_radius", 0.0)) > 0.0:
		lines.append("Splash radius %.0f" % stats["splash_radius"])
	if float(stats.get("slow_factor", 0.0)) > 0.0:
		lines.append("Slow %d%% for %.1fs" % [roundi(float(stats["slow_factor"]) * 100.0), stats["slow_duration"]])
	if int(stats.get("armor_pierce", 0)) > 0:
		lines.append("Armor pierce %d" % stats["armor_pierce"])
	lines.append("Target: %s    Invested %d g" % [TowerTargeting.mode_name(_tower_targeting), definition.total_invested(_tower_tier)])
	tower_stats.text = "\n".join(lines)
	_refresh_card()
	if not can_control:
		placement_hint.text = "This tower belongs to another position."
		placement_hint.add_theme_color_override("font_color", COLOR_WARN)
		_message_timer = MESSAGE_DURATION


func hide_tower() -> void:
	if _shown_tower_id == 0 and _creep_definition == null and not tower_panel.visible:
		return
	_shown_tower_id = 0
	_tower_definition = null
	_creep_definition = null
	tower_panel.visible = false
	idle_info.visible = true
	_set_portrait("", WC3Theme.STONE, WC3Theme.MUTED)
	_refresh_card()


## Creep inspection panel, refreshed by the controller while selected.
func show_creep(definition: CreepDefinition, info: Dictionary) -> void:
	var first_show := _creep_definition != definition
	_shown_tower_id = 0
	_tower_definition = null
	_creep_definition = definition
	tower_panel.visible = true
	idle_info.visible = false
	if first_show:
		_set_portrait(definition.display_name, definition.color, definition.color.lightened(0.4), definition.visual_scene, &"walk")
	tower_name.text = "%s  ·  %s  ·  from P%d" % [definition.display_name, definition.role, int(info["position"]) + 1]
	var lines := PackedStringArray([
		"Health %d / %d    Armor %d    Speed %.1f tiles/s%s" % [info["health"], info["max_health"], definition.armor, float(info["speed"]), "  (slowed)" if info["slowed"] else ""],
		"Bounty %d gold%s" % [info["bounty"], "    %s" % definition.trait_summary() if not definition.trait_summary().is_empty() else ""],
		definition.description,
	])
	tower_stats.text = "\n".join(lines)
	_refresh_card()


func _set_portrait(title: String, primary: Color, accent: Color, scene: PackedScene = null, animation: StringName = &"") -> void:
	portrait.color = primary.darkened(0.55)
	portrait_glyph.text = title.substr(0, 1).to_upper() if not title.is_empty() else "?"
	portrait_glyph.add_theme_color_override("font_color", accent)
	_show_portrait_model(scene, animation)


## Small separate 3D world behind the portrait glyph; only draws while a
## model is shown.
func _build_portrait_view() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(container)
	_portrait_viewport = SubViewport.new()
	_portrait_viewport.own_world_3d = true
	_portrait_viewport.transparent_bg = true
	_portrait_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(_portrait_viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	light.light_energy = 1.3
	_portrait_viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
	environment.environment.ambient_light_energy = 0.6
	_portrait_viewport.add_child(environment)
	_portrait_camera = Camera3D.new()
	_portrait_camera.fov = 35.0
	_portrait_viewport.add_child(_portrait_camera)
	_portrait_holder = Node3D.new()
	_portrait_viewport.add_child(_portrait_holder)


func _show_portrait_model(scene: PackedScene, animation: StringName) -> void:
	if _portrait_viewport == null or scene == _portrait_scene:
		return
	_portrait_scene = scene
	for child in _portrait_holder.get_children():
		child.queue_free()
	var model := ActorModel.instantiate(scene)
	portrait_glyph.visible = model == null
	if model == null:
		_portrait_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_portrait_holder.add_child(model)
	ActorModel.play(model, animation, true)
	# Frame the model from the front (+Z) and slightly above, WC3-portrait style.
	var box := ActorModel.bounds(model)
	var center := box.get_center() + Vector3(0.0, box.size.y * 0.1, 0.0)
	var extent := maxf(box.size.y, maxf(box.size.x, box.size.z) * 0.8)
	_portrait_camera.position = center + Vector3(0.0, extent * 0.35, extent * 2.1)
	_portrait_camera.look_at(center, Vector3.UP)
	_portrait_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


## WC3 multiboards fold to their title bar; this one hides everything but
## the header when collapsed.
func _build_multiboard_toggle() -> void:
	var layout := position_label.get_parent()
	_multiboard_toggle = Button.new()
	_multiboard_toggle.text = "▾  Scoreboard"
	_multiboard_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_multiboard_toggle.focus_mode = Control.FOCUS_NONE
	_multiboard_toggle.flat = true
	_multiboard_toggle.pressed.connect(toggle_multiboard)
	layout.add_child(_multiboard_toggle)
	layout.move_child(_multiboard_toggle, 0)


func toggle_multiboard() -> void:
	_multiboard_collapsed = not _multiboard_collapsed
	_multiboard_toggle.text = ("▸  Scoreboard" if _multiboard_collapsed else "▾  Scoreboard")
	# The return button stays under update_state's control (shown after a run).
	for child in position_label.get_parent().get_children():
		if child != _multiboard_toggle and child != return_button and child is Control:
			(child as Control).visible = not _multiboard_collapsed


# --- Command card ---------------------------------------------------------------

func _build_command_card() -> void:
	for index in range(CARD_KEYS.size()):
		var button := Button.new()
		button.custom_minimum_size = CARD_SLOT_SIZE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 11)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_card_slot_pressed.bind(index))
		command_card.add_child(button)
		_card_slots.append(button)
		_card_actions.append(Callable())


func _clear_card() -> void:
	for index in range(_card_slots.size()):
		var button := _card_slots[index]
		button.text = ""
		button.tooltip_text = ""
		button.disabled = true
		button.toggle_mode = false
		button.set_pressed_no_signal(false)
		button.remove_theme_color_override("font_color")
		_card_actions[index] = Callable()


## Fills one slot; the grid position gives it its WC3 hotkey.
func _set_card_slot(index: int, label: String, tooltip: String, action: Callable, enabled := true, pressed := false, color := Color(0, 0, 0, 0)) -> void:
	var button := _card_slots[index]
	# Always two lines ("Q Upgrade" / "70g") so every slot, and the console,
	# keeps the same height.
	var lines := label.split("\n")
	button.text = "%s %s\n%s" % [OS.get_keycode_string(CARD_KEYS[index]), lines[0], lines[1] if lines.size() > 1 else ""]
	button.tooltip_text = "%s  [%s]" % [tooltip, OS.get_keycode_string(CARD_KEYS[index])]
	button.disabled = not enabled
	button.toggle_mode = pressed
	button.set_pressed_no_signal(pressed)
	if color.a > 0.0:
		button.add_theme_color_override("font_color", color)
	_card_actions[index] = action


func _refresh_card() -> void:
	if _card_slots.is_empty():
		return
	var signature := _card_state_signature()
	if signature == _card_signature:
		return
	_card_signature = signature
	_clear_card()
	if _shown_tower_id != 0 and _tower_definition != null:
		_fill_tower_card()
	elif _creep_definition != null:
		_set_card_slot(SLOT_CANCEL, "Cancel", "Deselect", func() -> void: selection_cleared.emit())
	elif _catalog != null:
		_fill_build_card()


func _card_state_signature() -> String:
	if _creep_definition != null and _shown_tower_id == 0:
		return "creep"
	if _shown_tower_id != 0 and _tower_definition != null:
		return "tower|%d|%d|%d|%s|%d|%d|%s" % [_shown_tower_id, _tower_tier, _tower_targeting, _tower_can_control, _upgrade_cost, _sell_value, _upgrade_cost >= 0 and _gold >= _upgrade_cost]
	if _catalog == null:
		return "empty"
	var parts := PackedStringArray(["build", _selected_definition_id])
	for definition in _catalog.towers:
		var cost := _modifiers.build_cost(definition.cost) if _modifiers else definition.cost
		parts.append("%d:%s" % [cost, _gold >= cost])
	return "|".join(parts)


func _fill_build_card() -> void:
	for index in range(mini(_catalog.towers.size(), SLOT_FIRST_TARGETING)):
		var definition: TowerDefinition = _catalog.towers[index]
		var cost := _modifiers.build_cost(definition.cost) if _modifiers else definition.cost
		var label := "%s\n%dg" % [definition.display_name.replace(" Tower", ""), cost]
		var tooltip := "%s  ·  %d gold\n%s\n%s" % [definition.display_name, cost, definition.role, definition.description]
		_set_card_slot(index, label, tooltip, _on_palette_button_pressed.bind(definition.id), _gold >= cost, definition.id == _selected_definition_id, definition.accent_color.lightened(0.25))
	if not _selected_definition_id.is_empty():
		_set_card_slot(SLOT_CANCEL, "Cancel", "Stop placing", _on_palette_button_pressed.bind(_selected_definition_id))


func _fill_tower_card() -> void:
	if _upgrade_cost >= 0:
		_set_card_slot(SLOT_UPGRADE, "Upgrade\n%dg" % _upgrade_cost, "Upgrade to %s for %d gold" % [_tower_definition.tier_name(_tower_tier + 1), _upgrade_cost],
			func() -> void: upgrade_requested.emit(_shown_tower_id), _tower_can_control and _gold >= _upgrade_cost)
	else:
		_set_card_slot(SLOT_UPGRADE, "Max\ntier", "This tower is fully upgraded", Callable(), false)
	for mode in range(mini(TowerTargeting.Mode.size(), 4)):
		_set_card_slot(SLOT_FIRST_TARGETING + mode, TARGETING_SHORT_NAMES[mode], "Target the %s creep in range" % TowerTargeting.mode_name(mode).to_lower(),
			func() -> void: targeting_requested.emit(_shown_tower_id, mode), _tower_can_control, mode == _tower_targeting)
	_set_card_slot(SLOT_SELL, "Sell\n%dg" % _sell_value, "Sell for %d gold (%d%% refund)" % [_sell_value, _tower_definition.sell_refund_percent],
		func() -> void: sell_requested.emit(_shown_tower_id), _tower_can_control)
	_set_card_slot(SLOT_CANCEL, "Cancel", "Deselect", func() -> void: selection_cleared.emit())


func _on_card_slot_pressed(index: int) -> void:
	var action := _card_actions[index]
	if action.is_valid():
		action.call()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F10:
		toggle_settings()
		get_viewport().set_input_as_handled()
		return
	var index := CARD_KEYS.find(event.keycode)
	if index >= 0 and not _card_slots[index].disabled and _card_actions[index].is_valid():
		_card_actions[index].call()
		get_viewport().set_input_as_handled()


func show_placement_message(text: String, is_error: bool) -> void:
	placement_hint.text = text
	placement_hint.add_theme_color_override("font_color", COLOR_ERROR if is_error else COLOR_OK)
	_message_timer = MESSAGE_DURATION


func show_toast(text: String, is_warning: bool) -> void:
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", COLOR_WARN if is_warning else COLOR_OK)
	toast_label.visible = true
	_toast_timer = TOAST_DURATION


# --- Overlays -----------------------------------------------------------------

func show_offer(upgrades: Array[RunUpgradeDefinition], can_choose: bool) -> void:
	var ids: Array[String] = []
	for upgrade in upgrades:
		ids.append(upgrade.id)
	if offer_overlay.visible and ids == _offer_ids:
		return
	_offer_ids = ids
	for child in offer_cards.get_children():
		child.queue_free()
	for upgrade in upgrades:
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 150)
		card.text = "%s\n[%s]\n\n%s" % [upgrade.display_name, upgrade.category_name(), upgrade.description]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.disabled = not can_choose
		card.pressed.connect(func() -> void: offer_chosen.emit(upgrade.id))
		offer_cards.add_child(card)
	offer_subtitle.text = "Pick one team upgrade. The wave timer is paused." if can_choose else "The host is choosing a team upgrade..."
	offer_overlay.visible = true


func hide_offer() -> void:
	if offer_overlay.visible:
		offer_overlay.visible = false
		_offer_ids.clear()


func show_end_screen(results: Dictionary, catalog: ContentCatalog) -> void:
	var victory := bool(results.get("victory", false))
	end_title.text = "VICTORY" if victory else "DEFEAT"
	end_title.add_theme_color_override("font_color", COLOR_OK if victory else COLOR_ERROR)
	var stats: Dictionary = results.get("stats", {})
	var duration := float(results.get("duration", 0.0))
	var upgrade_names := PackedStringArray()
	for upgrade_id in results.get("upgrades", []):
		var upgrade := catalog.get_upgrade(str(upgrade_id))
		upgrade_names.append(upgrade.display_name if upgrade else str(upgrade_id))
	end_summary.text = "\n".join(PackedStringArray([
		"Wave reached  %d / %d" % [results.get("wave_reached", 0), results.get("wave_count", 0)],
		"Duration  %02d:%02d" % [int(duration) / 60, int(duration) % 60],
		"Towers built / upgraded / sold  %d / %d / %d" % [stats.get("towers_built", 0), stats.get("towers_upgraded", 0), stats.get("towers_sold", 0)],
		"Kills  %d    Boss kills  %d    Leaks  %d" % [stats.get("kills", 0), stats.get("boss_kills", 0), stats.get("leaks", 0)],
		"Gold earned / spent  %d / %d" % [stats.get("gold_earned", 0), stats.get("gold_spent", 0)],
		"Lives remaining  %d" % results.get("lives", 0),
		"Seed  %s" % results.get("seed", 0),
		"Upgrades  %s" % (", ".join(upgrade_names) if not upgrade_names.is_empty() else "none"),
	]))
	if not _end_screen_shown:
		_end_screen_shown = true
		hide_offer()
		end_overlay.visible = true


func show_controls_overlay() -> void:
	controls_overlay.visible = true


func toggle_settings() -> void:
	settings_overlay.visible = not settings_overlay.visible
	if settings_overlay.visible:
		master_slider.set_value_no_signal(GameSettings.master_volume)
		music_slider.set_value_no_signal(GameSettings.music_volume)
		effects_slider.set_value_no_signal(GameSettings.effects_volume)
		edge_pan_check.set_pressed_no_signal(GameSettings.edge_pan_enabled)
		shadows_check.set_pressed_no_signal(GameSettings.shadows_enabled)


## Closes the top-most dismissible overlay. Returns true when one was closed.
func close_top_overlay() -> bool:
	if controls_overlay.visible:
		controls_overlay.visible = false
		GameSettings.mark_controls_seen()
		return true
	if settings_overlay.visible:
		settings_overlay.visible = false
		return true
	if not offer_overlay.visible and not end_overlay.visible and tower_panel.visible:
		selection_cleared.emit()
		return true
	return false
