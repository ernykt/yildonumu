# Player.gd
extends CharacterBody2D

#region Export Değişkenleri
# Inspector'dan ayarlanabilen değerler
@export var player_id: int = 1 # Oyuncu 1 mi 2 mi olduğunu belirlemek için
@export var move_speed: float = 400.0 # Yatay hareket hızı
@export var sprint_speed_multiplier: float = 1.5 # Koşarken hız çarpanı
@export var jump_speed: float = -400.0 # Zıplama gücü (eksi değer yukarı doğru hareketi temsil eder)
@export var gravity: float = 980.0 # Yer çekimi
@export var max_stamina: float = 100.0 # Maksimum dayanıklılık (stamina)
@export var stamina_regen_rate: float = 10.0 # Saniyede yenilenen dayanıklılık
@export var stamina_drain_rate: float = 20.0 # Saniyede tükenen dayanıklılık
@export var stun_duration: float = 0.5 # Engelle çarpınca sersemleme süresi
#endregion

#region Hazır Nodelar
# Sahnedeki nodelara referanslar
@onready var sprite: Sprite2D = $PlayerSprite # Oyuncunun görseli
@onready var player_collider: CollisionShape2D = $PlayerCollider # Oyuncunun ana çarpışma şekli
@onready var player_area: Area2D = $PlayerArea # Köpek veya toplanabilir öğeleri algılamak için alan
@onready var progress_bar: ProgressBar = $ProgressBar # Stamina göstermek için progress bar
#endregion

#region FSM Durumları
# Oyuncunun içinde bulunabileceği durumlar (Finite State Machine)
enum State {
	IDLE, # Durma durumu
	WALK_RUN, # Yürüme/Koşma durumu
	JUMP, # Zıplama durumu
	STUNNED # Sersemleme durumu (engele çarpınca)
}
var current_state: State = State.IDLE # Oyuncunun mevcut durumu
var stun_timer: float = 0.0 # Sersemleme durumu için zamanlayıcı
#endregion

#region Oyuncu Durum Değişkenleri
var current_stamina: float # Mevcut dayanıklılık
var input_direction: float = 0.0 # -1: geri, 1: ileri, 0: yatay hareket yok
var action_forward: String # İleri hareket input aksiyon adı
var action_backward: String # Geri hareket input aksiyon adı
var action_jump: String # Zıplama input aksiyon adı
#endregion

func _ready():
	# Başlangıç dayanıklılığını maksimuma ayarla
	current_stamina = max_stamina
	
	# Progress Bar'ın başlangıç ayarları
	progress_bar.max_value = max_stamina
	progress_bar.min_value = 0
	progress_bar.value = current_stamina
	
	# Player ID'ye göre input aksiyonlarını ayarla
	# Godot'un Proje Ayarları -> Input Map bölümünden bu aksiyonları tanımlamalısınız.
	if player_id == 1:
		action_forward = "player1_forward"
		action_backward = "player1_backward"
		action_jump = "player1_jump"
		# Player 1'e özel sprite veya animasyon ayarları burada yapılabilir.
		# Örneğin: sprite.texture = preload("res://player1_visual.png")
	elif player_id == 2:
		action_forward = "player2_forward"
		action_backward = "player2_backward"
		action_jump = "player2_jump"
		# Player 2'ye özel sprite veya animasyon ayarları burada yapılabilir.
		# Örneğin: sprite.texture = preload("res://player2_visual.png")
	
	# Oyun başladığında oyuncuyu IDLE (durma) durumuna ayarla
	set_state(State.IDLE)

func _physics_process(delta):
	# Yer çekimi her zaman uygulanır (zıplarken veya düşerken)
	velocity.y += gravity * delta
	
	# FSM (Sonlu Durum Makinesi) yapısına göre mevcut durumu işle
	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		State.WALK_RUN:
			handle_walk_run_state(delta)
		State.JUMP:
			handle_jump_state(delta)
		State.STUNNED:
			handle_stunned_state(delta)
	
	# Hareket ve çarpışma algılamayı uygula
	move_and_slide()
	
	# Engellere çarpışmaları kontrol et (durumdan bağımsız)
	check_obstacle_collisions()
	
	# Progress Bar'ı güncel tut
	progress_bar.value = current_stamina

# Yeni bir duruma geçişi yöneten fonksiyon
func set_state(new_state: State):
	# Eğer zaten aynı durumdaysak, hiçbir şey yapma
	if current_state == new_state: 
		return
	
	# Durumdan çıkış mantığı (isteğe bağlı, önceki durumu temizlemek için)
	match current_state:
		State.STUNNED:
			stun_timer = 0.0 # Sersemleme bitince zamanlayıcıyı sıfırla
			# Sersemleme animasyonunu durdurma veya normal animasyona geçiş
		_:
			pass # Diğer durumlar için özel çıkış mantığı yok
			
	# Mevcut durumu yeni duruma ayarla
	current_state = new_state
	
	# Yeni duruma giriş mantığı (isteğe bağlı, yeni durumu başlatmak için)
	match current_state:
		State.IDLE:
			# Sprite animasyonunu IDLE (boşta) olarak ayarla
			# print("Oyuncu %d: IDLE durumunda" % player_id)
			pass
		State.WALK_RUN:
			# Sprite animasyonunu Yürüme/Koşma olarak ayarla
			# print("Oyuncu %d: WALKING/RUNNING durumunda" % player_id)
			pass
		State.JUMP:
			# Sprite animasyonunu Zıplama olarak ayarla
			# print("Oyuncu %d: JUMP durumunda" % player_id)
			pass
		State.STUNNED:
			stun_timer = stun_duration # Sersemleme süresini başlat
			velocity.x = 0 # Sersemlenince yatay hızı sıfırla
			# Sprite animasyonunu STUNNED (sersemlemiş) olarak ayarla
			# print("Oyuncu %d: STUNNED durumunda" % player_id)
			pass

