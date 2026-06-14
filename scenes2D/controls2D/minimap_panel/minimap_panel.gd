extends PanelContainer

## Minimap / radar panel — decorative, with an optional coordinate readout.
## The animated radar sweep lives in a child RadarSweep (radar_sweep.gd).

@onready var _coord: Label = $Content/CoordLabel

## Replace the coordinate line text (e.g. "LAT 47.3  //  LON -122.4").
func set_coords(text: String) -> void:
	if _coord != null:
		_coord.text = text
