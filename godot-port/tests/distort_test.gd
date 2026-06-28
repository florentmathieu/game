extends SceneTree
# Vérifie que la distorsion préserve l'adjacence (nb) et la connectivité (hops),
# ne change que la géométrie (centroïdes déplacés), et reconstruit les arêtes-murets.
const VMesh := preload("res://rules/Mesh.gd")

func _initialize() -> void:
	var m := VMesh.new()
	m.generate(424242, 720.0, 560.0, 50.0, 28.0)
	m.decorate(424242 ^ 0x9e37, 0.30)
	var n: int = m.cells.size()
	# instantané avant distorsion
	var nb_before: Array = []
	for c in m.cells: nb_before.append((c.nb as Array).duplicate())
	var ctr_before: Array = []
	for c in m.cells: ctr_before.append(Vector2(c.cx, c.cy))
	# échantillon de hops
	var pairs := [[0, n / 2], [0, n - 1], [1, n - 2], [n / 3, 2 * n / 3]]
	var hops_before: Array = []
	for p in pairs: hops_before.append(m.hops(p[0], p[1]))

	m.distort(0.5)   # ~ mission 8 (corruptLevel)

	var ok := true
	# 1) adjacence strictement identique
	for i in n:
		if (m.cells[i].nb as Array) != nb_before[i]: ok = false; break
	# 2) hops inchangés (graphe de déplacement préservé)
	for k in pairs.size():
		if m.hops(pairs[k][0], pairs[k][1]) != hops_before[k]: ok = false
	# 3) la géométrie a bougé (au moins un centroïde déplacé de façon notable)
	var moved := 0.0
	for i in n: moved = max(moved, ctr_before[i].distance_to(Vector2(m.cells[i].cx, m.cells[i].cy)))
	if moved < 1.0: ok = false
	# 4) arêtes-murets reconstruites
	if m.wall_seg.is_empty(): ok = false

	print("cells=%d  nb identiques=%s  hops identiques=%s  déplacement max=%.1f px  wall_seg=%d" % [
		n, ok, ok, moved, m.wall_seg.size()])
	print("\n%s" % ("OK — distorsion préserve l'adjacence" if ok else "!! divergence d'adjacence"))
	quit()
