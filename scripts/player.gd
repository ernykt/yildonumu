# Player.gd
extends CharacterBody2D

#region Export Değişkenleri
# Inspector'dan ayarlanabilen değerler
@export var player_id: int = 1
@export var move_speed: float = 400.0
@export var sprint_speed_multiplier: float = 1.5
@export var jump_speed: float = -400.0
@export var gravity: float = 980.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 10.0
@export var stamina_drain_rate: float = 20.0
@export var stun_duration: float = 0.5
# YENİ: Zıplamanın stamina maliyeti için değişken
@export var jump_stamina_cost: float = 15.0

@export var stamina_message_threshold_ratio: float = 0.2
@export var message_scale_min: Vector2 = Vector2(0.9, 0.9)
@export var message_scale_max: Vector2 = Vector2(1.1, 1.1)
@export var message_scale_duration: float = 0.8

# Sırta alma mekaniği için değişkenler
@export var piggyback_speed_multiplier: float = 0.7
@export var carrier_stamina_regen_rate: float = 5.0
@export var piggyback_offset: Vector2 = Vector2(0, -40)

# Hızlandırma mekaniği için değişkenler
@export var boost_duration: float = 1.0     # Hızlandırmanın süresi (saniye)
@export var boost_speed_multiplier: float = 1.5 # Hızlandırmanın hız çarpanı
#endregion

#region Hazır Nodelar
@onready var sprite_eren: AnimatedSprite2D = $PlayerSpriteEren
@onready var sprite_elif: AnimatedSprite2D = $PlayerSpriteElif
@onready var player_collider: CollisionShape2D = $PlayerCollider
@onready var player_area: Area2D = $PlayerArea
@onready var progress_bar: ProgressBar = $ProgressBar
@onready var stamina_message_label: Label = $StaminaMessage

var active_sprite: AnimatedSprite2D
#endregion

#region FSM Durumları
enum State {
	IDLE,
	WALK_RUN,
	JUMP,
	STUNNED,
	CARRYING,
	CARRIED
}
var current_state: State = State.IDLE
var stun_timer: float = 0.0
#endregion

#region Oyuncu Durum Değişkenleri
var current_stamina: float
var input_direction: float = 0.0
var action_forward: String
var action_backward: String
var action_jump: String
var action_interact: String

# Sırta alma durumu için referanslar
var other_player: CharacterBody2D = null
var carried_by: CharacterBody2D = null
var carrying_player: CharacterBody2D = null
var players_in_interaction_zone: Array = []
var interaction_cooldown: float = 0.0
var boost_timer: float = 0.0
#endregion

var message_tween: Tween

func _ready():
	add_to_group("players")

	player_area.body_entered.connect(_on_player_area_body_entered)
	player_area.body_exited.connect(_on_player_area_body_exited)

	current_stamina = max_stamina
	progress_bar.max_value = max_stamina
	progress_bar.min_value = 0
	progress_bar.value = current_stamina

	stamina_message_label.hide()
	stamina_message_label.text = "Piggyback !"
	stamina_message_label.pivot_offset = stamina_message_label.size / 2.0

	if player_id == 1:
		active_sprite = sprite_eren
		sprite_elif.hide()
		action_forward = "player1_forward"
		action_backward = "player1_backward"
		action_jump = "player1_jump"
		action_interact = "player1_interact"
	elif player_id == 2:
		active_sprite = sprite_elif
		sprite_eren.hide()
		action_forward = "player2_forward"
		action_backward = "player2_backward"
		action_jump = "player2_jump"
		action_interact = "player2_interact"

	set_state(State.IDLE)

func _physics_process(delta):
	interaction_cooldown = max(0.0, interaction_cooldown - delta)
	boost_timer = max(0.0, boost_timer - delta)

	if other_player == null:
		find_other_player()

	if current_state != State.CARRIED:
		velocity.y += gravity * delta

	match current_state:
		State.IDLE:
			handle_idle_state(delta)
			handle_interaction_check()
		State.WALK_RUN:
			handle_walk_run_state(delta)
			handle_interaction_check()
		State.JUMP:
			handle_jump_state(delta)
		State.STUNNED:
			handle_stunned_state(delta)
		State.CARRYING:
			handle_carrying_state(delta)
		State.CARRIED:
			handle_carried_state(delta)

	if current_state != State.CARRIED:
		move_and_slide()

	check_obstacle_collisions()
	progress_bar.value = current_stamina
	update_stamina_message()

func set_state(new_state: State):
	if current_state == new_state: return

	match current_state:
		State.STUNNED:
			stun_timer = 0.0
		State.CARRYING:
			carrying_player = null
		State.CARRIED:
			player_collider.disabled = false
			carried_by = null
		_:
			pass

	current_state = new_state

	match current_state:
		State.IDLE:
			active_sprite.play("idle")
		State.WALK_RUN:
			active_sprite.play("run")
		State.JUMP:
			active_sprite.play("jump")
		State.STUNNED:
			stun_timer = stun_duration
			velocity.x = 0
		State.CARRYING:
			pass
		State.CARRIED:
			active_sprite.play("carried")
			velocity = Vector2.ZERO
			player_collider.disabled = true
			if stamina_message_label.is_visible_in_tree():
				stamina_message_label.hide()

func handle_idle_state(delta):
	handle_horizontal_input()
	handle_stamina_regen(delta)

	if input_direction != 0:
		set_state(State.WALK_RUN)
	# DEĞİŞTİ: Zıplama için stamina kontrolü eklendi
	elif can_process_input() and Input.is_action_just_pressed(action_jump) and is_on_floor():
		if current_stamina >= jump_stamina_cost:
			current_stamina -= jump_stamina_cost
			velocity.y = jump_speed
			set_state(State.JUMP)

	velocity.x = 0

