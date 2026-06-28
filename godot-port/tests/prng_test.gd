extends SceneTree
const Rng = preload("res://rules/Rng.gd")
func _initialize() -> void:
	var rng := Rng.new(1234)
	for i in 8:
		print("%.10f" % rng.next())
	quit()
