class_name PUWWorldClockAndWeather
extends Node
## Section 9, 10 & M5: Regional Kanto day/night clock and weather simulation driving NPC schedules & Pokémon ecology.

signal hour_changed(hour_24: int, phase_name: String)
signal weather_changed(region_zone: String, weather_name: String)

var game_minutes: float = 480.0 # 08:00 Morning start
var minutes_per_real_second: float = 2.0
var active_weather: String = "CLEAR"

func get_phase_name() -> String:
	var h: int = int(game_minutes / 60.0) % 24
	if h >= 5 and h < 11: return "MORNING"
	if h >= 11 and h < 17: return "DAY"
	if h >= 17 and h < 20: return "SUNSET"
	return "NIGHT"

func step_clock(delta: float) -> void:
	var prev_h: int = int(game_minutes / 60.0) % 24
	game_minutes = fmod(game_minutes + delta * minutes_per_real_second, 1440.0)
	var cur_h: int = int(game_minutes / 60.0) % 24
	if cur_h != prev_h:
		hour_changed.emit(cur_h, get_phase_name())
