class_name GameHud
extends Control

## Presentation-only HUD. It never mutates run state; it emits intents that
## the controller validates (locally for the host, via RPC for clients).

signal tower_palette_selected(definition_id: String)
signal launch_requested
signal ready_requested
signal upgrade_requested(tower_id: int, target_id: String)
signal sell_requested(tower_id: int)
signal targeting_requested(tower_id: int, mode: int)
signal offer_chosen(upgrade_id: String)
## Halfway choice: "relic" (race_id empty) or "race" with the recruited race.
signal midpoint_chosen(choice: String, race_id: String)
signal return_requested
signal selection_cleared
## WC3 Stop (S): clears the local builder's order queue.
signal builder_stop_requested
## Send `amount` of your gold to another player.
signal gold_send_requested(to_peer: int, amount: int)
## A chat line or slash command typed by the local player.
signal chat_submitted(text: String)

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
## Upgrade branches take the top row (Q W E), as many as the tree offers.
const SLOT_UPGRADE := 0
const MAX_UPGRADE_OPTIONS := 3
## Build card: the race's towers fill every slot but Stop (S) and Cancel (V).
const BUILD_SLOTS: Array[int] = [0, 1, 2, 3, 4, 6, 7, 8, 9, 10]
const SLOT_FIRST_TARGETING := 4
const SLOT_SELL := 10
## Row two, column two: the S hotkey, where WC3 puts Stop.
const SLOT_STOP := 5
const SLOT_CANCEL := 11
## Card-sized names for TowerTargeting.Mode (FIRST, LAST, STRONGEST, NEAREST).
const TARGETING_SHORT_NAMES: Array[String] = ["First", "Last", "Strong", "Near"]
## Quick amounts on the multiboard's Send Gold buttons.
const SEND_GOLD_AMOUNTS: Array[int] = [25, 100]
const SYSTEM_COLOR := Color("f0d868")
## Chat lines fade after this long unless the chat box is open.
const CHAT_LINE_SECONDS := 12.0
const CHAT_VISIBLE_LINES := 8
const CHAT_HISTORY := 60
## The console is 176 px tall; the chat log sits just above it.
const CHAT_BOTTOM_OFFSET := -186.0

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
## The local player's race: its towers fill the build card.
var _race: RaceDefinition
## Second race recruited at the halfway point (null until then).
var _bonus_race: RaceDefinition
var _relics := 0
var _midpoint_overlay: Control
var _midpoint_cards: HBoxContainer
var _midpoint_signature := ""
## [{definition: TowerDefinition, cost: int}] upgrade branches of the shown tower
var _tower_options: Array[Dictionary] = []
var _tower_targeting := 0
var _tower_can_control := false
var _sell_value := 0
var _tower_building := false
var _tower_upgrading := false
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
## Multiboard player rows (name, gold, Send Gold buttons), rebuilt only when
## a balance or name changes.
var _players_list: VBoxContainer
var _players_signature := ""
## Chat: [{text (BBCode), plain, time}] oldest first.
var _chat_lines: Array[Dictionary] = []
var _chat_log: VBoxContainer
var _chat_input: LineEdit
var _chat_refresh_timer := 0.0
## The System's broadcast banner over the battlefield (the announcer).
var _announcer_banner: SystemLowerThird
## End screen: one row per award (RunAwards), rebuilt when they change.
var _awards_box: VBoxContainer
var _awards_signature := ""

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
	_build_midpoint_overlay()
	end_overlay.visible = false
	settings_overlay.visible = false
	controls_overlay.visible = false
	toast_label.visible = false
	placement_hint.text = ""
	_build_position_rows()
	_build_players_list()
	_build_chat()
	_build_announcer_banner()


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
	_chat_refresh_timer -= delta
	if _chat_refresh_timer <= 0.0:
		_chat_refresh_timer = 0.5
		_refresh_chat()


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
	gold_label.text = "GOLD  %s" % int(context.get("gold", 0))
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
	_race = context.get("race") as RaceDefinition
	_bonus_race = context.get("bonus_race") as RaceDefinition
	_relics = int(context.get("relics", 0))
	_gold = int(context.get("gold", 0))
	_modifiers = modifiers
	_refresh_card()
	if not _selected_definition_id.is_empty():
		var selected := _catalog.get_tower(_selected_definition_id)
		var stats := modifiers.modify_stats(selected.stats(), _catalog.line_of(selected.id))
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
	_update_player_rows(snapshot, context)

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
			owner_text = str(names.get(owner, "Player %d" % owner))
		row.text = "P%d  %-6s  SPAWNED %02d  QUEUED %02d" % [position_index + 1, owner_text, spawned[position_index], queued[position_index]]


