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
var _pending_bullets: int = 0
var _pending_target = null
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
	combat_manager.player_ready_changed.connect(_on_player_ready_changed)
	combat_manager.action_queued.connect(_on_action_queued)
	combat_manager.action_started.connect(_on_action_started)
	combat_manager.action_resolved.connect(_on_action_resolved)
	
	combat_manager.character_died.connect(_on_character_died)
	combat_manager.combat_ended.connect(_on_combat_ended)
	# atb_updated ya no existe — _refresh_bars se llama desde _process

	# Conectar botones (también una sola vez)
	attack_button.pressed.connect(_on_attack_pressed)
	reload_button.pressed.connect(_on_reload_pressed)
	bullet_slider.value_changed.connect(_on_bullet_slider_changed)
	pause_button.pressed.connect(func(): emit_signal("pause_requested"))

	action_panel.hide()

# Llamado desde CombatSetup en cada (re)inicio — NO conecta señales,
# solo reconstruye las tarjetas visuales con los personajes actuales.
func _process(_delta: float) -> void:
	if combat_manager != null:
		_refresh_bars()


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
	if not is_player:
		# Conectar el botón al handler de selección de enemigo
		select_button.pressed.connect(_on_enemy_selected.bind(character, select_button))

	# Botón "Usar" — solo para jugadores, aparece cuando están listos
	var use_button = null
	if is_player:
		use_button = Button.new()
		use_button.text = "USAR"
		use_button.hide()
		use_button.pressed.connect(_on_use_player_pressed.bind(character))
		vbox.add_child(use_button)

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
		"use_button": use_button,
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

	_refresh_player_ready_state()


# ──────────────────────────────────────────────
#  ESTADO "LISTO" DE JUGADORES — mostrar/ocultar botón Usar
# ──────────────────────────────────────────────
func _refresh_player_ready_state() -> void:
	# En las cards de jugador:
	#  - Si está listo (ATB 100%) y NO encolado: botón "USAR" habilitado
	#  - Si está encolado o actuando: botón "EN COLA" deshabilitado
	#  - Si no está listo: botón oculto
	for card in player_card_nodes:
		var c = card["char"]
		if not card.has("use_button"):
			continue
		var btn: Button = card["use_button"]
		if not c.get("is_alive"):
			btn.hide()
			continue
		var is_ready = c.get("atb") >= c.get("atb_max")
		var in_queue = combat_manager._is_actor_in_queue_or_acting(c)
		if in_queue:
			btn.show()
			btn.text = "EN COLA"
			btn.disabled = true
		elif is_ready:
			btn.show()
			btn.text = "USAR"
			btn.disabled = false
		else:
			btn.hide()

# ──────────────────────────────────────────────
#  TURNO DEL JUGADOR
# ──────────────────────────────────────────────
func _on_player_ready_changed(player_char, is_ready: bool) -> void:
	# Solo refresca las cards para mostrar/ocultar el botón "Usar"
	_refresh_player_ready_state()



# Llamado desde el botón "Usar" de una card de jugador lista.
# Encola la intención de tomar turno. No abre menú — el menú se abrirá
# cuando llegue su turno en la cola (action_started con kind == "player_turn").
func _on_use_player_pressed(player_char) -> void:
	combat_manager.queue_player_turn(player_char)
	_refresh_player_ready_state()


func _on_enemy_selected(enemy, btn: Button) -> void:
	print("[UI] _on_enemy_selected: ", enemy.get("character_name"), " action_panel.visible=", action_panel.visible)
	selected_enemy = enemy
	attack_button.disabled = false
	print("[UI] attack_button.disabled despues: ", attack_button.disabled)
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
		_log("[color=red]Sin municion suficiente.[/color]")
		return

	# Guardar info pendiente — el setup del QTE se hace en _on_action_started
	# cuando llegue la señal con kind="player_attack"
	_pending_bullets = bullets
	_pending_target = selected_enemy
	# IMPORTANTE: promover ANTES de _close_action_panel (que resetea selected_enemy a null)
	combat_manager.confirm_player_attack(selected_enemy, bullets)
	_close_action_panel()

func _on_qte_resolved(shots: Array) -> void:
	print("[UI] _on_qte_resolved recibido, shots: ", shots.size())
	var total_dmg = 0.0

	_log("[color=white]Resultado de %d disparo(s):[/color]" % shots.size())
	for i in shots.size():
		var shot: Dictionary = shots[i]
		var dmg: float = shot["damage"]
		total_dmg += dmg
		_log("  [color=green]Bala %d → %s  %.0f dmg[/color]" % [i + 1, shot["zone"], dmg])

	_log("[color=green]  Total: %.0f daño[/color]" % total_dmg)

	if _tracker:
		_tracker.record_attack(combat_manager.active_get_name(), shots.size(), total_dmg)
		var target_for_tracker = selected_enemy if selected_enemy != null else _pending_target
		if target_for_tracker != null:
			_tracker.record_enemy_damage(target_for_tracker.get("character_name"), total_dmg)

	print("[UI] llamando resolve_player_attack con dmg ", total_dmg)
	combat_manager.resolve_player_attack(total_dmg)
	print("[UI] resolve_player_attack devuelto")
	_close_action_panel()
	_refresh_bars()

