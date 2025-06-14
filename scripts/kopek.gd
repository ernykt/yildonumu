# Kopek.gd
extends CharacterBody2D

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

@export var move_speed: float = 600.0 # Köpeğin hızı
# Not: Sinyal editörden bağlandığı için _ready() fonksiyonuna gerek yoktur.
signal obstacle_destroyed(position: Vector2)

func _ready() -> void:
	audio_stream_player_2d.play()

func _physics_process(delta):
	# Sürekli olarak sağa doğru hareket et.
	velocity.x = move_speed
	move_and_slide()

# KopekArea'nın algılama alanına bir nesne girdiğinde bu fonksiyon çalışır.
func _on_kopek_area_body_entered(body):
	# ÖNEMLİ: Bu fonksiyonun çalışması için KopekArea'nın Collision -> Mask
	# ayarında "players" (Layer 2) ve "obstacles" (Layer 4) katmanlarının
	# işaretli olması gerekir.

	# Kontrol 1: Giren nesne bir oyuncu mu? (Grup kontrolü en sağlıklısıdır)
	var is_player = body.is_in_group("players")

	# Kontrol 2: Giren nesne bir engel mi? (Layer 4)
	# Godot'ta katmanlar 0'dan başladığı için 4. katman 3. index'e denk gelir.
	var is_obstacle = body.is_in_group("obstacle")

	# Eğer nesne bir oyuncu VEYA bir engel ise...
	if is_player or is_obstacle:
		if is_obstacle:
			obstacle_destroyed.emit(body.global_position)
			body.call_deferred("queue_free")
		if is_player:
			get_tree().reload_current_scene()
