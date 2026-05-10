extends Control

# ──────────────────────────────────────────────
#  REFERENCIAS A NODOS  (ajustá los paths a tu escena)
# ──────────────────────────────────────────────
@export var combat_manager: Node

# Contenedores de tarjetas de personaje
@export var player_cards_container: HBoxContainer
@export var enemy_cards_container: HBoxContainer

# Panel de acción del jugador
@export var action_panel: PanelContainer
@export var active_char_label: Label
@export var ammo_label: Label
@export var bullet_slider: HSlider
@export var bullet_count_label: Label
@export var attack_button: Button
@export var reload_button: Button

# Log de combate
@export var log_label: RichTextLabel

# Botón de pausa
@export var pause_button: Button
@export var qte_display: Control  # Nodo QTEDisplay

# ──────────────────────────────────────────────
#  SEÑALES
# ──────────────────────────────────────────────
signal pause_requested

# ──────────────────────────────────────────────
#  ESTADO UI
# ──────────────────────────────────────────────
var selected_enemy = null
var enemy_buttons: Array[Button] = []
var player_card_nodes: Array[Dictionary] = []  # [{char, hp_bar, atb_bar, labels}]
var enemy_card_nodes: Array[Dictionary] = []
var _tracker: Node = null  # CombatTracker, asignado desde CombatSetup

# ──────────────────────────────────────────────
#  SETUP
# ──────────────────────────────────────────────
func set_tracker(tracker: Node) -> void:
	_tracker = tracker

