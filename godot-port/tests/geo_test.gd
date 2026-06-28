extends SceneTree
const Geo = preload("res://rules/Geo.gd")
func _initialize() -> void:
	for a in [[1,10],[2,20],[3,20]]:
		var g = Geo.new(); g.generate(1234 + a[0], a[0], a[1])
		var forge := 0; var boss := 0
		for c in g.info: if g.info[c].forge: forge += 1
		for c in g.info: if g.info[c].boss: boss += 1
		print("acte%d: régions=%d forge=%d boss=%d camp=%d" % [a[0], g.info.size(), forge, boss, g.camp])
	quit()
