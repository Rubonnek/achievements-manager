extends Node

@export var status_label : Label

var manager := AchievementsManager.new()
var save_path := "user://achievements_save.cfg"

func _ready() -> void:
	# Add some achievements
	manager.add_achievement("First Steps", "Take your first steps in the game", "", 1, false)
	manager.add_achievement("Explorer", "Discover 10 locations", "", 10, false)
	manager.add_achievement("Master", "Reach level 50", "", 1,true)

	print("Achievements added.")
	print("Press S to save, L to load, U to unlock an achievement.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S:
			save_achievements()
		elif event.keycode == KEY_L:
			load_achievements()
		elif event.keycode == KEY_U:
			unlock_random_achievement()

func save_achievements() -> void:
	var config := ConfigFile.new()
	config.set_value("achievements", "data", manager.get_data())
	var err := config.save(save_path)
	if err == OK:
		print("Achievements saved to ", save_path)
		status_label.text = "Achievements saved!"
	else:
		print("Failed to save achievements.")
		status_label.text = "Save failed!"

func load_achievements() -> void:
	var config := ConfigFile.new()
	var err := config.load(save_path)
	if err == OK:
		var data = config.get_value("achievements", "data", [])
		manager.set_data(data)
		print("Achievements loaded from ", save_path)
		status_label.text = "Achievements loaded!\nUnlocked: " + str(manager.get_unlocked_count()) + "/" + str(manager.get_total_count())
	else:
		print("Failed to load save file.")
		status_label.text = "Load failed!"

func unlock_random_achievement() -> void:
	var ids := manager.get_all_achievement_ids()
	if ids.is_empty():
		return
	var random_id := ids[randi() % ids.size()]
	if not manager.is_achievement_unlocked(random_id):
		manager.unlock_achievement(random_id)
		print("Unlocked achievement: ", manager.get_achievement_name(random_id))
		status_label.text = "Unlocked: " + manager.get_achievement_name(random_id)
	else:
		print("Achievement already unlocked.")
		status_label.text = "Already unlocked."
