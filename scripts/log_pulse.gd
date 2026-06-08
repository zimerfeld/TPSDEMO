extends VBoxContainer

## Staggered pulse-glow on child Log* labels. Each label runs its own
## looped Tween on modulate:a, phase-offset across the feed so the
## brightness moves down the panel like a scan.

@export var pulse_min: float = 0.35
@export var pulse_max: float = 1.0
@export var pulse_period: float = 1.8

func _ready() -> void:
	var targets: Array[Label] = []
	for child in get_children():
		if child is Label and String(child.name).begins_with("Log"):
			targets.append(child)
	if targets.is_empty():
		return
	var step := pulse_period / float(targets.size())
	for i in range(targets.size()):
		var label := targets[i]
		label.modulate.a = pulse_max
		var tween := create_tween()
		tween.set_loops()
		tween.set_trans(Tween.TRANS_SINE)
		if i > 0:
			tween.tween_interval(step * float(i))
		tween.tween_property(label, "modulate:a", pulse_min, pulse_period * 0.5)
		tween.tween_property(label, "modulate:a", pulse_max, pulse_period * 0.5)