# IDLE (durma) durumunu yöneten fonksiyon
func handle_idle_state(delta):
	handle_horizontal_input() # Yatay inputu kontrol et
	handle_stamina_regen(delta) # Dayanıklılığı yenile (sadece IDLE durumunda)
	
	# Durum geçişleri
	if input_direction != 0: # Yatay hareket inputu varsa
		set_state(State.WALK_RUN)
	elif Input.is_action_just_pressed(action_jump) and is_on_floor(): # Zıplama inputu ve yerdeyse
		velocity.y = jump_speed # Zıplama hızını uygula
		set_state(State.JUMP) # Zıplama durumuna geç
	
	velocity.x = 0 # IDLE durumunda yatay hızı sıfırla (yerde sabit kal)

# WALK_RUN (yürüme/koşma) durumunu yöneten fonksiyon
func handle_walk_run_state(delta):
	handle_horizontal_input() # Yatay inputu kontrol et
	
	# Stamina'ya bağlı olarak hareket hızını hesapla.
	# Stamina azaldıkça hareket hızı azalır, ancak 'move_speed'in %20'sinden az olamaz.
	var stamina_ratio = current_stamina / max_stamina
	var current_base_speed = lerp(move_speed * 0.2, move_speed, stamina_ratio)
	
	var current_speed = current_base_speed
	
	# İleri giderken ve dayanıklılık varken koşma/sprint yap
	if input_direction == 1 and current_stamina > 0:
		current_speed *= sprint_speed_multiplier
	# Not: Stamina bittiğinde sprint yapma durumu 'current_base_speed' tarafından zaten kontrol ediliyor.

	# Hareket varken (ileri veya geri), stamina harca
	if input_direction != 0: # Eğer hareket ediyorsak (ileri veya geri)
		current_stamina -= stamina_drain_rate * delta
		current_stamina = max(0, current_stamina) # Dayanıklılık 0'ın altına düşmesin
	
	velocity.x = input_direction * current_speed # Yatay hızı uygula
	
	# Durum geçişleri
	if input_direction == 0: # Yatay hareket inputu yoksa
		set_state(State.IDLE) # IDLE durumuna geç
	elif Input.is_action_just_pressed(action_jump) and is_on_floor(): # Zıplama inputu ve yerdeyse
		velocity.y = jump_speed # Zıplama hızını uygula (jump_speed stamina'dan etkilenmiyor)
		set_state(State.JUMP) # Zıplama durumuna geç

# JUMP (zıplama) durumunu yöneten fonksiyon
func handle_jump_state(delta):
	handle_horizontal_input() # Zıplarken de yatay hareket kontrolü
	
	# Zıplarken yatay hareket hızını uygula (bu hız stamina'dan etkilenmez, orijinal move_speed kullanılır)
	velocity.x = input_direction * move_speed
	
	# Zıplama eyleminin kendisi stamina harcasın
	current_stamina -= stamina_drain_rate * delta # Zıplarken stamina harca
	current_stamina = max(0, current_stamina) # Dayanıklılık 0'ın altına düşmesin
	
	# Durum geçişleri
	if is_on_floor(): # Yere değerse
		if input_direction != 0: # Hala yatay hareket inputu varsa
			set_state(State.WALK_RUN) # Yürüme/Koşma durumuna geç
		else:
			set_state(State.IDLE) # Yoksa IDLE durumuna geç

# STUNNED (sersemleme) durumunu yöneten fonksiyon
func handle_stunned_state(delta):
	stun_timer -= delta # Zamanlayıcıyı azalt
	if stun_timer <= 0: # Sersemleme süresi bittiyse
		set_state(State.IDLE) # IDLE durumuna geri dön (veya inputa göre WALK_RUN)
	# Sersemlemişken hareket yok, velocity.x zaten set_state içinde 0'a çekildi.

# Yatay inputu işleyen ve sprite yönünü ayarlayan fonksiyon
func handle_horizontal_input():
	input_direction = 0.0
	if Input.is_action_pressed(action_forward):
		input_direction += 1.0
		sprite.flip_h = false # Sprite'ı sağa döndür
	if Input.is_action_pressed(action_backward):
		input_direction -= 1.0
		sprite.flip_h = true # Sprite'ı sola döndür

# Sadece stamina yenilenmesini yöneten yardımcı fonksiyon (sadece IDLE durumunda çağrılmalı)
func handle_stamina_regen(delta):
	current_stamina += stamina_regen_rate * delta
	current_stamina = min(max_stamina, current_stamina) # Stamina maksimumu geçmesin

# Engellere çarpışmaları kontrol eden fonksiyon
func check_obstacle_collisions():
	# CharacterBody2D'nin çarptığı tüm kayan çarpışmaları kontrol et
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		# Çarptığımız objenin bir TileMap olup olmadığını kontrol et
		if collision.get_collider() and collision.get_collider() is TileMap:
			# Eğer zaten sersemlemiş değilsek, sersemleme durumuna geç
			if current_state != State.STUNNED:
				set_state(State.STUNNED)
			break # Aynı karede birden fazla çarpışma olsa bile sadece ilkini işle
