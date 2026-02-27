#============================================================================
#  achievement_entry.gd                                                     |
#============================================================================
#                         This file is part of:                             |
#                       ACHIEVEMENTS MANAGER                                |
#============================================================================
# Copyright (c) 2025 Wilson Enrique Alvarez Torres                          |
#                                                                           |
# Permission is hereby granted, free of charge, to any person obtaining     |
# a copy of this software and associated documentation files (the           |
# "Software"), to deal in the Software without restriction, including       |
# without limitation the rights to use, copy, modify, merge, publish,       |
# distribute, sublicense, and/or sell copies of the Software, and to        |
# permit persons to whom the Software is furnished to do so, subject to     |
# the following conditions:                                                 |
#                                                                           |
# The above copyright notice and this permission notice shall be            |
# included in all copies or substantial portions of the Software.           |
#                                                                           |
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,           |
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF        |
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    |
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      |
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      |
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         |
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    |
#============================================================================
extends RefCounted

## High-level wrapper for accessing and modifying achievement data.
##
## This class provides a convenient object-oriented interface for working with individual achievements
## in the [AchievementsManager]. It wraps the internal dictionary storage with type-safe getters and
## setters, while maintaining direct reference to the underlying data - meaning all changes are
## immediately reflected in the manager's storage without additional synchronization.[br]
## [br]
## [b]Key Features:[/b][br]
## - Direct manipulation of achievement properties (name, description, icon, etc.)[br]
## - Instant unlocking with [method unlock][br]
## - Built-in progress tracking[br]
## - Custom metadata storage for extended properties[br]
## - Weak reference to parent manager for signal emission[br]
## [br]
## [b]Usage:[/b][br]
## [codeblock]
## # Obtain an entry from the manager
## var entry = manager.get_achievement_entry(achievement_id)
##
## # Read properties
## print(entry.get_name())
##
## # Modify properties
## entry.set_name("Updated Name")
##
## # Progress tracking
## entry.set_progress(5, 10)  # Set current to 5, max to 10
## entry.add_progress(1)  # Add 1 to progress
## var current_progress = entry.get_progress_current()
## var max_progress = entry.get_progress_max()
## if entry.is_progress_complete():
##     entry.unlock()
##
## # Custom metadata
## entry.set_metadata("category", "combat")
## var category = entry.get_metadata("category")
## [/codeblock]
class_name AchievementEntry

## Emitted when [method set_updated] is called.
signal achievement_unlocked(p_achievement_entry: AchievementEntry)

## Emitted when [method set_updated] is called.
signal achievement_updated(p_achievement_entry: AchievementEntry)

# Enum representing the field indices for achievement data storage.[br]
# Used by [AchievementsManager] to efficiently store and retrieve achievement properties.[br]
# [b]Note:[/b] ID is not stored in the dictionary - it's the array index in AchievementsManager.
enum _key {
	NAME, # Display name of the achievement
	DESCRIPTION, # Achievement description
	HIDDEN, # Whether the achievement should be hidden until unlocked
	UNLOCKED, # Whether the achievement is unlocked (runtime state)
	STRING_ID, # String identifier for interfacing with external achievement systems
	ICON, # Icon texture for the achievement
	PROGRESS_CURRENT, # Current progress value
	PROGRESS_MAX, # Maximum progress value
	METADATA, # Additional arbitrary metadata storage
}

# Reference to the internal dictionary storing achievement data.
var _data: Dictionary

# The achievement ID (array index in AchievementsManager).
var _id: int

# Weak reference to the achievements manager for signal emission.
var _manager_ref: WeakRef


# Initializes a new achievement entry.[br]
# [br]
# [b]For internal use by AchievementsManager.[/b] Use [method AchievementsManager.get_achievement_entry]
# to obtain an [AchievementEntry] instance.[br]
# [br]
# [param p_id]: The achievement ID (array index).[br]
# [param p_data]: Dictionary reference containing achievement data indexed by [enum _key] values.[br]
# [param p_manager]: Reference to the AchievementsManager instance.
func _init(p_id: int, p_data: Dictionary, p_manager: AchievementsManager = null) -> void:
	_id = p_id
	_data = p_data
	if is_instance_valid(p_manager):
		_manager_ref = weakref(p_manager)
	else:
		assert(false, "AchievementEntry: should not be instantiated without an associated AchievementsManager")


