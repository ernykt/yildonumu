# Main.gd
extends Node2D

@onready var kopek: CharacterBody2D = $Kopek
@onready var count_down: Label = $CountDown
@onready var i = 1
# YENİ: Efektin görünümünü Inspector'dan kolayca ayarlamak için grup ve yeni değişkenler eklendi.
@export_group("Duman Efekti Ayarları")
# Dumanın, engelin merkezine göre nerede çıkacağı.
@export var smoke_offset: Vector2 = Vector2(0, 0)
# Dumanın ne kadar yukarı yükseleceği (negatif değer = yukarı).
@export var smoke_rise_amount: float = -100.0
# Duman efektinin toplam süresi (saniye).
@export var smoke_duration: float = 1.5

const SMOKE_EFFECT = preload("res://scenes/smoke_effect.tscn")

# Oyun başladığında sinyali dinlemek için bağlantı kur.
func _ready():
	get_tree().paused = true
	kopek.obstacle_destroyed.connect(_on_kopek_obstacle_destroyed)


# Sinyal alındığında çalışacak olan fonksiyon.
func _on_kopek_obstacle_destroyed(obstacle_position: Vector2):
	# Duman efekti sahnesinden yeni bir kopya (instance) oluştur.
	var smoke_instance = SMOKE_EFFECT.instantiate()
	
	# Duman efektinin başlangıç pozisyonunu ayarla.
	smoke_instance.global_position = obstacle_position + smoke_offset
	
	# Duman efektini ana sahneye ekle ki görünür olsun ve animasyon çalışabilsin.
	add_child(smoke_instance)
	
	# YENİ: Duman efektini canlandırmak için bir Tween oluştur.
	var tween = create_tween()
	
	# Tween'in paralel çalışmasını sağla, böylece yükselme ve kaybolma aynı anda olur.
	tween.set_parallel()
	
	# 1. Animasyon: Pozisyonu değiştir (yukarı yükselt).
	# Dumanı mevcut pozisyonundan 'smoke_rise_amount' kadar yukarı taşı.
	tween.tween_property(smoke_instance, "position", smoke_instance.position + Vector2(0, smoke_rise_amount), smoke_duration)\
		.set_ease(Tween.EASE_OUT) # Animasyonun sonunda yavaşlamasını sağlar.

	# 2. Animasyon: Görünürlüğü azalt (kaybolmasını sağla).
	# Dumanın rengini (modulate), alfasını 0 yaparak tamamen şeffaf hale getir.
	tween.tween_property(smoke_instance, "modulate", Color(1, 1, 1, 0), smoke_duration)
	
	# Animasyon bittiğinde, duman nesnesini sahneden silerek belleği temizle.
	tween.finished.connect(smoke_instance.queue_free)

func _on_count_down_timer_timeout() -> void:
	if i <= 3:
		count_down.text = str(i)
		i += 1
	else:
		get_tree().paused = false
		count_down.visible = false