## A GOLD section under the position rows: every player's balance, with
## Send Gold buttons on your teammates' rows.
func _build_players_list() -> void:
	var heading := Label.new()
	heading.text = "PLAYER GOLD"
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override("font_color", Color(0.616, 0.584, 0.51))
	_players_list = VBoxContainer.new()
	_players_list.add_theme_constant_override("separation", 1)
	var layout := positions_list.get_parent()
	layout.add_child(heading)
	layout.move_child(heading, positions_list.get_index() + 1)
	layout.add_child(_players_list)
	layout.move_child(_players_list, heading.get_index() + 1)


func _update_player_rows(snapshot: Dictionary, context: Dictionary) -> void:
	var gold: Dictionary = snapshot.get("gold", {})
	var names: Dictionary = context.get("owner_names", {})
	var local_peer: int = context["local_peer"]
	var peers: Array = gold.keys()
	peers.sort()
	var ended := int(snapshot["phase"]) in [RunStateModel.Phase.VICTORY, RunStateModel.Phase.DEFEAT]
	var signature := "%s|%s|%s|%s" % [gold, names, local_peer, ended]
	if signature == _players_signature:
		return
	_players_signature = signature
	for child in _players_list.get_children():
		child.queue_free()
	for peer_id in peers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := "YOU" if int(peer_id) == local_peer else str(names.get(int(peer_id), "Host" if int(peer_id) == BuildPermissionPolicy.HOST_PEER_ID else "Player %d" % int(peer_id)))
		label.text = "%-10s %5dg" % [name.left(10), int(gold[peer_id])]
		label.add_theme_color_override("font_color", Color("f0d868") if int(peer_id) == local_peer else Color("d5e2dd"))
		row.add_child(label)
		if int(peer_id) != local_peer and not ended:
			for amount in SEND_GOLD_AMOUNTS:
				var send := Button.new()
				send.text = "+%d" % amount
				send.tooltip_text = "Send %d of your gold to %s" % [amount, name]
				send.add_theme_font_size_override("font_size", 10)
				send.custom_minimum_size = Vector2(34, 18)
				send.focus_mode = Control.FOCUS_NONE
				send.disabled = _gold < amount
				send.pressed.connect(func() -> void: gold_send_requested.emit(int(peer_id), amount))
				row.add_child(send)
		_players_list.add_child(row)


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