## Gets the unique identifier for this achievement.[br]
## [br]
## [b]Returns:[/b] The achievement ID (array index).
func get_id() -> int:
	return _id


## Gets the display name of the achievement.[br]
## [br]
## [b]Returns:[/b] The achievement name.
func get_name() -> String:
	var name: String = _data.get(_key.NAME, "")
	return name


## Sets the display name of the achievement.[br]
## [br]
## [param p_name]: The new achievement name.
func set_name(p_name: String) -> void:
	_data[_key.NAME] = p_name
	__send_entry_to_manager_viewer()


## Returns the achievement description.[br]
func get_description() -> String:
	var description: String = _data.get(_key.DESCRIPTION, "")
	return description


## Sets the description explaining how to unlock the achievement.[br]
## [br]
## [param p_description]: The new achievement description.
func set_description(p_description: String) -> void:
	_data[_key.DESCRIPTION] = p_description
	__send_entry_to_manager_viewer()


## Gets whether this achievement should be hidden until unlocked.[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if hidden, [code]false[/code] otherwise.
func is_hidden() -> bool:
	var is_visible: bool = _data.get(_key.HIDDEN, false)
	return is_visible


## Sets whether this achievement should be hidden until unlocked.[br]
## [br]
## [param p_hide]: [code]true[/code] to hide, [code]false[/code] to show.
func set_hidden(p_hide: bool) -> void:
	_data[_key.HIDDEN] = p_hide
	__send_entry_to_manager_viewer()


## Gets whether this achievement is currently unlocked.[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if unlocked, [code]false[/code] otherwise.
func is_unlocked() -> bool:
	var unlocked: bool = _data.get(_key.UNLOCKED, false)
	return unlocked


## Sets whether this achievement is currently unlocked.[br]
## [br]
## [param p_is_unlocked]: [code]true[/code] to unlock, [code]false[/code] to lock.
func set_unlocked(p_is_unlocked: bool) -> void:
	if p_is_unlocked and not _data.get(_key.UNLOCKED, false):
		_data[_key.UNLOCKED] = true
		achievement_unlocked.emit(self)
	elif not p_is_unlocked:
		var _success: bool = _data.erase(_key.UNLOCKED)
	__send_entry_to_manager_viewer()


## Gets the string identifier for this achievement.[br]
## [br]
## Used for interfacing with external achievement systems (e.g., Steam, Epic Games).[br]
## [br]
## [b]Returns:[/b] The achievement string ID.
func get_string_id() -> String:
	var string_id: String = _data.get(_key.STRING_ID, "")
	return string_id


## Sets the string identifier for this achievement.[br]
## [br]
## Used for interfacing with external achievement systems (e.g., Steam, Epic Games).[br]
## [br]
## [param p_string_id]: The new achievement string ID.
func set_string_id(p_string_id: String) -> void:
	_data[_key.STRING_ID] = p_string_id
	__send_entry_to_manager_viewer()


## Gets the icon texture for this achievement.[br]
## [br]
## [b]Returns:[/b] The achievement icon texture, or [code]null[/code] if not set.
func get_icon() -> Texture2D:
	var icon: Texture2D = _data.get(_key.ICON, null)
	return icon


## Sets the icon texture for this achievement.[br]
## [br]
## [param p_icon]: The new achievement icon texture.
func set_icon(p_icon: Texture2D) -> void:
	_data[_key.ICON] = p_icon
	__send_entry_to_manager_viewer()


