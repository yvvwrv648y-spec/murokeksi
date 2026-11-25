class_name PUWWorldClock
extends Node
## World clock and weather state for Pokemon Ultimate World.
##
## This is a living-world state holder only. It is NOT wired
## into any scene; callers read it and pass its values on.
##
## State:
## - day: int, starts at 1.
## - minute_of_day: int, 0..1439, starts at DEFAULT_MINUTE_OF_DAY
##   (600 = 10:00).
## - weather: String, one of exactly "clear", "rain", "sun",
##   "snow". Starts at "clear".
##
## Time-of-day ranges are THIS SYSTEM'S CONVENTION, a
## presentation choice, not sourced game data:
## - "day"   = 06:00-17:59 (minute_of_day 360..1079)
## - "dusk"  = 18:00-19:59 (minute_of_day 1080..1199)
## - "night" = 20:00-05:59 (minute_of_day 1200..1439, 0..359)
##
## Hook points for callers:
## - Evolution: pass get_time_of_day() as the evolution
##   context's "time_of_day" value and get_weather() as the
##   context's "weather" value. The evolution manager
##   (pokemon/evolution/evolution_manager.gd) accepts
##   "day" / "dusk" / "night" for its time_of_day rows and
##   reads context "weather" == "rain" for its
##   overworld-rain rows.
## - Encounters: encounter code can read get_time_of_day()
##   and get_weather() the same way to vary what appears.
##
## Persistence: to_dict() packs {day, minute_of_day, weather}
## and from_dict(d) restores it, for the save system.

const MINUTES_PER_DAY: int = 1440
const DEFAULT_MINUTE_OF_DAY: int = 600 # 10:00
const VALID_WEATHER: Array = ["clear", "rain", "sun", "snow"]
const DEFAULT_WEATHER: String = "clear"

var day: int = 1
var minute_of_day: int = DEFAULT_MINUTE_OF_DAY
var weather: String = DEFAULT_WEATHER


## Advance time by the given number of minutes (negative
## values are ignored: the clock only moves forward). Wraps
## past midnight, incrementing day once per full day passed.
func tick(minutes: int) -> void:
	if minutes <= 0:
		return
	var total: int = minute_of_day + minutes
	day += total / MINUTES_PER_DAY
	minute_of_day = total % MINUTES_PER_DAY


## "day", "dusk" or "night" for the current minute_of_day,
## using the ranges documented in the header.
func get_time_of_day() -> String:
	if minute_of_day >= 360 and minute_of_day < 1080:
		return "day"
	if minute_of_day >= 1080 and minute_of_day < 1200:
		return "dusk"
	return "night"


## True when get_time_of_day() is "night".
func is_night() -> bool:
	return get_time_of_day() == "night"


## Set the weather. Accepts only "clear", "rain", "sun" and
## "snow"; anything else is refused (returns false) and the
## current weather is left unchanged.
func set_weather(weather_id: String) -> bool:
	var candidate: String = weather_id.strip_edges().to_lower()
	if not VALID_WEATHER.has(candidate):
		return false
	weather = candidate
	return true


func get_weather() -> String:
	return weather


func get_day() -> int:
	return day


func get_minute_of_day() -> int:
	return minute_of_day


## Pack the state for saving.
func to_dict() -> Dictionary:
	return {
		"day": day,
		"minute_of_day": minute_of_day,
		"weather": weather,
	}


## Restore state packed by to_dict(). Invalid weather values
## are refused (the current weather is kept); minute_of_day
## wraps into 0..1439 and day is clamped to at least 1.
## Returns true when the dict was applied.
func from_dict(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	day = maxi(1, int(d.get("day", day)))
	minute_of_day = ((int(d.get("minute_of_day", minute_of_day)) % MINUTES_PER_DAY) + MINUTES_PER_DAY) % MINUTES_PER_DAY
	var weather_value: Variant = d.get("weather", weather)
	var candidate: String = str(weather_value).strip_edges().to_lower()
	if VALID_WEATHER.has(candidate):
		weather = candidate
	return true
