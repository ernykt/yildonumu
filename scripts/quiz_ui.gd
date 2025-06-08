# Quiz.gd
extends Control

# Quiz sorularımızı ve cevaplarımızı tutan veri yapısı.
# Yeni soruları buraya ekleyerek quiz'i kolayca genişletebilirsin.
var quiz_data = [
	{
		"question": "Türkiye'nin başkenti neresidir?",
		"options": ["İstanbul", "Ankara", "İzmir"],
		"correct_answer_index": 1 # Ankara'nın index'i (0'dan başlar)
	},
	{
		"question": "Godot Engine'in ana programlama dili nedir?",
		"options": ["C#", "GDScript", "Python"],
		"correct_answer_index": 1
	},
	{
		"question": "Oyundaki sarı saçlı karakterin adı nedir?",
		"options": ["Elif", "Ayşe", "Eren"],
		"correct_answer_index": 0
	},
	{
		"question": "Bu oyunun adı nedir?",
		"options": ["Yıldönümü Macerası", "Kaçış", "Koşu"],
		"correct_answer_index": 0
	}
]

# Arayüz elemanlarına referanslar
@onready var question_label: Label = $MarginContainer/VBoxContainer/QuestionLabel
@onready var answer_button_1: Button = $MarginContainer/VBoxContainer/AnswerButton1
@onready var answer_button_2: Button = $MarginContainer/VBoxContainer/AnswerButton2
@onready var answer_button_3: Button = $MarginContainer/VBoxContainer/AnswerButton3
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var next_question_button: Button = $MarginContainer/VBoxContainer/NextQuestionButton

# Quiz'in durumunu takip eden değişkenler
var current_question_index = 0
var score = 0
var answer_buttons = [] # Butonları bir listede tutmak yönetimi kolaylaştırır

func _ready():
	# Butonları listeye ekle
	answer_buttons = [answer_button_1, answer_button_2, answer_button_3]

	# Butonların "pressed" sinyallerini, hangi butona basıldığını bilecek şekilde bağlıyoruz.
	# .bind(index) metodu, sinyal tetiklendiğinde fonksiyona ekstra bir argüman göndermemizi sağlar.
	answer_button_1.pressed.connect(_on_answer_button_pressed.bind(0))
	answer_button_2.pressed.connect(_on_answer_button_pressed.bind(1))
	answer_button_3.pressed.connect(_on_answer_button_pressed.bind(2))
	
	next_question_button.pressed.connect(_on_next_question_button_pressed)

	# Quiz'i başlat
	start_quiz()

# Quiz'i sıfırlar ve ilk soruyu yükler
func start_quiz():
	score = 0
	current_question_index = 0
	display_question(current_question_index)

# Belirtilen index'teki soruyu ve seçenekleri ekrana yazar
func display_question(index):
	# UI elemanlarını başlangıç durumuna getir
	feedback_label.hide()
	next_question_button.hide()
	
	# Butonları tekrar tıklanabilir yap
	for button in answer_buttons:
		button.disabled = false
		
	# Soruyu ve seçenekleri etiketlere ve butonlara yazdır
	var question_data = quiz_data[index]
	question_label.text = question_data["question"]
	answer_button_1.text = question_data["options"][0]
	answer_button_2.text = question_data["options"][1]
	answer_button_3.text = question_data["options"][2]

# Bir cevap butonuna basıldığında bu fonksiyon çalışır
func _on_answer_button_pressed(button_index):
	# Cevap verdikten sonra diğer butonlara basılmasını engelle
	for button in answer_buttons:
		button.disabled = true

	# Seçilen cevabın doğru olup olmadığını kontrol et
	var correct_index = quiz_data[current_question_index]["correct_answer_index"]
	
	if button_index == correct_index:
		# Cevap doğruysa
		feedback_label.text = "Doğru!"
		feedback_label.modulate = Color.GREEN # Rengi yeşil yap
		score += 1
	else:
		# Cevap yanlışsa
		feedback_label.text = "Yanlış! Doğru cevap: " + quiz_data[current_question_index]["options"][correct_index]
		feedback_label.modulate = Color.RED # Rengi kırmızı yap
	
	# Geri bildirim etiketini ve "Sonraki Soru" butonunu göster
	feedback_label.show()
	next_question_button.show()

# "Sonraki Soru" butonuna basıldığında bu fonksiyon çalışır
func _on_next_question_button_pressed():
	current_question_index += 1
	
	# Hala gösterilecek soru var mı diye kontrol et
	if current_question_index < quiz_data.size():
		display_question(current_question_index)
	else:
		# Quiz bittiyse, sonucu göster
		show_final_score()

# Quiz bittiğinde nihai sonucu gösterir
func show_final_score():
	# Tüm quiz elemanlarını gizle
	for button in answer_buttons:
		button.hide()
	next_question_button.hide()
	feedback_label.hide()
	
	# Sonuç mesajını göster
	question_label.text = "Quiz Bitti! \nSkorun: %d / %d" % [score, quiz_data.size()]