## Gets the current progress value for this achievement.[br]
## [br]
## [b]Returns:[/b] The current progress value, or 0 if not set.
func get_progress_current() -> int:
	var current: int = _data.get(_key.PROGRESS_CURRENT, 0)
	if OS.is_debug_build():
		var max_progress: int = _data.get(_key.PROGRESS_MAX, 1)
		if current > max_progress:
			push_warning("AchievementEntry: current progress is greater than max progress. This should not happen.")
	return current


## Sets the current progress value for this achievement.[br]
## [br]
## [param p_current]: The new current progress value.
func set_progress_current(p_current: int) -> void:
	var max_progress: int = _data.get(_key.PROGRESS_MAX, 1)
	p_current = mini(p_current, max_progress)
	_data[_key.PROGRESS_CURRENT] = p_current
	__send_entry_to_manager_viewer()


## Gets the maximum progress value for this achievement.[br]
## [br]
## [b]Returns:[/b] The maximum progress value, or 0 if not set.
func get_progress_max() -> int:
	var max_progress: int = _data.get(_key.PROGRESS_MAX, 1)
	if OS.is_debug_build():
		var current: int = _data.get(_key.PROGRESS_CURRENT, 1)
		if current > max_progress:
			push_warning("AchievementEntry: current progress is greater than max progress. This should not happen.")
	return max_progress


## Sets the maximum progress value for this achievement.[br]
## [br]
## [param p_new_max]: The new maximum progress value.
func set_progress_max(p_new_max: int) -> void:
	_data[_key.PROGRESS_MAX] = p_new_max
	var current: int = _data.get(_key.PROGRESS_CURRENT, 0)
	if OS.is_debug_build():
		if current > p_new_max:
			push_warning("AchievementEntry: new max progress value is less than current progress value. Achievement will be unlocked automatically and current value will be clamped. Was this intended?")
	current = mini(current, p_new_max)
	if current != 0:
		_data[_key.PROGRESS_CURRENT] = current
	__send_entry_to_manager_viewer()


## Sets both the current and maximum progress values for this achievement.[br]
## [br]
## [param p_current]: The current progress value.[br]
## [param p_max]: The maximum progress value.
func set_progress(p_current: int, p_max: int) -> void:
	if OS.is_debug_build():
		if p_current > p_max:
			push_warning("AchievementEntry: current achievement progress should be less or equal to the max possible progress. Automatically fixing.")
	p_current = mini(p_current, p_max)
	_data[_key.PROGRESS_CURRENT] = p_current
	_data[_key.PROGRESS_MAX] = p_max
	__send_entry_to_manager_viewer()


## Helper function for progressing an achievement without exceeding the maximum progress.[br]
## [br]
## [param p_amount]: The amount to add to the progress.
func add_progress(p_amount: int = 1) -> void:
	var current: int = get_progress_current()
	set_progress_current(current + p_amount)


## Checks if the achievement progress is complete (current >= max).[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if progress is complete, [code]false[/code] otherwise.
func is_progress_complete() -> bool:
	var current: int = get_progress_current()
	var max_progress: int = get_progress_max()
	return current >= max_progress


## Sets a metadata value for this achievement.[br]
## [br]
## Metadata can store arbitrary key-value pairs for custom achievement data.[br]
## [br]
## [param p_key]: The metadata key.[br]
## [param p_value]: The metadata value.
func set_metadata(p_key: Variant, p_value: Variant) -> void:
	var metadata: Dictionary = _data.get(_key.METADATA, { })
	metadata[p_key] = p_value
	if not _data.has(_key.METADATA):
		_data[_key.METADATA] = metadata
	__send_entry_to_manager_viewer()


## Gets a metadata value from this achievement.[br]
## [br]
## [param p_key]: The metadata key to retrieve.[br]
## [param p_default_value]: The default value to return if the key doesn't exist.[br]
## [br]
## [b]Returns:[/b] The metadata value, or the default value if not found.
func get_metadata(p_key: Variant, p_default_value: Variant = null) -> Variant:
	var metadata: Dictionary = _data.get(_key.METADATA, { })
	var value: Variant = metadata.get(p_key, p_default_value)
	return value


