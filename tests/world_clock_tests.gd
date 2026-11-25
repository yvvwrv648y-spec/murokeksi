extends SceneTree
## Headless tests for the Pokemon Ultimate World world clock
## and weather state (PUWWorldClock).
##
## The clock under test is PUWWorldClock (world_clock.gd),
## merged at res://systems/world/world_clock.gd. It is a
## state holder only; nothing here wires it into a scene.
##
## How to run it (Godot 4.7, headless, no game window needed):
##   godot --headless --script res://tests/world_clock_tests.gd
## It prints one PASS or FAIL line per test, then a summary line,
## then quits. Exit code 0 means every test passed, 1 means at
## least one failed.
##
## Boundaries checked are this system's own documented
## convention: day = 06:00-17:59, dusk = 18:00-19:59,
## night = 20:00-05:59.

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _init() -> void:
	print("PUW world clock tests — starting.")
	if root == null:
		print("FAIL: no scene tree root. Run with: godot --headless --script res://tests/world_clock_tests.gd")
		quit(1)
		return
	_run("test_tick_advances_minutes_and_hours", Callable(self, "test_tick_advances_minutes_and_hours"))
	_run("test_tick_past_midnight_wraps_and_increments_day", Callable(self, "test_tick_past_midnight_wraps_and_increments_day"))
	_run("test_time_of_day_boundaries", Callable(self, "test_time_of_day_boundaries"))
	_run("test_set_weather_accepts_rain", Callable(self, "test_set_weather_accepts_rain"))
	_run("test_set_weather_refuses_hail", Callable(self, "test_set_weather_refuses_hail"))
	_run("test_to_dict_from_dict_round_trip", Callable(self, "test_to_dict_from_dict_round_trip"))
	print("PUW world clock tests — done: %d passed, %d failed." % [_passed, _failed])
	if _failed > 0:
		print("Failed tests: " + str(_failed_names))
		quit(1)
		return
	quit(0)


func _run(test_name: String, fn: Callable) -> void:
	var ok: bool = bool(fn.call())
	if ok:
		_passed += 1
		print("PASS: " + test_name)
	else:
		_failed += 1
		_failed_names.append(test_name)
		print("FAIL: " + test_name)


func _expect(cond: bool, what: String) -> bool:
	if not cond:
		print("  check failed: " + what)
	return cond


# Helper: a fresh clock set to an exact minute of day 1.
func _clock_at(minute_of_day: int) -> PUWWorldClock:
	var clock: PUWWorldClock = PUWWorldClock.new()
	clock.from_dict({"day": 1, "minute_of_day": minute_of_day, "weather": "clear"})
	return clock


# Test 1: tick advances minutes and hours correctly. The
# documented start is day 1 at 600 minutes (10:00): tick(30)
# gives 630 (10:30), tick(90) more gives 720 (12:00), and the
# day does not change.
func test_tick_advances_minutes_and_hours() -> bool:
	var ok: bool = true
	var clock: PUWWorldClock = PUWWorldClock.new()
	ok = _expect(clock.get_day() == 1, "a new clock must start on day 1") and ok
	ok = _expect(clock.get_minute_of_day() == 600, "a new clock must start at minute 600 (10:00), got " + str(clock.get_minute_of_day())) and ok
	clock.tick(30)
	ok = _expect(clock.get_minute_of_day() == 630, "tick(30) from 600 must give 630, got " + str(clock.get_minute_of_day())) and ok
	clock.tick(90)
	ok = _expect(clock.get_minute_of_day() == 720, "tick(90) from 630 must give 720, got " + str(clock.get_minute_of_day())) and ok
	ok = _expect(clock.get_day() == 1, "ticking within one day must not change the day") and ok
	clock.free()
	return ok


# Test 2: ticking past midnight wraps minute_of_day and
# increments day. From 23:50 (1430), tick(20) gives day 2 at
# minute 10. A full extra day of ticking lands on day 3 at
# the same minute.
func test_tick_past_midnight_wraps_and_increments_day() -> bool:
	var ok: bool = true
	var clock: PUWWorldClock = _clock_at(1430)
	clock.tick(20)
	ok = _expect(clock.get_day() == 2, "ticking past midnight must give day 2, got " + str(clock.get_day())) and ok
	ok = _expect(clock.get_minute_of_day() == 10, "ticking 20 minutes past 23:50 must wrap to minute 10, got " + str(clock.get_minute_of_day())) and ok
	clock.tick(1440)
	ok = _expect(clock.get_day() == 3, "ticking a full day must give day 3, got " + str(clock.get_day())) and ok
	ok = _expect(clock.get_minute_of_day() == 10, "ticking a full day must keep minute 10, got " + str(clock.get_minute_of_day())) and ok
	clock.free()
	return ok


