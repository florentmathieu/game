extends SceneTree
const VMesh = preload("res://rules/Mesh.gd")
func _initialize() -> void:
	var m := VMesh.new()
	m.generate(2026, 720, 560, 44, 28)
	var cs := 0
	for c in m.cells: cs += int(c.cx) + int(c.cy)
	var e := 0
	for c in m.cells: e += c.nb.size()
	print("GODOT cells=%d checksum=%d edges2=%d" % [m.cells.size(), cs, e])
	quit()
