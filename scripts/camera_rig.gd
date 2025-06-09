# KameraSistemi.gd
extends Node2D

#region Kamera Ayarları
@export_group("Takip ve Yumuşatma")
@export var smoothing_speed: float = 5.0 # Kamera hareketlerinin ve zoom'un yumuşaklık hızı.
# YENİ: Kameranın dikey konumunu ayarlamak için bir ofset değişkeni.
# Negatif değerler kamerayı yukarı kaydırır.
@export var vertical_offset: float = -80.0

@export_group("Zoom Ayarları")
# Kameranın en fazla ne kadar UZAKLAŞABİLECEĞİ sınırı (daha küçük sayı = daha uzak).
@export var min_zoom_level: float = 0.7
# Kameranın en fazla ne kadar YAKINLAŞABİLECEĞİ sınırı (daha büyük sayı = daha yakın).
@export var max_zoom_level: float = 1.5
# Oyuncular ile ekran kenarı arasındaki boşluk oranı.
@export var zoom_margin: float = 1.2
#endregion

# Takip edilecek oyuncular
var targets: Array = []

# Hazır Nodelar
@onready var camera_2d: Camera2D = $Camera2D
@onready var wall_left: StaticBody2D = $InvisibleWalls/WallLeft
@onready var wall_right: StaticBody2D = $InvisibleWalls/WallRight
@onready var wall_top: StaticBody2D = $InvisibleWalls/WallTop
@onready var wall_bottom: StaticBody2D = $InvisibleWalls/WallBottom


func _ready():
	targets = get_tree().get_nodes_in_group("players")
	camera_2d.zoom = Vector2(min_zoom_level, min_zoom_level)

func _physics_process(delta):
	# Düzeltme: Oyuncuları bulana kadar aramaya devam et.
	if targets.size() < 2:
		targets = get_tree().get_nodes_in_group("players")
		handle_single_target(delta)
		return

	# Hedef pozisyonu ve zoom'u hesapla
	var bounding_box = get_targets_bounding_box()
	var target_position = bounding_box.get_center()
	
	# YENİ: Dikey ofseti hedef pozisyona ekle.
	target_position.y += vertical_offset
	
	var target_zoom = calculate_target_zoom(bounding_box)

	# Kamera pozisyonunu ve zoom'unu yumuşak bir geçişle (lerp) güncelle
	global_position = global_position.lerp(target_position, smoothing_speed * delta)
	camera_2d.zoom = camera_2d.zoom.lerp(Vector2(target_zoom, target_zoom), smoothing_speed * delta)
	
	# Görünmez duvarları kamera sınırlarına göre güncelle
	update_invisible_walls()


# Sadece bir oyuncu varsa veya hiç yoksa kameranın davranışını yönetir
func handle_single_target(delta):
	if targets.is_empty(): return
	
	var target_position = targets[0].global_position
	
	# YENİ: Dikey ofseti tek oyuncu modunda da uygula.
	target_position.y += vertical_offset

	var target_zoom = clamp(1.0, min_zoom_level, max_zoom_level)
	
	global_position = global_position.lerp(target_position, smoothing_speed * delta)
	camera_2d.zoom = camera_2d.zoom.lerp(Vector2(target_zoom, target_zoom), smoothing_speed * delta)
	update_invisible_walls()


# Tüm hedefleri çevreleyen bir sınırlayıcı kutu (bounding box) döndürür
func get_targets_bounding_box() -> Rect2:
	var bounding_box = Rect2(targets[0].global_position, Vector2.ZERO)
	for i in range(1, targets.size()):
		bounding_box = bounding_box.expand(targets[i].global_position)
	return bounding_box


# Verilen sınırlayıcı kutuya göre ideal zoom seviyesini hesaplar
func calculate_target_zoom(bounding_box: Rect2) -> float:
	var viewport_size = get_viewport_rect().size
	var required_size = bounding_box.size * zoom_margin
	
	var view_size_at_max_zoom = viewport_size / max_zoom_level
	if required_size.x < view_size_at_max_zoom.x and required_size.y < view_size_at_max_zoom.y:
		return max_zoom_level

	var zoom_ratio_x = viewport_size.x / required_size.x
	var zoom_ratio_y = viewport_size.y / required_size.y

	var target_zoom = min(zoom_ratio_x, zoom_ratio_y)

	return clamp(target_zoom, min_zoom_level, max_zoom_level)


# Görünmez duvarları kamera görüş alanının kenarlarına yerleştirir
func update_invisible_walls():
	var view_size = get_viewport_rect().size / camera_2d.zoom
	var view_half_width = view_size.x / 2
	var view_half_height = view_size.y / 2
	var thickness = 10.0
	
	wall_left.position.x = -view_half_width - thickness / 2
	wall_left.get_child(0).shape.size = Vector2(thickness, view_size.y)
	
	wall_right.position.x = view_half_width + thickness / 2
	wall_right.get_child(0).shape.size = Vector2(thickness, view_size.y)
	
	wall_top.position.y = -view_half_height - thickness / 2
	wall_top.get_child(0).shape.size = Vector2(view_size.x, thickness)
	
	wall_bottom.position.y = view_half_height + thickness / 2
	wall_bottom.get_child(0).shape.size = Vector2(view_size.x, thickness)