## `options` are the tower's upgrade branches: [{definition, cost}].
func show_tower(record: Dictionary, definition: TowerDefinition, stats: Dictionary, options: Array[Dictionary], sell_value: int, can_control: bool, gold: int) -> void:
	_shown_tower_id = int(record["id"])
	_tower_definition = definition
	_tower_targeting = int(record["targeting"])
	_tower_can_control = can_control
	_tower_options = options
	_sell_value = sell_value
	_tower_building = float(record.get("build_remaining", 0.0)) > 0.0
	_tower_upgrading = float(record.get("upgrade_remaining", 0.0)) > 0.0
	_gold = gold
	_creep_definition = null
	tower_panel.visible = true
	idle_info.visible = false
	_set_portrait(definition.display_name, definition.primary_color, definition.accent_color, definition.visual_scene, &"idle")
	tower_name.text = "%s  ·  Tier %d  ·  P%d" % [definition.display_name, definition.tier, int(record["position"]) + 1]
	var lines := PackedStringArray([
		"Damage %d    Range %.0f    Cooldown %.2fs" % [stats["damage"], stats["range"], stats["cooldown"]],
	])
	if float(stats.get("splash_radius", 0.0)) > 0.0:
		lines.append("Splash radius %.0f" % stats["splash_radius"])
	if float(stats.get("slow_factor", 0.0)) > 0.0:
		lines.append("Slow %d%% for %.1fs" % [roundi(float(stats["slow_factor"]) * 100.0), stats["slow_duration"]])
	if int(stats.get("armor_pierce", 0)) > 0:
		lines.append("Armor pierce %d" % stats["armor_pierce"])
	var traits := PackedStringArray()
	if not bool(stats.get("targets_air", true)):
		traits.append("Ground only")
	elif not bool(stats.get("targets_ground", true)):
		traits.append("Air only")
	if bool(stats.get("magic", false)):
		traits.append("Magic (no effect on magic immune)")
	if float(stats.get("detection_range", 0.0)) > 0.0:
		traits.append("Detects invisible within %.0f" % stats["detection_range"])
	if not traits.is_empty():
		lines.append("  ·  ".join(traits))
	lines.append("Target: %s    Invested %d g" % [TowerTargeting.mode_name(_tower_targeting), int(record.get("invested", 0))])
	if _tower_building:
		lines.insert(0, "Under construction  ·  %d%%" % roundi(100.0 * (1.0 - float(record["build_remaining"]) / maxf(float(record.get("build_total", 1.0)), 0.01))))
	elif _tower_upgrading:
		var target := _catalog.get_tower(str(record.get("upgrade_to", "")))
		lines.insert(0, "Upgrading to %s  ·  %d%%" % [target.display_name if target else "?", roundi(100.0 * (1.0 - float(record["upgrade_remaining"]) / maxf(float(record.get("upgrade_total", 1.0)), 0.01)))])
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
		var option_parts := PackedStringArray()
		for option in _tower_options:
			option_parts.append("%s:%d:%s" % [(option["definition"] as TowerDefinition).id, option["cost"], _gold >= int(option["cost"])])
		return "tower|%d|%s|%d|%s|%s|%d|%s|%s" % [_shown_tower_id, _tower_definition.id, _tower_targeting, _tower_can_control, ",".join(option_parts), _sell_value, _tower_building, _tower_upgrading]
	if _catalog == null:
		return "empty"
	var parts := PackedStringArray(["build", _selected_definition_id, _race.id if _race else "", _bonus_race.id if _bonus_race else "", str(_relics)])
	for definition in _build_roster():
		var cost := _modifiers.build_cost(definition.cost) if _modifiers else definition.cost
		parts.append("%d:%s" % [cost, _gold >= cost])
	return "|".join(parts)


## Towers the local builder can build: its race's roots.
## Towers the local builder can build: its race's roots, then the recruited
## race's, then the race ultimate (which needs a Relic).
func _build_roster() -> Array[TowerDefinition]:
	var race := _race if _race != null else _catalog.default_race()
	if race == null:
		return _catalog.towers
	var roster: Array[TowerDefinition] = race.towers.duplicate()
	if _bonus_race != null and _bonus_race != race:
		roster.append_array(_bonus_race.towers)
	if race.ultimate != null:
		roster.append(race.ultimate)
	return roster


## A short slot label: slots fit about seven characters, so long names show
## one word: the first, unless it is a filler like "The" or "Da", then the
## last ("Nosy Neighbor" -> "Nosy", "The Hive Queen" -> "Queen").
static func _short_name(definition: TowerDefinition) -> String:
	var short_name := definition.display_name.replace(" Tower", "")
	if short_name.length() <= 9:
		return short_name
	var first := short_name.get_slice(" ", 0)
	return first if first.length() > 3 else short_name.get_slice(" ", short_name.get_slice_count(" ") - 1)