func handle_walk_run_state(delta):
	handle_horizontal_input()

	var stamina_ratio = current_stamina / max_stamina
	var current_base_speed = lerp(move_speed * 0.2, move_speed, stamina_ratio)
	var current_speed = current_base_speed

	if input_direction == 1 and current_stamina > 0:
		current_speed *= sprint_speed_multiplier

	if input_direction != 0:
		current_stamina -= stamina_drain_rate * delta
		current_stamina = max(0, current_stamina)

	velocity.x = input_direction * current_speed

	if input_direction == 0:
		set_state(State.IDLE)
	# DEĞİŞTİ: Zıplama için stamina kontrolü eklendi
	elif can_process_input() and Input.is_action_just_pressed(action_jump) and is_on_floor():
		if current_stamina >= jump_stamina_cost:
			current_stamina -= jump_stamina_cost
			velocity.y = jump_speed
			set_state(State.JUMP)

func handle_jump_state(delta):
	handle_horizontal_input()
	velocity.x = input_direction * move_speed
	
	if is_on_floor():
		set_state(State.IDLE if input_direction == 0 else State.WALK_RUN)

func handle_stunned_state(delta):
	stun_timer -= delta
	if stun_timer <= 0:
		set_state(State.IDLE)

func handle_carrying_state(delta):
	if not is_instance_valid(carrying_player):
		set_state(State.IDLE)
		return

	handle_horizontal_input()

	if input_direction != 0:
		active_sprite.play("run")
	else:
		active_sprite.play("idle")

	if Input.is_action_just_pressed(action_jump) and is_on_floor():
		velocity.y = jump_speed

	var final_speed = move_speed * piggyback_speed_multiplier
	if boost_timer > 0.0:
		final_speed *= boost_speed_multiplier
	
	velocity.x = input_direction * final_speed

	current_stamina += carrier_stamina_regen_rate * delta
	current_stamina = min(max_stamina, current_stamina)

	carrying_player.global_position = self.global_position + piggyback_offset

func handle_carried_state(delta):
	handle_stamina_regen(delta)
	
	if Input.is_action_just_pressed(action_interact):
		if is_instance_valid(carried_by):
			carried_by.activate_speed_boost()

	if current_stamina >= max_stamina:
		dismount_with_jump()
		return

func can_process_input() -> bool:
	if current_state == State.STUNNED or current_state == State.CARRIED:
		return false
	return true

func handle_horizontal_input():
	if not can_process_input():
		input_direction = 0.0
		return

	input_direction = 0.0
	if Input.is_action_pressed(action_forward):
		input_direction += 1.0
		active_sprite.flip_h = false
	if Input.is_action_pressed(action_backward):
		input_direction -= 1.0
		active_sprite.flip_h = true

func handle_stamina_regen(delta):
	current_stamina += stamina_regen_rate * delta
	current_stamina = min(max_stamina, current_stamina)

func check_obstacle_collisions():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() and collision.get_collider() is TileMap:
			if current_state != State.STUNNED:
				set_state(State.STUNNED)
			break

func update_stamina_message():
	var threshold_stamina = max_stamina * stamina_message_threshold_ratio
	if current_stamina <= threshold_stamina and not is_piggybacking():
		if not stamina_message_label.is_visible_in_tree():
			stamina_message_label.show()
			start_stamina_message_tween()
	else:
		if stamina_message_label.is_visible_in_tree():
			stamina_message_label.hide()
			if message_tween:
				message_tween.stop()
				stamina_message_label.scale = Vector2(1,1)

func start_stamina_message_tween():
	if message_tween: message_tween.stop()
	else: message_tween = get_tree().create_tween()

	message_tween.set_loops()
	message_tween.tween_property(stamina_message_label, "scale", message_scale_max, message_scale_duration).set_ease(Tween.EASE_OUT)
	message_tween.tween_property(stamina_message_label, "scale", message_scale_min, message_scale_duration).set_ease(Tween.EASE_IN)

func find_other_player():
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		if p != self:
			other_player = p
			break

func handle_interaction_check():
	if interaction_cooldown > 0.0:
		return

	if not can_process_input():
		return

	if Input.is_action_just_pressed(action_interact) and is_instance_valid(other_player):
		if other_player.is_requesting_piggyback() and other_player in players_in_interaction_zone:
			start_carrying(other_player)
			other_player.start_being_carried(self)

func _on_player_area_body_entered(body: Node2D):
	if body.is_in_group("players") and body != self:
		if not body in players_in_interaction_zone:
			players_in_interaction_zone.append(body)

func _on_player_area_body_exited(body: Node2D):
	if body in players_in_interaction_zone:
		players_in_interaction_zone.erase(body)

func is_requesting_piggyback() -> bool:
	return stamina_message_label.is_visible_in_tree()

func start_carrying(player_to_carry: CharacterBody2D):
	carrying_player = player_to_carry
	set_state(State.CARRYING)

func start_being_carried(carrier: CharacterBody2D):
	carried_by = carrier
	set_state(State.CARRIED)

func stop_piggyback():
	interaction_cooldown = 0.5

	if is_instance_valid(carried_by):
		carried_by.set_state(State.IDLE)
	elif is_instance_valid(carrying_player):
		carrying_player.set_state(State.IDLE)

	set_state(State.IDLE)

func dismount_with_jump():
	if carried_by == null or not is_instance_valid(carried_by):
		return

	carried_by.set_state(State.IDLE)
	velocity.y = jump_speed
	set_state(State.JUMP)

func activate_speed_boost():
	boost_timer = boost_duration

func is_piggybacking() -> bool:
	return current_state == State.CARRYING or current_state == State.CARRIED