func _ready() -> void:
	# Las señales del CombatManager se conectan UNA SOLA VEZ acá.
	# Al reiniciar el combate NO se llama _ready() de nuevo,
	# así que no hay riesgo de conexiones duplicadas.
	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_resolved.connect(_on_enemy_turn_resolved)
	combat_manager.character_died.connect(_on_character_died)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.atb_updated.connect(_refresh_bars)

	# Conectar botones (también una sola vez)
	attack_button.pressed.connect(_on_attack_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	bullet_slider.value_changed.connect(_on_bullet_slider_changed)
	pause_button.pressed.connect(func(): emit_signal("pause_requested"))

	action_panel.hide()

# Llamado desde CombatSetup en cada (re)inicio — NO conecta señales,
# solo reconstruye las tarjetas visuales con los personajes actuales.
func reinitialize() -> void:
	action_panel.hide()
	selected_enemy = null
	_close_action_panel()
	_build_character_cards()
	_start_combat()

func _build_character_cards() -> void:
	# Limpia contenedores
	for child in player_cards_container.get_children():
		child.queue_free()
	for child in enemy_cards_container.get_children():
		child.queue_free()

	player_card_nodes.clear()
	enemy_card_nodes.clear()
	enemy_buttons.clear()

	for player in combat_manager.player_chars:
		var card = _create_card(player, true)
		player_cards_container.add_child(card["root"])
		player_card_nodes.append(card)

	for enemy in combat_manager.enemy_chars:
		var card = _create_card(enemy, false)
		enemy_cards_container.add_child(card["root"])
		enemy_card_nodes.append(card)
		enemy_buttons.append(card["select_button"])

func _create_card(character, is_player: bool) -> Dictionary:
	var root = PanelContainer.new()
	root.custom_minimum_size = Vector2(150, 180)

	var vbox = VBoxContainer.new()
	root.add_child(vbox)

	var name_label = Label.new()
	name_label.text = character.character_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var hp_bar = ProgressBar.new()
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	hp_bar.custom_minimum_size.y = 16
	vbox.add_child(hp_bar)

	var hp_label = Label.new()
	hp_label.text = "HP: %.0f / %.0f" % [character.current_hp, character.max_hp]
	vbox.add_child(hp_label)

	var atb_bar = ProgressBar.new()
	atb_bar.max_value = character.atb_max
	atb_bar.value = character.atb
	atb_bar.custom_minimum_size.y = 12
	# Teñir el ATB de amarillo
	var style = StyleBoxFlat.new()
	style.bg_color = Color.YELLOW
	atb_bar.add_theme_stylebox_override("fill", style)
	vbox.add_child(atb_bar)

	var atb_label = Label.new()
	atb_label.text = "ATB"
	vbox.add_child(atb_label)

	var select_button = Button.new()
	select_button.text = "Seleccionar"
	select_button.hide()
	vbox.add_child(select_button)

	# Para jugadores, mostrar munición
	var ammo_bar = null
	if is_player:
		var pc = character
		ammo_bar = ProgressBar.new()
		ammo_bar.max_value = pc.max_ammo
		ammo_bar.value = pc.current_ammo
		ammo_bar.custom_minimum_size.y = 12
		var ammo_style = StyleBoxFlat.new()
		ammo_style.bg_color = Color.CYAN
		ammo_bar.add_theme_stylebox_override("fill", ammo_style)
		vbox.add_child(ammo_bar)

		var ammo_label_card = Label.new()
		ammo_label_card.text = "Ammo: %d/%d" % [pc.current_ammo, pc.max_ammo]
		vbox.add_child(ammo_label_card)

	return {
		"root": root,
		"char": character,
		"hp_bar": hp_bar,
		"hp_label": hp_label,
		"atb_bar": atb_bar,
		"ammo_bar": ammo_bar,
		"select_button": select_button,
	}

func _start_combat() -> void:
	log_label.clear()
	_log("[color=white]Combate iniciado![/color]")

# ──────────────────────────────────────────────
#  REFRESH DE BARRAS (cada frame via señal)
# ──────────────────────────────────────────────
func _refresh_bars() -> void:
	for card in player_card_nodes:
		var c = card["char"]
		card["hp_bar"].value = c.current_hp
		card["hp_label"].text = "HP: %.0f / %.0f" % [c.current_hp, c.max_hp]
		card["atb_bar"].value = c.atb
		if card["ammo_bar"]:
			card["ammo_bar"].value = c.current_ammo

	for card in enemy_card_nodes:
		var c = card["char"]
		card["hp_bar"].value = c.current_hp
		card["hp_label"].text = "HP: %.0f / %.0f" % [c.current_hp, c.max_hp]
		card["atb_bar"].value = c.atb

# ──────────────────────────────────────────────
#  TURNO DEL JUGADOR
# ──────────────────────────────────────────────
func _on_player_turn_started(player_char) -> void:
	action_panel.show()
	active_char_label.text = "Turno de: %s" % combat_manager.active_get_name()
	ammo_label.text = "Municion: %d / %d  |  Cadencia max: %d  |  Chance actual: %.0f%%" % [
		combat_manager.active_get_ammo(),
		combat_manager.active_get_max_ammo(),
		combat_manager.active_get_cadence(),
		combat_manager.active_get_hit_chance() * 100
	]

	# Configurar slider de balas
	bullet_slider.min_value = 1
	bullet_slider.max_value = combat_manager.active_get_cadence()
	bullet_slider.value = min(combat_manager.active_get_cadence(), combat_manager.active_get_ammo())
	bullet_slider.step = 1
	_on_bullet_slider_changed(bullet_slider.value)

	# Mostrar botones de selección en enemigos vivos
	selected_enemy = null
	attack_button.disabled = true

	for i in enemy_card_nodes.size():
		var card = enemy_card_nodes[i]
		var enemy = card["char"]
		var btn: Button = card["select_button"]
		if enemy.get("is_alive"):
			btn.show()
			# Sin CONNECT_ONE_SHOT para que el jugador pueda cambiar de objetivo
			if not btn.pressed.is_connected(_on_enemy_selected.bind(enemy, btn)):
				btn.pressed.connect(_on_enemy_selected.bind(enemy, btn))
		else:
			btn.hide()

func _on_enemy_selected(enemy, btn: Button) -> void:
	selected_enemy = enemy
	attack_button.disabled = false
	# Resaltar seleccionado
	for card in enemy_card_nodes:
		var b: Button = card["select_button"]
		b.text = "Seleccionar"
	btn.text = "✓ Objetivo"
	_log("[color=orange]Objetivo: %s[/color]" % enemy.get("character_name"))

func _on_bullet_slider_changed(value: float) -> void:
	bullet_count_label.text = "Balas a usar: %d" % int(value)

func _on_attack_pressed() -> void:
	if selected_enemy == null:
		return
	var bullets = int(bullet_slider.value)
	if not combat_manager.active_can_shoot(bullets):
		_log("[color=red]Sin munición suficiente.[/color]")
		return

	_log("[color=white]%s apunta a %s - QTE iniciado[/color]" % [
		combat_manager.active_get_name(), selected_enemy.character_name
	])

	# Ocultar panel de acción mientras dura el QTE
	action_panel.hide()

	# Conectar resultado del QTE (one shot para este disparo)
	if not qte_display.attack_resolved.is_connected(_on_qte_resolved):
		qte_display.attack_resolved.connect(_on_qte_resolved, CONNECT_ONE_SHOT)

	# Pasar datos del enemigo (hitboxes) al QTE
	var enemy_idx: int = combat_manager.enemy_chars.find(selected_enemy)
	if enemy_idx >= 0 and enemy_idx < GameData.enemy_data.size():
		qte_display.set_enemy(GameData.enemy_data[enemy_idx])

	# Consumir munición y arrancar el QTE
	combat_manager.active_consume_ammo(bullets)
	combat_manager.active_start_qte(qte_display, bullets)

func _on_qte_resolved(shots: Array) -> void:
	var total_dmg := 0.0

	_log("[color=white]Resultado de %d disparo(s):[/color]" % shots.size())
	for i in shots.size():
		var shot: Dictionary = shots[i]
		var dmg: float = shot["damage"]
		total_dmg += dmg
		_log("  [color=green]Bala %d → %s  %.0f dmg[/color]" % [i + 1, shot["zone"], dmg])

	_log("[color=green]  Total: %.0f daño[/color]" % total_dmg)

	if _tracker:
		_tracker.record_attack(combat_manager.active_get_name(), shots.size(), total_dmg)
		_tracker.record_enemy_damage(selected_enemy.get("character_name"), total_dmg)

	combat_manager.action_attack_with_damage(selected_enemy, total_dmg)
	_close_action_panel()
	_refresh_bars()

func _on_reload_pressed() -> void:
	_log("[color=cyan]%s recarga. Municion restaurada.[/color]" % combat_manager.active_get_name())
	if _tracker:
		_tracker.record_reload(combat_manager.active_get_name())
	combat_manager.action_reload()
	_close_action_panel()
	_refresh_bars()

func _close_action_panel() -> void:
	action_panel.hide()
	selected_enemy = null
	for card in enemy_card_nodes:
		var btn: Button = card["select_button"]
		btn.hide()
		# Desconectar para que el próximo turno reconecte limpio
		var enemy = card["char"]
		if btn.pressed.is_connected(_on_enemy_selected.bind(enemy, btn)):
			btn.pressed.disconnect(_on_enemy_selected.bind(enemy, btn))

# ──────────────────────────────────────────────
#  SEÑALES DE COMBATE
# ──────────────────────────────────────────────
func _on_enemy_turn_resolved(enemy, target, dmg: float) -> void:
	_log("[color=red]%s ataca a %s - %.0f dano[/color]" % [
		enemy.get("character_name"), target.get("character_name"), dmg
	])
	_refresh_bars()

func _on_character_died(character, is_player: bool) -> void:
	var color = "red" if is_player else "gray"
	_log("[color=%s]%s fue eliminado.[/color]" % [color, character.get("character_name")])
	# Deshabilitar visualmente la tarjeta
	for card in (player_card_nodes if is_player else enemy_card_nodes):
		if card["char"] == character:
			card["root"].modulate = Color(0.4, 0.4, 0.4)

func _on_combat_ended(player_won: bool) -> void:
	action_panel.hide()
	if player_won:
		_log("[color=yellow]Victoria: El jugador gana el combate.[/color]")
	else:
		_log("[color=red]Derrota. Todos los personajes del jugador cayeron.[/color]")

# ──────────────────────────────────────────────
#  HELPER LOG
# ──────────────────────────────────────────────
func _log(text: String) -> void:
	log_label.append_text(text + "\n")
	# Auto-scroll al final
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count())