func _fill_build_card() -> void:
	var roster := _build_roster()
	for index in range(mini(roster.size(), BUILD_SLOTS.size())):
		var definition: TowerDefinition = roster[index]
		var cost := _modifiers.build_cost(definition.cost) if _modifiers else definition.cost
		var label := "%s\n%dg" % [_short_name(definition), cost]
		var tooltip := "%s  ·  %d gold\n%s\n%s" % [definition.display_name, cost, definition.role, definition.description]
		var affordable := _gold >= cost
		if _race != null and definition == _race.ultimate:
			# The ultimate costs gold plus one Relic from the halfway choice.
			label = "%s\n%dg+R" % [_short_name(definition), cost]
			tooltip = "%s  ·  %d gold + 1 Relic (you have %d)\n%s\n%s" % [definition.display_name, cost, _relics, definition.role, definition.description]
			affordable = affordable and _relics > 0
		_set_card_slot(BUILD_SLOTS[index], label, tooltip, _on_palette_button_pressed.bind(definition.id), affordable, definition.id == _selected_definition_id, definition.accent_color.lightened(0.25))
	if not _selected_definition_id.is_empty():
		_set_card_slot(SLOT_CANCEL, "Cancel", "Stop placing", _on_palette_button_pressed.bind(_selected_definition_id))
	else:
		_set_card_slot(SLOT_STOP, "Stop", "Stop: clear your builder's queued orders", func() -> void: builder_stop_requested.emit())


func _fill_tower_card() -> void:
	if _tower_building or _tower_upgrading:
		_set_card_slot(SLOT_UPGRADE, "Building" if _tower_building else "Upgrading", "Wait for the current work to finish", Callable(), false)
	elif _tower_options.is_empty():
		_set_card_slot(SLOT_UPGRADE, "Final\nform", "This tower has no further upgrades", Callable(), false)
	else:
		# Each branch of the upgrade tree gets its own slot, as in Wintermaul.
		for index in range(mini(_tower_options.size(), MAX_UPGRADE_OPTIONS)):
			var option: TowerDefinition = _tower_options[index]["definition"]
			var cost := int(_tower_options[index]["cost"])
			var tooltip := "Upgrade into %s for %d gold\n%s\n%s" % [option.display_name, cost, option.role, option.description]
			_set_card_slot(SLOT_UPGRADE + index, "%s\n%dg" % [_short_name(option), cost], tooltip,
				upgrade_requested.emit.bind(_shown_tower_id, option.id), _tower_can_control and _gold >= cost, false, option.accent_color.lightened(0.25))
	for mode in range(mini(TowerTargeting.Mode.size(), 4)):
		_set_card_slot(SLOT_FIRST_TARGETING + mode, TARGETING_SHORT_NAMES[mode], "Target the %s creep in range" % TowerTargeting.mode_name(mode).to_lower(),
			func() -> void: targeting_requested.emit(_shown_tower_id, mode), _tower_can_control, mode == _tower_targeting)
	if _tower_building:
		_set_card_slot(SLOT_SELL, "Cancel\n%dg" % _sell_value, "Cancel construction for a full refund of %d gold" % _sell_value,
			func() -> void: sell_requested.emit(_shown_tower_id), _tower_can_control)
	else:
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
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		open_chat()
		get_viewport().set_input_as_handled()
		return
	var index := CARD_KEYS.find(event.keycode)
	if index >= 0 and not _card_slots[index].disabled and _card_actions[index].is_valid():
		_card_actions[index].call()
		get_viewport().set_input_as_handled()


# --- Chat ----------------------------------------------------------------------

