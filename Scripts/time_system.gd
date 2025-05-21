extends Node
class_name TimeSystem

# Configuration
@export var day_duration_seconds: float = 300.0 # 5 minutes per day
@export var dawn_duration_percent: float = 0.1 # Dawn is 10% of day
@export var day_duration_percent: float = 0.4 # Day is 40% of day
@export var dusk_duration_percent: float = 0.1 # Dusk is 10% of day
@export var night_duration_percent: float = 0.4 # Night is 40% of day
@export var start_time_of_day: String = "Day" # Starting time of day
@export var pause_time_at_night: bool = false # Useful for testing

# State tracking
var time_elapsed: float = 0.0
var day_progress: float = 0.0 # 0.0 to 1.0 representing progress through a day
var current_time_of_day: String = "Day"
var current_date: int = 1 # Day counter
var is_paused: bool = false

# Time thresholds (calculated in _ready)
var dawn_start: float = 0.0
var day_start: float = 0.0
var dusk_start: float = 0.0
var night_start: float = 0.0

# Signals
signal time_changed(new_time_of_day, current_date)
signal day_passed
signal time_cycle_fraction_changed(fraction, time_of_day)

func _ready():
	
	# Add to group for easy access
	add_to_group("TimeSystem")
	
	# Calculate time thresholds
	dawn_start = 0.0
	day_start = dawn_duration_percent
	dusk_start = day_start + day_duration_percent
	night_start = dusk_start + dusk_duration_percent
	
	# Set starting time
	current_time_of_day = start_time_of_day
	_set_day_progress_from_time_of_day(current_time_of_day)
	
	# Emit initial signal
	emit_signal("time_changed", current_time_of_day, current_date)
	# Connect to the time system if available
func _process(delta):
	if is_paused:
		return
		
	var debug_label = get_node_or_null("/root/Game/CanvasLayer/DebugLabel")
	if debug_label:
		debug_label.text = "Time: " + current_time_of_day + " | Day: " + str(current_date)
	# Don't update time at night if pause_time_at_night is enabled
	if pause_time_at_night and current_time_of_day == "Night":
		return
		
	# Update elapsed time
	time_elapsed += delta
	
	# Calculate day progress (0.0 to 1.0)
	day_progress = fmod(time_elapsed / day_duration_seconds, 1.0)
	
	# Determine time of day
	var old_time_of_day = current_time_of_day
	
	if day_progress >= night_start:
		current_time_of_day = "Night"
	elif day_progress >= dusk_start:
		current_time_of_day = "Dusk"
	elif day_progress >= day_start:
		current_time_of_day = "Day"
	else:
		current_time_of_day = "Dawn"
	
	# Check for day change
	if day_progress < 0.001 and time_elapsed >= day_duration_seconds:
		current_date += 1
		emit_signal("day_passed")
		print("TimeSystem: New day - Day " + str(current_date))
	
	# Emit signal when time of day changes
	if old_time_of_day != current_time_of_day:
		emit_signal("time_changed", current_time_of_day, current_date)
		print("TimeSystem: Time of day changed to " + current_time_of_day)
	
	# Always emit time cycle fraction (for smooth transitions)
	var cycle_fraction = 0.0
	if current_time_of_day == "Dawn":
		cycle_fraction = (day_progress - dawn_start) / dawn_duration_percent
	elif current_time_of_day == "Day":
		cycle_fraction = (day_progress - day_start) / day_duration_percent
	elif current_time_of_day == "Dusk":
		cycle_fraction = (day_progress - dusk_start) / dusk_duration_percent
	elif current_time_of_day == "Night":
		cycle_fraction = (day_progress - night_start) / night_duration_percent
	
	emit_signal("time_cycle_fraction_changed", cycle_fraction, current_time_of_day)

func _set_day_progress_from_time_of_day(time_of_day):
	# Set day progress based on the time of day (for initialization)
	match time_of_day:
		"Dawn":
			day_progress = dawn_start + (dawn_duration_percent / 2)
		"Day":
			day_progress = day_start + (day_duration_percent / 2)
		"Dusk":
			day_progress = dusk_start + (dusk_duration_percent / 2)
		"Night":
			day_progress = night_start + (night_duration_percent / 2)
	
	# Calculate the elapsed time
	time_elapsed = day_progress * day_duration_seconds

# Control methods
func pause_time():
	is_paused = true

func resume_time():
	is_paused = false

func set_time_of_day(time_of_day):
	if time_of_day in ["Dawn", "Day", "Dusk", "Night"]:
		current_time_of_day = time_of_day
		_set_day_progress_from_time_of_day(time_of_day)
		emit_signal("time_changed", current_time_of_day, current_date)

func skip_to_next_day():
	current_date += 1
	day_progress = 0.0
	time_elapsed = current_date * day_duration_seconds
	current_time_of_day = "Dawn"
	emit_signal("day_passed")
	emit_signal("time_changed", current_time_of_day, current_date)

# Utility methods
func get_time_name():
	return current_time_of_day

func get_date():
	return current_date

func get_day_progress():
	return day_progress

func is_time_between(start_time, end_time):
	# Check if current time is between start and end times
	var times = ["Dawn", "Day", "Dusk", "Night"]
	var start_index = times.find(start_time)
	var end_index = times.find(end_time)
	var current_index = times.find(current_time_of_day)
	
	if start_index == -1 or end_index == -1 or current_index == -1:
		return false
	
	if start_index <= end_index:
		return current_index >= start_index and current_index <= end_index
	else:
		# Handle case where we wrap around (e.g., Night to Dawn)
		return current_index >= start_index or current_index <= end_index
