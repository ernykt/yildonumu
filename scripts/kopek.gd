# Kopek.gd
extends CharacterBody2D

@export var move_speed: float = 600.0 # Köpeğin hızı

@onready var kopek_area: Area2D = $KopekArea

func _ready():
	# KopekArea'nın body_entered sinyalini bir fonksiyona bağla
	# Bu, alana bir fiziksel nesne girdiğinde tetiklenir.
	kopek_area.body_entered.connect(_on_kopek_area_body_entered)

func _physics_process(delta):
	# Sürekli olarak sağa doğru hareket et
	velocity.x = move_speed
	move_and_slide()

# KopekArea'nın algılama alanına bir nesne girdiğinde bu fonksiyon çalışır.
func _on_kopek_area_body_entered(body):
	# Eğer giren nesne "obstacles" grubundaysa veya katmanındaysa
	# Onu yok et (sahneden sil).
	# Not: Engellerin ya "obstacles" grubunda olması ya da 4. fizik katmanında
	# olması gerekir. Katman ayarını zaten yaptık.
	if body.get_collision_layer_value(3): # Layer 4'ün value'su 8'dir (2^3). Layer 1:1, 2:2, 3:4, 4:8
		# Düzeltme: Godot'ta layer'lar bit flag olarak çalışır. 4. katman 2^(4-1) = 8 değerine sahiptir.
		# get_collision_layer_value(n-1) olarak kontrol edilir.
		body.queue_free()