func _build_chat() -> void:
	var box := VBoxContainer.new()
	box.name = "Chat"
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 12.0
	box.offset_right = 560.0
	box.offset_top = CHAT_BOTTOM_OFFSET - 230.0
	box.offset_bottom = CHAT_BOTTOM_OFFSET
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_chat_log = VBoxContainer.new()
	_chat_log.alignment = BoxContainer.ALIGNMENT_END
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_theme_constant_override("separation", 1)
	box.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.max_length = ChatCommands.MAX_MESSAGE_LENGTH
	_chat_input.placeholder_text = "Say something  ·  /give 50 Name  ·  /help"
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_input_submitted)
	_chat_input.gui_input.connect(_on_chat_input_gui_input)
	box.add_child(_chat_input)


func open_chat() -> void:
	_chat_input.visible = true
	_chat_input.grab_focus()
	_refresh_chat()


func close_chat() -> void:
	_chat_input.clear()
	_chat_input.release_focus()
	_chat_input.visible = false
	_refresh_chat()


func is_chat_open() -> bool:
	return _chat_input.visible


func _on_chat_input_submitted(text: String) -> void:
	var line := ChatCommands.clean(text)
	close_chat()
	if not line.is_empty():
		chat_submitted.emit(line)


func _on_chat_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_chat()
		_chat_input.accept_event()


## The announcer's banner: top centre, under the toast line.
func _build_announcer_banner() -> void:
	_announcer_banner = SystemLowerThird.new()
	_announcer_banner.auto_hide = true
	_announcer_banner.anchor_left = 0.5
	_announcer_banner.anchor_right = 0.5
	_announcer_banner.offset_left = -330.0
	_announcer_banner.offset_right = 330.0
	_announcer_banner.offset_top = 80.0
	_announcer_banner.offset_bottom = 124.0
	add_child(_announcer_banner)


## The System speaks: a banner over the battlefield plus a chat-log line.
func announce(text: String) -> void:
	_announcer_banner.say(text)
	add_chat_line("System", SYSTEM_COLOR, text)


## Adds a line to the chat log. `text` is shown literally (no BBCode).
func add_chat_line(speaker: String, color: Color, text: String) -> void:
	var bbcode := "[color=#%s]%s:[/color] %s" % [color.to_html(false), _escape_bbcode(speaker), _escape_bbcode(text)]
	_chat_lines.append({"text": bbcode, "plain": "%s: %s" % [speaker, text], "time": Time.get_ticks_msec() / 1000.0})
	if _chat_lines.size() > CHAT_HISTORY:
		_chat_lines.remove_at(0)
	_refresh_chat()


## Plain-text chat history, oldest first (tests and the end screen).
func chat_history() -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _chat_lines:
		lines.append(str(line["plain"]))
	return lines


func _refresh_chat() -> void:
	if _chat_log == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var shown: Array[String] = []
	for index in range(_chat_lines.size() - 1, -1, -1):
		var line := _chat_lines[index]
		if shown.size() >= CHAT_VISIBLE_LINES or (not is_chat_open() and now - float(line["time"]) > CHAT_LINE_SECONDS):
			break
		shown.push_front(str(line["text"]))
	var rows := _chat_log.get_children()
	for index in range(maxi(rows.size(), shown.size())):
		var row: RichTextLabel = rows[index] if index < rows.size() else null
		if row == null:
			row = RichTextLabel.new()
			row.bbcode_enabled = true
			row.fit_content = true
			row.scroll_active = false
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_font_size_override("normal_font_size", 13)
			row.add_theme_constant_override("outline_size", 4)
			row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
			_chat_log.add_child(row)
		row.visible = index < shown.size()
		if row.visible and row.text != shown[index]:
			row.text = shown[index]


static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


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
	_show_awards(results.get("awards", []))
	if not _end_screen_shown:
		_end_screen_shown = true
		hide_offer()
		end_overlay.visible = true