func _on_reload_pressed() -> void:
	_log("[color=cyan]%s recarga. Municion restaurada.[/color]" % combat_manager.active_get_name())
	if _tracker:
		_tracker.record_reload(combat_manager.active_get_name())
	combat_manager.confirm_player_reload()
	_close_action_panel()
	_refresh_bars()

func _close_action_panel() -> void:
	action_panel.hide()
	selected_enemy = null
	# Ocultar botones de selección de enemigos.
	# La conexión .pressed se hace una sola vez en _create_card y queda persistente
	# entre turnos — no hay que desconectar/reconectar.
	for card in enemy_card_nodes:
		var btn: Button = card["select_button"]
		btn.hide()
		btn.text = "Seleccionar"  # resetear texto para el próximo turno

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
	if log_label == null:
		return
	log_label.append_text(text + "\n")
	# Auto-scroll al final (sin await — el await se cuelga si get_tree().paused = true)
	log_label.scroll_to_line(log_label.get_line_count())

# ──────────────────────────────────────────────
#  HANDLERS DE LA COLA DE ACCIONES
# ──────────────────────────────────────────────
func _on_action_queued(action_data: Dictionary) -> void:
	var actor_name = action_data["actor"].get("character_name")
	var kind = action_data["kind"]
	if kind == "enemy_attack":
		_log("[color=gray]%s entra en cola...[/color]" % actor_name)
	elif kind == "player_attack":
		_log("[color=cyan]%s prepara ataque (en cola)...[/color]" % actor_name)
	elif kind == "player_reload":
		_log("[color=cyan]%s preparara recarga...[/color]" % actor_name)

func _on_action_started(action_data: Dictionary) -> void:
	var actor = action_data["actor"]
	var actor_name = actor.get("character_name")
	var kind = action_data["kind"]
	print("[UI] _on_action_started: kind=", kind, " actor=", actor_name)

	if kind == "enemy_attack":
		_log("[color=orange]%s ataca![/color]" % actor_name)

	elif kind == "player_turn":
		# Ahora sí abrimos el menú — es el turno del jugador
		_log("[color=cyan]Turno de %s[/color]" % actor_name)
		action_panel.show()
		active_char_label.text = "Turno de: %s" % actor_name
		ammo_label.text = "Municion: %d / %d  |  Cadencia max: %d" % [
			actor.get("current_ammo"),
			actor.get("max_ammo"),
			actor.get("cadence"),
		]
		bullet_slider.max_value = actor.get("cadence")
		bullet_slider.value = min(actor.get("cadence"), actor.get("current_ammo"))
		selected_enemy = null
		attack_button.disabled = true
		reload_button.disabled = false
		_refresh_player_ready_state()

		# Mostrar botones "Seleccionar" en enemigos vivos
		for card in enemy_card_nodes:
			var c = card["char"]
			var btn: Button = card["select_button"]
			if c.get("is_alive"):
				btn.show()
				btn.text = "Seleccionar"
				btn.disabled = false
			else:
				btn.hide()

	elif kind == "player_attack":
		# Es turno de este jugador en la cola — abrir QTE
		_log("[color=white]%s apunta - QTE iniciado[/color]" % actor_name)
		# Conectar la resolución del QTE para este disparo (one-shot)
		if not qte_display.attack_resolved.is_connected(_on_qte_resolved):
			qte_display.attack_resolved.connect(_on_qte_resolved, CONNECT_ONE_SHOT)
		# Consumir munición ahora
		combat_manager.active_consume_ammo(_pending_bullets)
		# Pasar datos del enemigo (hitboxes) al QTE
		var target = action_data["target"]
		var enemy_idx: int = combat_manager.enemy_chars.find(target)
		if enemy_idx >= 0 and enemy_idx < GameData.enemy_data.size():
			qte_display.set_enemy(GameData.enemy_data[enemy_idx])
		# Iniciar QTE — esto bloquea hasta que el jugador termine
		qte_display.start_qte(actor, _pending_bullets)
		# selected_enemy se mantiene del momento del attack press
		selected_enemy = target

	elif kind == "player_reload":
		_log("[color=cyan]%s recarga - municion restaurada[/color]" % actor_name)
		if _tracker:
			_tracker.record_reload(actor_name)

func _on_action_resolved(action_data: Dictionary) -> void:
	var actor = action_data["actor"]
	var kind = action_data["kind"]
	if kind == "enemy_attack":
		var target = action_data.get("target")
		var dmg = action_data.get("damage", 0.0)
		if target != null:
			_log("[color=red]%s hace %.0f dano a %s[/color]" % [
				actor.get("character_name"), dmg, target.get("character_name")
			])