## Gets a reference to the internal metadata dictionary.[br]
## [br]
## [b]Returns:[/b] The metadata dictionary, or empty dictionary if not set.[br]
## [br]
## [color=yellow]Warning:[/color] Returns a reference to the internal dictionary. Modifying it will modify the metadata directly.
func get_metadata_data() -> Dictionary:
	var metadata: Dictionary = _data.get(_key.METADATA, { })
	if not _data.has(_key.METADATA):
		# Store a reference so external modifications update the entry automatically
		_data[_key.METADATA] = metadata
	return metadata


## Checks if this achievement has any metadata.[br]
## [br]
## [b]Returns:[/b] [code]true[/code] if metadata exists and is not empty, [code]false[/code] otherwise.
func has_metadata() -> bool:
	var metadata: Dictionary = _data.get(_key.METADATA, { })
	var has_data: bool = not metadata.is_empty()
	return has_data


## Gets the weak reference to the achievements manager.[br]
## [br]
## [b]Returns:[/b] WeakRef to the manager, or [code]null[/code] if not set.
func get_manager_ref() -> WeakRef:
	return _manager_ref


## Gets the achievements manager instance if still valid.[br]
## [br]
## [b]Returns:[/b] The AchievementsManager instance, or [code]null[/code] if invalid.
func get_manager() -> AchievementsManager:
	if _manager_ref:
		var manager: AchievementsManager = _manager_ref.get_ref()
		return manager
	return null


## Unlocks the achievement and emits [signal achievement_unlocked] if the achievement is locked. If the achievement is already unlocked, this method does nothing.
func unlock() -> void:
	if is_unlocked():
		return
	set_unlocked(true)


## Returns a reference to the internal achievement data dictionary.[br]
## [br]
## [color=yellow]Warning:[/color] Modifying this dictionary will modify the data accessed by the AchievementEntry instance and the AchievementsManager instance as well.
func get_data() -> Dictionary:
	return _data


## Emits [signal achievement_updated] to notify that achievement data has been updated.[br]
## [br]
## Call this after modifying achievement properties (e.g., name, description, icon, or metadata) to signal
## that the achievement should be refreshed in UI or other systems.
func set_updated() -> void:
	achievement_updated.emit(self)


# Sends this achievement entry data to the debugger viewer for visualization.[br]
# [br]
# [b]For internal use.[/b] This is called automatically when achievement data changes.
func __send_entry_to_manager_viewer() -> void:
	if EngineDebugger.is_active():
		var manager: AchievementsManager = get_manager()
		if not is_instance_valid(manager):
			push_error("AchievementEntry: manager instance is invalid. Could not synchronize entry change.")
			return
		if manager.has_meta(&"deregistered"):
			return

		# Duplicate the achievement data to avoid modifying the runtime data
		var duplicated_achievement_data: Dictionary = _data.duplicate(true)

		# Convert the image into an object that we can send into the debugger
		if duplicated_achievement_data.has(AchievementEntry._key.ICON):
			var texture: Texture2D = duplicated_achievement_data[AchievementEntry._key.ICON]
			var image: Image = texture.get_image()
			duplicated_achievement_data[AchievementEntry._key.ICON] = var_to_bytes_with_objects(image)

		# Stringify metadata keys and values where needed for display
		var metadata: Dictionary = _data.get(_key.METADATA, { })
		if not metadata.is_empty():
			var stringified_metadata: Dictionary = { }
			for key: Variant in metadata:
				var value: Variant = metadata[key]
				if key is Callable or key is Object:
					stringified_metadata[str(key)] = str(value)
				else:
					stringified_metadata[key] = str(value)
			# Replace the source metadata with the stringified version that can be displayed remotely:
			duplicated_achievement_data[_key.METADATA] = stringified_metadata

		var achievements_manager_id: int = manager.get_instance_id()
		EngineDebugger.send_message("achievements_manager:sync_entry", [achievements_manager_id, _id, duplicated_achievement_data])


func _to_string() -> String:
	return "<AchievementEntry#%d>" % get_id()