## "And the awards go to...": each award's title, winner and the System's
## line about it, under the run summary.
func _show_awards(awards: Array) -> void:
	var signature := str(awards)
	if signature == _awards_signature:
		return
	_awards_signature = signature
	if _awards_box == null:
		_awards_box = VBoxContainer.new()
		_awards_box.add_theme_constant_override("separation", 4)
		end_summary.get_parent().add_child(_awards_box)
		end_summary.get_parent().move_child(_awards_box, end_summary.get_index() + 1)
	for child in _awards_box.get_children():
		child.queue_free()
	if awards.is_empty():
		return
	var heading := Label.new()
	heading.text = "AND THE AWARDS GO TO..."
	BroadcastTheme.headline(heading, 22, BroadcastTheme.CYAN, Color(0, 0, 0, 0.6))
	_awards_box.add_child(heading)
	for award: Dictionary in awards:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var title := Label.new()
		title.text = str(award.get("title", ""))
		title.custom_minimum_size.x = 250
		BroadcastTheme.headline(title, 16, BroadcastTheme.GOLD, Color(0, 0, 0, 0.6))
		row.add_child(title)
		var winner := Label.new()
		winner.text = "%s  ·  %s" % [award.get("name", ""), award.get("line", "")]
		winner.add_theme_font_size_override("font_size", 13)
		row.add_child(winner)
		_awards_box.add_child(row)


## Award titles shown on the end screen (tests).
func award_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	if _awards_box == null:
		return titles
	for row in _awards_box.get_children():
		if row is HBoxContainer and not row.is_queued_for_deletion():
			titles.append((row.get_child(0) as Label).text)
	return titles


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
# --- Halfway choice --------------------------------------------------------------

## Built in code like the offer overlay: a Relic card for the race ultimate
## beside one card per race the player could recruit.
func _build_midpoint_overlay() -> void:
	_midpoint_overlay = ColorRect.new()
	_midpoint_overlay.name = "MidpointOverlay"
	(_midpoint_overlay as ColorRect).color = Color(0.01, 0.02, 0.02, 0.8)
	_midpoint_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_midpoint_overlay.visible = false
	add_child(_midpoint_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_midpoint_overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var title := Label.new()
	title.text = "HALFWAY THERE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.831, 0.952, 0.917))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Take a Relic to build your race's ultimate tower once, or recruit a second race and build its towers too. The wave timer waits for everyone."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(760, 0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.706, 0.78, 0.761))
	column.add_child(subtitle)
	_midpoint_cards = HBoxContainer.new()
	_midpoint_cards.add_theme_constant_override("separation", 12)
	column.add_child(_midpoint_cards)


func show_midpoint(own: RaceDefinition, recruitable: Array[RaceDefinition], ultimate_cost: int) -> void:
	var signature := "%s|%d|%s" % [own.id if own else "", ultimate_cost, recruitable.map(func(race: RaceDefinition) -> String: return race.id)]
	if _midpoint_overlay.visible and signature == _midpoint_signature:
		return
	_midpoint_signature = signature
	for child in _midpoint_cards.get_children():
		child.queue_free()
	if own != null and own.ultimate != null:
		var relic := _midpoint_card("TAKE A RELIC\n\n%s\n%d gold + 1 Relic\n\n%s" % [own.ultimate.display_name, ultimate_cost, own.ultimate.description], own.color)
		relic.pressed.connect(func() -> void: midpoint_chosen.emit("relic", ""))
		_midpoint_cards.add_child(relic)
	for race in recruitable:
		var card := _midpoint_card("RECRUIT %s\n\n%s" % [race.display_name.to_upper(), race.description], race.color)
		card.pressed.connect(func() -> void: midpoint_chosen.emit("race", race.id))
		_midpoint_cards.add_child(card)
	_midpoint_overlay.visible = true


func hide_midpoint() -> void:
	if _midpoint_overlay != null and _midpoint_overlay.visible:
		_midpoint_overlay.visible = false
		_midpoint_signature = ""


func _midpoint_card(text: String, color: Color) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(190, 210)
	card.text = text
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_color_override("font_color", color.lightened(0.35))
	return card


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
