class_name PUWPlatformManager
extends Node
## Addendum Section 8: Platform-aware renderer & mobile safe-area manager (Desktop / Mobile / Web).
func get_target_profile() -> String:
	if OS.has_feature("web"): return "web_compatibility"
	if OS.has_feature("ios") or OS.has_feature("android"): return "native_mobile"
	return "desktop_forward_plus"
