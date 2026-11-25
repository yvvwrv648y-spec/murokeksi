class_name PUWBikeRigFacade
extends RefCounted
## Small facade joining PUWBikes (logic / co-op lock) with
## PUWBikeRigLoader (art). Added as a separate file so bikes.gd does
## not need editing: tandem rigs are only handed out when
## PUWBikes.tandem_available(coop_active) is true, exactly the
## existing lock. Solo rigs are available regardless of co-op.


static func solo_rig(cast_id: String) -> Dictionary:
	return PUWBikeRigLoader.build_solo_frames(cast_id)


static func tandem_rig(driver_id: String, passenger_id: String, coop_active: bool) -> Dictionary:
	if not PUWBikes.tandem_available(coop_active):
		return {"frames": null, "status": "locked_coop_inactive", "frame_count": 0, "sheet": ""}
	return PUWBikeRigLoader.build_tandem_frames(driver_id, passenger_id)