# Test 3: get_time_of_day / is_night flip at the documented
# boundaries: 05:59 is night, 06:00 is day, 17:59 is day,
# 18:00 is dusk, 19:59 is dusk, 20:00 is night.
func test_time_of_day_boundaries() -> bool:
	var ok: bool = true
	var before_dawn: PUWWorldClock = _clock_at(359)
	ok = _expect(before_dawn.get_time_of_day() == "night", "05:59 must be night, got " + before_dawn.get_time_of_day()) and ok
	ok = _expect(before_dawn.is_night(), "is_night must be true at 05:59") and ok
	before_dawn.free()
	var dawn: PUWWorldClock = _clock_at(360)
	ok = _expect(dawn.get_time_of_day() == "day", "06:00 must be day, got " + dawn.get_time_of_day()) and ok
	ok = _expect(not dawn.is_night(), "is_night must be false at 06:00") and ok
	dawn.free()
	var late_day: PUWWorldClock = _clock_at(1079)
	ok = _expect(late_day.get_time_of_day() == "day", "17:59 must be day, got " + late_day.get_time_of_day()) and ok
	late_day.free()
	var dusk_start: PUWWorldClock = _clock_at(1080)
	ok = _expect(dusk_start.get_time_of_day() == "dusk", "18:00 must be dusk, got " + dusk_start.get_time_of_day()) and ok
	ok = _expect(not dusk_start.is_night(), "is_night must be false at 18:00") and ok
	dusk_start.free()
	var dusk_end: PUWWorldClock = _clock_at(1199)
	ok = _expect(dusk_end.get_time_of_day() == "dusk", "19:59 must be dusk, got " + dusk_end.get_time_of_day()) and ok
	dusk_end.free()
	var night_start: PUWWorldClock = _clock_at(1200)
	ok = _expect(night_start.get_time_of_day() == "night", "20:00 must be night, got " + night_start.get_time_of_day()) and ok
	ok = _expect(night_start.is_night(), "is_night must be true at 20:00") and ok
	night_start.free()
	return ok


# Test 4: set_weather("rain") is accepted and reads back.
func test_set_weather_accepts_rain() -> bool:
	var ok: bool = true
	var clock: PUWWorldClock = PUWWorldClock.new()
	ok = _expect(clock.get_weather() == "clear", "a new clock must start clear, got " + clock.get_weather()) and ok
	ok = _expect(clock.set_weather("rain"), "set_weather(\"rain\") must return true") and ok
	ok = _expect(clock.get_weather() == "rain", "weather must read back rain, got " + clock.get_weather()) and ok
	clock.free()
	return ok


# Test 5: set_weather("hail") is refused: "hail" is not one
# of the four weather ids, the call returns false, and the
# weather is unchanged.
func test_set_weather_refuses_hail() -> bool:
	var ok: bool = true
	var clock: PUWWorldClock = PUWWorldClock.new()
	ok = _expect(clock.set_weather("rain"), "set_weather(\"rain\") must succeed before the hail check") and ok
	ok = _expect(not clock.set_weather("hail"), "set_weather(\"hail\") must return false") and ok
	ok = _expect(clock.get_weather() == "rain", "weather must stay rain after a refused set, got " + clock.get_weather()) and ok
	clock.free()
	return ok


# Test 6: to_dict / from_dict round trip preserves day,
# minute_of_day and weather.
func test_to_dict_from_dict_round_trip() -> bool:
	var ok: bool = true
	var clock: PUWWorldClock = PUWWorldClock.new()
	clock.from_dict({"day": 4, "minute_of_day": 1250, "weather": "snow"})
	var packed: Dictionary = clock.to_dict()
	ok = _expect(int(packed.get("day", 0)) == 4, "to_dict day must be 4, got " + str(packed.get("day", 0))) and ok
	ok = _expect(int(packed.get("minute_of_day", 0)) == 1250, "to_dict minute_of_day must be 1250, got " + str(packed.get("minute_of_day", 0))) and ok
	ok = _expect(str(packed.get("weather", "")) == "snow", "to_dict weather must be snow, got " + str(packed.get("weather", ""))) and ok
	var restored: PUWWorldClock = PUWWorldClock.new()
	ok = _expect(restored.from_dict(packed), "from_dict must accept a to_dict result") and ok
	ok = _expect(restored.get_day() == 4, "restored day must be 4, got " + str(restored.get_day())) and ok
	ok = _expect(restored.get_minute_of_day() == 1250, "restored minute_of_day must be 1250, got " + str(restored.get_minute_of_day())) and ok
	ok = _expect(restored.get_weather() == "snow", "restored weather must be snow, got " + restored.get_weather()) and ok
	clock.free()
	restored.free()
	return ok
